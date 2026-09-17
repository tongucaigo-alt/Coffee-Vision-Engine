import 'dart:convert';

import 'package:atlas_contribution_app/src/models.dart';
import 'package:atlas_contribution_app/src/mvp/review_models.dart';
import 'package:atlas_contribution_app/src/mvp/review_preparation.dart';
import 'package:flutter_test/flutter_test.dart';

const _time = '2026-09-15T10:00:00Z';
const _later = '2026-09-15T10:01:00Z';

RegionAnnotation _region({String label = 'bird', double x = .2}) =>
    RegionAnnotation(
      id: 'private-region',
      box: RegionBox(x, .3, .15, .15),
      label: label,
    );

ReviewPhoto _photo({
  String id = 'private-photo',
  String checksumCharacter = 'a',
  PhotoDecision decision = PhotoDecision.unreviewed,
  List<RegionAnnotation> regions = const [],
  Map<String, dynamic>? analysis,
}) => ReviewPhoto(
  id: id,
  surface: ReviewSurface.cup,
  usableConfirmedAtUtc: _time,
  photo: ContributionPhoto(
    role: null,
    localName: '$id.jpg',
    checksum: 'sha256:${checksumCharacter * 64}',
    originalChecksum: 'sha256:${'b' * 64}',
    width: 100,
    height: 150,
    byteLength: 123,
    capturedAt: null,
    importedAt: _time,
    decision: decision,
    regions: regions,
  ),
  analysis: analysis,
);

ReviewSession _session({List<ReviewPhoto>? photos}) => ReviewSession(
  id: 'private-session',
  groupId: 'private-group',
  createdAtUtc: _time,
  localConsentAtUtc: _time,
  sameSampleDeclared: true,
  photos: photos ?? [_photo()],
);

Map<String, dynamic> _analysis(
  ReviewPhoto photo, {
  String outcome = 'noMatch',
  String run = 'private-run',
  Map<String, dynamic>? measurements,
}) => {
  'version': 'atlas-local-analysis-v1',
  'photoId': photo.id,
  'photoChecksum': photo.photo.checksum,
  'surface': photo.surface.name,
  'runId': run,
  'outcome': outcome,
  'errorStage': outcome == 'technicalError' ? 'vision' : null,
  'globalPhysicalMeasurements': measurements ?? _measurements(),
  'localName': 'private-analysis.jpg',
  'participantId': 'private-participant',
  'audit': {'secret': 'private-audit'},
  'symbols': <Object?>[],
};

Map<String, dynamic> _measurements({int residue = 12}) => {
  'residuePixelCount': residue,
  'contentResidueRatio': residue == 0 ? 0.0 : .12,
  'componentCount': residue == 0 ? 0 : 2,
  'candidateRelationCount': residue == 0 ? 0 : 1,
  'selectedRelationCount': 0,
};

ReviewSession _capture(ReviewSession session) =>
    captureInitialObservations(session, capturedAtUtc: _time);

ReviewSession _prepared(ReviewSession session) => session.next(
  preparedInput: prepareReviewInput(session, preparedAtUtc: _later),
);

Map<String, dynamic> _payload(ReviewSession session) =>
    session.preparedInput!['payload'] as Map<String, dynamic>;

void main() {
  test('v1 loads unchanged with unknown history; its next revision is v2', () {
    final legacy = _session().toJson()
      ..['version'] = legacyReviewVersion
      ..remove('observationHistory')
      ..remove('initialObservations')
      ..remove('preparedInput');
    final loaded = ReviewSession.fromJson(legacy);
    expect(loaded.observationHistory, 'unknown');
    expect(loaded.toJson(), legacy);
    final next = _capture(loaded);
    expect(next.toJson()['version'], reviewVersion);
    expect(next.observationHistory, 'unknown');
    expect(next.currentInitialObservation!['exposureHistory'], 'unknown');
  });

  test(
    'skip seals all photo decisions and exact identities without erasing observations',
    () {
      final photos = [
        _photo(),
        _photo(id: 'uncertain', decision: PhotoDecision.uncertain),
        _photo(
          id: 'marked',
          decision: PhotoDecision.marked,
          regions: [_region()],
        ),
      ];
      final original = _session(photos: photos);
      final captured = _capture(original);
      expect(original.photos.first.photo.decision, PhotoDecision.unreviewed);
      expect(captured.photos.map((p) => p.photo.decision), [
        PhotoDecision.skipped,
        PhotoDecision.uncertain,
        PhotoDecision.marked,
      ]);
      final snapshot = captured.currentInitialObservation!;
      expect(snapshot['sessionId'], original.id);
      expect(snapshot['groupId'], original.groupId);
      expect(snapshot['sourceRevision'], captured.revision);
      expect(snapshot['physicalIndependence'], 'unverified');
      expect(snapshot['exposureHistory'], 'known');
      final savedPhoto = (snapshot['photos'] as List).last as Map;
      expect(savedPhoto['photoChecksum'], photos.last.photo.checksum);
      expect((savedPhoto['regions'] as List).single, _region().toJson());
    },
  );

  test('notSeen and skipped remain separate decisions', () {
    final captured = _capture(
      _session(
        photos: [
          _photo(decision: PhotoDecision.notSeen),
          _photo(id: 'skipped', decision: PhotoDecision.skipped),
        ],
      ),
    );
    expect(captured.photos.map((p) => p.photo.decision), [
      PhotoDecision.notSeen,
      PhotoDecision.skipped,
    ]);
  });

  test(
    'sealed snapshot is deep immutable and not replaced by later region edits',
    () {
      final captured = _capture(
        _session(
          photos: [
            _photo(decision: PhotoDecision.marked, regions: [_region()]),
          ],
        ),
      );
      final snapshot = captured.currentInitialObservation!;
      expect(() => snapshot['capturedAtUtc'] = _later, throwsUnsupportedError);
      expect(
        () => (snapshot['photos'] as List).clear(),
        throwsUnsupportedError,
      );
      final firstRegion =
          (((snapshot['photos'] as List).first as Map)['regions'] as List).first
              as Map;
      expect(
        () => (firstRegion['box'] as Map)['x'] = .7,
        throwsUnsupportedError,
      );
      final changed = captured.withPhoto(
        captured.photos.single.update(
          photo: captured.photos.single.photo.annotated([
            _region(label: 'tree'),
          ], PhotoDecision.marked),
        ),
      );
      expect(changed.currentInitialObservation, snapshot);
      expect(_capture(changed), same(changed));
      expect(changed.initialObservations, hasLength(1));
    },
  );

  test(
    'replaced photo set gets a new snapshot while old identity remains in history',
    () {
      final first = _capture(_session());
      final replacement = first.next(photos: [_photo(checksumCharacter: 'c')]);
      expect(replacement.currentInitialObservation, isNull);
      final second = _capture(replacement);
      expect(second.initialObservations, hasLength(2));
      expect(
        second.initialObservations.first,
        first.initialObservations.single,
      );
      final removed = second.next(photos: const []);
      expect(removed.initialObservations, second.initialObservations);
    },
  );

  test(
    'known earlier group exposure and unknown history survive research snapshot',
    () {
      final captured = captureInitialObservations(
        _session(),
        capturedAtUtc: _time,
        priorExposures: [
          {
            'kind': 'namedCandidate',
            'sessionId': 'earlier',
            'exposedAtUtc': _time,
          },
          {'history': 'unknown', 'sessionId': 'legacy'},
        ],
      );
      expect(captured.currentInitialObservation!['exposureHistory'], 'unknown');
      expect(
        captured.currentInitialObservation!['priorExposures'],
        hasLength(2),
      );
    },
  );

  test(
    'snapshot captures existing candidate exposure without claiming it was independent',
    () {
      final p = _photo();
      final analysis = _analysis(p)
        ..['symbols'] = [
          {'key': 'candidate'},
        ];
      final exposed = p.update(
        analysis: analysis,
        exposed: true,
        feedback: [
          CandidateFeedback(
            candidateKey: 'candidate',
            runId: 'private-run',
            answer: CandidateAnswer.maybe,
            exposedAtUtc: _time,
          ),
        ],
      );
      final captured = _capture(_session(photos: [exposed]));
      expect(
        captured.currentInitialObservation!['priorExposures'],
        hasLength(2),
      );
      expect(
        captured.currentInitialObservation!['physicalIndependence'],
        'unverified',
      );
    },
  );

  test(
    'preparation requires a ready session and a sealed initial observation',
    () {
      expect(
        () => prepareReviewInput(_session(), preparedAtUtc: _later),
        throwsStateError,
      );
      expect(
        () => _capture(_session().next(sameSample: false)),
        throwsStateError,
      );
      expect(() => _capture(_session().next(deleted: true)), throwsStateError);
    },
  );

  test(
    'allowlisted payload carries user names, boxes and exact numeric summary only',
    () {
      final p = _photo(decision: PhotoDecision.marked, regions: [_region()]);
      final analysis = _analysis(p);
      (analysis['globalPhysicalMeasurements'] as Map)['privateExtra'] =
          'private-secret';
      final session = _prepared(
        _capture(_session(photos: [p.update(analysis: analysis)])),
      );
      expect(session.preparedInput!['status'], 'ready');
      final payload = _payload(session);
      final photo = (payload['photos'] as List).single as Map;
      expect(photo['globalPhysicalMeasurements'], _measurements());
      expect(photo['userObservations'], [
        {
          'origin': 'userObservation',
          'symbolName': 'Kuş',
          'box': _region().box.toJson(),
        },
      ]);
      expect(
        photo['physicalMeasurementScope'],
        'wholeImageContentNotUserRegion',
      );
      final text = jsonEncode(payload);
      for (final forbidden in [
        'private-',
        'sha256:',
        'photoId',
        'runId',
        'groupId',
        'participantId',
        'localName',
        'audit',
        'sourceFingerprint',
        'regionDensity',
      ]) {
        expect(text, isNot(contains(forbidden)), reason: forbidden);
      }
      expect(() => payload['status'] = 'other', throwsUnsupportedError);
    },
  );

  test(
    'physical measurements alone can prepare input despite no knowledge match',
    () {
      final p = _photo();
      final prepared = _prepared(
        _capture(_session(photos: [p.update(analysis: _analysis(p))])),
      );
      expect(prepared.preparedInput!['status'], 'ready');
      expect(prepared.preparedInput!['observationCount'], 0);
      expect(prepared.preparedInput!['physicalPhotoCount'], 1);
      expect(interpretationInput(prepared)['status'], 'noSelectedSymbols');
    },
  );

  test(
    'empty, pending, and technical error do not fabricate symbols or measurements',
    () {
      final p = _photo();
      final pending = _prepared(_capture(_session()));
      expect(pending.preparedInput!['status'], 'analysisPending');
      expect(pending.preparedInput!['pendingPhotoCount'], 1);
      final empty = _prepared(
        _capture(
          _session(
            photos: [
              p.update(
                analysis: _analysis(p, measurements: _measurements(residue: 0)),
              ),
            ],
          ),
        ),
      );
      expect(empty.preparedInput!['status'], 'empty');
      final failed = _prepared(
        _capture(
          _session(
            photos: [
              p.update(analysis: _analysis(p, outcome: 'technicalError')),
            ],
          ),
        ),
      );
      expect(failed.preparedInput!['status'], 'empty');
      expect(failed.preparedInput!['technicalErrorCount'], 1);
      final photo = (_payload(failed)['photos'] as List).single as Map;
      expect(photo['analysisState'], 'technicalError');
      expect(photo['globalPhysicalMeasurements'], isNull);
      expect(photo['userObservations'], isEmpty);
    },
  );

  test(
    'technical failures retain user observations and mark preparation partial',
    () {
      final p = _photo(
        decision: PhotoDecision.marked,
        regions: [_region(label: 'tree')],
      );
      final prepared = _prepared(
        _capture(
          _session(
            photos: [
              p.update(analysis: _analysis(p, outcome: 'technicalError')),
            ],
          ),
        ),
      );
      expect(prepared.preparedInput!['status'], 'partial');
      expect(prepared.preparedInput!['observationCount'], 1);
      expect(jsonEncode(_payload(prepared)), contains('Ağaç'));
      expect(prepared.preparedInput!['physicalPhotoCount'], 0);
    },
  );

  test(
    'invalid measurement values are excluded instead of converted to findings',
    () {
      final p = _photo(decision: PhotoDecision.marked, regions: [_region()]);
      for (final measurements in [
        _measurements()..['contentResidueRatio'] = 1.2,
        _measurements()..['residuePixelCount'] = -1,
        _measurements()..['componentCount'] = 2.5,
        _measurements()..['selectedRelationCount'] = 2,
        _measurements()..remove('candidateRelationCount'),
        _measurements()..['componentCount'] = 'twelve',
      ]) {
        final result = _prepared(
          _capture(
            _session(
              photos: [
                p.update(analysis: _analysis(p, measurements: measurements)),
              ],
            ),
          ),
        );
        expect(result.preparedInput!['status'], 'partial');
        expect(result.preparedInput!['invalidMeasurementPhotoCount'], 1);
        final photo = (_payload(result)['photos'] as List).single as Map;
        expect(photo['globalPhysicalMeasurements'], isNull);
        expect(photo['physicalMeasurementsStatus'], 'invalid');
      }
    },
  );

  test(
    'source edits invalidate preparation; consent changes and reload preserve it',
    () {
      final p = _photo(decision: PhotoDecision.marked, regions: [_region()]);
      final prepared = _prepared(
        _capture(_session(photos: [p.update(analysis: _analysis(p))])),
      );
      final consent = prepared.next(researchAllowed: true);
      expect(consent.preparedInput, prepared.preparedInput);
      expect(
        consent.next(researchAllowed: false).preparedInput,
        prepared.preparedInput,
      );
      final reopened = ReviewSession.fromJson(
        jsonDecode(jsonEncode(consent.toJson())) as Map<String, dynamic>,
      );
      expect(reopened.preparedInput, prepared.preparedInput);
      expect(reopened.initialObservations, prepared.initialObservations);
      final edited = prepared.withPhoto(
        prepared.photos.single.update(
          photo: prepared.photos.single.photo.annotated([
            _region(x: .4),
          ], PhotoDecision.marked),
        ),
      );
      expect(edited.preparedInput, isNull);
      expect(prepared.next(sameSample: false).preparedInput, isNull);
      expect(prepared.next(photos: const []).preparedInput, isNull);
      expect(prepared.next(deleted: true).preparedInput, isNull);
    },
  );

  test(
    'retry analysis changes invalidate preparation but preserve first observations',
    () {
      final p = _photo(decision: PhotoDecision.marked, regions: [_region()]);
      final failed = _prepared(
        _capture(
          _session(
            photos: [
              p.update(analysis: _analysis(p, outcome: 'technicalError')),
            ],
          ),
        ),
      );
      final retried = failed.withPhoto(
        failed.photos.single.update(analysis: _analysis(p, run: 'new-run')),
      );
      expect(retried.preparedInput, isNull);
      expect(retried.initialObservations, failed.initialObservations);
      expect(_prepared(retried).preparedInput!['status'], 'ready');
    },
  );

  test(
    'same run with changed global summary invalidates; unrelated audit does not',
    () {
      final p = _photo();
      final prepared = _prepared(
        _capture(_session(photos: [p.update(analysis: _analysis(p))])),
      );
      final same = prepared.withPhoto(
        prepared.photos.single.update(
          analysis: _analysis(p)..['audit'] = {'other': 'metadata'},
        ),
      );
      expect(same.preparedInput, prepared.preparedInput);
      final changed = prepared.withPhoto(
        prepared.photos.single.update(
          analysis: _analysis(p, measurements: _measurements(residue: 25)),
        ),
      );
      expect(changed.preparedInput, isNull);
    },
  );
}
