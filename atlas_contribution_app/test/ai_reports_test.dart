import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/ai/ai_store.dart';
import 'package:atlas_contribution_app/src/ai/ai_runtime.dart';
import 'package:atlas_contribution_app/src/ai/ai_client.dart';
import 'package:atlas_contribution_app/src/ai/ai_contract.dart';
import 'package:atlas_contribution_app/src/local_store.dart';
import 'package:flutter/services.dart';

class ReportClient extends AiClient {
  ReportClient(super.prompt);
  bool offline = true;
  final sent = <Map<String, dynamic>>[];
  @override
  Future<void> sendReport(
    AiProfile profile,
    String key,
    Map<String, dynamic> report,
  ) async {
    if (offline) throw const AiFailure('Offline');
    sent.add(report);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'offline reports persist and a changed address never receives old reports',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'atlas-report-runtime-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final source = DraftStore(Directory('${directory.path}/source'));
      await source.initialize();
      final client = ReportClient(
        FortunePrompt(
          await rootBundle.loadString('assets/fortune-prompt-v1.json'),
        ),
      );
      final runtime = await AiRuntime.create(
        source,
        client: client,
        readKey: (_) async => 'secret',
      );
      const profile = AiProfile(
        id: 'test',
        name: 'Atlas',
        url: 'https://original.example',
        model: 'atlas',
        provider: AiProvider.atlas,
      );
      await runtime.store.saveProfile(profile);
      await runtime.store.queueReport({
        'id': 'report-1',
        'sessionId': 's',
        'profileId': profile.id,
        'url': profile.url,
        'text': 'Yorum',
        'reason': 'other',
        'state': 'pending',
      });
      expect(await runtime.sendPendingReports(), 1);
      client.offline = false;
      await runtime.store.saveProfile(
        const AiProfile(
          id: 'test',
          name: 'Atlas',
          url: 'https://changed.example',
          model: 'atlas',
          provider: AiProvider.atlas,
        ),
      );
      expect(await runtime.sendPendingReports(), 1);
      expect(client.sent, isEmpty);
      await runtime.store.saveProfile(profile);
      expect(await runtime.sendPendingReports(), 0);
      expect(client.sent.single.keys.toSet(), {
        'version',
        'id',
        'reason',
        'text',
      });
    },
  );
  test(
    'pending reports persist, deduplicate, erase delivered text and delete with session',
    () async {
      final directory = await Directory.systemTemp.createTemp('atlas-reports-');
      addTearDown(() => directory.delete(recursive: true));
      final store = AiStore(directory);
      final row = {
        'id': 'report-1',
        'sessionId': 'session-1',
        'text': 'Yorum',
        'state': 'pending',
      };
      await store.queueReport(row);
      await store.queueReport(row);
      expect(await AiStore(directory).pendingReports(), hasLength(1));
      await store.markReportSent('report-1');
      expect(await store.pendingReports(), isEmpty);
      expect(
        ((await store.read())['contentReports'] as List).first.containsKey(
          'text',
        ),
        isFalse,
      );
      await store.queueReport({...row, 'id': 'report-2'});
      await store.deleteSession('session-1');
      expect((await store.read())['contentReports'], isEmpty);
    },
  );
}
