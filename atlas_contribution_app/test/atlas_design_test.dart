import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/annotation_sequence.dart';
import 'package:atlas_contribution_app/src/label_picker.dart';
import 'package:atlas_contribution_app/src/fortune_progress.dart';
import 'package:coffee_camera/src/ui/photo_preview.dart';
import 'package:atlas_contribution_app/src/capture_settings.dart';
import 'package:atlas_contribution_app/src/atlas_design.dart';
import 'package:atlas_contribution_app/src/contribution_home.dart';
import 'package:atlas_contribution_app/src/local_store.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'package:atlas_contribution_app/src/offline_contribution.dart';
import 'fixtures.dart';
import 'suitability_fixture.dart';
import 'photo_set_test.dart' show setDraft;

class _UiStore extends DraftStore {
  _UiStore({this.rows = const [], this.current})
    : super(Directory('unused-ui-fixture'));
  ContributionDraft? current;
  final List<Map<String, dynamic>> rows;
  @override
  File file(String name) => File('build/ui-previews/record-fixture.png');
  @override
  Future<ContributionDraft?> load() async => current;
  @override
  Future<void> save(ContributionDraft draft) async {
    current = draft;
  }

  @override
  Future<void> pruneExpiredReceipts() async {}
  @override
  Future<Map<String, dynamic>?> galleryPending() async => null;
  @override
  Future<List<String>> pendingDeletes() async => [];
  @override
  Future<List<Map<String, dynamic>>> receipts() async => rows;
}

final _captureKey = GlobalKey();
Future<void> _snapshot(
  WidgetTester tester,
  String name, {
  bool settle = true,
}) async {
  if (!const bool.fromEnvironment('ATLAS_UI_CAPTURE')) return;
  await tester.runAsync(() async {
    final context = _captureKey.currentContext!;
    await precacheImage(
      const AssetImage('assets/brand/atlas-logo.png'),
      context,
    );
    await precacheImage(MemoryImage(testImage()), context);
  });
  if (settle) await tester.pumpAndSettle();
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

Widget _app(
  Widget child, {
  double scale = 1,
  EdgeInsets padding = EdgeInsets.zero,
}) => RepaintBoundary(
  key: _captureKey,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: atlasTheme(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(scale),
        padding: padding,
        viewPadding: padding,
      ),
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

  for (final count in [0, 3]) {
    for (final scale in [1.0, 1.8]) {
      testWidgets(
        'draft $count keeps full heading and reachable actions at scale $scale',
        (tester) async {
          tester.view.physicalSize = const Size(360, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final store = _UiStore(
            current: testDraft(
              photos: [
                for (final role in legacyCaptureRoles.take(count))
                  testPhoto(role),
              ],
            ),
          );
          await tester.pumpWidget(
            _app(
              ContributionHome(
                modern: true,
                store: store,
                service: OfflineContributionService(store),
                photoSuitability: SupportedSuitability(),
              ),
              scale: scale,
            ),
          );
          await tester.pumpAndSettle();
          if (count == 0) {
            expect(find.text('Çekime hazır taslak'), findsOneWidget);
          }
          final heading = find.text('Fincanını Keşfet');
          await tester.ensureVisible(heading);
          await tester.pumpAndSettle();
          final viewport = tester.getRect(
            find.byKey(const ValueKey('atlas-home-scroll')),
          );
          final bounds = tester.getRect(heading);
          expect(bounds.top, greaterThanOrEqualTo(viewport.top));
          expect(bounds.bottom, lessThanOrEqualTo(viewport.bottom));
          for (final text in ['Galeriden Seç', 'Fincanını Tara']) {
            await tester.ensureVisible(find.text(text));
            await tester.pumpAndSettle();
            expect(find.text(text).hitTestable(), findsOneWidget);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final (size, scale) in [
    (const Size(412, 915), 1.0),
    (const Size(412, 915), 1.5),
    (const Size(384, 832), .9),
    (const Size(320, 640), 1.8),
    (const Size(360, 800), 1.0),
    (const Size(320, 640), 1.0),
  ]) {
    testWidgets('Atlas navigation is usable at $size and text scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = size;
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
          padding: size.width == 384
              ? const EdgeInsets.only(top: 28, bottom: 48)
              : EdgeInsets.zero,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Fincanını Keşfet'), findsOneWidget);
      expect(find.textContaining('120'), findsNothing);
      expect(find.text('Profil'), findsNothing);
      expect(find.text('Ritüeller'), findsNothing);
      expect(tester.takeException(), isNull);
      final memberButton = find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == 'Üye Girişi',
      );
      expect(memberButton.hitTestable(), findsOneWidget);
      expect(tester.widget<IconButton>(memberButton).onPressed, isNotNull);
      await tester.tap(memberButton);
      await tester.pumpAndSettle();
      expect(
        find.text('Üyelik bu test sürümünde henüz kullanılamıyor.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Kapat'));
      await tester.pumpAndSettle();
      final galleryButton = find.widgetWithText(
        OutlinedButton,
        'Galeriden Seç',
      );
      expect(tester.widget<OutlinedButton>(galleryButton).onPressed, isNotNull);
      final captureLabel = tester.getRect(find.text('3 Açılı Çekim'));
      expect(captureLabel.left, greaterThanOrEqualTo(24));
      expect(
        captureLabel.right,
        lessThanOrEqualTo(tester.view.physicalSize.width - 24),
      );
      final frame = find.byKey(const ValueKey('atlas-home-frame'));
      var frameBounds = tester.getRect(frame);
      final headingBounds = tester.getRect(find.text('Fincanını Keşfet'));
      if (size.height >= 800) {
        expect(find.text('Fincanını Keşfet').hitTestable(), findsOneWidget);
        expect(find.text('Kahvende bir hikâye.').hitTestable(), findsOneWidget);
      }
      expect(headingBounds.left, greaterThanOrEqualTo(frameBounds.left + 20));
      expect(headingBounds.right, lessThanOrEqualTo(frameBounds.right - 20));
      expect(
        (headingBounds.center.dx - frameBounds.center.dx).abs(),
        lessThanOrEqualTo(.5),
      );
      final suffix = '${size.width.toInt()}-${size.height.toInt()}-$scale';
      await _snapshot(tester, 'home-$suffix');
      final scanButton = find.widgetWithText(FilledButton, 'Fincanını Tara');
      await tester.ensureVisible(scanButton);
      await tester.pumpAndSettle();
      frameBounds = tester.getRect(frame);
      expect(tester.widget<FilledButton>(scanButton).onPressed, isNotNull);
      expect(scanButton.hitTestable(), findsOneWidget);
      expect(
        (tester.getRect(scanButton).center.dx - frameBounds.center.dx).abs(),
        lessThanOrEqualTo(.5),
      );
      expect(
        tester.getRect(scanButton).bottom,
        lessThanOrEqualTo(tester.getTopLeft(find.byType(NavigationBar)).dy),
      );
      final footerBounds = tester.getRect(
        find.byKey(const ValueKey('atlas-home-footer')),
      );
      expect(tester.getSize(find.byType(NavigationBar)).height, 76);
      expect(
        footerBounds.top,
        closeTo(tester.getRect(find.byType(NavigationBar)).bottom, .5),
      );
      expect(
        tester.getRect(find.byType(NavigationBar)).top - frameBounds.bottom,
        inInclusiveRange(0, 16),
      );
      expect(
        tester.getRect(scanButton).center.dy,
        greaterThanOrEqualTo(frameBounds.top + frameBounds.height * .7),
      );
      for (final label in ['Gizlilik Politikası', 'İçerik Bildir', 'Destek']) {
        final placeholder = find.widgetWithText(TextButton, label);
        await tester.ensureVisible(placeholder);
        expect(tester.widget<TextButton>(placeholder).onPressed, isNotNull);
        await tester.tap(placeholder);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        await tester.tap(find.text('Kapat'));
        await tester.pumpAndSettle();
        expect(tester.getSize(placeholder).height, greaterThanOrEqualTo(48));
        expect(
          tester.getRect(placeholder).top,
          greaterThanOrEqualTo(tester.getRect(frame).bottom),
        );
      }
      expect(tester.takeException(), isNull);
      await _snapshot(tester, 'home-footer-$suffix');
      await tester.tap(find.text('Ayarlar').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('AI Laboratuvarı · Test'));
      expect(tester.takeException(), isNull);
      await _snapshot(tester, 'settings-$suffix');
      await tester.tap(find.text('Kayıtlarım').last);
      await tester.pumpAndSettle();
      expect(find.text('Taslaklar'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _snapshot(tester, 'records-$suffix');
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final scale in [1.0, 1.8]) {
    testWidgets('preview and annotation controls fit at scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = scale == 1
          ? const Size(360, 800)
          : const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final photo = testPhoto(
        CaptureRole.free,
      ).asSetPhoto(type: PhotoSurface.cup);
      final draft = setDraft()
          .withPhoto(photo)
          .copy(cupSelectionDone: true, saucerDecided: true);
      final store = _UiStore(current: draft);
      await tester.runAsync(() async {
        await Directory('build/ui-previews').create(recursive: true);
        await store.file('preview').writeAsBytes(testImage());
      });
      await tester.pumpWidget(
        _app(
          ContributionHome(
            modern: true,
            store: store,
            service: OfflineContributionService(store),
            photoSuitability: SupportedSuitability(),
            onReadFortune: (_) async {},
            onGenerateFortune: (_) async {},
            aiDescription: () async => 'Test bağlantısı',
            onConfirmedRecorded: (_, _) async => RecordPreparationStatus.ready,
          ),
          scale: scale,
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await FileImage(store.file('preview')).evict();
        await precacheImage(
          FileImage(store.file('preview')),
          _captureKey.currentContext!,
        );
      });
      await tester.tap(find.text('Kaldığın Yerden Devam Et'));
      await tester.pumpAndSettle();
      expect(find.text('Şekilleri İncele'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _snapshot(tester, 'preview-$scale');
      await tester.tap(find.text('Şekilleri İncele'));
      await tester.pumpAndSettle();
      expect(find.text('Sen ne görüyorsun?'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _snapshot(tester, 'annotation-$scale');
      await tester.tap(find.byTooltip('Kalanları Atla'));
      await tester.pumpAndSettle();
      expect(find.text('Kaydet ve Falını Oluştur'), findsOneWidget);
      expect(find.text('Yalnız Kaydet'), findsOneWidget);
      expect(find.text('İşaretleri Gözden Geçir'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _snapshot(tester, 'save-$scale');
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: PhotoPreview(
              filePath: store.file('preview').path,
              config: cameraConfigForRole(CaptureRole.free),
              title: cameraCaptureTitle(CaptureRole.free),
              instruction: cameraCaptureInstruction(CaptureRole.free),
              useAppTitleLayout: true,
              onBack: () {},
              onRetake: () {},
              onApprove: () {},
            ),
          ),
          scale: scale,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _snapshot(tester, 'camera-preview-$scale');
      await tester.pumpWidget(
        _app(Scaffold(body: LabelPicker()), scale: scale),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _snapshot(tester, 'labels-$scale');
      await tester.pumpWidget(
        _app(
          Scaffold(
            appBar: AppBar(title: const Text('Fincanının Hikâyesi')),
            body: FortuneScan(
              showDecorativeSymbols: true,
              progress: const FortuneProgress(FortunePhase.generating),
              photos: [photo],
              imageFor: (_) => FileImage(store.file('preview')),
              onCancel: () {},
            ),
          ),
          scale: scale,
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Durdur'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _snapshot(tester, 'generating-$scale', settle: false);
      await tester.pump(const Duration(milliseconds: 1000));
      await _snapshot(tester, 'generating-symbols-$scale', settle: false);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('records filters and draft remain usable at scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = scale == 1
          ? const Size(360, 800)
          : const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final draft = testDraft(photos: [testPhoto(CaptureRole.top)]);
      await tester.runAsync(() async {
        await Directory('build/ui-previews').create(recursive: true);
        await File(
          'build/ui-previews/record-fixture.png',
        ).writeAsBytes(testImage());
      });
      final store = _UiStore(
        rows: [
          {
            'root_id': draft.rootId,
            'submitted_at': '2026-10-01T10:00:00Z',
            'document': draft.toJson(),
          },
        ],
      );
      var resumed = false;
      await tester.pumpWidget(
        _app(
          ContributionHistory(
            store: store,
            service: OfflineContributionService(store),
            modern: true,
            canStart: true,
            currentDraft: draft,
            onContinue: () async {
              resumed = true;
            },
            onEdit: (_) async {},
            onRepeat: (_) async {},
            recordStarred: (_) async => true,
          ),
          scale: scale,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Fincanın Hikâyesi'), findsOneWidget);
      expect(find.text('Yarım kalan çalışman'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        await FileImage(store.file('top.jpg')).evict();
        await precacheImage(
          FileImage(store.file('top.jpg')),
          _captureKey.currentContext!,
        );
      });
      await _snapshot(tester, 'records-filled-$scale');
      await tester.tap(find.text('Yarım kalan çalışman'));
      expect(resumed, isTrue);
      await tester.tap(find.text('Kayıtlı'));
      await tester.pumpAndSettle();
      expect(find.text('Yarım kalan çalışman'), findsNothing);
      expect(find.text('Fincanın Hikâyesi'), findsOneWidget);
      await tester.ensureVisible(find.text('Yıldızlılar'));
      await tester.tap(find.text('Yıldızlılar'));
      await tester.pumpAndSettle();
      expect(find.text('Fincanın Hikâyesi'), findsOneWidget);
      await tester.ensureVisible(find.text('Taslaklar'));
      await tester.tap(find.text('Taslaklar'));
      await tester.pumpAndSettle();
      expect(find.text('Yarım kalan çalışman'), findsOneWidget);
      expect(find.text('Fincanın Hikâyesi'), findsNothing);
      expect(tester.takeException(), isNull);
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
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const paragraphs = [
        'Sakin bir gün sana iyi gelebilir.',
        'Bir sembol paylaşmadın; kendi çağrışımlarına yer açabilirsin.',
        'Yakın zamanda küçük bir mola düşünebilirsin.',
        'Bu hikâyenin devamını sen yazabilirsin.',
      ];
      await tester.pumpWidget(
        _app(
          Scaffold(
            appBar: AppBar(title: const Text('Fincanının Hikâyesi')),
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
