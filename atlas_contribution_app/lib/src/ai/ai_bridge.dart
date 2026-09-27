import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../local_store.dart';
import '../models.dart';
import '../mvp/review_models.dart';
import '../mvp/review_store.dart';
import 'ai_contract.dart';
import 'ai_store.dart';

class AiBridge {
  AiBridge(this.source, this.reviews, this.ai);
  final DraftStore source;
  final ReviewStore reviews;
  final AiStore ai;
  Future<void> _tail = Future.value();
  String sessionId(String root) => 'linked-$root';
  Future<ReviewSession> importReceipt(
    Map<String, dynamic> row, {
    bool fresh = false,
  }) {
    final work = _tail.then((_) => _import(row, fresh: fresh));
    _tail = work.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return work;
  }

  Future<ReviewSession> _import(
    Map<String, dynamic> row, {
    required bool fresh,
  }) async {
    final root = row['root_id'] as String;
    if ((await source.pendingDeletes()).contains(root)) {
      throw const AiFailure('Kayıt silinmeyi bekliyor.');
    }
    final receipts = (await source.receipts())
        .where((r) => r['root_id'] == root && r['local_only'] == true)
        .toList();
    receipts.sort(
      (a, b) => ((b['document'] as Map)['revision'] as int).compareTo(
        (a['document'] as Map)['revision'] as int,
      ),
    );
    if (receipts.isEmpty) {
      throw const AiFailure('Kaynak kayıt silinmiş veya süresi dolmuş.');
    }
    row = receipts.first;
    final draft = ContributionDraft.fromJson(
      Map<String, dynamic>.from(row['document'] as Map),
    );
    if (!draft.reviewed || draft.cups.isEmpty) {
      throw const AiFailure('Fincan fotoğraflarını gözden geçir.');
    }
    await reviews.initialize();
    final id = sessionId(root);
    final old = (await reviews.sessions()).where((s) => s.id == id).firstOrNull;
    if (old?.deleted == true || await ai.isDeleted(id)) {
      throw const AiFailure('Kayıt silinmiş.');
    }
    final link = ((await ai.read())['links'] as Map)[root] as Map?;
    if (old != null && link?['receiptId'] == draft.id) return old;
    final photos = <ReviewPhoto>[];
    for (final p in draft.photos) {
      final pid =
          'linked-${sha256.convert(utf8.encode('$root|${p.localName}|${p.checksum}'))}';
      final data = p.toJson()..['localName'] = '$pid.jpg';
      final photo = ContributionPhoto.fromJson(data);
      final bytes = await source.file(p.localName).readAsBytes();
      if (bytes.length != p.byteLength ||
          'sha256:${sha256.convert(bytes)}' != p.checksum) {
        throw const AiFailure('Fotoğraf doğrulanamadı.');
      }
      await reviews.file('$pid.pending').writeAsBytes(bytes, flush: true);
      await reviews.file('$pid.pending').rename(reviews.file('$pid.jpg').path);
      final surface = p.surface == PhotoSurface.saucer
          ? ReviewSurface.saucer
          : ReviewSurface.cup;
      final previous = old?.photos
          .where(
            (e) =>
                e.id == pid &&
                e.surface == surface &&
                e.declaredRole == p.angle,
          )
          .firstOrNull;
      photos.add(
        previous?.update(photo: photo) ??
            ReviewPhoto(
              id: pid,
              photo: photo,
              surface: surface,
              declaredRole: p.angle,
              displayCrop: p.displayCrop,
            ),
      );
    }
    final samePhotos =
        old != null &&
        old.photos.length == photos.length &&
        photos.every(
          (p) => old.photos.any(
            (q) =>
                q.id == p.id &&
                q.surface == p.surface &&
                q.declaredRole == p.declaredRole,
          ),
        );
    final now = DateTime.now().toUtc().toIso8601String();
    final next =
        old?.next(
          photos: photos,
          sameSample: samePhotos ? old.sameSampleDeclared : false,
        ) ??
        ReviewSession(
          id: id,
          groupId: draft.groupId,
          createdAtUtc: now,
          localConsentAtUtc: draft.consentedAt,
          observationHistory: fresh && draft.revision == 1
              ? 'known'
              : 'unknown',
          photos: photos,
        );
    await reviews.save(next);
    await ai.change((d) {
      (d['links'] as Map)[root] = {
        'sessionId': id,
        'receiptId': draft.id,
        'revision': draft.revision,
      };
    });
    return next;
  }

  Future<void> deleteRoot(String root) async {
    final id = sessionId(root);
    await ai.deleteSession(id);
    await reviews.initialize();
    final s = (await reviews.sessions()).where((s) => s.id == id).firstOrNull;
    if (s != null) await reviews.delete(s);
  }

  Future<void> reconcile() async {
    await reviews.initialize();
    final roots = (await source.receipts()).map((r) => r['root_id']).toSet();
    final pending = (await source.pendingDeletes()).toSet();
    final links = (await ai.read())['links'] as Map;
    for (final root in links.keys.cast<String>().toList()) {
      if (!roots.contains(root) || pending.contains(root)) {
        await deleteRoot(root);
      }
    }
  }

  Future<bool> isCurrent(ReviewSession snapshot) async {
    await reconcile();
    if (await ai.isDeleted(snapshot.id)) return false;
    if (snapshot.id.startsWith('linked-')) {
      final root = snapshot.id.substring(7);
      final rows = (await source.receipts())
          .where((r) => r['root_id'] == root)
          .toList();
      if (rows.isEmpty) return false;
      final current = await importReceipt(rows.first);
      return !current.deleted &&
          preparationSourceFingerprint(current) ==
              preparationSourceFingerprint(snapshot);
    }
    final current = (await reviews.sessions())
        .where((s) => s.id == snapshot.id)
        .firstOrNull;
    return current != null &&
        !current.deleted &&
        preparationSourceFingerprint(current) ==
            preparationSourceFingerprint(snapshot);
  }
}
