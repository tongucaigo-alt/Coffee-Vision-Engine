import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:atlas_contribution_app/src/annotation_page.dart';
import 'package:atlas_contribution_app/src/cropped_photo.dart';
import 'package:atlas_contribution_app/src/local_store.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'package:atlas_contribution_app/src/mvp/review_controller.dart';
import 'package:atlas_contribution_app/src/mvp/review_capture_settings.dart';
import 'package:atlas_contribution_app/src/mvp/review_engine.dart';
import 'package:atlas_contribution_app/src/mvp/review_models.dart';
import 'package:atlas_contribution_app/src/mvp/review_page.dart';
import 'package:atlas_contribution_app/src/mvp/review_preparation.dart';
import 'package:atlas_contribution_app/src/mvp/review_store.dart';
import 'package:atlas_contribution_app/src/photo_crop.dart';
import 'package:atlas_contribution_app/src/theme.dart';
import 'package:coffee_camera/coffee_camera.dart';
import 'package:coffee_camera/src/models/target_geometry.dart';
import 'package:coffee_camera/src/ui/camera_focus_region.dart';
import 'package:coffee_camera/src/ui/camera_target_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:image/image.dart' as img;

import '../test/fixtures.dart';
import '../test/contribution_capture_flow_test.dart' as contribution_flow;
import '../test/mvp_review_test.dart' as diagnostic;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  contribution_flow.main();
  testWidgets('diagnostic-only real physical pipeline with user observation', (
    tester,
  ) async {
    // Android's image codec now participates in crop validation. Give the
    // renderer an initial frame before awaiting that decode during import.
    await _diagnosticStage('first-frame', () async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox.expand())),
      );
      await tester.pumpAndSettle();
    });
    final temp = await _diagnosticStage(
      'fixture-directory',
      () => Directory.systemTemp.createTemp('atlas-mvp-diagnostic-'),
    );
    final store = ReviewStore(temp);
    addTearDown(() => temp.delete(recursive: true));
    final source = testImage();
    final sourceFile = File('${temp.path}/generated-camera.png');
    final croppedFile = File('${temp.path}/generated-camera-crop.png');
    await sourceFile.writeAsBytes(source);
    final croppedBytes = img.encodePng(
      img.copyCrop(
        img.decodeImage(source)!,
        x: 32,
        y: 40,
        width: 80,
        height: 100,
      ),
    );
    await croppedFile.writeAsBytes(croppedBytes);
    final expectedCrop = PhotoCrop(.2, .2, .5, .5);
    var p = await _diagnosticStage(
      'import-cropped-generated-photo',
      () => store.importPhoto(
        source,
        surface: ReviewSurface.cup,
        declaredRole: CaptureRole.free,
        capture: CameraCaptureResult(
          filePath: sourceFile.path,
          croppedCupPath: croppedFile.path,
          cropRect: const Rect.fromLTWH(32, 40, 80, 100),
          widthPixels: 160,
          heightPixels: 200,
          fileSizeBytes: source.length,
          croppedWidthPixels: 80,
          croppedHeightPixels: 100,
          croppedFileSizeBytes: croppedBytes.length,
          capturedAt: DateTime.parse(diagnostic.timestamp),
          qualityScore: 80,
          coffeePresenceScore: .8,
          coffeeDetected: true,
          mode: CameraCaptureMode.manual,
        ),
      ),
    );
    expect(p.displayCrop!.toJson(), expectedCrop.toJson());
    expect(p.photo.role, CaptureRole.free);
    p = p.update(
      confirmedAt: diagnostic.timestamp,
      photo: p.photo.annotated([
        RegionAnnotation(
          id: 'test-user-observation',
          box: RegionBox(.3, .3, .15, .15),
          label: 'tree',
        ),
      ], PhotoDecision.marked),
    );
    final session = diagnostic.review(photos: [p]);
    await _diagnosticStage('save-review', () => store.save(session));
    final controller = ReviewController(store: store, session: session);
    await _diagnosticStage('analyze-review', controller.analyze);
    final output = controller.session.photos.single.analysis!;
    expect(output['outcome'], anyOf('noMatch', 'insufficientSymbolEvidence'));
    expect(output['symbols'], isEmpty);
    expect(output['symbolAvailability'], 'notConfigured');
    expect(output['knowledgeRelease']['checksum'], mvpKnowledgeChecksum);
    expect(
      interpretationInput(controller.session)['userObservations'],
      hasLength(1),
    );
    final snapshot = controller.session.currentInitialObservation!;
    expect(snapshot['version'], initialObservationVersion);
    expect(snapshot['groupId'], session.groupId);
    expect(snapshot['priorExposures'], isEmpty);
    expect(snapshot['photos'].single['photoChecksum'], p.photo.checksum);
    expect(snapshot['photos'].single['regions'].single['label'], 'tree');
    expect(snapshot['photos'].single['displayCrop'], expectedCrop.toJson());
    final prepared = controller.session.preparedInput!;
    expect(prepared['version'], reviewPreparationVersion);
    expect(prepared['status'], 'ready');
    final payload = prepared['payload'] as Map;
    expect(payload['version'], reviewPayloadVersion);
    final observation = payload['photos'].single['userObservations'].single;
    expect(observation['origin'], 'userObservation');
    expect(observation['symbolName'], 'Ağaç');
    expect(observation['box'], p.photo.regions.single.box.toJson());
    final payloadText = jsonEncode(payload);
    for (final privateValue in [
      session.id,
      session.groupId,
      p.id,
      p.photo.checksum,
      p.photo.localName,
      temp.path,
    ]) {
      expect(payloadText, isNot(contains(privateValue)));
    }
    final restored = (await ReviewStore(temp).sessions()).single;
    expect(restored.recordVersion, reviewVersion);
    expect(
      restored.initialObservations,
      controller.session.initialObservations,
    );
    expect(restored.preparedInput, prepared);
    expect(restored.photos.single.displayCrop!.toJson(), expectedCrop.toJson());
    binding.reportData = {
      'fixture': 'test-generated-image-and-test-user-tree',
      'testOnly': true,
      'physicalPipeline': output,
      'interpretationInput': interpretationInput(controller.session),
      'part1': {
        'initialObservation': snapshot,
        'preparedInput': prepared,
        'durableReloadVerified': true,
        'payloadPrivateValuesExcluded': true,
        'displayCrop': expectedCrop.toJson(),
        'cropDurableReloadVerified': true,
      },
    };
    await tester.pumpWidget(
      MaterialApp(
        theme: contributionTheme(),
        home: ReviewPage(
          controller: controller,
          captureStore: DraftStore(Directory('${temp.path}/unused-old-store')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<CroppedPhoto>(find.byType(CroppedPhoto)).crop!.toJson(),
      expectedCrop.toJson(),
    );
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await binding.takeScreenshot('mvp-diagnostic-photo');
    await tester.ensureVisible(find.text('Gördüğüm şekilleri ekle'));
    await tester.tap(find.text('Gördüğüm şekilleri ekle'));
    await tester.pumpAndSettle();
    expect(find.byType(AnnotationPage), findsOneWidget);
    expect(
      tester.widget<CroppedPhoto>(find.byType(CroppedPhoto)).crop!.toJson(),
      expectedCrop.toJson(),
    );
    await tester.tap(find.text('Ağaç'));
    await tester.pumpAndSettle();
    final canvas = tester.getRect(
      find.byKey(const ValueKey('annotation-canvas')),
    );
    final selected = tester.getRect(
      find.byKey(const ValueKey('selected-region')),
    );
    expect((selected.left - canvas.left) / canvas.width, closeTo(.2, .00001));
    expect((selected.top - canvas.top) / canvas.height, closeTo(.2, .00001));
    expect(selected.width / canvas.width, closeTo(.3, .00001));
    expect(selected.height / canvas.height, closeTo(.3, .00001));
    await binding.takeScreenshot('mvp-diagnostic-cropped-annotation');
    await tester.pageBack();
    await tester.pumpAndSettle();
    binding.reportData!['part1']['sameReviewAnnotationCropVerified'] = true;
    await tester.scrollUntilVisible(find.text('İnceleme kaydedildi'), 200);
    await tester.pumpAndSettle();
    await binding.takeScreenshot('mvp-diagnostic-result');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('diagnostic-only ordered retry and durable restart', (
    tester,
  ) async {
    final temp = await Directory.systemTemp.createTemp(
      'atlas-mvp-retry-diagnostic-',
    );
    addTearDown(() => temp.delete(recursive: true));
    final store = ReviewStore(temp);
    final photos = <ReviewPhoto>[];
    for (final r in reviewCaptureRoles) {
      photos.add(
        (await store.importPhoto(
          testImage(),
          surface: ReviewSurface.cup,
          declaredRole: r,
        )).update(confirmedAt: diagnostic.timestamp),
      );
    }
    final session = diagnostic.review(photos: photos);
    await store.save(session);
    var fail = true;
    final calls = <String>[];
    final controller = ReviewController(
      store: store,
      session: session,
      loadEngine: () async => diagnostic.fakeEngine(
        vision: (input) async {
          calls.add(input.sourceId!);
          if (fail && input.sourceId == photos[1].id) {
            throw StateError('test-only failure');
          }
          return diagnostic.features(input);
        },
      ),
    );
    await controller.analyze();
    expect(controller.session.photos[1].failed, true);
    final initialObservations = controller.session.initialObservations;
    expect(initialObservations, hasLength(1));
    expect(
      controller.session.photos.every(
        (p) => p.photo.decision == PhotoDecision.skipped,
      ),
      true,
    );
    expect(controller.session.preparedInput!['technicalErrorCount'], 1);
    expect(
      controller
          .session
          .preparedInput!['payload']['photos'][1]['globalPhysicalMeasurements'],
      isNull,
    );
    expect(
      controller.session.photos[0].analysis!['outcome'],
      'insufficientSymbolEvidence',
    );
    final exact = controller.liveResults[photos[0].id];
    fail = false;
    await controller.analyze(retryPhotoId: photos[1].id);
    expect(calls, [photos[0].id, photos[1].id, photos[2].id, photos[1].id]);
    expect(identical(exact, controller.liveResults[photos[0].id]), true);
    final restored = (await ReviewStore(temp).sessions()).single;
    expect(restored.photos.every((p) => p.analyzed && !p.failed), true);
    expect(restored.initialObservations, initialObservations);
    expect(restored.preparedInput, controller.session.preparedInput);
    expect(restored.preparedInput!['technicalErrorCount'], 0);
    expect(restored.preparedInput!['status'], 'empty');
    binding.reportData!['retry'] = {
      'fixture': 'test-kds-and-test-record',
      'testOnly': true,
      'calls': calls,
      'outcomes': restored.photos.map((p) => p.analysis!['outcome']).toList(),
      'successfulExactInstancePreserved': true,
      'restartRevision': restored.revision,
      'initialObservationPreserved': true,
      'skippedObservationCount': restored.photos.length,
      'preparedInput': restored.preparedInput,
    };
    await controller.close();
    controller.dispose();
  });
  testWidgets('diagnostic-only 15 percent box, small center move and resize', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: contributionTheme(),
        home: AnnotationPage(
          photo: testPhoto(CaptureRole.free),
          image: MemoryImage(testImage()),
          displayCrop: PhotoCrop(.2, .2, .5, .5),
          onSave: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('İşaret'));
    await tester.pumpAndSettle();
    final canvas = find.byKey(const ValueKey('annotation-canvas'));
    final selected = find.byKey(const ValueKey('selected-region'));
    final image = tester.getRect(canvas);
    await tester.tapAt(image.center);
    await tester.pumpAndSettle();
    final initial = tester.getRect(selected);
    expect(initial.width / image.width, closeTo(.15, .00001));
    expect(initial.height / image.height, closeTo(.15, .00001));
    expect((initial.center - image.center).distance, lessThan(.01));

    // Shrink the new box to a size where all corner touch targets overlap.
    final shrink = await tester.startGesture(initial.bottomRight);
    await shrink.moveBy(Offset(-image.width * .11, -image.height * .11));
    await tester.pump();
    await shrink.up();
    await tester.pumpAndSettle();
    final small = tester.getRect(selected);
    expect(small.width / image.width, closeTo(.04, .00001));
    expect(small.height / image.height, closeTo(.04, .00001));
    for (var i = 0; i < 4; i++) {
      expect(
        tester
            .getRect(find.byKey(ValueKey('resize-corner-$i')))
            .contains(small.center),
        true,
      );
    }
    final move = await tester.startGesture(small.center);
    await move.moveBy(const Offset(6, 8));
    await tester.pump();
    final moved = tester.getRect(selected);
    expect(moved.left, closeTo(small.left + 6, .01));
    expect(moved.top, closeTo(small.top + 8, .01));
    expect(moved.width, closeTo(small.width, .01));
    expect(moved.height, closeTo(small.height, .01));
    await move.up();
    await tester.pumpAndSettle();

    final resize = await tester.startGesture(moved.bottomRight);
    await resize.moveBy(const Offset(4, 5));
    await tester.pump();
    final resized = tester.getRect(selected);
    expect((resized.topLeft - moved.topLeft).distance, lessThan(.01));
    expect(resized.width, closeTo(moved.width + 4, .01));
    expect(resized.height, closeTo(moved.height + 5, .01));
    await resize.up();
    await tester.pumpAndSettle();
    binding.reportData!['part1Annotation'] = {
      'fixture': 'test-generated-in-memory-image',
      'testOnly': true,
      'initialNormalizedWidth': initial.width / image.width,
      'initialNormalizedHeight': initial.height / image.height,
      'smallCenterMoveVerified': true,
      'smallCornerResizeVerified': true,
      'displayCrop': PhotoCrop(.2, .2, .5, .5).toJson(),
    };
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await binding.takeScreenshot('mvp-diagnostic-small-box');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final role in reviewCaptureRoles) {
    testWidgets('diagnostic-only synthetic camera focus ${role.name}', (
      tester,
    ) async {
      final config = reviewCameraConfig(role);
      await tester.pumpWidget(
        MaterialApp(
          theme: contributionTheme(),
          home: Scaffold(
            backgroundColor: Colors.black,
            body: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = constraints.biggest;
                  final target = TargetGeometry.fromViewport(size, config);
                  final region = CameraFocusRegion(
                    target: target,
                    handleGuide: config.handleGuide,
                  );
                  final mask = CoffeeRegionMask(
                    normalizedBounds: Rect.fromLTWH(
                      target.bounds.left / size.width,
                      target.bounds.top / size.height,
                      target.bounds.width / size.width,
                      target.bounds.height / size.height,
                    ),
                    width: 24,
                    height: 24,
                    intensities: Uint8List.fromList([
                      for (var y = 0; y < 24; y++)
                        for (var x = 0; x < 24; x++)
                          (x - 12) * (x - 12) + (y - 12) * (y - 12) < 100 &&
                                  (x + y) % 3 != 0
                              ? 210
                              : 0,
                    ]),
                    coverage: .5,
                  );
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomPaint(painter: _SyntheticFocusPainter(region)),
                      CameraBackgroundFocus(
                        region: region,
                        sigma: config.backgroundBlurSigma,
                      ),
                      TickerMode(
                        enabled: false,
                        child: CameraTargetOverlay(
                          config: config,
                          ringColor: Colors.greenAccent,
                          targetGeometry: target,
                          subjectDetected: true,
                          coffeeDetected: true,
                          coffeeMask: mask,
                          scanProgress: .55,
                          progress: .65,
                        ),
                      ),
                      Positioned(
                        top: 24,
                        left: 20,
                        right: 20,
                        child: Text(
                          '${reviewCaptureTitle(role)}\n${reviewCaptureInstruction(role)}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                          ),
                        ),
                      ),
                      const Positioned(
                        bottom: 24,
                        left: 20,
                        right: 20,
                        child: Text(
                          'Üretilmiş test görseli · Kamera donanımı kullanılmıyor',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CameraBackgroundFocus), findsOneWidget);
      expect(find.byType(CameraTargetOverlay), findsOneWidget);
      expect(
        tester
            .widget<CameraTargetOverlay>(find.byType(CameraTargetOverlay))
            .config
            .handleGuide,
        config.handleGuide,
      );
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await binding.takeScreenshot('mvp-diagnostic-camera-focus-${role.name}');
      binding.reportData ??= <String, dynamic>{};
      binding.reportData!['focus-${role.name}'] = {
        'fixture': 'generated-checkerboard-cup-and-mask',
        'testOnly': true,
        'cameraHardwareUsed': false,
        'handleGuide': config.handleGuide.name,
        'backgroundBlurSigma': config.backgroundBlurSigma,
      };
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}

Future<T> _diagnosticStage<T>(String name, Future<T> Function() action) async {
  debugPrint('ATLAS_DIAGNOSTIC $name start');
  try {
    final result = await action().timeout(
      const Duration(seconds: 30),
      onTimeout: () =>
          throw TimeoutException('ATLAS_DIAGNOSTIC $name exceeded 30s'),
    );
    debugPrint('ATLAS_DIAGNOSTIC $name complete');
    return result;
  } catch (error) {
    debugPrint('ATLAS_DIAGNOSTIC $name failed: $error');
    rethrow;
  }
}

class _SyntheticFocusPainter extends CustomPainter {
  const _SyntheticFocusPainter(this.region);
  final CameraFocusRegion region;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var y = 0; y < size.height; y += 16) {
      for (var x = 0; x < size.width; x += 16) {
        paint.color = ((x ~/ 16 + y ~/ 16) % 2 == 0)
            ? const Color(0xffbbada0)
            : const Color(0xff86756a);
        canvas.drawRect(
          Rect.fromLTWH(x.toDouble(), y.toDouble(), 16, 16),
          paint,
        );
      }
    }
    paint
      ..color = const Color(0xfff0e8d8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16;
    canvas.drawPath(region.handleOutline, paint);
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(region.target.center, region.target.radius, paint);
    paint.color = const Color(0xff6b4230);
    canvas.drawCircle(region.target.center, region.target.radius * .87, paint);
    paint.color = const Color(0xff332017);
    for (var i = 0; i < 55; i++) {
      final dx = ((i * 37) % 101 - 50) / 75 * region.target.radius;
      final dy = ((i * 61) % 101 - 50) / 75 * region.target.radius;
      if (dx * dx + dy * dy <
          region.target.radius * region.target.radius * .6) {
        canvas.drawCircle(
          region.target.center + Offset(dx, dy),
          4 + i % 4,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SyntheticFocusPainter oldDelegate) =>
      oldDelegate.region.target.viewportSize != region.target.viewportSize ||
      oldDelegate.region.handleGuide != region.handleGuide;
}
