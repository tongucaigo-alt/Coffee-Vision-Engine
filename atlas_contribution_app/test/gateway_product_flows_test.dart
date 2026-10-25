import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/ai/ai_client.dart';
import 'package:atlas_contribution_app/src/ai/ai_contract.dart';
import 'package:atlas_contribution_app/src/ai/ai_runtime.dart';
import 'package:atlas_contribution_app/src/ai/ai_pages.dart';
import 'package:atlas_contribution_app/src/ai/ai_transport.dart';
import 'package:atlas_contribution_app/src/ai/content_reporting.dart';
import 'package:atlas_contribution_app/src/atlas_design.dart';
import 'package:atlas_contribution_app/src/local_store.dart';
import 'package:atlas_contribution_app/src/mvp/review_models.dart';
import 'package:atlas_contribution_app/src/tarot/tarot_ai.dart';
import 'package:atlas_contribution_app/src/tarot/tarot_models.dart';
import 'package:atlas_contribution_app/src/tarot/tarot_runtime.dart';
import 'package:atlas_contribution_app/src/tarot/tarot_store.dart';
import 'package:atlas_contribution_app/src/tarot/tarot_pages.dart';
import 'tarot_test.dart' show fixture;

// Widget binding's default HTTP is a 400 stub. This factory alone opts into
// real sockets; connectionFactory still restricts every request to loopback.
class LoopbackHttpOverrides extends HttpOverrides {}

class LocalGateway {
  LocalGateway(
    this.root,
    this.process,
    this.ai,
    this.tarot,
    this.client,
    this.profile,
  );
  final Directory root;
  final Process process;
  final AiRuntime ai;
  final TarotRuntime tarot;
  final TarotAiClient client;
  final AiProfile profile;
  Directory get reports => Directory('${root.path}/reports');
  Future<int> calls() async => int.parse(
    await File('${reports.path}/upstream-count.txt').readAsString(),
  );
  Future<void> close() async {
    process.kill();
    await process.exitCode;
    tarot.dispose();
    await root.delete(recursive: true);
  }
}

Future<LocalGateway> gateway([String mode = 'success']) async {
  final root = await Directory.systemTemp.createTemp(
    'atlas-synthetic-gateway-',
  );
  final process = await Process.start(
    Platform.environment['ATLAS_TEST_NODE'] ?? 'node',
    ['test/fixtures/synthetic_gateway.mjs', '${root.path}/reports', mode],
  );
  process.stderr.drain<void>();
  final line = await process.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .first
      .timeout(const Duration(seconds: 15));
  final port = (jsonDecode(line) as Map)['port'] as int;
  HttpClient createClient() =>
      HttpOverrides.runWithHttpOverrides(
          () => HttpClient(),
          LoopbackHttpOverrides(),
        )
        ..connectionFactory = (_, _, _) =>
            Socket.startConnect(InternetAddress.loopbackIPv4, port);
  final source = DraftStore(
    Directory('${root.path}/source'),
    manualRetention: true,
  );
  await source.initialize();
  final ai = await AiRuntime.create(
    source,
    client: AiClient(
      FortunePrompt(
        await rootBundle.loadString('assets/fortune-prompt-v1.json'),
      ),
      allowLan: true,
      createHttpClient: createClient,
    ),
    readKey: (_) async => 's' * 40,
  );
  final profile = AiProfile(
    id: 'atlas',
    name: 'Atlas',
    url: 'http://192.168.10.1:$port',
    model: 'atlas',
    provider: AiProvider.atlas,
  );
  await ai.store.saveProfile(profile);
  final client = TarotAiClient(
    await rootBundle.loadString('assets/tarot-prompt-v1.json'),
    transport: AiTransport(allowLan: true, createHttpClient: createClient),
    pollInterval: const Duration(milliseconds: 15),
  );
  final tarot = await TarotRuntime.create(
    Directory('${root.path}/tarot'),
    ai,
    client: client,
  );
  await File('${tarot.store.directory.path}/state.json').writeAsString(
    jsonEncode({
      'version': 1,
      'draws': [fixture().toJson()],
      'deletedDailyDays': [],
    }),
  );
  return LocalGateway(root, process, ai, tarot, client, profile);
}

Future<void> waitForUpstream(LocalGateway g) async {
  for (var i = 0; i < 200; i++) {
    if (await File('${g.reports.path}/upstream-count.txt').exists()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Synthetic upstream did not start');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'real gateway Tarot succeeds with Atlas-only profile and cold reopen; double tap starts once',
    () async {
      final g = await gateway();
      addTearDown(g.close);
      await Future.wait([
        g.tarot.generate('fixture'),
        g.tarot.generate('fixture'),
      ]);
      final result = (await g.tarot.store.get('fixture'))!;
      expect(
        result.result.state,
        TarotResultState.completed,
        reason: result.result.error,
      );
      expect(result.result.promptHash, g.client.hash);
      expect(await g.calls(), 1);
      final reopened = TarotStore(g.tarot.store.directory);
      await reopened.initialize();
      expect((await reopened.get('fixture'))!.result.text, result.result.text);
      expect(jsonEncode(result.context()), jsonEncode(fixture().context()));
    },
  );
  test(
    'real gateway cancellation never stores a late Tarot response',
    () async {
      final g = await gateway('slow');
      addTearDown(g.close);
      final pending = g.tarot.generate('fixture');
      await waitForUpstream(g);
      await g.tarot.cancel('fixture');
      await pending;
      await Future<void>.delayed(const Duration(milliseconds: 900));
      final draw = (await g.tarot.store.get('fixture'))!;
      expect(draw.result.state, TarotResultState.cancelled);
      expect(draw.result.text, isNull);
      expect(await g.calls(), 1);
      expect(g.tarot.busy('fixture'), isFalse);
    },
  );
  test(
    'gateway failure is stored and only explicit retry creates the next attempt',
    () async {
      final g = await gateway('retry');
      addTearDown(g.close);
      await g.tarot.generate('fixture');
      expect(
        (await g.tarot.store.get('fixture'))!.result.state,
        TarotResultState.failed,
      );
      expect(await g.calls(), 1);
      await g.tarot.generate('fixture');
      expect(
        (await g.tarot.store.get('fixture'))!.result.state,
        TarotResultState.completed,
      );
      expect(await g.calls(), 2);
    },
  );
  test('gateway timeout cancels without resubmitting', () async {
    final g = await gateway('slow');
    addTearDown(g.close);
    await expectLater(
      g.client.generate(
        fixture(),
        g.profile,
        's' * 40,
        AiCancellation(),
        timeout: const Duration(milliseconds: 200),
      ),
      throwsA(isA<AiFailure>()),
    );
    await Future<void>.delayed(const Duration(milliseconds: 900));
    expect(await g.calls(), 1);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 30));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
    }
    await tester.pumpAndSettle();
  }

  for (final kind in ['coffee-direct', 'tarot']) {
    testWidgets(
      '$kind saved result UI reports through real authenticated gateway; retries deduplicate',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1500);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final g = (await tester.runAsync(gateway))!;
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox());
          await tester.runAsync(g.close);
        });
        late Widget page;
        if (kind == 'tarot') {
          await tester.runAsync(() => g.tarot.generate('fixture'));
          final draw = (await tester.runAsync(
            () => g.tarot.store.get('fixture'),
          ))!;
          page = TarotDrawPage(runtime: g.tarot, draw: draw);
        } else {
          final session = ReviewSession(
            id: 'synthetic-coffee',
            groupId: 'synthetic-group',
            createdAtUtc: '2026-10-01T00:00:00Z',
            localConsentAtUtc: '2026-10-01T00:00:00Z',
          );
          await tester.runAsync(() async {
            await g.ai.reviews.initialize();
            await g.ai.reviews.save(session);
            await g.ai.store.change(
              (data) => (data['results'] as List).add({
                'id': 'coffee-result',
                'sessionId': session.id,
                'groupId': session.groupId,
                'sourceFingerprint': preparationSourceFingerprint(session),
                'state': 'completed',
                'context': {'photos': []},
                'comparison': false,
                'answers': [
                  {
                    'text': 'Sentetik doğrudan sağlayıcı yorumu.',
                    'profileId': 'direct',
                    'profileUrl': 'https://provider.invalid/v1',
                  },
                ],
              }),
            );
          });
          page = AiFortunePage(runtime: g.ai, session: session, simple: true);
        }
        await tester.pumpWidget(MaterialApp(theme: atlasTheme(), home: page));
        await settle(tester);
        if (kind == 'coffee-direct') {
          for (
            var i = 0;
            i < 40 && find.byType(ContentReportButton).evaluate().isEmpty;
            i++
          ) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 50)),
            );
            await tester.pump();
          }
          expect(
            find.byType(ContentReportButton),
            findsOneWidget,
            reason: tester
                .widgetList<Text>(find.byType(Text))
                .map((w) => w.data)
                .toList()
                .toString(),
          );
        }
        if (find.text('Yorumunu Oku').evaluate().isNotEmpty) {
          await tester.tap(find.text('Yorumunu Oku'));
          await settle(tester);
        }
        Future<void> report() async {
          await tester.scrollUntilVisible(
            find.byType(ContentReportButton),
            350,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.runAsync(
            () => tester.tap(find.text('Bu yorumu bildir')),
          );
          await settle(tester);
          expect(find.byType(AlertDialog), findsOneWidget);
          await tester.runAsync(() => tester.tap(find.text('Bildir')));
          await settle(tester);
          expect(find.text('Bildirim iletildi.'), findsOneWidget);
        }

        await report();
        await report();
        final records = (await tester.runAsync(
          () =>
              g.reports.list().where((f) => f.path.endsWith('.json')).toList(),
        ))!;
        expect(records, hasLength(1));
        final stored =
            jsonDecode(
                  (await tester.runAsync(
                    () => File(records.single.path).readAsString(),
                  ))!,
                )
                as Map;
        expect((stored['report'] as Map).keys.toSet(), {
          'version',
          'id',
          'reason',
          'text',
        });
        expect(
          await tester.runAsync(() => g.ai.store.pendingReports()),
          isEmpty,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'report disk failure remains visibly pending and provider credentials are never a reporting target',
    (tester) async {
      final g = (await tester.runAsync(() => gateway('report-failure')))!;
      addTearDown(g.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ContentReportButton(
              runtime: g.ai,
              sessionId: 'test',
              contentId: 'test',
              text: 'Sentetik yorum',
            ),
          ),
        ),
      );
      await tester.runAsync(() => tester.tap(find.text('Bu yorumu bildir')));
      await settle(tester);
      await tester.runAsync(() => tester.tap(find.text('Bildir')));
      await settle(tester);
      expect(find.textContaining('telefonda bekliyor'), findsOneWidget);
      expect(
        await tester.runAsync(() => g.ai.store.pendingReports()),
        hasLength(1),
      );
      expect(find.text('Bildirim iletildi.'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  test(
    'a direct generation profile cannot be submitted as the reporting recipient',
    () async {
      final g = await gateway();
      addTearDown(g.close);
      await expectLater(
        g.ai.submitContentReport(
          target: const AiProfile(
            id: 'direct',
            name: 'Direct',
            url: 'https://provider.invalid/v1',
            model: 'fake',
            provider: AiProvider.direct,
          ),
          sessionId: 'test',
          contentId: 'test',
          text: 'Sentetik yorum',
          reason: 'other',
        ),
        throwsA(isA<AiFailure>()),
      );
      expect(await g.ai.store.pendingReports(), isEmpty);
      expect(await g.reports.exists(), isFalse);
    },
  );
  testWidgets(
    'local report write failure is visible and never claims delivery',
    (tester) async {
      final g = (await tester.runAsync(gateway))!;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(g.close);
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ContentReportButton(
              runtime: g.ai,
              sessionId: 'test',
              contentId: 'test',
              text: 'Sentetik yorum',
            ),
          ),
        ),
      );
      await tester.runAsync(() => tester.tap(find.text('Bu yorumu bildir')));
      await settle(tester);
      // A directory at the pending-file path forces a real local write error.
      await tester.runAsync(
        () => Directory('${g.ai.store.directory.path}/state.pending').create(),
      );
      await tester.runAsync(() => tester.tap(find.text('Bildir')));
      await settle(tester);
      expect(
        find.textContaining('Bildirim kaydedilemedi veya gönderilemedi'),
        findsOneWidget,
      );
      expect(find.text('Bildirim iletildi.'), findsNothing);
      expect(await tester.runAsync(() => g.reports.exists()), isFalse);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'direct-only installation offers in-app reporting setup without falsely reporting success',
    (tester) async {
      final g = (await tester.runAsync(gateway))!;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(g.close);
      });
      await tester.runAsync(
        () => g.ai.store.change((data) => (data['profiles'] as List).clear()),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ContentReportButton(
              runtime: g.ai,
              sessionId: 'test',
              contentId: 'test',
              text: 'Sentetik yorum',
            ),
          ),
        ),
      );
      await tester.runAsync(() => tester.tap(find.text('Bu yorumu bildir')));
      await settle(tester);
      expect(find.text('Bildirim bağlantısı gerekli'), findsOneWidget);
      expect(find.text('Bağlantıyı Ayarla'), findsOneWidget);
      expect(find.text('Bildirim iletildi.'), findsNothing);
      await tester.tap(find.text('Vazgeç'));
      await settle(tester);
      expect(await tester.runAsync(() => g.ai.store.pendingReports()), isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
