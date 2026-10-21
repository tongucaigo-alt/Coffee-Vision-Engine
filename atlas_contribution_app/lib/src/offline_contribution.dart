import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

import 'local_store.dart';
import 'models.dart';
import 'service.dart';

class OfflineContributionService implements ContributionBackend {
  OfflineContributionService(this.store);

  final DraftStore store;

  @override
  bool get isOffline => true;

  @override
  Future<Map<String, dynamic>> call(
    String action, [
    Map<String, dynamic> data = const {},
  ]) async {
    if (action == 'cancel') return const {};
    throw const ContributionFailure('Bu işlem yerel toplama modunda yok.');
  }

  @override
  Future<void> delete(String rootId) async {}

  @override
  Future<List<Map<String, dynamic>>> list({bool admin = false}) {
    if (admin) {
      throw const ContributionFailure('Yerel toplama modunda yönetici yok.');
    }
    return store.receipts();
  }

  @override
  Future<Map<String, String>> photoUrls(String id) async => const {};

  @override
  Future<Uint8List> readPhoto(String id, ContributionPhoto photo) =>
      store.file(photo.localName).readAsBytes();

  @override
  Future<Map<String, dynamic>> submit(
    ContributionDraft draft,
    Future<Uint8List> Function(ContributionPhoto) read,
    void Function(int complete) progress,
  ) async {
    if (!draft.reviewed) {
      throw const ContributionFailure('Önce fotoğrafları gözden geçir.');
    }
    for (var i = 0; i < draft.photos.length; i++) {
      final photo = draft.photos[i];
      final bytes = await read(photo);
      if (bytes.length != photo.byteLength ||
          'sha256:${sha256.convert(bytes)}' != photo.checksum) {
        throw const ContributionFailure(
          'Fotoğraf doğrulanamadı. Kayıt telefonda korunuyor.',
        );
      }
      progress(i + 1);
    }
    final now = DateTime.now().toUtc();
    return {
      'id': draft.id,
      'root_id': draft.rootId,
      'group_id': draft.groupId,
      'submitted_at': now.toIso8601String(),
      'expires_at': null,
      'retention': 'manual',
      'local_only': true,
      if (await store.hasLocalAcceptance())
        'localUseVersion': DraftStore.localAcceptanceVersion,
      'document': draft.copy(queued: false).toJson(),
    };
  }
}
