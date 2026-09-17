import '../gallery_import.dart';
import '../models.dart';
import 'review_models.dart';
import 'review_store.dart';

final class ReviewGallery {
  ReviewGallery(this.store, this.picker);
  final ReviewStore store;
  final GalleryPicker picker;
  Future<ReviewSession?> select(
    ReviewSession session,
    ReviewSurface surface,
    CaptureRole? role, {
    String? replaceId,
  }) async {
    final intent = {
      'id': session.id,
      'revision': session.revision,
      'surface': surface.name,
      'role': role?.name,
      'replaceId': replaceId,
    };
    await store.galleryIntent(intent);
    try {
      return await _finish(intent, await picker.pick());
    } catch (_) {
      await store.galleryIntent(null);
      rethrow;
    }
  }

  Future<ReviewSession?> recover() async {
    final intent = await store.pendingGallery();
    if (intent == null) return null;
    try {
      return await _finish(intent, await picker.recover());
    } catch (_) {
      await store.galleryIntent(null);
      rethrow;
    }
  }

  Future<ReviewSession?> _finish(
    Map<String, dynamic> intent,
    dynamic bytes,
  ) async {
    final current = (await store.sessions())
        .where((s) => s.id == intent['id'])
        .firstOrNull;
    if (bytes == null ||
        current == null ||
        current.deleted ||
        current.revision != intent['revision']) {
      await store.galleryIntent(null);
      return current;
    }
    final photo = await store.importPhoto(
      bytes,
      surface: ReviewSurface.values.byName(intent['surface'] as String),
      declaredRole: intent['role'] == null
          ? null
          : CaptureRole.values.byName(intent['role'] as String),
    );
    final next = current.next(
      photos: [
        for (final p in current.photos)
          if (p.id == intent['replaceId']) photo else p,
        if (intent['replaceId'] == null) photo,
      ],
    );
    await store.save(next);
    await store.galleryIntent(null);
    return next;
  }
}
