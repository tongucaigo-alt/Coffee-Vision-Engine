import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/atlas_design.dart';
import 'package:atlas_contribution_app/src/contribution_home.dart';
import 'package:atlas_contribution_app/src/offline_contribution.dart';
import 'package:atlas_contribution_app/src/umay_home_tour.dart';
import 'package:atlas_contribution_app/src/umay_guide_scope.dart';
import 'package:atlas_contribution_app/src/umay_guide_catalog.dart';
import 'package:atlas_contribution_app/src/umay_annotation_guide.dart';
import 'package:atlas_contribution_app/src/umay_camera_guide.dart';
import 'package:atlas_contribution_app/src/user_profile_page.dart';
import 'package:atlas_contribution_app/src/user_profile_store.dart';
import 'package:atlas_contribution_app/src/privacy_support.dart';
import 'package:atlas_contribution_app/src/tarot/tarot_runtime.dart';
import 'package:atlas_contribution_app/src/tarot/tarot_pages.dart';
import 'package:atlas_contribution_app/src/tarot/tarot_models.dart';
import 'package:atlas_contribution_app/src/tarot/tarot_store.dart';
import 'package:atlas_contribution_app/src/ai/ai_runtime.dart';
import 'package:atlas_contribution_app/src/ai/ai_client.dart';
import 'package:atlas_contribution_app/src/ai/ai_contract.dart';
import 'package:atlas_contribution_app/src/ai/ai_pages.dart';
import 'package:atlas_contribution_app/src/ai/content_reporting.dart';
import 'package:atlas_contribution_app/src/fortune_progress.dart';
import 'package:atlas_contribution_app/src/local_store.dart';
import 'contribution_save_status_test.dart' show MemoryStore, PausedService;
import 'photo_set_test.dart' show setDraft, setImage;
import 'suitability_fixture.dart';
import '../tool/umay_guide_preview.dart' show GuidePreviewStore;
import 'tarot_test.dart' show catalog, fixture;

Widget app(
  Widget home,
  UmayGuideController c, {
  GlobalKey? capture,
  double scale = 1,
  bool bold = false,
}) => UmayGuideScope(
  controller: c,
  child: MaterialApp(
    theme: atlasTheme(),
    debugShowCheckedModeBanner: false,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(scale),
        boldText: bold,
        disableAnimations: true,
        padding: const EdgeInsets.only(top: 24, bottom: 24),
        viewPadding: const EdgeInsets.only(top: 24, bottom: 24),
      ),
      child: capture == null
          ? child!
          : RepaintBoundary(key: capture, child: child!),
    ),
    home: home,
  ),
);

Future<void> ready(WidgetTester t) async {
  if (t.view.physicalSize / t.view.devicePixelRatio == const Size(800, 600)) {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(384, 832);
    addTearDown(t.view.reset);
  }
  await t.pump();
  final context = find.byType(Scaffold).evaluate().firstOrNull;
  if (context != null) {
    await t.runAsync(() async {
      for (final asset in [
        'assets/umay/umay-speaking-left.png',
        'assets/umay/umay-speaking-right.png',
        'assets/guide/example-cup.png',
        'assets/brand/atlas-logo.png',
        'assets/buttons/atlas_camera_button.webp',
        'assets/buttons/atlas_gallery_button.webp',
        'assets/buttons/tarot_daily_button.webp',
        'assets/buttons/tarot_shuffle_button.webp',
      ]) {
        await precacheImage(AssetImage(asset), context);
      }
    });
  }
  for (var i = 0; i < 5; i++) {
    await t.pump(const Duration(milliseconds: 200));
  }
}

Future<void> capture(WidgetTester t, GlobalKey key, String name) async {
  final directory = Platform.environment['UMAY_APP_CAPTURE_DIR'];
  if (directory == null) return;
  await t.pump();
  await t.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await boundary.toImage(pixelRatio: 2);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    await Directory(directory).create(recursive: true);
    await File('$directory/$name.png').writeAsBytes(png!.buffer.asUint8List());
    img.dispose();
  });
}

Future<void> skip(WidgetTester t) async {
  await t.tap(find.byKey(const ValueKey('umay-tour-skip')));
  await ready(t);
}

const probeSteps = [
  UmayTourStep(target: 'probe-action', message: 'İlk adım'),
  UmayTourStep(target: 'probe-action', message: 'İkinci adım'),
];

class Probe extends StatefulWidget {
  const Probe(this.created, this.pressed, {super.key});
  final VoidCallback created, pressed;
  @override
  State<Probe> createState() => _ProbeState();
}

class _ProbeState extends State<Probe> {
  @override
  void initState() {
    super.initState();
    widget.created();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: FilledButton(
        key: const ValueKey('probe-action'),
        onPressed: widget.pressed,
        child: const Text('İşlem'),
      ),
    ),
  );
}

class ProfileMemory extends UserProfileStore {
  ProfileMemory() : super(Directory('unused-umay-profile'));
  int writes = 0;
  @override
  Future<UserProfile> read() async => const UserProfile();
  @override
  Future<void> save(UserProfile value) async {
    writes++;
  }

  @override
  Future<void> delete() async {
    writes++;
  }
}

class TarotMemory extends TarotStore {
  TarotMemory(this.draw) : super(Directory('unused-umay-tarot'));
  TarotDraw draw;
  int writes = 0;
  @override
  Future<List<TarotDraw>> draws() async => [draw];
  @override
  Future<TarotDraw?> get(String id) async => draw;
  @override
  Future<TarotDraw> select(String id, int index) async {
    writes++;
    return draw;
  }

  @override
  Future<TarotDraw> reveal(String id, int position) async {
    writes++;
    return draw;
  }
}

class NoNetworkClient extends AiClient {
  NoNetworkClient(super.prompt);
  int requests = 0, reports = 0;
  @override
  Future<Map<String, dynamic>> generate(
    AiProfile p,
    String key,
    Map<String, dynamic> context, {
    required AiCancellation cancellation,
    required void Function(String) onStatus,
    String? requestId,
    List<String> previousTexts = const [],
    void Function(FortuneProgress)? onProgress,
    Future<void> Function()? beforeRequest,
    void Function(String, int)? onStage,
    AiGenerationBudget? budget,
    int maxAttempts = 2,
  }) async {
    requests++;
    throw StateError('Guide must not generate.');
  }

  @override
  Future<void> sendReport(
    AiProfile profile,
    String key,
    Map<String, dynamic> report,
  ) async {
    reports++;
  }
}

void main() {
  setUpAll(() async {
    for (final entry in {
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
      'Plus Jakarta Sans': 'assets/brand/PlusJakartaSans.ttf',
      'Literata': 'assets/brand/Literata.ttf',
      'EB Garamond': 'assets/brand/EBGaramond.ttf',
      'packages/lucide_icons_flutter/Lucide':
          'packages/lucide_icons_flutter/assets/lucide.ttf',
    }.entries) {
      await (FontLoader(
        entry.key,
      )..addFont(rootBundle.load(entry.value))).load();
    }
  });

  test(
    'shown sections and automatic preference persist only in the guide file',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'atlas-umay-preferences-',
      );
      addTearDown(() => dir.delete(recursive: true));
      final sentinel = File('${dir.path}/records.json')
        ..writeAsStringSync('unchanged');
      final c = UmayGuideController(Directory('${dir.path}/umay-guides'));
      await c.load();
      expect(c.shouldShow('home'), true);
      await c.presented('home');
      await c.setAutomatic(false);
      final reopened = UmayGuideController(c.directory);
      await reopened.load();
      expect(reopened.shown, {'home'});
      expect(reopened.automatic, false);
      expect(reopened.shouldShow('settings'), false);
      reopened.requestReplay('home');
      expect(reopened.shouldShow('home'), true);
      await reopened.presented('home');
      expect(reopened.shouldShow('home'), false);
      expect(await reopened.restartAll(), true);
      final restarted = UmayGuideController(c.directory);
      await restarted.load();
      expect(restarted.shown, isEmpty);
      expect(restarted.automatic, true);
      expect(restarted.shouldShow('home'), true);
      restarted.dispose();
      expect(sentinel.readAsStringSync(), 'unchanged');
      c.dispose();
      reopened.dispose();
    },
  );

  testWidgets(
    'one presentation, safe target taps, no remount when closing or changing section',
    (t) async {
      var created = 0, actions = 0;
      final id = ValueNotifier('one');
      final c = UmayGuideController();
      await t.pumpWidget(
        app(
          ValueListenableBuilder<String>(
            valueListenable: id,
            builder: (_, value, _) => UmayGuideOnce(
              id: value,
              steps: probeSteps,
              child: Probe(() => created++, () => actions++),
            ),
          ),
          c,
        ),
      );
      await ready(t);
      expect(find.text('1/2'), findsOneWidget);
      expect(c.shown, {'one'});
      expect(created, 1);
      await t.tap(find.byKey(const ValueKey('umay-tour-target')));
      await ready(t);
      expect(find.text('2/2'), findsOneWidget);
      expect(actions, 0);
      await t.tap(find.byKey(const ValueKey('umay-tour-next')));
      await ready(t);
      expect(find.byKey(const ValueKey('umay-tour-avatar')), findsNothing);
      expect(created, 1);
      await t.tap(find.byKey(const ValueKey('probe-action')));
      await t.pump();
      expect(actions, 1);
      id.value = 'two';
      await ready(t);
      expect(find.text('1/2'), findsOneWidget);
      expect(created, 1);
      await skip(t);
      id.value = 'one';
      await ready(t);
      expect(find.byKey(const ValueKey('umay-tour-avatar')), findsNothing);
      expect(created, 1);
      c.requestReplay('one');
      await ready(t);
      expect(find.text('1/2'), findsOneWidget);
      await t.pumpWidget(const SizedBox.shrink());
      id.dispose();
      c.dispose();
    },
  );

  testWidgets(
    'hidden routes never consume seen flags or overlap the visible tour',
    (t) async {
      final c = UmayGuideController()..automatic = false;
      await t.pumpWidget(
        app(
          Builder(
            builder: (context) => UmayGuideOnce(
              id: 'outer',
              steps: probeSteps,
              child: Scaffold(
                body: FilledButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UmayGuideOnce(
                        id: 'inner',
                        steps: probeSteps,
                        child: const Scaffold(body: Text('Inner')),
                      ),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
          c,
        ),
      );
      await ready(t);
      await t.tap(find.text('Open'));
      await ready(t);
      await c.setAutomatic(true);
      await ready(t);
      expect(c.shown, {'inner'});
      expect(find.byKey(const ValueKey('umay-tour-avatar')), findsOneWidget);
      await skip(t);
      await t.binding.handlePopRoute();
      await ready(t);
      expect(c.shown, {'inner', 'outer'});
      expect(find.byKey(const ValueKey('umay-tour-avatar')), findsOneWidget);
      await t.pumpWidget(const SizedBox.shrink());
      c.dispose();
    },
  );

  testWidgets(
    'background does not consume first entry and preserves a visible step',
    (t) async {
      final c = UmayGuideController();
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await t.pumpWidget(
        app(
          UmayGuideOnce(
            id: 'resume',
            steps: probeSteps,
            child: Probe(() {}, () {}),
          ),
          c,
        ),
      );
      await ready(t);
      expect(c.shown, isEmpty);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await ready(t);
      expect(find.text('1/2'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('umay-tour-next')));
      await ready(t);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await t.pump();
      expect(find.byKey(const ValueKey('umay-tour-avatar')), findsNothing);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await ready(t);
      expect(find.text('2/2'), findsOneWidget);
      expect(c.shown, {'resume'});
      await t.pumpWidget(const SizedBox.shrink());
      c.dispose();
    },
  );

  testWidgets(
    'annotation lesson creates the real editor only after finishing',
    (t) async {
      final c = UmayGuideController();
      var created = 0;
      final audit = AnnotationGuideAudit();
      await t.pumpWidget(
        app(
          UmayGuideOnce(
            id: 'annotation',
            steps: umayAnnotationSteps,
            lessonBuilder: (presented, finish) => UmayAnnotationGuide(
              onPresented: presented,
              onFinish: finish,
              audit: audit,
            ),
            child: Probe(() => created++, () {}),
          ),
          c,
        ),
      );
      await ready(t);
      expect(find.text('1/18'), findsOneWidget);
      expect(created, 0);
      await skip(t);
      expect(created, 1);
      expect(audit.draftChanges, 0);
      expect(audit.finishActions, 0);
      await t.pumpWidget(const SizedBox.shrink());
      c.dispose();
    },
  );

  testWidgets(
    'actual home, settings hub, manual annotation replay and profile stay read-only',
    (t) async {
      final c = UmayGuideController();
      final store = GuidePreviewStore();
      final key = GlobalKey();
      await t.pumpWidget(
        app(
          ContributionHome(
            modern: true,
            store: store,
            service: OfflineContributionService(store),
            tarotPage: const SizedBox.shrink(),
            onOpenGuide: () async {},
          ),
          c,
          capture: key,
        ),
      );
      await ready(t);
      expect(find.text('1/4'), findsOneWidget);
      await skip(t);
      await t.tap(find.byKey(const ValueKey('atlas-nav-settings')));
      await ready(t);
      expect(c.shown.contains('settings'), true);
      await skip(t);
      await t.tap(find.byKey(const ValueKey('settings-guide')));
      await ready(t);
      expect(find.text('Umay ile Atlas’ı tanı'), findsOneWidget);
      await capture(t, key, 'settings-hub');
      await t.tap(find.byKey(const ValueKey('guide-replay-annotation')));
      await ready(t);
      expect(find.text('1/18'), findsOneWidget);
      await skip(t);
      expect(find.byKey(const ValueKey('settings-guide')), findsOneWidget);
      expect(store.writes, 0);
      expect(c.shown, containsAll(['home', 'settings', 'annotation']));
      await t.pumpWidget(const SizedBox.shrink());
      c.dispose();
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'camera lesson uses real chrome without a camera at $scale text',
      (t) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = Size(
          scale == 1 ? 384 : 320,
          scale == 1 ? 832 : 640,
        );
        addTearDown(t.view.reset);
        final key = GlobalKey();
        var finished = false;
        final c = UmayGuideController()..automatic = false;
        await t.pumpWidget(
          app(
            UmayCameraGuide(onFinish: (_) => finished = true),
            c,
            capture: key,
            scale: scale,
            bold: scale == 1,
          ),
        );
        await ready(t);
        for (var i = 0; i < umayCameraSteps.length; i++) {
          expect(find.text('${i + 1}/5'), findsOneWidget);
          expect(
            find.byKey(const ValueKey('umay-tour-next')).hitTestable(),
            findsOneWidget,
          );
          expect(t.takeException(), isNull);
          await capture(t, key, 'camera-${scale}x-${i + 1}');
          await t.tap(find.byKey(const ValueKey('umay-tour-next')));
          await ready(t);
        }
        expect(finished, true);
        await t.pumpWidget(const SizedBox.shrink());
        c.dispose();
      },
    );
  }

  testWidgets(
    'actual profile and privacy guide target existing controls without writes',
    (t) async {
      final profile = ProfileMemory();
      final c = UmayGuideController();
      final key = GlobalKey();
      await t.pumpWidget(app(UserProfilePage(store: profile), c, capture: key));
      await ready(t);
      for (var i = 0; i < umayProfileSteps.length; i++) {
        expect(find.text('${i + 1}/4'), findsOneWidget);
        expect(t.takeException(), isNull);
        await t.tap(find.byKey(const ValueKey('umay-tour-next')));
        await ready(t);
      }
      expect(profile.writes, 0);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpWidget(app(const PrivacySupportPage(), c, capture: key));
      await ready(t);
      expect(c.shown, containsAll(['profile', 'privacy']));
      expect(find.text('1/2'), findsOneWidget);
      await capture(t, key, 'privacy');
      await t.pumpWidget(const SizedBox.shrink());
      c.dispose();
    },
  );

  testWidgets(
    'actual Tarot stages show their own guide without selecting or generating',
    (t) async {
      final c = UmayGuideController();
      final cards = catalog();
      final seed = fixture();
      final memory = TarotMemory(seed);
      var requests = 0;
      final runtime = TarotRuntime(
        store: memory,
        catalog: cards,
        promptVersion: 'guide',
        promptHash: 'guide',
        generateReading: (_, _) async {
          requests++;
          return 'unused';
        },
      );
      final key = GlobalKey();
      await t.pumpWidget(app(TarotHomePage(runtime: runtime), c, capture: key));
      await ready(t);
      expect(find.text('1/3'), findsOneWidget);
      await capture(t, key, 'tarot-home');
      await skip(t);
      await t.pumpWidget(const SizedBox.shrink());
      final selection = TarotDraw(
        id: seed.id,
        spread: seed.spread,
        createdAt: seed.createdAt,
        deck: seed.deck,
        selected: const [],
        revealed: 0,
      );
      memory.draw = selection;
      await t.pumpWidget(
        app(
          TarotDrawPage(runtime: runtime, draw: selection),
          c,
          capture: key,
        ),
      );
      await ready(t);
      expect(c.shown, contains('tarot-selection'));
      await capture(t, key, 'tarot-selection');
      await skip(t);
      await t.pumpWidget(const SizedBox.shrink());
      memory.draw = seed;
      await t.pumpWidget(
        app(
          TarotDrawPage(runtime: runtime, draw: seed),
          c,
          capture: key,
        ),
      );
      await ready(t);
      expect(c.shown, contains('tarot-ready'));
      await capture(t, key, 'tarot-ready');
      await skip(t);
      expect(memory.writes, 0);
      expect(requests, 0);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      runtime.dispose();
      c.dispose();
    },
  );

  testWidgets('actual photo review guide does not mutate a draft or submit', (
    t,
  ) async {
    late Directory temp;
    late MemoryStore store;
    await t.runAsync(() async {
      temp = await Directory.systemTemp.createTemp('atlas-guide-photo-');
      store = MemoryStore(temp, setDraft());
      final p = await store.importGallery(setImage(0));
      store.draft = store.draft!
          .withPhoto(p.asSetPhoto())
          .copy(cupSelectionDone: true, saucerDecided: true);
    });
    final before = jsonEncode(store.draft!.toJson());
    final service = PausedService(store);
    final c = UmayGuideController()..shown.add('home');
    final key = GlobalKey();
    await t.pumpWidget(
      app(
        ContributionHome(
          modern: true,
          store: store,
          service: service,
          photoSuitability: SupportedSuitability(),
          onOpenGuide: () async {},
        ),
        c,
        capture: key,
      ),
    );
    await ready(t);
    await t.tap(find.byKey(const ValueKey('coffee-resume')));
    await ready(t);
    expect(c.shown, contains('photos'));
    await capture(t, key, 'photo-review');
    for (var i = 0; i < umayPhotoReviewSteps.length; i++) {
      expect(find.text('${i + 1}/6'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('umay-tour-next')));
      await ready(t);
    }
    expect(jsonEncode(store.draft!.toJson()), before);
    expect(service.submissions, 0);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
    c.dispose();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    await t.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      try {
        await temp.delete(recursive: true);
      } on FileSystemException catch (e) {
        // Windows may retain an image codec handle until the test isolate exits.
        if (e.osError?.errorCode != 32) rethrow;
      }
    });
  });

  testWidgets(
    'connection and report confirmation guides never generate or send a report',
    (t) async {
      late Directory temp;
      late AiRuntime runtime;
      late NoNetworkClient client;
      await t.runAsync(() async {
        temp = await Directory.systemTemp.createTemp('atlas-guide-report-');
        final source = DraftStore(Directory('${temp.path}/source'));
        await source.initialize();
        client = NoNetworkClient(
          FortunePrompt(
            await rootBundle.loadString('assets/fortune-prompt-v1.json'),
          ),
        );
        runtime = await AiRuntime.create(
          source,
          client: client,
          readKey: (_) async => 'test',
        );
        await runtime.store.saveProfile(
          const AiProfile(
            id: 'guide',
            name: 'Örnek Atlas bağlantısı',
            url: 'https://guide.invalid',
            model: 'atlas',
            provider: AiProvider.atlas,
          ),
        );
      });
      final c = UmayGuideController();
      final key = GlobalKey();
      await t.pumpWidget(app(AiLabPage(runtime: runtime), c, capture: key));
      await ready(t);
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await ready(t);
      expect(c.shown, contains('connection'));
      await capture(t, key, 'connection');
      await skip(t);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpWidget(
        app(
          Scaffold(
            body: ContentReportButton(
              runtime: runtime,
              sessionId: 'guide',
              contentId: 'sample',
              text: 'Örnek açıklama.',
            ),
          ),
          c,
          capture: key,
        ),
      );
      await ready(t);
      await t.tap(find.text('Bu yorumu bildir'));
      for (
        var wait = 0;
        wait < 50 && find.byType(AlertDialog).evaluate().isEmpty;
        wait++
      ) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await t.pump(const Duration(milliseconds: 20));
      }
      await ready(t);
      await capture(t, key, 'report-before-guide');
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(c.shown, contains('report'));
      expect(find.text('1/2'), findsOneWidget);
      await capture(t, key, 'report-guide');
      await t.tap(find.byKey(const ValueKey('umay-tour-next')));
      await ready(t);
      await t.tap(find.byKey(const ValueKey('umay-tour-target')));
      await ready(t);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(client.reports, 0);
      expect(client.requests, 0);
      await t.tap(find.text('Vazgeç'));
      await ready(t);
      expect(client.reports, 0);
      final data = await t.runAsync(() => runtime.store.read());
      expect(data!['contentReports'] ?? [], isEmpty);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      c.dispose();
      runtime.preparation.dispose();
      runtime.progress.dispose();
      await t.runAsync(() => temp.delete(recursive: true));
    },
  );
}
