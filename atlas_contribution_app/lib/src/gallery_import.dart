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
  Future<List<Uint8List>> pickMany();
  Future<List<Uint8List>> recoverMany();
}

class AndroidGalleryPicker implements MultiGalleryPicker {
  final _picker = ImagePicker();
  @override
  Future<List<Uint8List>> pickMany() async => [
    for (final file in await _picker.pickMultiImage(requestFullMetadata: false))
      await file.readAsBytes(),
  ];
  @override
  Future<List<Uint8List>> recoverMany() async {
    final lost = await _picker.retrieveLostData();
    if (lost.exception != null) throw lost.exception!;
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
    if (lost.files!.length != 1) {
      throw const FormatException('Expected one photo');
    }
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
    final operation = <String, dynamic>{
      'operation': 'photoSet',
      'draft': base.toJson(),
      'surface': surface.name,
      'replaceId': replaceId,
    };
    await store.saveSetGalleryPending(operation);
    try {
      final many = surface == PhotoSurface.cup && replaceId == null;
      final items = many && picker is MultiGalleryPicker
          ? await (picker as MultiGalleryPicker).pickMany()
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
      final items = picker is MultiGalleryPicker
          ? await (picker as MultiGalleryPicker).recoverMany()
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
    if ((replaceId != null || surface == PhotoSurface.saucer) &&
        items.length != 1) {
      throw const FormatException('Bu alan için bir fotoğraf seç.');
    }
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
}
