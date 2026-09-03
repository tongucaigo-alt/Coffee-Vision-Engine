import 'dart:convert';
import 'dart:typed_data';

import 'package:atlas_canonical_json/atlas_canonical_json.dart' as atlas;
import 'package:coffee_symbol/coffee_symbol.dart';

import 'symbol_dataset_exception.dart';
import 'symbol_dataset_models.dart';

/// Strict, in-memory parser for one frozen Symbol release bundle.
///
/// The parser performs no file I/O, authoring, normalization, ranking, or
/// external Source/Governance/Evidence registry resolution.
final class SymbolDatasetParser {
  const SymbolDatasetParser();

  static const _canonicalizer = atlas.AtlasCanonicalJson();

  /// Parses one manifest and its separately supplied canonical record set.
  SymbolDatasetSnapshot parse({
    required Uint8List manifestBytes,
    required Iterable<Uint8List> recordDocuments,
  }) {
    final recordInput = recordDocuments.toList(growable: false);
    final manifestDocument = _decode(manifestBytes, 'manifest');
    final manifest = _parseManifest(manifestDocument);

    final rawRecords = <_RawRecord>[];
    final rawIdentities = <(SymbolDatasetRecordType, String, int)>{};
    for (var index = 0; index < recordInput.length; index++) {
      final document = 'records[$index]';
      final raw = _inspectRecord(_decode(recordInput[index], document));
      final identity = (raw.recordType, raw.recordId, raw.revision);
      if (!rawIdentities.add(identity)) {
        throw SymbolDatasetException(
          SymbolDatasetFailure.duplicateIdentity,
          document: document,
          field: 'record identity',
        );
      }
      rawRecords.add(raw);
    }

    final rawByIdentity = <(SymbolDatasetRecordType, String, int), _RawRecord>{
      for (final raw in rawRecords)
        (raw.recordType, raw.recordId, raw.revision): raw,
    };
    final expectedIdentities = <(SymbolDatasetRecordType, String, int)>{};
    final definitions = <SymbolDefinition>[];
    final bindings = <SymbolEvidenceBinding>[];

    for (final recordRef in manifest.records) {
      final identity = (
        recordRef.recordType,
        recordRef.recordId,
        recordRef.revision,
      );
      expectedIdentities.add(identity);
      final raw = rawByIdentity[identity];
      if (raw == null) {
        throw SymbolDatasetException(
          SymbolDatasetFailure.missingRecord,
          document: 'manifest',
          field: recordRef.recordId,
        );
      }
      if (raw.checksum != recordRef.checksum) {
        throw SymbolDatasetException(
          SymbolDatasetFailure.checksumMismatch,
          document: raw.document,
          field: 'record checksum',
        );
      }
      switch (recordRef.recordType) {
        case SymbolDatasetRecordType.symbolDefinition:
          definitions.add(_parseDefinition(raw));
        case SymbolDatasetRecordType.symbolEvidenceBinding:
          bindings.add(_parseBinding(raw));
      }
    }

    for (final raw in rawRecords) {
      final identity = (raw.recordType, raw.recordId, raw.revision);
      if (!expectedIdentities.contains(identity)) {
        throw SymbolDatasetException(
          SymbolDatasetFailure.unexpectedRecord,
          document: raw.document,
          field: raw.recordId,
        );
      }
    }

    _validateReferences(manifest, definitions, bindings);
    return SymbolDatasetSnapshot(
      manifest: manifest,
      definitions: definitions,
      bindings: bindings,
    );
  }

  static SymbolReleaseManifest _parseManifest(_DecodedDocument document) {
    final object = document.object;
    final schemaVersion = _manifestSchemaVersion(object, document.name);
    const commonFields = {
      'schemaVersion',
      'recordType',
      'releaseId',
      'createdAtUtc',
      'canonicalJsonProfileRef',
      'governanceSnapshotRef',
      'records',
      'sourceCatalogReleaseRef',
      'symbolAdmissionPolicyRef',
      'manifestChecksum',
    };
    const physicalFields = {
      'evidenceAdmissionPolicyRef',
      'evidenceAssessmentRegistryReleaseRef',
      'knowledgeDatasetReleaseRefs',
    };
    _requireShape(
      object,
      required: schemaVersion == '1.0'
          ? {...commonFields, ...physicalFields}
          : commonFields,
      allowed: {...commonFields, ...physicalFields},
      document: document.name,
      field: 'manifest',
    );
    if (_string(object['recordType'], document.name, 'recordType') !=
        SymbolReleaseManifest.recordType) {
      throw SymbolDatasetException(
        SymbolDatasetFailure.unsupportedRecordType,
        document: document.name,
        field: 'recordType',
      );
    }

    final manifestChecksum = _string(
      object['manifestChecksum'],
      document.name,
      'manifestChecksum',
    );
    final checksumPayload = Map<String, Object?>.of(object)
      ..remove('manifestChecksum');
    final atlas.AtlasCanonicalJsonResult checksumResult;
    try {
      checksumResult = _canonicalizer.canonicalizeValue(checksumPayload);
    } on atlas.AtlasCanonicalJsonException catch (error) {
      throw SymbolDatasetException(
        SymbolDatasetFailure.canonicalJsonRejected,
        document: document.name,
        field: 'manifest checksum payload',
        canonicalFailure: error.code,
      );
    }
    if (checksumResult.checksum != manifestChecksum) {
      throw SymbolDatasetException(
        SymbolDatasetFailure.checksumMismatch,
        document: document.name,
        field: 'manifestChecksum',
      );
    }

    final recordsSource = _list(object['records'], document.name, 'records');
    final records = <SymbolReleaseRecordRef>[];
    for (var index = 0; index < recordsSource.length; index++) {
      records.add(
        _parseRecordRef(recordsSource[index], document.name, 'records[$index]'),
      );
    }
    if (records.isEmpty) {
      throw SymbolDatasetException(
        SymbolDatasetFailure.schemaViolation,
        document: document.name,
        field: 'records',
      );
    }
    _requireStrictRecordOrder(records, document.name);

    final hasBindings = records.any(
      (record) =>
          record.recordType == SymbolDatasetRecordType.symbolEvidenceBinding,
    );
    if (schemaVersion == '2.0') {
      final presentPhysicalFields = physicalFields
          .where(object.containsKey)
          .toSet();
      if (hasBindings &&
          presentPhysicalFields.length != physicalFields.length) {
        throw SymbolDatasetException(
          SymbolDatasetFailure.schemaViolation,
          document: document.name,
          field: 'physical dependencies',
        );
      }
      if (!hasBindings && presentPhysicalFields.isNotEmpty) {
        throw SymbolDatasetException(
          SymbolDatasetFailure.schemaViolation,
          document: document.name,
          field: 'physical dependencies',
        );
      }
    }

    final knowledgeReleases = <KnowledgeDatasetReleaseRef>[];
    if (schemaVersion == '1.0' || hasBindings) {
      final knowledgeSource = _list(
        object['knowledgeDatasetReleaseRefs'],
        document.name,
        'knowledgeDatasetReleaseRefs',
      );
      if (knowledgeSource.length != 1) {
        throw SymbolDatasetException(
          SymbolDatasetFailure.schemaViolation,
          document: document.name,
          field: 'knowledgeDatasetReleaseRefs',
        );
      }
      knowledgeReleases.add(
        _parseKnowledgeReleaseRef(
          knowledgeSource.single,
          document.name,
          'knowledgeDatasetReleaseRefs[0]',
        ),
      );
    }

    try {
      final common = (
        releaseId: _string(object['releaseId'], document.name, 'releaseId'),
        createdAtUtc: _string(
          object['createdAtUtc'],
          document.name,
          'createdAtUtc',
        ),
        canonicalJsonProfileRef: _parseProfileRef(
          object['canonicalJsonProfileRef'],
          document.name,
          'canonicalJsonProfileRef',
        ),
        governanceSnapshotRef: _parseGovernanceRef(
          object['governanceSnapshotRef'],
          document.name,
          'governanceSnapshotRef',
        ),
        sourceCatalogReleaseRef: _parseSourceCatalogRef(
          object['sourceCatalogReleaseRef'],
          document.name,
          'sourceCatalogReleaseRef',
        ),
        symbolAdmissionPolicyRef: _parseSymbolPolicyRef(
          object['symbolAdmissionPolicyRef'],
          document.name,
          'symbolAdmissionPolicyRef',
        ),
      );
      if (schemaVersion == '2.0') {
        return SymbolReleaseManifest.v2(
          schemaVersion: schemaVersion,
          releaseId: common.releaseId,
          createdAtUtc: common.createdAtUtc,
          canonicalJsonProfileRef: common.canonicalJsonProfileRef,
          governanceSnapshotRef: common.governanceSnapshotRef,
          records: records,
          sourceCatalogReleaseRef: common.sourceCatalogReleaseRef,
          symbolAdmissionPolicyRef: common.symbolAdmissionPolicyRef,
          evidenceAdmissionPolicyRef: hasBindings
              ? _parseEvidencePolicyRef(
                  object['evidenceAdmissionPolicyRef'],
                  document.name,
                  'evidenceAdmissionPolicyRef',
                )
              : null,
          evidenceAssessmentRegistryReleaseRef: hasBindings
              ? _parseAssessmentRegistryRef(
                  object['evidenceAssessmentRegistryReleaseRef'],
                  document.name,
                  'evidenceAssessmentRegistryReleaseRef',
                )
              : null,
          knowledgeDatasetReleaseRefs: knowledgeReleases,
          manifestChecksum: manifestChecksum,
        );
      }
      return SymbolReleaseManifest(
        schemaVersion: schemaVersion,
        releaseId: _string(object['releaseId'], document.name, 'releaseId'),
        createdAtUtc: common.createdAtUtc,
        canonicalJsonProfileRef: common.canonicalJsonProfileRef,
        governanceSnapshotRef: common.governanceSnapshotRef,
        records: records,
        sourceCatalogReleaseRef: common.sourceCatalogReleaseRef,
        symbolAdmissionPolicyRef: common.symbolAdmissionPolicyRef,
        evidenceAdmissionPolicyRef: _parseEvidencePolicyRef(
          object['evidenceAdmissionPolicyRef'],
          document.name,
          'evidenceAdmissionPolicyRef',
        ),
        evidenceAssessmentRegistryReleaseRef: _parseAssessmentRegistryRef(
          object['evidenceAssessmentRegistryReleaseRef'],
          document.name,
          'evidenceAssessmentRegistryReleaseRef',
        ),
        knowledgeDatasetReleaseRefs: knowledgeReleases,
        manifestChecksum: manifestChecksum,
      );
    } on ArgumentError {
      throw SymbolDatasetException(
        SymbolDatasetFailure.schemaViolation,
        document: document.name,
        field: 'manifest',
      );
    }
  }

  static _RawRecord _inspectRecord(_DecodedDocument document) {
    final object = document.object;
    _requireSchemaVersion(object, document.name);
    final recordTypeSource = _string(
      object['recordType'],
      document.name,
      'recordType',
    );
    final recordType = _recordType(recordTypeSource, document.name);
    final idField = switch (recordType) {
      SymbolDatasetRecordType.symbolDefinition => 'symbolId',
      SymbolDatasetRecordType.symbolEvidenceBinding => 'bindingId',
    };
    final recordId = _string(object[idField], document.name, idField);
    final revision = _integer(object['revision'], document.name, 'revision');
    return _RawRecord(
      document: document.name,
      object: object,
      checksum: document.result.checksum,
      recordType: recordType,
      recordId: recordId,
      revision: revision,
    );
  }

  static SymbolDefinition _parseDefinition(_RawRecord raw) {
    final object = raw.object;
    _requireShape(
      object,
      required: const {
        'schemaVersion',
        'recordType',
        'symbolId',
        'revision',
        'canonicalJsonProfileRef',
        'preferredNames',
        'neutralDefinitions',
      },
      allowed: const {
        'schemaVersion',
        'recordType',
        'symbolId',
        'revision',
        'canonicalJsonProfileRef',
        'preferredNames',
        'aliases',
        'neutralDefinitions',
      },
      document: raw.document,
      field: 'SymbolDefinition',
    );
    final preferred = _parseTexts(
      object['preferredNames'],
      raw.document,
      'preferredNames',
      requireNonEmpty: true,
    );
    final aliases = object.containsKey('aliases')
        ? _parseTexts(object['aliases'], raw.document, 'aliases')
        : <SourcedLocalizedText>[];
    final definitions = _parseTexts(
      object['neutralDefinitions'],
      raw.document,
      'neutralDefinitions',
      requireNonEmpty: true,
    );

    try {
      return SymbolDefinition(
        symbolRef: SymbolRevisionRef(
          symbolId: raw.recordId,
          revision: raw.revision,
          checksum: raw.checksum,
        ),
        canonicalJsonProfileRef: _parseProfileRef(
          object['canonicalJsonProfileRef'],
          raw.document,
          'canonicalJsonProfileRef',
        ),
        preferredNames: preferred,
        aliases: aliases,
        neutralDefinitions: definitions,
      );
    } on ArgumentError {
      throw SymbolDatasetException(
        SymbolDatasetFailure.schemaViolation,
        document: raw.document,
        field: 'SymbolDefinition',
      );
    }
  }

  static SymbolEvidenceBinding _parseBinding(_RawRecord raw) {
    final object = raw.object;
    _requireShape(
      object,
      required: const {
        'schemaVersion',
        'recordType',
        'bindingId',
        'revision',
        'canonicalJsonProfileRef',
        'symbolRef',
        'knowledgeTargetRef',
        'evidenceAssessmentRefs',
      },
      allowed: const {
        'schemaVersion',
        'recordType',
        'bindingId',
        'revision',
        'canonicalJsonProfileRef',
        'symbolRef',
        'knowledgeTargetRef',
        'sourceRefs',
        'evidenceAssessmentRefs',
      },
      document: raw.document,
      field: 'SymbolEvidenceBinding',
    );
    final sourceRefs = object.containsKey('sourceRefs')
        ? _parseSourceRefs(object['sourceRefs'], raw.document, 'sourceRefs')
        : <SourceRef>[];
    final assessmentRefs = _parseAssessmentRefs(
      object['evidenceAssessmentRefs'],
      raw.document,
      'evidenceAssessmentRefs',
    );

    try {
      return SymbolEvidenceBinding(
        bindingId: raw.recordId,
        revision: raw.revision,
        canonicalJsonProfileRef: _parseProfileRef(
          object['canonicalJsonProfileRef'],
          raw.document,
          'canonicalJsonProfileRef',
        ),
        symbolRef: _parseSymbolRef(
          object['symbolRef'],
          raw.document,
          'symbolRef',
        ),
        knowledgeTargetRef: _parseKnowledgeTargetRef(
          object['knowledgeTargetRef'],
          raw.document,
          'knowledgeTargetRef',
        ),
        sourceRefs: sourceRefs,
        evidenceAssessmentRefs: assessmentRefs,
      );
    } on ArgumentError {
      throw SymbolDatasetException(
        SymbolDatasetFailure.schemaViolation,
        document: raw.document,
        field: 'SymbolEvidenceBinding',
      );
    }
  }

  static void _validateReferences(
    SymbolReleaseManifest manifest,
    List<SymbolDefinition> definitions,
    List<SymbolEvidenceBinding> bindings,
  ) {
    final definitionsByIdentity = <(String, int), SymbolDefinition>{
      for (final definition in definitions)
        (definition.symbolId, definition.revision): definition,
    };
    for (final binding in bindings) {
      if (binding.knowledgeTargetRef.knowledgeRelease !=
          manifest.knowledgeRelease) {
        throw SymbolDatasetException(
          SymbolDatasetFailure.invalidReference,
          document: binding.bindingId,
          field: 'knowledgeTargetRef.knowledgeRelease',
        );
      }
      final identity = (binding.symbolRef.symbolId, binding.symbolRef.revision);
      final definition = definitionsByIdentity[identity];
      if (definition == null || definition.symbolRef != binding.symbolRef) {
        throw SymbolDatasetException(
          SymbolDatasetFailure.invalidReference,
          document: binding.bindingId,
          field: 'symbolRef',
        );
      }
    }
  }

  static _DecodedDocument _decode(Uint8List source, String name) {
    final atlas.AtlasCanonicalJsonResult result;
    try {
      result = _canonicalizer.canonicalizeUtf8(source);
    } on atlas.AtlasCanonicalJsonException catch (error) {
      throw SymbolDatasetException(
        SymbolDatasetFailure.canonicalJsonRejected,
        document: name,
        canonicalFailure: error.code,
      );
    }
    final Object? decoded = jsonDecode(utf8.decode(result.canonicalBytes));
    if (decoded is! Map<Object?, Object?>) {
      throw SymbolDatasetException(
        SymbolDatasetFailure.schemaViolation,
        document: name,
        field: 'root',
      );
    }
    final object = <String, Object?>{};
    for (final entry in decoded.entries) {
      final key = entry.key;
      if (key is! String) {
        throw SymbolDatasetException(
          SymbolDatasetFailure.schemaViolation,
          document: name,
          field: 'root key',
        );
      }
      object[key] = entry.value;
    }
    return _DecodedDocument(name: name, object: object, result: result);
  }

  static CanonicalJsonProfileRef _parseProfileRef(
    Object? source,
    String document,
    String field,
  ) {
    final object = _object(source, document, field);
    _requireShape(
      object,
      required: const {'profileId', 'revision', 'checksum'},
      allowed: const {'profileId', 'revision', 'checksum'},
      document: document,
      field: field,
    );
    final profileId = _string(
      object['profileId'],
      document,
      '$field.profileId',
    );
    final revision = _integer(object['revision'], document, '$field.revision');
    final checksum = _string(object['checksum'], document, '$field.checksum');
    final frozen = atlas.AtlasCanonicalJsonProfile.revision1;
    if (profileId != frozen.profileId ||
        revision != frozen.revision ||
        checksum != frozen.checksum) {
      throw SymbolDatasetException(
        SymbolDatasetFailure.unsupportedCanonicalProfile,
        document: document,
        field: field,
      );
    }
    try {
      return CanonicalJsonProfileRef(
        profileId: profileId,
        revision: revision,
        checksum: checksum,
      );
    } on ArgumentError {
      throw SymbolDatasetException(
        SymbolDatasetFailure.schemaViolation,
        document: document,
        field: field,
      );
    }
  }

  static SymbolReleaseRecordRef _parseRecordRef(
    Object? source,
    String document,
    String field,
  ) {
    final object = _object(source, document, field);
    _requireShape(
      object,
      required: const {'recordType', 'recordId', 'revision', 'checksum'},
      allowed: const {'recordType', 'recordId', 'revision', 'checksum'},
      document: document,
      field: field,
    );
    try {
      return SymbolReleaseRecordRef(
        recordType: _recordType(
          _string(object['recordType'], document, '$field.recordType'),
          document,
        ),
        recordId: _string(object['recordId'], document, '$field.recordId'),
        revision: _integer(object['revision'], document, '$field.revision'),
        checksum: _string(object['checksum'], document, '$field.checksum'),
      );
    } on ArgumentError {
      throw SymbolDatasetException(
        SymbolDatasetFailure.schemaViolation,
        document: document,
        field: field,
      );
    }
  }

  static GovernanceSnapshotRef _parseGovernanceRef(
    Object? source,
    String document,
    String field,
  ) {
    final object = _exactIdChecksumObject(
      source,
      document,
      field,
      'snapshotId',
    );
    try {
      return GovernanceSnapshotRef(
        snapshotId: _string(
          object['snapshotId'],
          document,
          '$field.snapshotId',
        ),
        checksum: _string(object['checksum'], document, '$field.checksum'),
      );
    } on ArgumentError {
      throw _schemaFailure(document, field);
    }
  }

  static SourceCatalogReleaseRef _parseSourceCatalogRef(
    Object? source,
    String document,
    String field,
  ) {
    final object = _exactIdChecksumObject(source, document, field, 'releaseId');
    try {
      return SourceCatalogReleaseRef(
        releaseId: _string(object['releaseId'], document, '$field.releaseId'),
        checksum: _string(object['checksum'], document, '$field.checksum'),
      );
    } on ArgumentError {
      throw _schemaFailure(document, field);
    }
  }

  static EvidenceAssessmentRegistryReleaseRef _parseAssessmentRegistryRef(
    Object? source,
    String document,
    String field,
  ) {
    final object = _exactIdChecksumObject(source, document, field, 'releaseId');
    try {
      return EvidenceAssessmentRegistryReleaseRef(
        releaseId: _string(object['releaseId'], document, '$field.releaseId'),
        checksum: _string(object['checksum'], document, '$field.checksum'),
      );
    } on ArgumentError {
      throw _schemaFailure(document, field);
    }
  }

  static SymbolAdmissionPolicyRef _parseSymbolPolicyRef(
    Object? source,
    String document,
    String field,
  ) {
    final object = _policyObject(source, document, field);
    try {
      return SymbolAdmissionPolicyRef(
        policyId: _string(object['policyId'], document, '$field.policyId'),
        revision: _integer(object['revision'], document, '$field.revision'),
        checksum: _string(object['checksum'], document, '$field.checksum'),
      );
    } on ArgumentError {
      throw _schemaFailure(document, field);
    }
  }

  static EvidenceAdmissionPolicyRef _parseEvidencePolicyRef(
    Object? source,
    String document,
    String field,
  ) {
    final object = _policyObject(source, document, field);
    try {
      return EvidenceAdmissionPolicyRef(
        policyId: _string(object['policyId'], document, '$field.policyId'),
        revision: _integer(object['revision'], document, '$field.revision'),
        checksum: _string(object['checksum'], document, '$field.checksum'),
      );
    } on ArgumentError {
      throw _schemaFailure(document, field);
    }
  }

  static KnowledgeDatasetReleaseRef _parseKnowledgeReleaseRef(
    Object? source,
    String document,
    String field,
  ) {
    final object = _exactIdChecksumObject(source, document, field, 'releaseId');
    try {
      return KnowledgeDatasetReleaseRef(
        releaseId: _string(object['releaseId'], document, '$field.releaseId'),
        checksum: _string(object['checksum'], document, '$field.checksum'),
      );
    } on ArgumentError {
      throw _schemaFailure(document, field);
    }
  }

  static SymbolRevisionRef _parseSymbolRef(
    Object? source,
    String document,
    String field,
  ) {
    final object = _object(source, document, field);
    _requireShape(
      object,
      required: const {'symbolId', 'revision', 'checksum'},
      allowed: const {'symbolId', 'revision', 'checksum'},
      document: document,
      field: field,
    );
    try {
      return SymbolRevisionRef(
        symbolId: _string(object['symbolId'], document, '$field.symbolId'),
        revision: _integer(object['revision'], document, '$field.revision'),
        checksum: _string(object['checksum'], document, '$field.checksum'),
      );
    } on ArgumentError {
      throw _schemaFailure(document, field);
    }
  }

  static KnowledgeTargetRef _parseKnowledgeTargetRef(
    Object? source,
    String document,
    String field,
  ) {
    final object = _object(source, document, field);
    _requireShape(
      object,
      required: const {
        'knowledgeReleaseId',
        'knowledgeReleaseChecksum',
        'knowledgeRecordId',
      },
      allowed: const {
        'knowledgeReleaseId',
        'knowledgeReleaseChecksum',
        'knowledgeRecordId',
      },
      document: document,
      field: field,
    );
    try {
      return KnowledgeTargetRef(
        knowledgeRelease: KnowledgeDatasetReleaseRef(
          releaseId: _string(
            object['knowledgeReleaseId'],
            document,
            '$field.knowledgeReleaseId',
          ),
          checksum: _string(
            object['knowledgeReleaseChecksum'],
            document,
            '$field.knowledgeReleaseChecksum',
          ),
        ),
        knowledgeRecordId: _string(
          object['knowledgeRecordId'],
          document,
          '$field.knowledgeRecordId',
        ),
      );
    } on ArgumentError {
      throw _schemaFailure(document, field);
    }
  }

  static List<SourcedLocalizedText> _parseTexts(
    Object? source,
    String document,
    String field, {
    bool requireNonEmpty = false,
  }) {
    final values = _list(source, document, field);
    if (requireNonEmpty && values.isEmpty)
      throw _schemaFailure(document, field);
    final result = <SourcedLocalizedText>[];
    for (var index = 0; index < values.length; index++) {
      final itemField = '$field[$index]';
      final object = _object(values[index], document, itemField);
      _requireShape(
        object,
        required: const {'language', 'value', 'sourceRefs'},
        allowed: const {'language', 'value', 'sourceRefs'},
        document: document,
        field: itemField,
      );
      try {
        result.add(
          SourcedLocalizedText(
            language: _string(
              object['language'],
              document,
              '$itemField.language',
            ),
            value: _string(object['value'], document, '$itemField.value'),
            sourceRefs: _parseSourceRefs(
              object['sourceRefs'],
              document,
              '$itemField.sourceRefs',
              requireNonEmpty: true,
            ),
          ),
        );
      } on ArgumentError {
        throw _schemaFailure(document, itemField);
      }
    }
    _requireStrictOrder(result, _compareTexts, document, field);
    return result;
  }

  static List<SourceRef> _parseSourceRefs(
    Object? source,
    String document,
    String field, {
    bool requireNonEmpty = false,
  }) {
    final values = _list(source, document, field);
    if (requireNonEmpty && values.isEmpty)
      throw _schemaFailure(document, field);
    final result = <SourceRef>[];
    for (var index = 0; index < values.length; index++) {
      final itemField = '$field[$index]';
      final object = _object(values[index], document, itemField);
      _requireShape(
        object,
        required: const {'sourceId', 'revision'},
        allowed: const {'sourceId', 'revision', 'locator'},
        document: document,
        field: itemField,
      );
      try {
        result.add(
          SourceRef(
            sourceId: _string(
              object['sourceId'],
              document,
              '$itemField.sourceId',
            ),
            revision: _integer(
              object['revision'],
              document,
              '$itemField.revision',
            ),
            locator: object.containsKey('locator')
                ? _string(object['locator'], document, '$itemField.locator')
                : null,
          ),
        );
      } on ArgumentError {
        throw _schemaFailure(document, itemField);
      }
    }
    _requireStrictOrder(result, _compareSources, document, field);
    return result;
  }

  static List<EvidenceAssessmentRef> _parseAssessmentRefs(
    Object? source,
    String document,
    String field,
  ) {
    final values = _list(source, document, field);
    if (values.isEmpty) throw _schemaFailure(document, field);
    final result = <EvidenceAssessmentRef>[];
    final identities = <(EvidenceAssessmentType, String, int)>{};
    for (var index = 0; index < values.length; index++) {
      final itemField = '$field[$index]';
      final object = _object(values[index], document, itemField);
      _requireShape(
        object,
        required: const {
          'assessmentId',
          'revision',
          'assessmentType',
          'checksum',
        },
        allowed: const {
          'assessmentId',
          'revision',
          'assessmentType',
          'checksum',
        },
        document: document,
        field: itemField,
      );
      final type = _assessmentType(
        _string(
          object['assessmentType'],
          document,
          '$itemField.assessmentType',
        ),
        document,
        '$itemField.assessmentType',
      );
      final assessmentId = _string(
        object['assessmentId'],
        document,
        '$itemField.assessmentId',
      );
      final revision = _integer(
        object['revision'],
        document,
        '$itemField.revision',
      );
      if (!identities.add((type, assessmentId, revision))) {
        throw SymbolDatasetException(
          SymbolDatasetFailure.duplicateIdentity,
          document: document,
          field: itemField,
        );
      }
      try {
        result.add(
          EvidenceAssessmentRef(
            assessmentId: assessmentId,
            revision: revision,
            assessmentType: type,
            checksum: _string(
              object['checksum'],
              document,
              '$itemField.checksum',
            ),
          ),
        );
      } on ArgumentError {
        throw _schemaFailure(document, itemField);
      }
    }
    _requireStrictOrder(result, _compareAssessments, document, field);
    return result;
  }

  static Map<String, Object?> _exactIdChecksumObject(
    Object? source,
    String document,
    String field,
    String idField,
  ) {
    final object = _object(source, document, field);
    _requireShape(
      object,
      required: {idField, 'checksum'},
      allowed: {idField, 'checksum'},
      document: document,
      field: field,
    );
    return object;
  }

  static Map<String, Object?> _policyObject(
    Object? source,
    String document,
    String field,
  ) {
    final object = _object(source, document, field);
    _requireShape(
      object,
      required: const {'policyId', 'revision', 'checksum'},
      allowed: const {'policyId', 'revision', 'checksum'},
      document: document,
      field: field,
    );
    return object;
  }

  static SymbolDatasetRecordType _recordType(String source, String document) {
    for (final type in SymbolDatasetRecordType.values) {
      if (type.wireName == source) return type;
    }
    throw SymbolDatasetException(
      SymbolDatasetFailure.unsupportedRecordType,
      document: document,
      field: 'recordType',
    );
  }

  static EvidenceAssessmentType _assessmentType(
    String source,
    String document,
    String field,
  ) {
    for (final type in EvidenceAssessmentType.values) {
      if (type.name == source) return type;
    }
    throw SymbolDatasetException(
      SymbolDatasetFailure.schemaViolation,
      document: document,
      field: field,
    );
  }

  static void _requireSchemaVersion(
    Map<String, Object?> object,
    String document,
  ) {
    if (_string(object['schemaVersion'], document, 'schemaVersion') != '1.0') {
      throw SymbolDatasetException(
        SymbolDatasetFailure.unsupportedSchemaVersion,
        document: document,
        field: 'schemaVersion',
      );
    }
  }

  static String _manifestSchemaVersion(
    Map<String, Object?> object,
    String document,
  ) {
    final version = _string(object['schemaVersion'], document, 'schemaVersion');
    if (version != '1.0' && version != '2.0') {
      throw SymbolDatasetException(
        SymbolDatasetFailure.unsupportedSchemaVersion,
        document: document,
        field: 'schemaVersion',
      );
    }
    return version;
  }

  static void _requireShape(
    Map<String, Object?> object, {
    required Set<String> required,
    required Set<String> allowed,
    required String document,
    required String field,
  }) {
    if (!object.keys.toSet().containsAll(required) ||
        object.keys.any((key) => !allowed.contains(key))) {
      throw SymbolDatasetException(
        SymbolDatasetFailure.schemaViolation,
        document: document,
        field: field,
      );
    }
  }

  static Map<String, Object?> _object(
    Object? source,
    String document,
    String field,
  ) {
    if (source is! Map<Object?, Object?>) throw _schemaFailure(document, field);
    final result = <String, Object?>{};
    for (final entry in source.entries) {
      if (entry.key is! String) throw _schemaFailure(document, field);
      result[entry.key! as String] = entry.value;
    }
    return result;
  }

  static List<Object?> _list(Object? source, String document, String field) {
    if (source is! List<Object?>) throw _schemaFailure(document, field);
    return source;
  }

  static String _string(Object? source, String document, String field) {
    if (source is! String) throw _schemaFailure(document, field);
    return source;
  }

  static int _integer(Object? source, String document, String field) {
    if (source is! int) throw _schemaFailure(document, field);
    return source;
  }

  static Never _schemaFailure(String document, String field) {
    throw SymbolDatasetException(
      SymbolDatasetFailure.schemaViolation,
      document: document,
      field: field,
    );
  }

  static void _requireStrictRecordOrder(
    List<SymbolReleaseRecordRef> records,
    String document,
  ) {
    _requireStrictOrder(records, compareRecordRefs, document, 'records');
  }

  static void _requireStrictOrder<T>(
    List<T> values,
    int Function(T, T) compare,
    String document,
    String field,
  ) {
    for (var index = 1; index < values.length; index++) {
      final order = compare(values[index - 1], values[index]);
      if (order == 0) {
        throw SymbolDatasetException(
          SymbolDatasetFailure.duplicateIdentity,
          document: document,
          field: '$field[$index]',
        );
      }
      if (order > 0) {
        throw SymbolDatasetException(
          SymbolDatasetFailure.nonCanonicalOrder,
          document: document,
          field: '$field[$index]',
        );
      }
    }
  }

  static int _compareTexts(
    SourcedLocalizedText first,
    SourcedLocalizedText second,
  ) {
    final language = first.language.compareTo(second.language);
    if (language != 0) return language;
    final value = first.value.compareTo(second.value);
    if (value != 0) return value;
    return _compareLists(first.sourceRefs, second.sourceRefs, _compareSources);
  }

  static int _compareSources(SourceRef first, SourceRef second) {
    final id = first.sourceId.compareTo(second.sourceId);
    if (id != 0) return id;
    final revision = first.revision.compareTo(second.revision);
    if (revision != 0) return revision;
    return (first.locator ?? '').compareTo(second.locator ?? '');
  }

  static int _compareAssessments(
    EvidenceAssessmentRef first,
    EvidenceAssessmentRef second,
  ) {
    final type = first.assessmentType.index.compareTo(
      second.assessmentType.index,
    );
    if (type != 0) return type;
    final id = first.assessmentId.compareTo(second.assessmentId);
    if (id != 0) return id;
    final revision = first.revision.compareTo(second.revision);
    if (revision != 0) return revision;
    return first.checksum.compareTo(second.checksum);
  }

  static int _compareLists<T>(
    List<T> first,
    List<T> second,
    int Function(T, T) compare,
  ) {
    final length = first.length < second.length ? first.length : second.length;
    for (var index = 0; index < length; index++) {
      final order = compare(first[index], second[index]);
      if (order != 0) return order;
    }
    return first.length.compareTo(second.length);
  }
}

final class _DecodedDocument {
  const _DecodedDocument({
    required this.name,
    required this.object,
    required this.result,
  });

  final String name;
  final Map<String, Object?> object;
  final atlas.AtlasCanonicalJsonResult result;
}

final class _RawRecord {
  const _RawRecord({
    required this.document,
    required this.object,
    required this.checksum,
    required this.recordType,
    required this.recordId,
    required this.revision,
  });

  final String document;
  final Map<String, Object?> object;
  final String checksum;
  final SymbolDatasetRecordType recordType;
  final String recordId;
  final int revision;
}
