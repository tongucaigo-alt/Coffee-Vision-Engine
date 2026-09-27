import 'dart:io';
import 'package:flutter/foundation.dart';
import '../fortune_progress.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../local_store.dart';
import '../mvp/review_store.dart';
import 'ai_bridge.dart';
import 'ai_client.dart';
import 'ai_contract.dart';
import 'ai_store.dart';
import 'ai_bundled.dart';

class AiRuntime {
  AiRuntime._(this.store, this.reviews, this.bridge, this.client, this.readKey);
  final Future<String> Function(AiProfile)? readKey;
  final progress = ValueNotifier<FortuneProgress>(
    const FortuneProgress(FortunePhase.saving),
  );
  final AiStore store;
  final ReviewStore reviews;
  final AiBridge bridge;
  final AiClient client;
  final FlutterSecureStorage _secrets = const FlutterSecureStorage();
  static Future<AiRuntime> create(
    DraftStore source, {
    AiClient? client,
    Future<String> Function(AiProfile)? readKey,
  }) async {
    final store = AiStore(
      Directory('${source.directory.parent.path}/ai-local'),
    );
    await store.recoverInterruptedResults();
    if (bundledKimiEnabled) {
      await store.change((data) {
        final profiles = data['profiles'] as List;
        profiles.removeWhere((p) => p['id'] == bundledKimiProfile.id);
        profiles.insert(0, bundledKimiProfile.toJson());
      });
    }
    final reviews = ReviewStore(
      Directory('${source.directory.parent.path}/mvp-reviews'),
      contributionStore: source,
    );
    reviews.additionalExposures = store.exposures;
    reviews.aiExposureAudit = store.researchAudit;
    reviews.onDelete = store.deleteSession;
    final bridge = AiBridge(source, reviews, store);
    source.onDeleteRoot = bridge.deleteRoot;
    await bridge.reconcile();
    return AiRuntime._(
      store,
      reviews,
      bridge,
      client ??
          AiClient(
            FortunePrompt(
              await rootBundle.loadString('assets/fortune-prompt-v1.json'),
            ),
          ),
      readKey,
    );
  }

  Future<String> key(AiProfile p) async => isBundledProfile(p)
      ? bundledCredential(p)
      : readKey != null
      ? await readKey!(p)
      : await _secrets.read(key: p.credentialKey) ?? '';
  Future<void> saveProfile(AiProfile p, String key) async {
    if (isBundledProfile(p)) {
      throw const AiFailure('Hazır test bağlantısı değiştirilemez.');
    }
    validateAiUrl(p.url);
    final old = (await store.profiles()).where((v) => v.id == p.id).firstOrNull;
    await _secrets.write(key: p.credentialKey, value: key);
    await store.saveProfile(p);
    if (old != null && old.credentialKey != p.credentialKey) {
      await _secrets.delete(key: old.credentialKey);
    }
  }
}
