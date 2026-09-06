import 'dart:convert';
import 'dart:typed_data';

import 'package:coffee_source_dataset/coffee_source_dataset.dart';
import 'package:test/test.dart';

import 'test_fixtures.dart';

void main() {
  const parser = SourceCatalogParser();

  group('SourceCatalogParser', () {
    test('parses a complete synthetic Source Catalog release', () {
      final bundle = syntheticBundle();

      final snapshot = parser.parse(
        manifestBytes: bundle.manifestBytes,
        recordDocuments: bundle.recordBytes,
      );

      expect(snapshot.manifest.releaseId, 'test-source-catalog-001');
      expect(snapshot.sourceRecords.single.sourceId, 'test-source-001');
      expect(snapshot.useAssessments.single.useAssessmentId, 'test-use-001');
      expect(snapshot.useAssessments.single.sourceRef.locator, 'p. 16');
    });

    test('is independent of document and object-property order', () {
      final bundle = syntheticBundle();
      final first = parser.parse(
        manifestBytes: bundle.manifestBytes,
        recordDocuments: bundle.recordBytes,
      );
      final second = parser.parse(
        manifestBytes: bytesFor(
          reverseRootProperties(bundle.manifest),
          pretty: true,
        ),
        recordDocuments: [
          bytesFor(reverseRootProperties(bundle.useAssessment), pretty: true),
          bytesFor(reverseRootProperties(bundle.sourceRecord), pretty: true),
        ],
      );

      expect(second, first);
      expect(second.hashCode, first.hashCode);
    });

    test('materializes recordDocuments exactly once', () {
      final bundle = syntheticBundle();
      var iterations = 0;
      final documents = _SingleUseIterable(
        bundle.recordBytes,
        () => iterations++,
      );

      parser.parse(
        manifestBytes: bundle.manifestBytes,
        recordDocuments: documents,
      );

      expect(iterations, 1);
    });

    test('returns immutable collections and deterministic value objects', () {
      final bundle = syntheticBundle();
      final first = parser.parse(
        manifestBytes: bundle.manifestBytes,
        recordDocuments: bundle.recordBytes,
      );
      final second = parser.parse(
        manifestBytes: bundle.manifestBytes,
        recordDocuments: bundle.recordBytes,
      );

      expect(() => first.sourceRecords.clear(), throwsUnsupportedError);
      expect(() => first.useAssessments.clear(), throwsUnsupportedError);
      expect(
        () => first.manifest.sourceRecords.clear(),
        throwsUnsupportedError,
      );
      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });

    test('rejects manifest self-checksum mismatch', () {
      final bundle = syntheticBundle();
      final manifest = deepCopy(bundle.manifest)
        ..['manifestChecksum'] = checksumForSeed('9');

      expect(
        () => parser.parse(
          manifestBytes: bytesFor(manifest),
          recordDocuments: bundle.recordBytes,
        ),
        throwsFailure(SourceCatalogFailure.checksumMismatch),
      );
    });

    test('rejects stale record checksum', () {
      final bundle = syntheticBundle();
      final manifest = deepCopy(bundle.manifest);
      final refs = (manifest['sourceRecords']! as List).cast<Object?>();
      final stale = Map<String, Object?>.from(refs.single! as Map)
        ..['checksum'] = checksumForSeed('9');
      manifest['sourceRecords'] = [stale];

      expect(
        () => parser.parse(
          manifestBytes: bytesFor(rechecksumManifest(manifest)),
          recordDocuments: bundle.recordBytes,
        ),
        throwsFailure(SourceCatalogFailure.checksumMismatch),
      );
    });

    test('rejects missing, extra, and duplicate documents', () {
      final bundle = syntheticBundle();
      final extra = syntheticUseAssessment()
        ..['useAssessmentId'] = 'test-use-extra';

      expect(
        () => parser.parse(
          manifestBytes: bundle.manifestBytes,
          recordDocuments: [bundle.recordBytes.first],
        ),
        throwsFailure(SourceCatalogFailure.missingRecord),
      );
      expect(
        () => parser.parse(
          manifestBytes: bundle.manifestBytes,
          recordDocuments: [...bundle.recordBytes, bytesFor(extra)],
        ),
        throwsFailure(SourceCatalogFailure.unexpectedRecord),
      );
      expect(
        () => parser.parse(
          manifestBytes: bundle.manifestBytes,
          recordDocuments: [
            bundle.recordBytes.first,
            bundle.recordBytes.first,
            bundle.recordBytes.last,
          ],
        ),
        throwsFailure(SourceCatalogFailure.duplicateIdentity),
      );
    });

    test('rejects sourceRef that does not resolve exactly', () {
      final assessment = syntheticUseAssessment();
      final ref = Map<String, Object?>.from(assessment['sourceRef']! as Map)
        ..['revision'] = 2;
      assessment['sourceRef'] = ref;
      final bundle = syntheticBundle(useAssessment: assessment);

      expect(
        () => parser.parse(
          manifestBytes: bundle.manifestBytes,
          recordDocuments: bundle.recordBytes,
        ),
        throwsFailure(SourceCatalogFailure.invalidReference),
      );
    });

    test('rejects eligibleCore anonymous uncaptured mutable source', () {
      final source = syntheticSourceRecord()
        ..['sourceClass'] = 'webPublication'
        ..['access'] = {
          'accessMode': 'online',
          'accessedAtUtc': '2026-09-05T10:00:00Z',
        }
        ..['integrity'] = {'manifestationType': 'uncapturedMutable'};
      final assessment = syntheticUseAssessment();
      final quality =
          Map<String, Object?>.from(assessment['qualityDimensions']! as Map)
            ..['attribution'] = 'anonymous'
            ..['sourceStability'] = 'uncapturedMutable';
      assessment['qualityDimensions'] = quality;
      final bundle = syntheticBundle(
        sourceRecord: source,
        useAssessment: assessment,
      );

      expect(
        () => parser.parse(
          manifestBytes: bundle.manifestBytes,
          recordDocuments: bundle.recordBytes,
        ),
        throwsFailure(SourceCatalogFailure.releaseEligibilityViolation),
      );
    });

    test('accepts non-core use of anonymous uncaptured mutable source', () {
      final source = syntheticSourceRecord()
        ..['sourceClass'] = 'webPublication'
        ..['access'] = {
          'accessMode': 'online',
          'accessedAtUtc': '2026-09-05T10:00:00Z',
        }
        ..['integrity'] = {'manifestationType': 'uncapturedMutable'};
      final assessment = syntheticUseAssessment()
        ..['assessmentOutcome'] = 'discoveryOnly';
      final quality =
          Map<String, Object?>.from(assessment['qualityDimensions']! as Map)
            ..['attribution'] = 'anonymous'
            ..['sourceStability'] = 'uncapturedMutable';
      assessment['qualityDimensions'] = quality;
      final bundle = syntheticBundle(
        sourceRecord: source,
        useAssessment: assessment,
      );

      expect(
        parser
            .parse(
              manifestBytes: bundle.manifestBytes,
              recordDocuments: bundle.recordBytes,
            )
            .useAssessments
            .single
            .assessmentOutcome
            .name,
        'discoveryOnly',
      );
    });

    test('rejects non-canonical semantic array order', () {
      final source = syntheticSourceRecord();
      source['identifiers'] = [
        {'identifierType': 'url', 'value': 'https://example.invalid/source'},
        {'identifierType': 'isbn', 'value': '9780000000000'},
      ];
      final bundle = syntheticBundle(sourceRecord: source);

      expect(
        () => parser.parse(
          manifestBytes: bundle.manifestBytes,
          recordDocuments: bundle.recordBytes,
        ),
        throwsFailure(SourceCatalogFailure.nonCanonicalOrder),
      );
    });

    test('rejects unknown fields and unsupported profile', () {
      final sourceWithUnknown = syntheticSourceRecord()..['meaning'] = 'none';
      final unknownBundle = syntheticBundle(sourceRecord: sourceWithUnknown);
      final sourceWithProfile = syntheticSourceRecord();
      sourceWithProfile['canonicalJsonProfileRef'] = {
        ...canonicalProfile,
        'revision': 2,
      };
      final profileBundle = syntheticBundle(sourceRecord: sourceWithProfile);

      expect(
        () => parser.parse(
          manifestBytes: unknownBundle.manifestBytes,
          recordDocuments: unknownBundle.recordBytes,
        ),
        throwsFailure(SourceCatalogFailure.schemaViolation),
      );
      expect(
        () => parser.parse(
          manifestBytes: profileBundle.manifestBytes,
          recordDocuments: profileBundle.recordBytes,
        ),
        throwsFailure(SourceCatalogFailure.unsupportedCanonicalProfile),
      );
    });

    test('rejects duplicate properties, BOM, and malformed UTF-8', () {
      final bundle = syntheticBundle();
      final duplicate = Uint8List.fromList(
        utf8.encode('{"schemaVersion":"1.0","schemaVersion":"1.0"}'),
      );
      final bom = Uint8List.fromList([
        0xef,
        0xbb,
        0xbf,
        ...bundle.manifestBytes,
      ]);
      final malformed = Uint8List.fromList([0xc3, 0x28]);

      for (final bytes in [duplicate, bom, malformed]) {
        expect(
          () => parser.parse(
            manifestBytes: bytes,
            recordDocuments: bundle.recordBytes,
          ),
          throwsFailure(SourceCatalogFailure.canonicalJsonRejected),
        );
      }
    });
  });
}

Matcher throwsFailure(SourceCatalogFailure failure) => throwsA(
  isA<SourceCatalogException>().having(
    (error) => error.failure,
    'failure',
    failure,
  ),
);

final class _SingleUseIterable extends Iterable<Uint8List> {
  _SingleUseIterable(this._values, this._onIterate);

  final List<Uint8List> _values;
  final void Function() _onIterate;
  bool _used = false;

  @override
  Iterator<Uint8List> get iterator {
    if (_used) throw StateError('iterated more than once');
    _used = true;
    _onIterate();
    return _values.iterator;
  }
}
