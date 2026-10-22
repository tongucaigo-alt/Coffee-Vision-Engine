import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'local_store.dart';
import 'models.dart';

abstract interface class GalleryPicker {
  Future<Uint8List?> pick();
  Future<Uint8List?> recover();
}

abstract interface class MultiGalleryPicker implements GalleryPicker {
  Future<List<Uint8List>> pickMany({int limit = 3});
  Future<List<Uint8List>> recoverMany({int limit = 3});
}

class GallerySelectionLimit extends FormatException {
  const GallerySelectionLimit(super.message);
}

String _cupLimitMessage(int limit) => limit == 3
    ? 'En fazla 3 fincan fotoğrafı seçebilirsin.'
    : limit > 0
    ? 'Bu çalışmaya en fazla $limit fincan fotoğrafı daha ekleyebilirsin.'
    : 'Bu çalışmada zaten 3 fincan fotoğrafı var. Mevcut bir fotoğrafı değiştirebilirsin.';

void _checkGalleryCount(int count, int limit, {bool cups = false}) {
  if (count > limit || limit < 1) {
    throw GallerySelectionLimit(
      cups
          ? _cupLimitMessage(limit)
          : 'Bu alan için yalnız 1 fotoğraf seçebilirsin.',
    );
  }
}

class AndroidGalleryPicker implements MultiGalleryPicker {
  AndroidGalleryPicker({ImagePicker? imagePicker})
    : _picker = imagePicker ?? ImagePicker();

  final ImagePicker _picker;
  @override
  Future<List<Uint8List>> pickMany({int limit = 3}) async {
    RangeError.checkValueInInterval(limit, 1, 3, 'limit');
    if (limit == 1) return [if (await pick() case final Uint8List bytes) bytes];
    final files = await _picker.pickMultiImage(
      requestFullMetadata: false,
      limit: limit,
    );
    // Older system pickers may ignore the cap. Reject before reading any images.
    _checkGalleryCount(files.length, limit, cups: true);
    return [for (final file in files) await file.readAsBytes()];
  }

  @override
  Future<List<Uint8List>> recoverMany({int limit = 3}) async {
    RangeError.checkValueInInterval(limit, 1, 3, 'limit');
    final lost = await _picker.retrieveLostData();
    if (lost.exception != null) throw lost.exception!;
    _checkGalleryCount(lost.files?.length ?? 0, limit, cups: true);
    return [for (final file in lost.files ?? []) await file.readAsBytes()];
  }

  @override
  Future<Uint8List?> pick() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: false,
    );
    return file?.readAsBytes();
  }

  @override
  Future<Uint8List?> recover() async {
    final lost = await _picker.retrieveLostData();
    if (lost.exception != null) throw lost.exception!;
    if (lost.files == null || lost.files!.isEmpty) return null;
    _checkGalleryCount(lost.files!.length, 1);
    return lost.files!.single.readAsBytes();
  }
}

class GalleryImport {
  GalleryImport(this.store, this.picker);
  final DraftStore store;
  final GalleryPicker picker;

  Future<ContributionDraft?> select(ContributionDraft base) async {
    if (!base.isGallery || base.queued) {
      throw ArgumentError('Invalid gallery draft');
    }
    await store.saveGalleryPending(base);
    try {
      return await _finish(base, await picker.pick());
    } catch (_) {
      await store.saveGalleryPending(null);
      rethrow;
    }
  }

  Future<ContributionDraft?> recover() async {
    final pending = await store.galleryPending();
    final current = await store.load();
    if (pending?['operation'] == 'photoSet') {
      return PhotoSetGallery(store, picker).recover(pending!);
    }
    if (pending?['draft'] == null) return current;
    final bytes = await picker.recover();
    final base = ContributionDraft.fromJson(
      Map<String, dynamic>.from(pending!['draft'] as Map),
    );
    // A committed replacement must not be imported twice after process death.
    if (current != null &&
        (current.id != base.id ||
            (current.photos.isNotEmpty &&
                (base.photos.isEmpty ||
                    current.photos.single.localName !=
                        base.photos.single.localName)))) {
      await store.saveGalleryPending(null);
      return current;
    }
    try {
      return await _finish(base, bytes) ?? current;
    } catch (_) {
      await store.saveGalleryPending(null);
      rethrow;
    }
  }

  Future<ContributionDraft?> _finish(
    ContributionDraft base,
    Uint8List? bytes,
  ) async {
    if (bytes == null) {
      await store.saveGalleryPending(null);
      return null;
    }
    final photo = await store.importGallery(bytes);
    final next = base.withPhoto(photo);
    await store.save(next);
    try {
      await store.saveGalleryPending(null);
      await store.collectOrphans();
    } catch (_) {
      // The durable import succeeded; cleanup must not hide it from the UI.
    }
    return next;
  }
}

/// Imports a batch atomically; the pending snapshot also identifies a replacement
/// across Android picker process recreation. Never infer a pose from selection order.
class PhotoSetGallery {
  PhotoSetGallery(this.store, this.picker);
  final DraftStore store;
  final GalleryPicker picker;
  Future<ContributionDraft?> select(
    ContributionDraft base, {
    PhotoSurface surface = PhotoSurface.cup,
    String? replaceId,
  }) async {
    if (!base.isSet || base.queued) throw ArgumentError('Invalid photo set');
    final limit = _selectionLimit(base, surface, replaceId);
    _checkGalleryCount(0, limit, cups: surface == PhotoSurface.cup);
    final operation = <String, dynamic>{
      'operation': 'photoSet',
      'draft': base.toJson(),
      'surface': surface.name,
      'replaceId': replaceId,
    };
    await store.saveSetGalleryPending(operation);
    try {
      final many =
          surface == PhotoSurface.cup && replaceId == null && limit > 1;
      final items = many && picker is MultiGalleryPicker
          ? await (picker as MultiGalleryPicker).pickMany(limit: limit)
          : [if (await picker.pick() case final Uint8List bytes) bytes];
      return await _finish(operation, items);
    } catch (_) {
      await store.saveSetGalleryPending(null);
      rethrow;
    }
  }

  Future<ContributionDraft?> recover(Map<String, dynamic> operation) async {
    final current = await store.load();
    // A completed batch or unrelated newer edit wins over a stale picker result.
    if (current != null &&
        jsonEncode(current.toJson()) != jsonEncode(operation['draft'])) {
      await store.saveSetGalleryPending(null);
      return current;
    }
    try {
      final base = ContributionDraft.fromJson(
        Map<String, dynamic>.from(operation['draft'] as Map),
      );
      final surface = PhotoSurface.values.byName(
        operation['surface'] as String,
      );
      final limit = _selectionLimit(
        base,
        surface,
        operation['replaceId'] as String?,
      );
      _checkGalleryCount(0, limit, cups: surface == PhotoSurface.cup);
      final many =
          surface == PhotoSurface.cup && operation['replaceId'] == null;
      final items = many && picker is MultiGalleryPicker
          ? await (picker as MultiGalleryPicker).recoverMany(limit: limit)
          : [if (await picker.recover() case final Uint8List bytes) bytes];
      return await _finish(operation, items) ?? current;
    } catch (_) {
      await store.saveSetGalleryPending(null);
      rethrow;
    }
  }

  Future<ContributionDraft?> _finish(
    Map<String, dynamic> operation,
    List<Uint8List> items,
  ) async {
    if (items.isEmpty) {
      await store.saveSetGalleryPending(null);
      return null;
    }
    final base = ContributionDraft.fromJson(
      Map<String, dynamic>.from(operation['draft'] as Map),
    );
    final surface = PhotoSurface.values.byName(operation['surface'] as String);
    final replaceId = operation['replaceId'] as String?;
    final old = base.photos.where((p) => p.id == replaceId).firstOrNull;
    if (replaceId != null && old == null) {
      throw StateError('Missing replacement');
    }
    // Validate the entire batch before creating a derivative or changing a draft.
    _checkGalleryCount(
      items.length,
      _selectionLimit(base, surface, replaceId),
      cups: surface == PhotoSurface.cup && replaceId == null,
    );
    var next = base;
    for (final bytes in items) {
      final imported = await store.importGallery(bytes);
      if (next.photos.any(
        (p) =>
            p.id != replaceId &&
            (p.checksum == imported.checksum ||
                p.originalChecksum == imported.originalChecksum),
      )) {
        continue;
      }
      final photo = imported.asSetPhoto(
        photoId: replaceId,
        type: surface,
        angle: old?.angle,
      );
      next = next.withPhoto(photo);
    }
    if (surface == PhotoSurface.saucer && next.saucers.isNotEmpty) {
      next = next.copy(saucerDecided: true);
    }
    await store.save(next);
    try {
      await store.saveSetGalleryPending(null);
      await store.collectOrphans();
    } catch (_) {
      // The committed batch remains usable even if optional cleanup fails.
    }
    return next;
  }

  int _selectionLimit(
    ContributionDraft base,
    PhotoSurface surface,
    String? replaceId,
  ) {
    if (replaceId != null) {
      if (!base.photos.any((p) => p.id == replaceId && p.surface == surface)) {
        throw StateError('Missing replacement');
      }
      return 1;
    }
    return surface == PhotoSurface.cup
        ? 3 - base.cups.length
        : 1 - base.saucers.length;
  }
}
