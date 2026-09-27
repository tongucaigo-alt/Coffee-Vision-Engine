import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coffee_vision/coffee_vision.dart';
import 'package:image/image.dart' as img;
import 'package:atlas_contribution_app/src/mvp/regional_summary.dart';
import 'package:atlas_contribution_app/src/ai/ai_contract.dart';
import 'package:atlas_contribution_app/src/ai/narrative.dart';
import 'package:atlas_contribution_app/src/fortune_progress.dart';
import 'ai_test.dart' show contextData;

Map<String, dynamic> richContext() {
  final c = contextData()..['version'] = 'atlas-fortune-context-v2';
  for (final p in c['photos'] as List) {
    p['regionalSummary'] = {
      'version': regionalSummaryVersion,
      'bands': [
        {'position': 'top', 'density': .1},
        {'position': 'middle', 'density': .2},
        {'position': 'bottom', 'density': .6},
      ],
      'components': [],
      'relations': [],
    };
  }
  return freezeNarrativeContext(c, planNarrative([]));
}

void main() {
  test(
    'real engine regions retain independent axes and normalized centers',
    () async {
      final image = img.Image(width: 240, height: 240)
        ..clear(img.ColorRgb8(245, 245, 245));
      img.fillRect(
        image,
        x1: 35,
        y1: 140,
        x2: 95,
        y2: 205,
        color: img.ColorRgb8(30, 25, 20),
      );
      img.fillRect(
        image,
        x1: 140,
        y1: 125,
        x2: 180,
        y2: 175,
        color: img.ColorRgb8(30, 25, 20),
      );
      final features = await CoffeeVisionEngine().analyzeFeatures(
        VisionImageInput(
          imageBytes: img.encodePng(image),
          surfaceType: VisionSurfaceType.cup,
        ),
      );
      final summary = summarizeRegions(features);
      validateRegionalSummary(summary);
      final bands = {
        for (final b in summary['bands']) b['position']: b['density'],
      };
      expect(
        bands.keys,
        unorderedEquals(['top', 'middle', 'bottom', 'left', 'center', 'right']),
      );
      expect(bands['bottom'], greaterThan(bands['top']));
      expect(summary['components'], isNotEmpty);
      expect(jsonEncode(summary), isNot(contains('sourceId')));
    },
  );

  test('v2 rejects private fields and dangling relation references', () {
    expect(
      validateAiContext(richContext())['version'],
      'atlas-fortune-context-v2',
    );
    final private = richContext();
    private['photos'][0]['regionalSummary']['localPath'] = 'private';
    expect(() => validateAiContext(private), throwsFormatException);
    final broken = richContext();
    broken['photos'][0]['regionalSummary']['relations'] = [
      {'from': 1, 'to': 2, 'distance': .1},
    ];
    expect(() => validateAiContext(broken), throwsFormatException);
    final failed = richContext();
    failed['photos'][0]['analysisState'] = 'technicalError';
    expect(() => validateAiContext(failed), throwsFormatException);
  });

  test(
    'topics rotate without consecutive repetition and freeze independently',
    () {
      final history = <Map<String, dynamic>>[];
      String? previous;
      final topics = <String>{};
      for (var i = 0; i < 12; i++) {
        final plan = planNarrative(history.take(5).toList());
        expect(plan['topic'], isNot(previous));
        topics.add(plan['topic'] as String);
        previous = plan['topic'] as String;
        final frozen = freezeNarrativeContext(richContext(), plan);
        history.insert(0, {'context': frozen});
        plan['topic'] = 'changed';
        expect(frozen['narrative']['topic'], isNot('changed'));
      }
      expect(topics, hasLength(6));
    },
  );

  test(
    'sentence and opening repetitions are local, punctuation-insensitive',
    () {
      const old =
          'Belki bugün kendine küçük bir alan açmak sana iyi gelebilir.';
      expect(
        narrativeRepetition('$old Başka bir kapanış.', [old]),
        'repetition',
      );
      expect(
        narrativeRepetition('Bambaşka bir başlangıç ve düşünce.', [old]),
        isNull,
      );
    },
  );

  test('shared v2 grounding cases allow only supported physical phrases', () {
    final fixtures = jsonDecode(
      File(
        '../atlas_ai_gateway/test/fixtures/regional-quality-cases.json',
      ).readAsStringSync(),
    );
    for (final row in fixtures as List) {
      final context = richContext();
      final text = List.generate(
        4,
        (i) =>
            '${i == 0 ? row['text'] : 'Belki düşünmek sana iyi gelebilir.'} ${List.filled(66, 'düşünce').join(' ')}',
      ).join('\n\n');
      expect(
        fortuneQualityError(text, 'stop', context: context),
        row['error'],
        reason: row['id'],
      );
    }
  });

  testWidgets('scan is accessible at large text with reduced motion', (
    tester,
  ) async {
    tester.view.resetPhysicalSize();
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 600),
            disableAnimations: true,
            textScaler: TextScaler.linear(2),
          ),
          child: const Scaffold(
            body: FortuneScan(
              progress: FortuneProgress(FortunePhase.generating),
              photos: [],
              imageFor: _unused,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Fincanının hikâyesi hazırlanıyor'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

ImageProvider _unused(dynamic _) => const AssetImage('unused');
