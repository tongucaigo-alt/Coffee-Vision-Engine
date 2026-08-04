import 'dart:convert';
import 'dart:typed_data';

import 'package:atlas_canonical_json/atlas_canonical_json.dart';
import 'package:coffee_symbol_dataset/coffee_symbol_dataset.dart';
import 'package:test/test.dart';

import 'test_fixtures.dart';

void main() {
  const parser = SymbolDatasetParser();

  group('SymbolDatasetParser', () {
    test('parses a complete synthetic core release', () {
      final bundle = syntheticBundle();

      final snapshot = parser.parse(
        manifestBytes: bundle.manifestBytes,
        recordDocuments: bundle.recordBytes,
      );

      expect(snapshot.manifest.releaseRef.releaseId, 'test-symbol-release-001');
      expect(snapshot.definitions, hasLength(1));
      expect(snapshot.bindings, hasLength(1));
      expect(snapshot.definitions.single.symbolId, 'test-symbol-001');
      expect(snapshot.bindings.single.bindingId, 'test-binding-001');
      expect(snapshot.knowledgeRelease.releaseId, 'test-kds-001');
    });

    test('accepts an unbound definition', () {
      final bundle = syntheticBundle(includeBinding: false);

      final snapshot = parser.parse(
        manifestBytes: bundle.manifestBytes,
        recordDocuments: bundle.recordBytes,
      );

      expect(snapshot.definitions, hasLength(1));
      expect(snapshot.bindings, isEmpty);
    });

    test('is independent of record document iteration order', () {
      final bundle = syntheticBundle();
      final first = parser.parse(
        manifestBytes: bundle.manifestBytes,
        recordDocuments: bundle.recordBytes,
      );
      final second = parser.parse(
        manifestBytes: bundle.manifestBytes,
        recordDocuments: bundle.recordBytes.reversed,
      );

      expect(second, first);
      expect(second.hashCode, first.hashCode);
    });

    test('materializes the caller record iterable exactly once', () {
      final bundle = syntheticBundle();
      var iterations = 0;
      final records = _SingleUseIterable(
        bundle.recordBytes,
        () => iterations++,
      );

      final snapshot = parser.parse(
        manifestBytes: bundle.manifestBytes,
        recordDocuments: records,
      );

      expect(snapshot.bindings, hasLength(1));
      expect(iterations, 1);
    });

    test('returns runtime-unmodifiable complete collections', () {
      final bundle = syntheticBundle();
      final snapshot = parser.parse(
        manifestBytes: bundle.manifestBytes,
        recordDocuments: bundle.recordBytes,
      );

      expect(() => snapshot.definitions.clear(), throwsUnsupportedError);
      expect(() => snapshot.bindings.clear(), throwsUnsupportedError);
      expect(() => snapshot.manifest.records.clear(), throwsUnsupportedError);
      expect(
        () => snapshot.manifest.knowledgeDatasetReleaseRefs.clear(),
        throwsUnsupportedError,
      );
    });

    test('preserves exact external dependency references', () {
      final bundle = syntheticBundle();
      final snapshot = parser.parse(
        manifestBytes: bundle.manifestBytes,
        recordDocuments: bundle.recordBytes,
      );

      expect(
        snapshot.manifest.governanceSnapshotRef.snapshotId,
        'test-governance-001',
      );
      expect(
        snapshot.manifest.sourceCatalogReleaseRef.releaseId,
        'test-source-release-001',
      );
      expect(
        snapshot.manifest.evidenceAssessmentRegistryReleaseRef.releaseId,
        'test-assessment-release-001',
      );
      expect(
        snapshot.bindings.single.evidenceAssessmentRefs.single.assessmentId,
        'test-assessment-001',
      );
    });

    test('rejects a mismatched manifest checksum', () {
      final bundle = syntheticBundle();
      final manifest = deepCopy(bundle.manifest)
        ..['manifestChecksum'] = checksum('9');

      expect(
        () => parser.parse(
          manifestBytes: bytesFor(manifest),
          recordDocuments: bundle.recordBytes,
        ),
        throwsFailure(SymbolDatasetFailure.checksumMismatch),
      );
    });

    test('rejects a mismatched record checksum', () {
      final bundle = syntheticBundle();
      final manifest = deepCopy(bundle.manifest);
      final records = List<Object?>.from(manifest['records']! as List);
      final definitionRef = Map<String, Object?>.from(records.first as Map)
        ..['checksum'] = checksum('9');
      records[0] = definitionRef;
      manifest['records'] = records;

      expect(
        () => parser.parse(
          manifestBytes: bytesFor(rechecksumManifest(manifest)),
          recordDocuments: bundle.recordBytes,
        ),
        throwsFailure(SymbolDatasetFailure.checksumMismatch),
      );
    });

    test('rejects a missing record document', () {
      final bundle = syntheticBundle();

      expect(
        () => parser.parse(
          manifestBytes: bundle.manifestBytes,
          recordDocuments: [bundle.recordBytes.first],
        ),
        throwsFailure(SymbolDatasetFailure.missingRecord),
      );
    });

    test('rejects an unlisted extra record document', () {
      final release = syntheticBundle(includeBinding: false);
      final complete = syntheticBundle();

      expect(
        () => parser.parse(
          manifestBytes: release.manifestBytes,
          recordDocuments: complete.recordBytes,
        ),
        throwsFailure(SymbolDatasetFailure.unexpectedRecord),
      );
    });

    test('rejects duplicate record identities before resolution', () {
      final bundle = syntheticBundle();

      expect(
        () => parser.parse(
          manifestBytes: bundle.manifestBytes,
          recordDocuments: [
            bundle.recordBytes.first,
            bundle.recordBytes.first,
            bundle.recordBytes.last,
          ],
        ),
        throwsFailure(SymbolDatasetFailure.duplicateIdentity),
      );
    });

    test('rejects non-canonical manifest record ordering', () {
      final bundle = syntheticBundle();
      final manifest = deepCopy(bundle.manifest);
      manifest['records'] = List<Object?>.from(
        manifest['records']! as List,
      ).reversed.toList();

      expect(
        () => parser.parse(
          manifestBytes: bytesFor(rechecksumManifest(manifest)),
          recordDocuments: bundle.recordBytes,
        ),
        throwsFailure(SymbolDatasetFailure.nonCanonicalOrder),
      );
    });

    test('rejects non-canonical semantic array ordering', () {
      final bundle = syntheticBundle();
      final definition = deepCopy(bundle.definition);
      final preferred = List<Object?>.from(
        definition['preferredNames']! as List,
      );
      final first = Map<String, Object?>.from(preferred.single as Map);
      first['sourceRefs'] = [
        {'sourceId': 'test-source-002', 'revision': 1},
        {'sourceId': 'test-source-001', 'revision': 1},
      ];
      preferred[0] = first;
      definition['preferredNames'] = preferred;
      final rebuilt = rebuildBundle(
        manifest: bundle.manifest,
        definition: definition,
        binding: bundle.binding,
      );

      expect(
        () => parser.parse(
          manifestBytes: rebuilt.manifestBytes,
          recordDocuments: rebuilt.recordBytes,
        ),
        throwsFailure(SymbolDatasetFailure.nonCanonicalOrder),
      );
    });

    test('rejects an unsupported canonical profile', () {
      final bundle = syntheticBundle();
      final definition = deepCopy(bundle.definition);
      final profile = Map<String, Object?>.from(
        definition['canonicalJsonProfileRef']! as Map,
      )..['revision'] = 2;
      definition['canonicalJsonProfileRef'] = profile;
      final rebuilt = rebuildBundle(
        manifest: bundle.manifest,
        definition: definition,
        binding: bundle.binding,
      );

      expect(
        () => parser.parse(
          manifestBytes: rebuilt.manifestBytes,
          recordDocuments: rebuilt.recordBytes,
        ),
        throwsFailure(SymbolDatasetFailure.unsupportedCanonicalProfile),
      );
    });

    test('rejects a stale SymbolDefinition checksum reference', () {
      final bundle = syntheticBundle();
      final binding = deepCopy(bundle.binding!);
      final symbolRef = Map<String, Object?>.from(binding['symbolRef']! as Map)
        ..['checksum'] = checksum('9');
      binding['symbolRef'] = symbolRef;
      final changed = _replaceBinding(bundle, binding);

      expect(
        () => parser.parse(
          manifestBytes: changed.manifestBytes,
          recordDocuments: changed.recordBytes,
        ),
        throwsFailure(SymbolDatasetFailure.invalidReference),
      );
    });

    test('rejects a binding to another Knowledge release', () {
      final bundle = syntheticBundle();
      final binding = deepCopy(bundle.binding!);
      final target = Map<String, Object?>.from(
        binding['knowledgeTargetRef']! as Map,
      )..['knowledgeReleaseId'] = 'test-kds-002';
      binding['knowledgeTargetRef'] = target;
      final changed = _replaceBinding(bundle, binding);

      expect(
        () => parser.parse(
          manifestBytes: changed.manifestBytes,
          recordDocuments: changed.recordBytes,
        ),
        throwsFailure(SymbolDatasetFailure.invalidReference),
      );
    });

    test('rejects unknown fields after checksum verification', () {
      final bundle = syntheticBundle();
      final definition = deepCopy(bundle.definition)..['meaning'] = 'forbidden';
      final rebuilt = rebuildBundle(
        manifest: bundle.manifest,
        definition: definition,
        binding: bundle.binding,
      );

      expect(
        () => parser.parse(
          manifestBytes: rebuilt.manifestBytes,
          recordDocuments: rebuilt.recordBytes,
        ),
        throwsFailure(SymbolDatasetFailure.schemaViolation),
      );
    });

    test('rejects an empty release', () {
      final bundle = syntheticBundle();
      final manifest = deepCopy(bundle.manifest)..['records'] = <Object?>[];

      expect(
        () => parser.parse(
          manifestBytes: bytesFor(rechecksumManifest(manifest)),
          recordDocuments: const <Uint8List>[],
        ),
        throwsFailure(SymbolDatasetFailure.schemaViolation),
      );
    });

    test('rejects more than one Knowledge release', () {
      final bundle = syntheticBundle();
      final manifest = deepCopy(bundle.manifest);
      manifest['knowledgeDatasetReleaseRefs'] = [
        {'releaseId': 'test-kds-001', 'checksum': checksum('1')},
        {'releaseId': 'test-kds-002', 'checksum': checksum('2')},
      ];

      expect(
        () => parser.parse(
          manifestBytes: bytesFor(rechecksumManifest(manifest)),
          recordDocuments: bundle.recordBytes,
        ),
        throwsFailure(SymbolDatasetFailure.schemaViolation),
      );
    });

    test('rejects invalid UTC calendar values', () {
      final bundle = syntheticBundle();
      final manifest = deepCopy(bundle.manifest)
        ..['createdAtUtc'] = '2026-02-30T00:00:00Z';

      expect(
        () => parser.parse(
          manifestBytes: bytesFor(rechecksumManifest(manifest)),
          recordDocuments: bundle.recordBytes,
        ),
        throwsFailure(SymbolDatasetFailure.schemaViolation),
      );
    });

    test('rejects duplicate JSON properties before model parsing', () {
      final duplicate = Uint8List.fromList(
        utf8.encode('{"schemaVersion":"1.0","schemaVersion":"1.0"}'),
      );

      expect(
        () => parser.parse(
          manifestBytes: duplicate,
          recordDocuments: const <Uint8List>[],
        ),
        throwsA(
          isA<SymbolDatasetException>()
              .having(
                (error) => error.failure,
                'failure',
                SymbolDatasetFailure.canonicalJsonRejected,
              )
              .having(
                (error) => error.canonicalFailure,
                'canonicalFailure',
                AtlasCanonicalJsonFailure.duplicateProperty,
              ),
        ),
      );
    });

    test('rejects UTF-8 BOM through the canonical boundary', () {
      final bundle = syntheticBundle();
      final bytes = Uint8List.fromList([
        0xef,
        0xbb,
        0xbf,
        ...bundle.manifestBytes,
      ]);

      expect(
        () => parser.parse(
          manifestBytes: bytes,
          recordDocuments: bundle.recordBytes,
        ),
        throwsA(
          isA<SymbolDatasetException>().having(
            (error) => error.canonicalFailure,
            'canonicalFailure',
            AtlasCanonicalJsonFailure.bomNotAllowed,
          ),
        ),
      );
    });

    test('accepts non-canonical object formatting deterministically', () {
      final bundle = syntheticBundle();
      final prettyManifest = Uint8List.fromList(
        utf8.encode(
          const JsonEncoder.withIndent('  ').convert(bundle.manifest),
        ),
      );
      final first = parser.parse(
        manifestBytes: bundle.manifestBytes,
        recordDocuments: bundle.recordBytes,
      );
      final second = parser.parse(
        manifestBytes: prettyManifest,
        recordDocuments: bundle.records
            .map(
              (record) => Uint8List.fromList(
                utf8.encode(const JsonEncoder.withIndent('  ').convert(record)),
              ),
            )
            .toList(growable: false),
      );

      expect(second, first);
    });

    test('accepts omitted optional aliases and sourceRefs', () {
      final bundle = syntheticBundle();
      final definition = deepCopy(bundle.definition)..remove('aliases');
      final binding = deepCopy(bundle.binding!)..remove('sourceRefs');
      final rebuilt = rebuildBundle(
        manifest: bundle.manifest,
        definition: definition,
        binding: binding,
      );

      final snapshot = parser.parse(
        manifestBytes: rebuilt.manifestBytes,
        recordDocuments: rebuilt.recordBytes,
      );

      expect(snapshot.definitions.single.aliases, isEmpty);
      expect(snapshot.bindings.single.sourceRefs, isEmpty);
    });

    test('produces deterministic content-safe toString values', () {
      final bundle = syntheticBundle();
      final snapshot = parser.parse(
        manifestBytes: bundle.manifestBytes,
        recordDocuments: bundle.recordBytes,
      );

      expect(snapshot.toString(), contains('test-symbol-release-001'));
      expect(snapshot.toString(), contains('definitionCount: 1'));
      expect(snapshot.toString(), isNot(contains('Test symbol')));
    });
  });
}

Matcher throwsFailure(SymbolDatasetFailure failure) => throwsA(
  isA<SymbolDatasetException>().having(
    (error) => error.failure,
    'failure',
    failure,
  ),
);

SyntheticBundle _replaceBinding(
  SyntheticBundle bundle,
  Map<String, Object?> binding,
) {
  const canonicalizer = AtlasCanonicalJson();
  final bindingChecksum = canonicalizer.canonicalizeValue(binding).checksum;
  final manifest = deepCopy(bundle.manifest);
  final refs = List<Object?>.from(manifest['records']! as List);
  final bindingRef = Map<String, Object?>.from(refs.last as Map)
    ..['checksum'] = bindingChecksum;
  refs[refs.length - 1] = bindingRef;
  manifest['records'] = refs;
  return SyntheticBundle(
    manifest: rechecksumManifest(manifest),
    records: [bundle.definition, binding],
    definition: bundle.definition,
    binding: binding,
  );
}

final class _SingleUseIterable extends Iterable<Uint8List> {
  _SingleUseIterable(this._values, this._onIterate);

  final List<Uint8List> _values;
  final void Function() _onIterate;
  var _used = false;

  @override
  Iterator<Uint8List> get iterator {
    if (_used) throw StateError('Iterable was consumed more than once.');
    _used = true;
    _onIterate();
    return _values.iterator;
  }
}
