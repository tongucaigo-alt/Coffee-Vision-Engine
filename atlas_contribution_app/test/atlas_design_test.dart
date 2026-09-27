import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/annotation_sequence.dart';
import 'package:atlas_contribution_app/src/atlas_design.dart';
import 'package:atlas_contribution_app/src/contribution_home.dart';
import 'package:atlas_contribution_app/src/local_store.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'package:atlas_contribution_app/src/offline_contribution.dart';
import 'fixtures.dart';

class _UiStore extends DraftStore {
  _UiStore() : super(Directory('unused-ui-fixture'));
  @override
  Future<ContributionDraft?> load() async => null;
  @override
  Future<void> pruneExpiredReceipts() async {}
  @override
  Future<Map<String, dynamic>?> galleryPending() async => null;
  @override
  Future<List<String>> pendingDeletes() async => [];
  @override
  Future<List<Map<String, dynamic>>> receipts() async => [];
}

final _captureKey = GlobalKey();
Future<void> _snapshot(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('ATLAS_UI_CAPTURE')) return;
  await tester.runAsync(() async {
    final context = _captureKey.currentContext!;
    await precacheImage(
      const AssetImage('assets/brand/atlas-logo.png'),
      context,
    );
    await precacheImage(MemoryImage(testImage()), context);
  });
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final boundary =
        _captureKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('build/ui-previews');
    await directory.create(recursive: true);
    await File(
      '${directory.path}/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Widget _app(Widget child, {double scale = 1}) => RepaintBoundary(
  key: _captureKey,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: atlasTheme(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: child,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'Plus Jakarta Sans',
    )..addFont(rootBundle.load('assets/brand/PlusJakartaSans.ttf'))).load();
    await (FontLoader(
      'Literata',
    )..addFont(rootBundle.load('assets/brand/Literata.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader('packages/lucide_icons_flutter/Lucide')..addFont(
          rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
        ))
        .load();
  });

  for (final scale in [1.0, 1.8]) {
    testWidgets('Atlas navigation is usable at text scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = scale == 1
          ? const Size(412, 915)
          : const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = _UiStore();
      await tester.pumpWidget(
        _app(
          ContributionHome(
            modern: true,
            store: store,
            service: OfflineContributionService(store),
            onAiSettings: () async {},
            onReview: () async {},
            onExport: () async {},
            onReadFortune: (_) async {},
          ),
          scale: scale,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Fincanını Keşfet'), findsOneWidget);
      expect(find.textContaining('120'), findsNothing);
      expect(find.text('Profil'), findsNothing);
      expect(find.text('Ritüeller'), findsNothing);
      expect(tester.takeException(), isNull);
      await _snapshot(tester, 'home-$scale');
      await tester.tap(find.text('Ayarlar').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('AI Laboratuvarı · Test'));
      expect(tester.takeException(), isNull);
      await _snapshot(tester, 'settings-$scale');
      await tester.tap(find.text('Kayıtlarım').last);
      await tester.pumpAndSettle();
      expect(find.text('Taslaklar'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _snapshot(tester, 'records-$scale');
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'skip preserves marked uncertain and unseen observations, with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final photos = [
        testPhoto(
          CaptureRole.free,
          decision: PhotoDecision.marked,
          regions: [
            RegionAnnotation(
              id: 'bird',
              box: RegionBox(.2, .2, .15, .15),
              label: 'bird',
            ),
          ],
        ),
        testPhoto(CaptureRole.handleRight, decision: PhotoDecision.uncertain),
        testPhoto(CaptureRole.handleLeft),
      ];
      final saved = <ContributionPhoto>[];
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => AnnotationSequence(
                        photos: photos,
                        imageFor: (_) => MemoryImage(testImage()),
                        onSave: (p) async => saved.add(p),
                      ),
                    ),
                  ),
                  child: const Text('İncele'),
                ),
              ),
            ),
          ),
          scale: 1.8,
        ),
      );
      await tester.tap(find.text('İncele'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _snapshot(tester, 'annotation-large');
      await tester.tap(find.byTooltip('Kalanları Atla'));
      await tester.pumpAndSettle();
      expect(saved, hasLength(1));
      expect(saved.single.role, CaptureRole.handleLeft);
      expect(saved.single.decision, PhotoDecision.skipped);
      expect(photos.first.regions.single.label, 'bird');
      expect(photos[1].decision, PhotoDecision.uncertain);
    },
  );

  testWidgets(
    'fortune presentation preserves text and does not invent symbol headings',
    (tester) async {
      const paragraphs = [
        'Sakin bir gün sana iyi gelebilir.',
        'Bir sembol paylaşmadın; kendi çağrışımlarına yer açabilirsin.',
        'Yakın zamanda küçük bir mola düşünebilirsin.',
        'Bu hikâyenin devamını sen yazabilirsin.',
      ];
      await tester.pumpWidget(
        _app(
          const Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: FortuneStory(
                  text:
                      'Sakin bir gün sana iyi gelebilir.\n\nBir sembol paylaşmadın; kendi çağrışımlarına yer açabilirsin.\n\nYakın zamanda küçük bir mola düşünebilirsin.\n\nBu hikâyenin devamını sen yazabilirsin.',
                  hasSymbols: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Çağrışımlar'), findsOneWidget);
      expect(find.text('Senin Gördüğün Semboller'), findsNothing);
      for (final p in paragraphs) {
        expect(find.text(p), findsOneWidget);
      }
      await _snapshot(tester, 'story');
      expect(tester.takeException(), isNull);
    },
  );
}
