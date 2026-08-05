import 'dart:convert';

import 'package:test/test.dart';

import '../tool/local_formation_review_server.dart';
import '../tool/src/lf1_review.dart';

void main() {
  group('LF-1 review', () {
    test('accepts canonical physical annotations and keeps them immutable', () {
      final index = Lf1ObservationIndex.parse(_observationSource());
      final annotations = const Lf1AnnotationCodec().parse(
        source: _annotationSource(),
        observations: index,
        panelSourceIds: {'source-a', 'source-b'},
      );

      expect(annotations.annotations, hasLength(12));
      expect(annotations.annotations.first.sourceId, 'source-a');
      expect(
        () => annotations.annotations.add(annotations.annotations.first),
        throwsUnsupportedError,
      );
    });

    test('rejects unknown candidates, duplicate IDs, and invalid boxes', () {
      final index = Lf1ObservationIndex.parse(_observationSource());
      final root = jsonDecode(_annotationSource()) as Map<String, Object?>;
      final annotations = root['annotations']! as List<Object?>;
      final first = annotations.first! as Map<String, Object?>;
      (first['alignments']! as List<Object?>).first = {
        'profileId': 'p01',
        'candidateId': 99,
        'status': 'aligned',
      };
      expect(
        () => const Lf1AnnotationCodec().parse(
          source: jsonEncode(root),
          observations: index,
          panelSourceIds: {'source-a', 'source-b'},
        ),
        throwsFormatException,
      );

      final invalid = jsonDecode(_annotationSource()) as Map<String, Object?>;
      final invalidAnnotations = invalid['annotations']! as List<Object?>;
      final invalidFirst = invalidAnnotations.first! as Map<String, Object?>;
      invalidFirst['right'] = invalidFirst['left'];
      expect(
        () => const Lf1AnnotationCodec().parse(
          source: jsonEncode(invalid),
          observations: index,
          panelSourceIds: {'source-a', 'source-b'},
        ),
        throwsFormatException,
      );
    });

    test('applies the balanced gate and deterministic tie-break', () {
      final index = Lf1ObservationIndex.parse(_observationSource());
      final annotations = const Lf1AnnotationCodec().parse(
        source: _annotationSource(),
        observations: index,
        panelSourceIds: {'source-a', 'source-b'},
      );
      final result = const Lf1Evaluator().evaluate(
        observations: index,
        annotationSet: annotations,
      );

      expect(result.groundTruthSufficient, isTrue);
      expect(result.residueAnnotationCount, 6);
      expect(result.negativeSpaceAnnotationCount, 6);
      expect(result.eligibleFormationGroupCount, 6);
      expect(result.profiles.first.passed, isTrue);
      expect(result.profiles.last.passed, isFalse);
      expect(result.productionProfileCandidateId, 'p01');
    });

    test('does not infer alignment from a full-frame candidate', () {
      final index = Lf1ObservationIndex.parse(_observationSource());
      final root = jsonDecode(_annotationSource()) as Map<String, Object?>;
      final annotations = root['annotations']! as List<Object?>;
      for (final value in annotations) {
        final annotation = value! as Map<String, Object?>;
        for (final alignmentValue
            in annotation['alignments']! as List<Object?>) {
          (alignmentValue! as Map<String, Object?>)['status'] = 'unrelated';
        }
      }
      final parsed = const Lf1AnnotationCodec().parse(
        source: jsonEncode(root),
        observations: index,
        panelSourceIds: {'source-a', 'source-b'},
      );
      final result = const Lf1Evaluator().evaluate(
        observations: index,
        annotationSet: parsed,
      );

      expect(
        result.profiles.every((profile) => profile.annotationCoverageRate == 0),
        isTrue,
      );
      expect(result.productionProfileCandidateId, isNull);
    });

    test('requires five residue and five negative-space annotations', () {
      final index = Lf1ObservationIndex.parse(_observationSource());
      final root = jsonDecode(_annotationSource()) as Map<String, Object?>;
      final annotations = root['annotations']! as List<Object?>;
      (annotations[0]! as Map<String, Object?>)['reviewStatus'] = 'exclude';
      (annotations[2]! as Map<String, Object?>)['reviewStatus'] = 'exclude';
      final parsed = const Lf1AnnotationCodec().parse(
        source: jsonEncode(root),
        observations: index,
        panelSourceIds: {'source-a', 'source-b'},
      );
      final result = const Lf1Evaluator().evaluate(
        observations: index,
        annotationSet: parsed,
      );

      expect(result.groundTruthSufficient, isFalse);
      expect(result.productionProfileCandidateId, isNull);
    });

    test('review server defaults to loopback port 8766', () {
      final options = Lf1ReviewServerOptions.parse(const [
        '--dataset',
        'dataset',
        '--manifest',
        'manifest',
        '--freeze',
        'freeze',
        '--capture-groups',
        'groups',
        '--report',
        'report',
        '--output',
        'output',
        '--repository-root',
        'repo',
      ]);
      expect(options.port, 8766);
    });
  });
}

String _observationSource() {
  final observations = <Map<String, Object?>>[];
  for (final profile in ['p01', 'p02']) {
    for (final source in ['source-a', 'source-b']) {
      observations.add({
        'profileId': profile,
        'sourceId': source,
        'surfaceType': 'cup',
        'analysisStatus': 'success',
        'determinismStatus': 'deterministic',
        'repeatsPerformed': 3,
        'mismatchedRepeatIndexes': <int>[],
        'failureCategory': null,
        'candidates': [
          {
            'candidateId': 1,
            'candidateIdentity': '$profile#$source#1',
            'evidence': <Object>[],
            'geometry': {
              'left': 0.0,
              'top': 0.0,
              'right': 1.0,
              'bottom': 1.0,
              'centroidX': 0.5,
              'centroidY': 0.5,
              'width': 1.0,
              'height': 1.0,
              'aspectRatio': 1.0,
              'touchesWorkingImageBorder': true,
            },
            'topology': {
              'nodeCount': 1,
              'directedEdgeCount': 0,
              'isIsolated': true,
            },
          },
        ],
      });
    }
  }
  return jsonEncode({
    'schemaVersion': '1.0',
    'researchId': 'lfr-001',
    'sourceDatasetVersion': 'test',
    'sourceManifestChecksum': 'sha256:test',
    'workingResolution': 512,
    'repeatCount': 3,
    'profiles': [
      for (final id in ['p01', 'p02'])
        {
          'profileId': id,
          'maxCentroidDistance': null,
          'maxBoundingBoxDistance': null,
          'requireBoundingBoxTouch': false,
          'maxOutgoingPerSource': 1,
        },
    ],
    'profileSummaries': [
      for (final id in ['p01', 'p02'])
        {
          'profileId': id,
          'enabledImageCount': 2,
          'successfulImageCount': 2,
          'failedImageCount': 0,
          'deterministicImageCount': 2,
          'nonDeterministicImageCount': 0,
          'candidateBudgetImageCount': 2,
          'candidateBudgetRate': 1.0,
          'totalCandidateCount': 2,
        },
    ],
    'observations': observations,
  });
}

String _annotationSource() {
  final annotations = <Map<String, Object?>>[];
  var id = 1;
  for (var group = 1; group <= 6; group++) {
    for (final source in ['source-a', 'source-b']) {
      annotations.add({
        'annotationId': 'annotation-${id++}',
        'sourceId': source,
        'left': 0.1,
        'top': 0.1,
        'right': 0.3,
        'bottom': 0.3,
        'polarity': group <= 3 ? 'residue' : 'negativeSpace',
        'reviewStatus': 'include',
        'formationGroupId': 'formation-$group',
        'notes': '',
        'alignments': [
          {'profileId': 'p01', 'candidateId': 1, 'status': 'aligned'},
          {'profileId': 'p02', 'candidateId': 1, 'status': 'unrelated'},
        ],
      });
    }
  }
  return jsonEncode({
    'schemaVersion': '1.0',
    'researchId': 'lfr-001',
    'annotations': annotations,
  });
}
