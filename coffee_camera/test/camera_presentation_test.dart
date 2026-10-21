import 'dart:io';
import 'dart:ui' as ui;

import 'package:coffee_camera/src/config/coffee_camera_config.dart';
import 'package:coffee_camera/src/capture/captured_image_processor.dart';
import 'package:coffee_camera/src/models/target_geometry.dart';
import 'package:coffee_camera/src/ui/camera_focus_region.dart';
import 'package:coffee_camera/src/ui/camera_light_hint.dart';
import 'package:coffee_camera/src/ui/camera_presentation.dart';
import 'package:coffee_camera/src/ui/camera_target_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _palette = CoffeeCameraTheme(
  background: Color(0xff1e100a),
  overlay: Color(0x55000000),
  foreground: Color(0xfffaf7f2),
  mutedForeground: Color(0xffdfd5c4),
);
final _logo = MemoryImage(
  File(
    '../atlas_contribution_app/assets/brand/atlas-logo.png',
  ).readAsBytesSync(),
);
const _boundaryKey = Key('preview-boundary');

void main() {
  setUpAll(() async {
    final text = FontLoader('AtlasPreview')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File(
              '../atlas_contribution_app/assets/brand/PlusJakartaSans.ttf',
            ).readAsBytesSync(),
          ),
        ),
      );
    await text.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File(
              '${Platform.environment['FLUTTER_ROOT'] ?? File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
            ).readAsBytesSync(),
          ),
        ),
      );
    await icons.load();
  });
  testWidgets(
    'branding does not change processed image bytes or crop metadata',
    (tester) async {
      await tester.runAsync(() async {
        final temp = await Directory.systemTemp.createTemp('atlas-brand-crop-');
        try {
          final input = File('${temp.path}/input.png');
          await input.writeAsBytes(
            File(
              '../atlas_contribution_app/assets/guide/example-cup.png',
            ).readAsBytesSync(),
          );
          const processor = CapturedImageProcessor();
          final plain = await processor.process(
            path: input.path,
            viewportSize: const Size(390, 844),
            config: const CoffeeCameraConfig(),
          );
          final before = await File(plain.croppedPath!).readAsBytes();
          final branded = await processor.process(
            path: input.path,
            viewportSize: const Size(390, 844),
            config: CoffeeCameraConfig(
              presentation: CoffeeCameraPresentation(
                backgroundImage: _logo,
                title: 'Fincanını Tara',
              ),
            ),
          );
          expect(branded.cropRect, plain.cropRect);
          expect(branded.originalWidth, plain.originalWidth);
          expect(branded.originalHeight, plain.originalHeight);
          expect(
            await File(branded.croppedPath!).readAsBytes(),
            orderedEquals(before),
          );
        } finally {
          await temp.delete(recursive: true);
        }
      });
    },
  );

  testWidgets(
    'light hint waits two seconds and resets for scan, torch and pause',
    (tester) async {
      final hint = CameraLightHint();
      hint.update(live: true, scanVisible: false, torch: false);
      await tester.pump(const Duration(milliseconds: 1999));
      expect(hint.visible, false);
      await tester.pump(const Duration(milliseconds: 1));
      expect(hint.visible, true);
      hint.update(live: true, scanVisible: true, torch: false);
      expect(hint.visible, false);
      hint.update(live: true, scanVisible: false, torch: true);
      await tester.pump(const Duration(seconds: 3));
      expect(hint.visible, false);
      hint.update(live: true, scanVisible: false, torch: false);
      await tester.pump(const Duration(seconds: 1));
      hint.update(live: false, scanVisible: false, torch: false);
      await tester.pump(const Duration(seconds: 3));
      expect(hint.visible, false);
      hint.update(live: true, scanVisible: false, torch: false);
      await tester.pump(const Duration(seconds: 2));
      expect(hint.visible, true);
      hint.dispose();
    },
  );

  for (final (guide, saucer) in [
    for (final guide in CameraHandleGuide.values) (guide, false),
    (CameraHandleGuide.none, true),
  ]) {
    testWidgets(
      'watermark leaves circle and handle pixel-identical: $guide, saucer=$saucer',
      (tester) async {
        const size = Size(360, 800);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final target = saucer
            ? TargetGeometry.forSaucer(size, const SaucerCaptureConfig())
            : TargetGeometry.fromViewport(size, const CoffeeCameraConfig());
        final region = CameraFocusRegion(target: target, handleGuide: guide);
        Future<Uint8List> render(bool logo) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(fontFamily: 'AtlasPreview'),
              home: RepaintBoundary(
                key: _boundaryKey,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const ColoredBox(color: Color(0xff4b403a)),
                    if (logo)
                      CameraBrandWatermark(image: _logo, region: region),
                  ],
                ),
              ),
            ),
          );
          await tester.runAsync(
            () =>
                precacheImage(_logo, tester.element(find.byKey(_boundaryKey))),
          );
          await tester.pump();
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(_boundaryKey),
          );
          return (await tester.runAsync(() async {
            final image = await boundary.toImage();
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!.buffer.asUint8List();
            image.dispose();
            return bytes;
          }))!;
        }

        final plain = await render(false);
        final branded = await render(true);
        var protected = 0;
        var outsideDifferences = 0;
        for (var y = 2; y < 798; y += 2) {
          for (var x = 2; x < 358; x += 2) {
            final point = Offset(x + .5, y + .5);
            final index = (y * 360 + x) * 4;
            final same = List.generate(
              4,
              (c) => plain[index + c] == branded[index + c],
            ).every((v) => v);
            if ([
              for (final dx in [-1.0, 0.0, 1.0])
                for (final dy in [-1.0, 0.0, 1.0]) point + Offset(dx, dy),
            ].every(region.clearArea.contains)) {
              expect(
                same,
                true,
                reason: 'Logo leaked into clear area at $point',
              );
              protected++;
            } else if (!same) {
              outsideDifferences++;
            }
          }
        }
        expect(protected, greaterThan(5000));
        expect(outsideDifferences, greaterThan(1000));
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  final variants = <String, (Size, double, CameraHandleGuide, bool)>{
    'free': (const Size(390, 844), 1, CameraHandleGuide.none, false),
    'handle-right': (const Size(390, 844), 1, CameraHandleGuide.right, false),
    'handle-left': (const Size(390, 844), 1, CameraHandleGuide.left, false),
    'saucer': (const Size(390, 844), 1, CameraHandleGuide.none, true),
    'small-large-text': (
      const Size(320, 568),
      2,
      CameraHandleGuide.right,
      false,
    ),
    'tall-large-text': (const Size(412, 915), 2, CameraHandleGuide.none, false),
  };
  for (final entry in variants.entries) {
    testWidgets('branded preview fits target exclusions: ${entry.key}', (
      tester,
    ) async {
      final (size, scale, guide, saucer) = entry.value;
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final config = CoffeeCameraConfig(theme: _palette, handleGuide: guide);
      final target = saucer
          ? TargetGeometry.forSaucer(size, config.saucerConfig)
          : TargetGeometry.fromViewport(size, config);
      var auto = true;
      var finishCalls = 0;
      final presentation = CoffeeCameraPresentation(
        backgroundImage: _logo,
        title: saucer ? 'Tabak Fotoğrafı' : 'Fincanını Tara',
        stepLabel: saucer
            ? 'İsteğe bağlı'
            : switch (guide) {
                CameraHandleGuide.none => 'Serbest açı · 1/3',
                CameraHandleGuide.right => 'Kulp sağda · 2/3',
                CameraHandleGuide.left => 'Kulp solda · 3/3',
              },
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'AtlasPreview'),
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(scale),
            ),
            child: Scaffold(
              body: RepaintBoundary(
                key: _boundaryKey,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(painter: _SyntheticScene(target)),
                    CameraBrandWatermark(
                      image: _logo,
                      region: CameraFocusRegion(
                        target: target,
                        handleGuide: guide,
                      ),
                    ),
                    CameraTargetOverlay(
                      config: config,
                      ringColor: config.theme.idleRing,
                      targetGeometry: target,
                    ),
                    StatefulBuilder(
                      builder: (context, setState) => CameraPresentationChrome(
                        presentation: presentation,
                        theme: _palette,
                        target: target,
                        instruction: saucer
                            ? 'Tabağı hedef alana yerleştir.'
                            : guide == CameraHandleGuide.none
                            ? 'Fincan sabit kalsın; kamerayla telvenin yoğun bölgesini göster.'
                            : guide == CameraHandleGuide.right
                            ? 'Fincan sabit kalsın; kamerayı sağ kulp çizgisine göre hizala.'
                            : 'Fincan sabit kalsın; kamerayı sol kulp çizgisine göre hizala.',
                        guidance: saucer
                            ? 'Tabağı hedef alana yerleştir'
                            : 'Fincanı hedef alanına getir',
                        shutter: IconButton.filled(
                          key: const Key('coffee-camera-shutter'),
                          onPressed: () {},
                          style: IconButton.styleFrom(
                            fixedSize: const Size.square(76),
                            backgroundColor: _palette.foreground,
                            foregroundColor: _palette.background,
                          ),
                          icon: const Icon(Icons.camera_alt),
                        ),
                        onBack: () {},
                        onFlash: () {},
                        torch: false,
                        showLightHint: true,
                        autoVisible: !saucer,
                        autoEnabled: auto,
                        onAutoChanged: (value) => setState(() => auto = value),
                        onFinish: saucer || guide == CameraHandleGuide.none
                            ? null
                            : () => finishCalls++,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => precacheImage(_logo, tester.element(find.byKey(_boundaryKey))),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      final header = tester.getRect(
        find.byKey(const Key('coffee-camera-brand-header')),
      );
      final footer = tester.getRect(
        find.byKey(const Key('coffee-camera-brand-footer')),
      );
      expect(header.bottom, lessThanOrEqualTo(target.bounds.top));
      expect(footer.top, greaterThanOrEqualTo(target.bounds.bottom));
      expect(
        tester.getSize(find.byKey(const Key('coffee-camera-shutter'))),
        const Size(76, 76),
      );
      if (!saucer && scale == 1) {
        await tester.tap(find.byKey(const Key('coffee-camera-auto-switch')));
        await tester.pump();
        expect(find.text('Otomatik · Kapalı'), findsOneWidget);
        expect(
          tester
              .getSize(find.byKey(const Key('coffee-camera-auto-switch')))
              .height,
          greaterThanOrEqualTo(48),
        );
      }
      final finish = find.byKey(const Key('coffee-finish-sequence'));
      if (!saucer && guide != CameraHandleGuide.none) {
        final flash = find.byTooltip('Işığı aç');
        final finishRect = tester.getRect(finish);
        expect(finish.hitTestable(), findsOneWidget);
        expect(finishRect.top, tester.getRect(flash).top);
        expect(
          finishRect.left,
          greaterThanOrEqualTo(tester.getRect(flash).right),
        );
        expect(finishRect.right, lessThanOrEqualTo(size.width - 12));
        expect(finishRect.bottom, lessThanOrEqualTo(target.bounds.top));
        expect(finishRect.height, greaterThanOrEqualTo(48));
        await tester.drag(
          find.byKey(const Key('coffee-camera-brand-header')),
          const Offset(0, -300),
        );
        await tester.pump(const Duration(seconds: 1));
        expect(tester.getRect(finish), finishRect);
        expect(finish.hitTestable(), findsOneWidget);
        await tester.tap(finish);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(finishCalls, 1);
      } else {
        expect(finish, findsNothing);
      }
      if (const bool.fromEnvironment('WRITE_CAMERA_PREVIEWS')) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(_boundaryKey),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final png = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!.buffer.asUint8List();
          final directory = Directory(
            '../atlas_contribution_app/build/camera-brand/previews',
          )..createSync(recursive: true);
          await File('${directory.path}/${entry.key}.png').writeAsBytes(png);
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
}

/// Local illustration for layout QA; this is not a camera or detection fixture.
class _SyntheticScene extends CustomPainter {
  _SyntheticScene(this.target);
  final TargetGeometry target;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xff776455),
    );
    for (var y = 0.0; y < size.height; y += 32) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y - 8),
        Paint()
          ..color = const Color(0xff806c5c)
          ..strokeWidth = 2,
      );
    }
    canvas.drawCircle(
      target.center,
      target.radius * .80,
      Paint()..color = const Color(0xffddd4bc),
    );
    canvas.drawCircle(
      target.center,
      target.radius * .69,
      Paint()..color = const Color(0xffb2a992),
    );
    for (var i = 0; i < 28; i++) {
      final point =
          target.center +
          Offset.fromDirection(i * 2.39, target.radius * (.12 + (i % 5) * .11));
      canvas.drawCircle(
        point,
        3 + (i % 4) * 1.6,
        Paint()..color = const Color(0xff61432e),
      );
    }
  }

  @override
  bool shouldRepaint(_SyntheticScene oldDelegate) => false;
}
