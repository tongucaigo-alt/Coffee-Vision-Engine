import 'dart:async';

import 'package:atlas_k6_end_to_end_demo/src/capture/atlas_three_angle_capture_app.dart';
import 'package:atlas_k6_end_to_end_demo/src/capture/atlas_three_angle_capture_models.dart';
import 'package:atlas_k6_end_to_end_demo/src/integration/atlas_k6_result.dart';
import 'package:atlas_k6_end_to_end_demo/src/integration/atlas_k6_surface_processor.dart';
import 'package:atlas_k6_end_to_end_demo/src/integration/atlas_three_angle_engine_controller.dart';
import 'package:coffee_camera/coffee_camera.dart';
import 'package:coffee_knowledge/coffee_knowledge.dart';
import 'package:coffee_pattern/coffee_pattern.dart';
import 'package:coffee_symbol/coffee_symbol.dart';
import 'package:coffee_vision/coffee_vision.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

void main() {
  testWidgets('tolerates the zero-size Android warm-up frame', (tester) async {
    tester.view.physicalSize = Size.zero;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app());
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(360, 800);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('presents the three roles in their canonical order', (
    tester,
  ) async {
    await tester.pumpWidget(_app());

    expect(find.text('Fincanını üç açıdan çek'), findsOneWidget);
    final positions = [
      tester.getTopLeft(find.text('Üst açı')).dy,
      tester.getTopLeft(find.text('Yan açı · Kulp sağda')).dy,
      tester.getTopLeft(find.text('Yan açı · Kulp solda')).dy,
    ];
    expect(positions[0], lessThan(positions[1]));
    expect(positions[1], lessThan(positions[2]));
  });

  testWidgets('setup failure is visible and blocks capture', (tester) async {
    var cameraCalls = 0;
    await tester.pumpWidget(
      AtlasThreeAngleCaptureApp(
        processSurface: ({required role, required path}) async =>
            _emptySurfaceResult(),
        cameraLauncher: (_, role) async {
          cameraCalls++;
          return _capture('must-not-open.jpg');
        },
        releaseCaptures: (_) async {},
        setupErrorMessage: 'Motor verileri doğrulanamadı.',
      ),
    );

    expect(find.text('Motor verileri doğrulanamadı.'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('start-three-angle-capture')),
          )
          .onPressed,
      isNull,
    );
    expect(cameraCalls, 0);
  });

  testWidgets('runs one camera attempt per step and completes the session', (
    tester,
  ) async {
    final roles = <AtlasCupCaptureRole>[];
    await tester.pumpWidget(
      _app(
        launcher: (_, role) async {
          roles.add(role);
          return _capture('missing-${role.name}.jpg');
        },
      ),
    );

    await tester.tap(find.byKey(const ValueKey('start-three-angle-capture')));
    await tester.pumpAndSettle();
    expect(find.text('Üst açıyı çek'), findsOneWidget);

    for (final expectedLabel in [
      'Kulp sağdayken çek',
      'Kulp soldayken çek',
      'Çekimleri tamamla',
    ]) {
      await tester.tap(find.byKey(const ValueKey('capture-primary-action')));
      await tester.pumpAndSettle();
      expect(find.text(expectedLabel), findsOneWidget);
    }

    expect(roles, AtlasCupCaptureRole.values);
    await tester.tap(find.byKey(const ValueKey('capture-primary-action')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('three-angle-complete')), findsOneWidget);
    expect(find.text('Üç açı hazır'), findsOneWidget);
  });

  testWidgets('partial back flow can preserve or discard the session', (
    tester,
  ) async {
    final released = <CameraCaptureResult>[];
    await tester.pumpWidget(
      _app(release: (captures) async => released.addAll(captures)),
    );
    await tester.tap(find.byKey(const ValueKey('start-three-angle-capture')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('capture-primary-action')));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Geri'));
    await tester.pumpAndSettle();
    expect(find.text('Çekimden çıkılsın mı?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('keep-capturing')));
    await tester.pumpAndSettle();
    expect(find.text('1 / 3'), findsOneWidget);
    expect(released, isEmpty);

    await tester.tap(find.byTooltip('Geri'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('discard-captures')));
    await tester.pumpAndSettle();
    expect(find.text('Fincanını üç açıdan çek'), findsOneWidget);
    expect(released, hasLength(1));
  });

  testWidgets('retake is transactional in the app-local flow', (tester) async {
    final original = _capture('missing-top-original.jpg');
    final replacement = _capture('missing-top-replacement.jpg');
    final responses = <CameraCaptureResult?>[
      original,
      _capture('missing-right.jpg'),
      _capture('missing-left.jpg'),
      null,
      replacement,
    ];
    final released = <CameraCaptureResult>[];
    await tester.pumpWidget(
      _app(
        launcher: (_, _) async => responses.removeAt(0),
        release: (captures) async => released.addAll(captures),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('start-three-angle-capture')));
    await tester.pumpAndSettle();
    for (var index = 0; index < 3; index++) {
      await tester.tap(find.byKey(const ValueKey('capture-primary-action')));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.byKey(const ValueKey('retake-top')));
    await tester.pumpAndSettle();
    expect(released, isEmpty);
    expect(find.text('Çekimleri tamamla'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('retake-top')));
    await tester.pumpAndSettle();
    expect(released, hasLength(1));
    expect(identical(released.single, original), isTrue);
  });

  testWidgets('analysis is explicit and preserves one result per angle', (
    tester,
  ) async {
    final calls = <AtlasCupCaptureRole>[];
    await tester.pumpWidget(
      _app(
        processSurface: ({required role, required path}) async {
          calls.add(role);
          return switch (role) {
            AtlasCupCaptureRole.top => _emptySurfaceResult(),
            AtlasCupCaptureRole.handleRight => _insufficientSurfaceResult(),
            AtlasCupCaptureRole.handleLeft => _symbolSurfaceResult(),
          };
        },
      ),
    );
    await _completeCapture(tester);

    expect(calls, isEmpty);
    expect(find.byKey(const ValueKey('analyze-three-angles')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('analyze-three-angles')));
    await tester.pumpAndSettle();

    expect(calls, AtlasCupCaptureRole.values);
    expect(
      find.byKey(const ValueKey('three-angle-analysis-results')),
      findsOneWidget,
    );
    expect(find.text('Eşleşme yok'), findsOneWidget);
    expect(find.text('Sembol kanıtı yetersiz'), findsOneWidget);
    expect(find.text('Sembol adayı var'), findsOneWidget);
    expect(find.textContaining('test-symbol-001'), findsOneWidget);
    expect(find.text('Test Symbol 1 · 1/3 açıda · 1 aday'), findsOneWidget);
    expect(find.text('Tek açıda gözlendi'), findsOneWidget);
  });

  testWidgets(
    'groups exact symbols across successful angles without hiding errors',
    (tester) async {
      var rightAttempts = 0;
      await tester.pumpWidget(
        _app(
          processSurface: ({required role, required path}) async {
            if (role == AtlasCupCaptureRole.handleRight &&
                rightAttempts++ == 0) {
              throw AtlasSurfaceProcessingException(
                stage: AtlasSurfaceProcessingStage.knowledge,
                cause: StateError('test-only failure'),
              );
            }
            return _symbolSurfaceResult(
              preferredNames: const {'en': 'Tree', 'tr': 'Ağaç'},
            );
          },
        ),
      );
      await _completeCapture(tester);
      await tester.tap(find.byKey(const ValueKey('analyze-three-angles')));
      await tester.pumpAndSettle();

      expect(find.text('Ağaç · 2/3 açıda · 2 aday'), findsOneWidget);
      expect(find.text('Birden fazla açıda gözlendi'), findsOneWidget);
      expect(find.text('Teknik hata'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('retry-angle-handleRight')),
        findsOneWidget,
      );
    },
  );

  testWidgets('falls back to symbol id when tr and en names are absent', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        processSurface: ({required role, required path}) async =>
            role == AtlasCupCaptureRole.top
            ? _symbolSurfaceResult(preferredNames: const {'de': 'Baum'})
            : _emptySurfaceResult(),
      ),
    );
    await _completeCapture(tester);
    await tester.tap(find.byKey(const ValueKey('analyze-three-angles')));
    await tester.pumpAndSettle();

    expect(find.text('test-symbol-001 · 1/3 açıda · 1 aday'), findsOneWidget);
  });

  testWidgets('shows active angle progress while processing', (tester) async {
    final gate = Completer<AtlasK6SurfaceResult>();
    await tester.pumpWidget(
      _app(processSurface: ({required role, required path}) => gate.future),
    );
    await _completeCapture(tester);

    await tester.tap(find.byKey(const ValueKey('analyze-three-angles')));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('three-angle-analysis-progress')),
      findsOneWidget,
    );
    expect(find.text('Üst açı analiz ediliyor'), findsOneWidget);
    expect(find.text('0 / 3 açı tamamlandı'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('start-new-three-angle-capture')),
          )
          .onPressed,
      isNull,
    );

    gate.complete(_emptySurfaceResult());
    await tester.pumpAndSettle();
  });

  testWidgets('technical error offers retry only for its angle', (
    tester,
  ) async {
    final calls = <AtlasCupCaptureRole>[];
    var rightAttempts = 0;
    await tester.pumpWidget(
      _app(
        processSurface: ({required role, required path}) async {
          calls.add(role);
          if (role == AtlasCupCaptureRole.handleRight && rightAttempts++ == 0) {
            throw AtlasSurfaceProcessingException(
              stage: AtlasSurfaceProcessingStage.pattern,
              cause: StateError('test-only failure'),
            );
          }
          return _emptySurfaceResult();
        },
      ),
    );
    await _completeCapture(tester);
    await tester.tap(find.byKey(const ValueKey('analyze-three-angles')));
    await tester.pumpAndSettle();

    expect(find.text('Teknik hata'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('retry-angle-handleRight')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('retry-angle-top')), findsNothing);
    expect(find.byKey(const ValueKey('retry-angle-handleLeft')), findsNothing);

    await tester.ensureVisible(
      find.byKey(const ValueKey('retry-angle-handleRight')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('retry-angle-handleRight')));
    await tester.pumpAndSettle();

    expect(calls, [
      ...AtlasCupCaptureRole.values,
      AtlasCupCaptureRole.handleRight,
    ]);
    expect(find.text('Teknik hata'), findsNothing);
    expect(find.byKey(const ValueKey('retry-angle-handleRight')), findsNothing);
  });

  testWidgets('has no layout overflow on supported phone viewports', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    for (final size in [const Size(360, 800), const Size(412, 915)]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'intro at $size');

      await tester.ensureVisible(
        find.byKey(const ValueKey('start-three-angle-capture')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('start-three-angle-capture')));
      await tester.pumpAndSettle();
      for (var index = 0; index < 3; index++) {
        await tester.tap(find.byKey(const ValueKey('capture-primary-action')));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull, reason: 'session at $size');

      await tester.tap(find.byKey(const ValueKey('capture-primary-action')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'complete at $size');

      await tester.ensureVisible(
        find.byKey(const ValueKey('analyze-three-angles')),
      );
      await tester.tap(find.byKey(const ValueKey('analyze-three-angles')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'results at $size');
      await tester.pumpWidget(const SizedBox());
    }
  });
}

Future<void> _completeCapture(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('start-three-angle-capture')));
  await tester.pumpAndSettle();
  for (var index = 0; index < 3; index++) {
    await tester.tap(find.byKey(const ValueKey('capture-primary-action')));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byKey(const ValueKey('capture-primary-action')));
  await tester.pumpAndSettle();
}

Widget _app({
  Future<CameraCaptureResult?> Function(
    BuildContext context,
    AtlasCupCaptureRole role,
  )?
  launcher,
  Future<void> Function(Iterable<CameraCaptureResult> captures)? release,
  AtlasThreeAngleSurfaceOperation? processSurface,
}) {
  return AtlasThreeAngleCaptureApp(
    processSurface:
        processSurface ??
        ({required role, required path}) async => _emptySurfaceResult(),
    cameraLauncher:
        launcher ?? (_, role) async => _capture('missing-${role.name}.jpg'),
    releaseCaptures: release ?? (_) async {},
  );
}

AtlasK6SurfaceResult _emptySurfaceResult() {
  final featureSet = VisionFeatureSet(
    surfaceType: VisionSurfaceType.cup,
    imageProvenance: VisionFeatureImageProvenance(
      sourceFormat: VisionImageFormat.jpeg,
      sourceWidth: 100,
      sourceHeight: 100,
      workingFormat: VisionImageFormat.png,
      workingWidth: 512,
      workingHeight: 512,
      workingResolution: 512,
      contentRect: VisionRect(left: 0, top: 0, right: 1, bottom: 1),
    ),
  );
  return AtlasK6SurfaceResult(
    featureSet: featureSet,
    patternResult: PatternAnalysisResult(
      surfaceType: PatternSurfaceType.cup,
      candidates: const [],
    ),
    candidateResults: const [],
    symbolCandidates: const [],
    processingDuration: Duration.zero,
  );
}

AtlasK6SurfaceResult _insufficientSurfaceResult() {
  final featureSet = createFeatureSet(VisionSurfaceType.cup);
  final patternResult = createPatternResult(featureSet);
  final matches = const KnowledgeRecordCollectionMatcher().match(
    candidate: patternResult.candidates.single,
    records: createDataset().activeRecords,
  );
  return AtlasK6SurfaceResult(
    featureSet: featureSet,
    patternResult: patternResult,
    candidateResults: [
      AtlasK6CandidateResult(
        candidate: patternResult.candidates.single,
        matches: matches,
      ),
    ],
    symbolCandidates: const [],
    processingDuration: Duration.zero,
  );
}

AtlasK6SurfaceResult _symbolSurfaceResult({
  Map<String, String>? preferredNames,
}) {
  final insufficient = _insufficientSurfaceResult();
  final release = createKnowledgeRelease();
  final symbols = createSymbolDataset(
    includeBindings: true,
    knowledgeRelease: release,
    firstSymbolPreferredNames: preferredNames,
  );
  final candidates = const SymbolCandidateResolver().resolve(
    knowledgeRelease: release,
    knowledgeMatches: [
      for (final candidate in insufficient.candidateResults)
        ...candidate.matches,
    ],
    definitions: symbols.definitions,
    bindings: symbols.bindings,
  );
  return AtlasK6SurfaceResult(
    featureSet: insufficient.featureSet,
    patternResult: insufficient.patternResult,
    candidateResults: insufficient.candidateResults,
    symbolCandidates: candidates,
    processingDuration: Duration.zero,
  );
}

CameraCaptureResult _capture(String path) {
  return CameraCaptureResult(
    filePath: path,
    cropRect: const Rect.fromLTWH(0, 0, 10, 10),
    widthPixels: 100,
    heightPixels: 100,
    fileSizeBytes: 10,
    capturedAt: DateTime.utc(2026, 9, 3),
    qualityScore: 80,
    coffeePresenceScore: 0.8,
    coffeeDetected: true,
    mode: CameraCaptureMode.manual,
  );
}
