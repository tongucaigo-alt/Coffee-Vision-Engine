import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'package:atlas_contribution_app/src/models.dart';
import 'package:atlas_contribution_app/src/mvp/review_models.dart';
import 'package:atlas_contribution_app/src/mvp/review_engine.dart';
import 'package:atlas_contribution_app/src/mvp/review_preparation.dart';
import 'package:atlas_contribution_app/src/ai/ai_contract.dart';
import 'package:atlas_contribution_app/src/ai/ai_client.dart';
import 'package:atlas_contribution_app/src/ai/ai_bundled.dart';
import 'package:atlas_contribution_app/src/ai/narrative.dart';

// Opt-in local evaluation. The ignored manifest supplies reference images.
// Only validateAiContext output crosses the network; observations below are
// controlled test labels, never training labels or claimed human observations.
void main() {
  test(
    'prepare twelve paired narrative evaluations',
    () async {
      final entries =
          jsonDecode(
                await File('build/suitability/eval-inputs.json').readAsString(),
              )
              as List;
      expect(entries.length, 12);
      final engine = ReviewEngine.fromBaseline(
        await File('assets/mvp/knowledge_dataset.json').readAsBytes(),
      );
      final prompts = [
        FortunePrompt(
          await File('build/suitability/old-prompt.json').readAsString(),
        ),
        FortunePrompt(
          await File('assets/fortune-prompt-v1.json').readAsString(),
        ),
      ];
      final output = File('build/suitability/narrative-pairs.json');
      final rows = await output.exists()
          ? (jsonDecode(await output.readAsString())['rows'] as List)
                .map((r) => Map<String, dynamic>.from(r as Map))
                .toList()
          : <Map<String, dynamic>>[];
      final recent = <Map<String, dynamic>>[];
      for (var i = 0; i < entries.length; i++) {
        if (rows.any((r) => r['case'] == i + 1)) {
          recent.insert(0, {
            'context': rows.firstWhere((r) => r['case'] == i + 1)['context'],
          });
          continue;
        }
        final bytes = await File(
          'build/suitability/device/${entries[i]['file']}',
        ).readAsBytes();
        final image = img.decodeImage(bytes)!;
        final checksum = 'sha256:${sha256.convert(bytes)}';
        final now = DateTime.now().toUtc().toIso8601String();
        var p = ReviewPhoto(
          id: 'sample-$i',
          surface: ReviewSurface.cup,
          usableConfirmedAtUtc: now,
          photo: ContributionPhoto(
            role: null,
            localName: 'sample-$i.jpg',
            checksum: checksum,
            originalChecksum: checksum,
            width: image.width,
            height: image.height,
            byteLength: bytes.length,
            capturedAt: null,
            importedAt: now,
            decision: PhotoDecision.skipped,
          ),
        );
        final analyzed = await engine.analyze(p, () async => bytes);
        p = p.update(analysis: analyzed.document);
        var s = ReviewSession(
          id: 'eval-$i',
          groupId: 'group-$i',
          createdAtUtc: now,
          localConsentAtUtc: now,
          sameSampleDeclared: true,
          photos: [p],
        );
        s = captureInitialObservations(s, capturedAtUtc: now);
        var context = Map<String, dynamic>.from(
          prepareReviewInput(s, preparedAtUtc: now)['payload'] as Map,
        );
        if (i.isOdd) {
          context = jsonDecode(jsonEncode(context)) as Map<String, dynamic>;
          (context['photos'] as List).first['userObservations'] = [
            {
              'origin': 'userObservation',
              'symbolName': [
                'Kuş',
                'Ağaç',
                'Kalp',
                'Yol',
                'Balık',
                'Ay',
              ][i ~/ 2],
              'box': {'x': .3, 'y': .3, 'width': .15, 'height': .15},
            },
          ];
        }
        context = validateAiContext(
          freezeNarrativeContext(context, planNarrative(recent)),
        );
        recent.insert(0, {'context': context});
        final row = <String, dynamic>{
          'case': i + 1,
          'reference': entries[i]['file'],
          'controlledTestLabels': i.isOdd,
          'context': context,
          'responses': <Map<String, dynamic>>[],
        };
        rows.add(row);
        for (final j in (i.isEven ? [0, 1] : [1, 0])) {
          final watch = Stopwatch()..start();
          final record = <String, dynamic>{
            'promptVersion': prompts[j].version,
            'promptHash': prompts[j].hash,
          };
          try {
            final result = await AiClient(prompts[j], bestEffort: true)
                .generate(
                  bundledKimiProfile,
                  bundledCredential(bundledKimiProfile),
                  context,
                  cancellation: AiCancellation(),
                  onStatus: (_) {},
                );
            record.addAll(result);
            record['qualityWarning'] = fortuneQualityError(
              result['text'] as String,
              'stop',
              context: context,
            );
          } on AiFailure catch (e) {
            record['error'] = e.message;
          }
          record['elapsedMs'] = watch.elapsedMilliseconds;
          (row['responses'] as List).add(record);
          await output.writeAsString(
            const JsonEncoder.withIndent('  ').convert({
              'humanBlindPreference': 'pending',
              'labelsAreSynthetic': true,
              'independentCupIdentity': 'unverified',
              'rows': rows,
            }),
          );
        }
      }
    },
    skip: !const bool.fromEnvironment('ATLAS_PAIRED_LIVE'),
    timeout: const Timeout(Duration(minutes: 45)),
  );
}
