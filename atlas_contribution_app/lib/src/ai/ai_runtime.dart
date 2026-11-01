import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import '../fortune_progress.dart';
import '../fortune_preparation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../local_store.dart';
import '../opencv_traces.dart';
import '../mvp/review_store.dart';
import 'ai_bridge.dart';
import 'ai_client.dart';
import 'ai_contract.dart';
import 'ai_store.dart';
import 'ai_bundled.dart';
import 'local_performance_probe.dart';
import '../user_profile_store.dart';

class AiRuntime {
  AiRuntime._(
    this.store,
    this.reviews,
    this.bridge,
    this.client,
    this.readKey,
    this.traces,
  );
  final TraceService traces;
  final Future<String> Function(AiProfile)? readKey;
  final progress = ValueNotifier<FortuneProgress>(
    const FortuneProgress(FortunePhase.saving),
  );
  late final preparation = FortunePreparationController(progress);
  final AiStore store;
  final ReviewStore reviews;
  final AiBridge bridge;
  final AiClient client;
  UserProfileStore get userProfile => UserProfileStore(
    Directory('${store.directory.parent.path}/user-profile'),
  );
  Future<UserProfile> readingProfile() async {
    try {
      return await userProfile.read();
    } catch (_) {
      return const UserProfile();
    }
  }

  final FlutterSecureStorage _secrets = const FlutterSecureStorage();
  static Future<AiRuntime> create(
    DraftStore source, {
    AiClient? client,
    Future<String> Function(AiProfile)? readKey,
  }) async {
    source.protectLinkedAiData();
    await source.ensureWritable();
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
    final traces = TraceService(
      Directory('${source.directory.parent.path}/opencv-traces'),
    );
    reviews.onDelete = (id) async {
      await store.deleteSession(id);
      await traces.deleteOwner(id);
    };
    final bridge = AiBridge(source, reviews, store);
    await bridge.reconcile();
    final runtime = AiRuntime._(
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
      traces,
    );
    // Publish the cross-store callback only after all initialization succeeded.
    source.onDeleteRoot = (root) async {
      await traces.deleteOwner(bridge.sessionId(root));
      await bridge.deleteRoot(root);
    };
    if (kDebugMode &&
        aiLabEnabled &&
        const bool.fromEnvironment('ATLAS_DIAGNOSTIC')) {
      // Measurement failures cannot change startup/recovery behavior.
      await runRequestedLocalPerformanceProbe(bridge).catchError((Object _) {});
    }
    return runtime;
  }

  Future<int> sendPendingReports() async {
    final profiles = await store.profiles();
    for (final row in await store.pendingReports()) {
      final profile = profiles
          .where((p) => p.id == row['profileId'] && p.url == row['url'])
          .firstOrNull;
      if (profile == null || profile.provider != AiProvider.atlas) continue;
      try {
        await client.sendReport(profile, await key(profile), {
          'version': 1,
          'id': row['id'],
          'reason': row['reason'],
          'text': row['text'],
        });
        await store.markReportSent(row['id'] as String);
      } catch (_) {
        /* Retain until an explicit retry. Never claim delivery. */
      }
    }
    return (await store.pendingReports()).length;
  }

  /// Generation providers are never used as moderation endpoints. The target
  /// must still be an explicitly configured, authenticated Atlas profile.
  Future<bool> submitContentReport({
    required AiProfile target,
    required String sessionId,
    required String contentId,
    required String text,
    required String reason,
  }) async {
    if (target.provider != AiProvider.atlas ||
        !['misleading', 'harmful', 'other'].contains(reason) ||
        text.trim().isEmpty ||
        text.length > 12000) {
      throw const AiFailure('Bildirim bilgisi geçersiz.');
    }
    final profiles = await store.profiles();
    if (!profiles.any(
      (p) =>
          p.provider == AiProvider.atlas &&
          p.id == target.id &&
          p.url == target.url,
    )) {
      throw const AiFailure('Bildirim bağlantısı değişti. Yeniden seçmelisin.');
    }
    final id = const Uuid().v5(
      '6ba7b811-9dad-11d1-80b4-00c04fd430c8',
      '${target.id}|${target.url}|$sessionId|$contentId|$reason|${sha256.convert(utf8.encode(text))}',
    );
    await store.queueReport({
      'id': id,
      'sessionId': sessionId,
      'profileId': target.id,
      'url': target.url,
      'reason': reason,
      'text': text,
      'state': 'pending',
    });
    await sendPendingReports();
    return !(await store.pendingReports()).any((r) => r['id'] == id);
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
    if (playTestEnabled && p.provider != AiProvider.atlas) {
      throw const AiFailure('Bu sürüm Atlas test bağlantısını kullanır.');
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
