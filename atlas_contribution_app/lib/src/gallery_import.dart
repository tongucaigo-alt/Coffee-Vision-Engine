import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'local_store.dart';
import 'models.dart';

abstract interface class GalleryPicker {
  Future<Uint8List?> pick();
  Future<Uint8List?> recover();
}

class AndroidGalleryPicker implements GalleryPicker {
  final _picker = ImagePicker();
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
