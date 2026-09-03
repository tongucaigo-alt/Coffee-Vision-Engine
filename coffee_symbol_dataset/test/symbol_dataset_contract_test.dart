import 'package:coffee_symbol/coffee_symbol.dart';
import 'package:coffee_symbol_dataset/coffee_symbol_dataset.dart';
import 'package:test/test.dart';

import 'test_fixtures.dart';

void main() {
  group('Symbol dataset contracts', () {
    test('typed references use exact value semantics', () {
      final first = SourceCatalogReleaseRef(
        releaseId: 'test-source-release-001',
        checksum: checksum('1'),
      );
      final second = SourceCatalogReleaseRef(
        releaseId: 'test-source-release-001',
        checksum: checksum('1'),
      );

      expect(second, first);
      expect(second.hashCode, first.hashCode);
      expect({first, second}, hasLength(1));
    });

    test('typed references reject invalid identifiers and checksums', () {
      expect(
        () => SymbolReleaseRef(
          releaseId: ' test-release',
          checksum: checksum('1'),
        ),
        throwsArgumentError,
      );
      expect(
        () => GovernanceSnapshotRef(
          snapshotId: 'test-governance-001',
          checksum: 'invalid',
        ),
        throwsArgumentError,
      );
      expect(
        () => SymbolAdmissionPolicyRef(
          policyId: 'test-policy-001',
          revision: 0,
          checksum: checksum('1'),
        ),
        throwsArgumentError,
      );
    });

    test('manifest canonicalizes records without changing identities', () {
      final definition = SymbolReleaseRecordRef(
        recordType: SymbolDatasetRecordType.symbolDefinition,
        recordId: 'test-symbol-001',
        revision: 1,
        checksum: checksum('1'),
      );
      final binding = SymbolReleaseRecordRef(
        recordType: SymbolDatasetRecordType.symbolEvidenceBinding,
        recordId: 'test-binding-001',
        revision: 1,
        checksum: checksum('2'),
      );
      final manifest = _manifest(records: [binding, definition]);

      expect(manifest.records, [definition, binding]);
      expect(identical(manifest.records.first, definition), isTrue);
      expect(identical(manifest.records.last, binding), isTrue);
      expect(manifest.knowledgeRelease!.releaseId, 'test-kds-001');
    });

    test('manifest requires at least one definition', () {
      final binding = SymbolReleaseRecordRef(
        recordType: SymbolDatasetRecordType.symbolEvidenceBinding,
        recordId: 'test-binding-001',
        revision: 1,
        checksum: checksum('2'),
      );

      expect(() => _manifest(records: [binding]), throwsArgumentError);
      expect(() => _manifest(records: const []), throwsArgumentError);
    });

    test('manifest requires exactly one Knowledge release', () {
      final definition = SymbolReleaseRecordRef(
        recordType: SymbolDatasetRecordType.symbolDefinition,
        recordId: 'test-symbol-001',
        revision: 1,
        checksum: checksum('1'),
      );

      expect(
        () => _manifest(records: [definition], knowledgeReleases: const []),
        throwsArgumentError,
      );
      expect(
        () => _manifest(
          records: [definition],
          knowledgeReleases: [
            KnowledgeDatasetReleaseRef(
              releaseId: 'test-kds-001',
              checksum: checksum('1'),
            ),
            KnowledgeDatasetReleaseRef(
              releaseId: 'test-kds-002',
              checksum: checksum('2'),
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('version 2 definition-only manifest omits physical dependencies', () {
      final definition = _definitionRef();
      final manifest = _v2Manifest(records: [definition]);

      expect(manifest.schemaVersion, '2.0');
      expect(manifest.hasBindings, isFalse);
      expect(manifest.evidenceAdmissionPolicyRef, isNull);
      expect(manifest.evidenceAssessmentRegistryReleaseRef, isNull);
      expect(manifest.knowledgeDatasetReleaseRefs, isEmpty);
      expect(manifest.knowledgeRelease, isNull);
    });

    test('version 2 binding manifest requires the complete physical set', () {
      final definition = _definitionRef();
      final binding = SymbolReleaseRecordRef(
        recordType: SymbolDatasetRecordType.symbolEvidenceBinding,
        recordId: 'test-binding-001',
        revision: 1,
        checksum: checksum('2'),
      );

      expect(
        () => _v2Manifest(records: [definition, binding]),
        throwsArgumentError,
      );
      final complete = _v2Manifest(
        records: [definition, binding],
        includePhysicalDependencies: true,
      );
      expect(complete.hasBindings, isTrue);
      expect(complete.knowledgeRelease!.releaseId, 'test-kds-001');
    });

    test(
      'version 2 definition-only manifest rejects physical dependencies',
      () {
        expect(
          () => _v2Manifest(
            records: [_definitionRef()],
            includePhysicalDependencies: true,
          ),
          throwsArgumentError,
        );
      },
    );

    test('manifest validates exact UTC timestamps', () {
      final definition = SymbolReleaseRecordRef(
        recordType: SymbolDatasetRecordType.symbolDefinition,
        recordId: 'test-symbol-001',
        revision: 1,
        checksum: checksum('1'),
      );

      expect(
        () => _manifest(
          records: [definition],
          createdAtUtc: '2024-02-29T23:59:59.123Z',
        ),
        returnsNormally,
      );
      expect(
        () => _manifest(
          records: [definition],
          createdAtUtc: '2023-02-29T00:00:00Z',
        ),
        throwsArgumentError,
      );
      expect(
        () => _manifest(
          records: [definition],
          createdAtUtc: '2026-08-04T00:00:00+00:00',
        ),
        throwsArgumentError,
      );
    });

    test('snapshot preserves immutable model objects and value semantics', () {
      const parser = SymbolDatasetParser();
      final bundle = syntheticBundle();
      final first = parser.parse(
        manifestBytes: bundle.manifestBytes,
        recordDocuments: bundle.recordBytes,
      );
      final second = parser.parse(
        manifestBytes: bundle.manifestBytes,
        recordDocuments: bundle.recordBytes,
      );

      expect(second, first);
      expect(second.hashCode, first.hashCode);
      expect(first.definitions.single, isA<SymbolDefinition>());
      expect(first.bindings.single, isA<SymbolEvidenceBinding>());
      expect({first, second}, hasLength(1));
    });

    test('exception toString is typed and does not expose source content', () {
      const exception = SymbolDatasetException(
        SymbolDatasetFailure.schemaViolation,
        document: 'records[0]',
        field: 'neutralDefinitions',
      );

      expect(exception.toString(), contains('schemaViolation'));
      expect(exception.toString(), contains('records[0]'));
      expect(exception.toString(), isNot(contains('Test symbol')));
    });
  });
}

SymbolReleaseRecordRef _definitionRef() => SymbolReleaseRecordRef(
  recordType: SymbolDatasetRecordType.symbolDefinition,
  recordId: 'test-symbol-001',
  revision: 1,
  checksum: checksum('1'),
);

SymbolReleaseManifest _v2Manifest({
  required Iterable<SymbolReleaseRecordRef> records,
  bool includePhysicalDependencies = false,
}) {
  return SymbolReleaseManifest.v2(
    schemaVersion: '2.0',
    releaseId: 'test-symbol-release-v2-001',
    createdAtUtc: '2026-08-22T00:00:00Z',
    canonicalJsonProfileRef: CanonicalJsonProfileRef(
      profileId: 'atlas-canonical-json',
      revision: 1,
      checksum:
          'sha256:16e9e10eb848828a863a7eca1c0b7e7c84e1a485065d00f938c6af356cd54ad7',
    ),
    governanceSnapshotRef: GovernanceSnapshotRef(
      snapshotId: 'test-governance-001',
      checksum: checksum('1'),
    ),
    records: records,
    sourceCatalogReleaseRef: SourceCatalogReleaseRef(
      releaseId: 'test-source-release-001',
      checksum: checksum('2'),
    ),
    symbolAdmissionPolicyRef: SymbolAdmissionPolicyRef(
      policyId: 'test-symbol-policy-001',
      revision: 1,
      checksum: checksum('3'),
    ),
    evidenceAdmissionPolicyRef: includePhysicalDependencies
        ? EvidenceAdmissionPolicyRef(
            policyId: 'test-evidence-policy-001',
            revision: 1,
            checksum: checksum('4'),
          )
        : null,
    evidenceAssessmentRegistryReleaseRef: includePhysicalDependencies
        ? EvidenceAssessmentRegistryReleaseRef(
            releaseId: 'test-assessment-release-001',
            checksum: checksum('5'),
          )
        : null,
    knowledgeDatasetReleaseRefs: includePhysicalDependencies
        ? [
            KnowledgeDatasetReleaseRef(
              releaseId: 'test-kds-001',
              checksum: checksum('6'),
            ),
          ]
        : const <KnowledgeDatasetReleaseRef>[],
    manifestChecksum: checksum('7'),
  );
}

SymbolReleaseManifest _manifest({
  required Iterable<SymbolReleaseRecordRef> records,
  String createdAtUtc = '2026-08-04T00:00:00Z',
  Iterable<KnowledgeDatasetReleaseRef>? knowledgeReleases,
}) {
  return SymbolReleaseManifest(
    schemaVersion: '1.0',
    releaseId: 'test-symbol-release-001',
    createdAtUtc: createdAtUtc,
    canonicalJsonProfileRef: CanonicalJsonProfileRef(
      profileId: 'atlas-canonical-json',
      revision: 1,
      checksum:
          'sha256:16e9e10eb848828a863a7eca1c0b7e7c84e1a485065d00f938c6af356cd54ad7',
    ),
    governanceSnapshotRef: GovernanceSnapshotRef(
      snapshotId: 'test-governance-001',
      checksum: checksum('1'),
    ),
    records: records,
    sourceCatalogReleaseRef: SourceCatalogReleaseRef(
      releaseId: 'test-source-release-001',
      checksum: checksum('2'),
    ),
    symbolAdmissionPolicyRef: SymbolAdmissionPolicyRef(
      policyId: 'test-symbol-policy-001',
      revision: 1,
      checksum: checksum('3'),
    ),
    evidenceAdmissionPolicyRef: EvidenceAdmissionPolicyRef(
      policyId: 'test-evidence-policy-001',
      revision: 1,
      checksum: checksum('4'),
    ),
    evidenceAssessmentRegistryReleaseRef: EvidenceAssessmentRegistryReleaseRef(
      releaseId: 'test-assessment-release-001',
      checksum: checksum('5'),
    ),
    knowledgeDatasetReleaseRefs:
        knowledgeReleases ??
        [
          KnowledgeDatasetReleaseRef(
            releaseId: 'test-kds-001',
            checksum: checksum('6'),
          ),
        ],
    manifestChecksum: checksum('7'),
  );
}
