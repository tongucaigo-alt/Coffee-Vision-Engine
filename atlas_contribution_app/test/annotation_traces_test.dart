import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/annotation_sequence.dart';
import 'package:atlas_contribution_app/src/annotation_page.dart';
import 'package:atlas_contribution_app/src/trace_overlay.dart';
import 'package:atlas_contribution_app/src/opencv_traces.dart';
import 'package:atlas_contribution_app/src/ai/ai_store.dart';
import 'fixtures.dart';
import 'trace_integration_test.dart' show photo, setFor;

void main() {
  testWidgets('colored aid appears in editor only after durable exposure, preserving canvas', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final p = photo();
    final gate = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(MaterialApp(home: AnnotationSequence(
      photos: [p], imageFor: (_) => MemoryImage(testImage()),
      onSave: (_) async {}, loadTraces: () async => setFor(p),
      onTraceShown: (_) { calls++; return gate.future; },
    )));
    await tester.pump();
    expect(calls, 1);
    expect(find.byType(TraceOverlay), findsNothing);
    final state = tester.state(find.byType(AnnotationPage));
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(TraceOverlay), findsOneWidget);
    expect(tester.state(find.byType(AnnotationPage)), same(state));
    expect(find.ancestor(of: find.byType(TraceOverlay), matching: find.byType(InteractiveViewer)), findsOneWidget);
    await tester.tap(find.byTooltip('Yakınlaştır'));
    await tester.pumpAndSettle();
    expect(tester.widget<InteractiveViewer>(find.byType(InteractiveViewer)).transformationController!.value.getMaxScaleOnAxis(), greaterThan(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('native failure leaves normal annotation usable', (tester) async {
    await tester.pumpWidget(MaterialApp(home: AnnotationSequence(
      photos: [photo()], imageFor: (_) => MemoryImage(testImage()),
      onSave: (_) async {}, loadTraces: () async => throw StateError('native'),
    )));
    await tester.pumpAndSettle();
    expect(find.byType(AnnotationPage), findsOneWidget);
    expect(find.byType(TraceOverlay), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('trace exposure survives reopening, is distinct from narrative and deduplicates', () async {
    final dir = await Directory.systemTemp.createTemp('atlas-aid-');
    addTearDown(() => dir.delete(recursive: true));
    final store = AiStore(dir);
    for (var i = 0; i < 2; i++) {
      await store.exposeTraceAid(sessionId: 'linked-root', groupId: 'group', photoIdentity: 'identity', algorithm: traceAlgorithm);
    }
    final reopened = AiStore(dir);
    final rows = await reopened.exposures('group');
    expect(rows, hasLength(1));
    expect(rows.single['kind'], 'coloredTraceAid');
    expect(rows.single['algorithm'], traceAlgorithm);
    expect((await reopened.read())['results'], isEmpty);
    await reopened.deleteSession('linked-root');
    await expectLater(reopened.exposeTraceAid(sessionId: 'linked-root', groupId: 'group', photoIdentity: 'new', algorithm: traceAlgorithm), throwsA(anything));
  });
}
