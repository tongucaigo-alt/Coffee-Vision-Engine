import 'package:coffee_source/coffee_source.dart';
import 'package:test/test.dart';

const _checksum =
    'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

void main() {
  group('SourceCatalogReleaseManifest', () {
    test('canonicalizes refs and exposes immutable collections', () {
      final manifest = _manifest(
        records: [
          SourceRecordReleaseRef(
            sourceId: 'source-z',
            revision: 1,
            checksum: _checksum,
          ),
          SourceRecordReleaseRef(
            sourceId: 'source-a',
            revision: 1,
            checksum: _checksum,
          ),
        ],
      );

      expect(manifest.sourceRecords.map((ref) => ref.sourceId), [
        'source-a',
        'source-z',
      ]);
      expect(() => manifest.sourceRecords.clear(), throwsUnsupportedError);
      expect(
        SourceCatalogReleaseManifest.recordType,
        'atlas.sourceCatalogReleaseManifest',
      );
    });

    test('rejects empty and duplicate memberships', () {
      expect(() => _manifest(records: const []), throwsArgumentError);
      final duplicate = SourceRecordReleaseRef(
        sourceId: 'source-a',
        revision: 1,
        checksum: _checksum,
      );
      expect(
        () => _manifest(records: [duplicate, duplicate]),
        throwsArgumentError,
      );
    });

    test('has deterministic equality and hashCode', () {
      final first = _manifest();
      final second = _manifest();
      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });
  });
}

SourceCatalogReleaseManifest _manifest({
  Iterable<SourceRecordReleaseRef>? records,
}) {
  return SourceCatalogReleaseManifest(
    schemaVersion: '1.0',
    releaseId: 'test-source-catalog-001',
    createdAtUtc: '2026-09-05T00:00:00Z',
    canonicalJsonProfileRef: CanonicalJsonProfileRef(
      profileId: 'atlas-canonical-json',
      revision: 1,
      checksum: _checksum,
    ),
    governanceSnapshotRef: GovernanceSnapshotRef(
      snapshotId: 'test-governance-001',
      checksum: _checksum,
    ),
    contextRegistryReleaseRef: ContextRegistryReleaseRef(
      releaseId: 'test-context-release-001',
      checksum: _checksum,
    ),
    sourceRecords:
        records ??
        [
          SourceRecordReleaseRef(
            sourceId: 'source-a',
            revision: 1,
            checksum: _checksum,
          ),
        ],
    useAssessments: [
      SourceUseAssessmentReleaseRef(
        useAssessmentId: 'test-use-001',
        revision: 1,
        checksum: _checksum,
      ),
    ],
    manifestChecksum: _checksum,
  );
}
