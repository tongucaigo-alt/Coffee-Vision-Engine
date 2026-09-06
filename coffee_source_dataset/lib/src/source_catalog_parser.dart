import 'dart:convert';
import 'dart:typed_data';

import 'package:atlas_canonical_json/atlas_canonical_json.dart' as atlas;
import 'package:coffee_source/coffee_source.dart';

import 'source_catalog_exception.dart';
import 'source_catalog_snapshot.dart';

enum _RecordType {
  sourceRecord('atlas.sourceRecord'),
  sourceUseAssessment('atlas.sourceUseAssessment');

  const _RecordType(this.wireName);
  final String wireName;
}

final class SourceCatalogParser {
  const SourceCatalogParser();

  static const _canonicalizer = atlas.AtlasCanonicalJson();

  SourceCatalogSnapshot parse({
    required Uint8List manifestBytes,
    required Iterable<Uint8List> recordDocuments,
  }) {
    final inputs = recordDocuments.toList(growable: false);
    final manifestDocument = _decode(manifestBytes, 'manifest');
    final manifest = _parseManifest(manifestDocument);

    final rawRecords = <_RawRecord>[];
    final identities = <(_RecordType, String, int)>{};
    for (var index = 0; index < inputs.length; index++) {
      final raw = _inspect(_decode(inputs[index], 'records[$index]'));
      if (!identities.add((raw.type, raw.id, raw.revision))) {
        throw _failure(
          SourceCatalogFailure.duplicateIdentity,
          raw.document.name,
          'record identity',
        );
      }
      rawRecords.add(raw);
    }

    final byIdentity = <(_RecordType, String, int), _RawRecord>{
      for (final raw in rawRecords) (raw.type, raw.id, raw.revision): raw,
    };
    final expected = <(_RecordType, String, int)>{};
    final records = <SourceRecord>[];
    final assessments = <SourceUseAssessment>[];

    for (final ref in manifest.sourceRecords) {
      final identity = (_RecordType.sourceRecord, ref.sourceId, ref.revision);
      expected.add(identity);
      final raw = byIdentity[identity];
      if (raw == null) {
        throw _failure(
          SourceCatalogFailure.missingRecord,
          'manifest',
          ref.sourceId,
        );
      }
      _requireChecksum(raw, ref.checksum);
      records.add(_parseSourceRecord(raw.document));
    }
    for (final ref in manifest.useAssessments) {
      final identity = (
        _RecordType.sourceUseAssessment,
        ref.useAssessmentId,
        ref.revision,
      );
      expected.add(identity);
      final raw = byIdentity[identity];
      if (raw == null) {
        throw _failure(
          SourceCatalogFailure.missingRecord,
          'manifest',
          ref.useAssessmentId,
        );
      }
      _requireChecksum(raw, ref.checksum);
      assessments.add(_parseAssessment(raw.document));
    }
    for (final raw in rawRecords) {
      if (!expected.contains((raw.type, raw.id, raw.revision))) {
        throw _failure(
          SourceCatalogFailure.unexpectedRecord,
          raw.document.name,
          raw.id,
        );
      }
    }

    final sourcesByIdentity = {
      for (final record in records) (record.sourceId, record.revision): record,
    };
    for (final assessment in assessments) {
      final source =
          sourcesByIdentity[(
            assessment.sourceRef.sourceId,
            assessment.sourceRef.revision,
          )];
      if (source == null) {
        throw _failure(
          SourceCatalogFailure.invalidReference,
          assessment.useAssessmentId,
          'sourceRef',
        );
      }
      if (assessment.assessmentOutcome ==
              SourceAssessmentOutcome.eligibleCore &&
          source.integrity.manifestationType ==
              SourceManifestationType.uncapturedMutable &&
          assessment.qualityDimensions.attribution ==
              AttributionQuality.anonymous) {
        throw _failure(
          SourceCatalogFailure.releaseEligibilityViolation,
          assessment.useAssessmentId,
          'assessmentOutcome',
        );
      }
    }
    return SourceCatalogSnapshot(
      manifest: manifest,
      sourceRecords: records,
      useAssessments: assessments,
    );
  }

  static SourceCatalogReleaseManifest _parseManifest(_Document document) {
    final object = document.object;
    _shape(
      object,
      required: const {
        'schemaVersion',
        'recordType',
        'releaseId',
        'createdAtUtc',
        'canonicalJsonProfileRef',
        'governanceSnapshotRef',
        'contextRegistryReleaseRef',
        'sourceRecords',
        'useAssessments',
        'manifestChecksum',
      },
      allowed: const {
        'schemaVersion',
        'recordType',
        'releaseId',
        'createdAtUtc',
        'canonicalJsonProfileRef',
        'governanceSnapshotRef',
        'contextRegistryReleaseRef',
        'sourceRecords',
        'useAssessments',
        'manifestChecksum',
      },
      document: document.name,
      field: 'manifest',
    );
    _version(object, document.name);
    if (_string(object['recordType'], document.name, 'recordType') !=
        SourceCatalogReleaseManifest.recordType) {
      throw _failure(
        SourceCatalogFailure.unsupportedRecordType,
        document.name,
        'recordType',
      );
    }
    final expectedChecksum = _string(
      object['manifestChecksum'],
      document.name,
      'manifestChecksum',
    );
    final payload = Map<String, Object?>.of(object)..remove('manifestChecksum');
    final actualChecksum = _canonicalizeValue(
      payload,
      document.name,
      'manifestChecksum',
    ).checksum;
    if (actualChecksum != expectedChecksum) {
      throw _failure(
        SourceCatalogFailure.checksumMismatch,
        document.name,
        'manifestChecksum',
      );
    }

    final sourceRefs = _sourceRecordRefs(
      object['sourceRecords'],
      document.name,
    );
    final assessmentRefs = _assessmentRefs(
      object['useAssessments'],
      document.name,
    );
    _strictOrder(
      sourceRefs,
      _compareSourceRefs,
      document.name,
      'sourceRecords',
    );
    _strictOrder(
      assessmentRefs,
      _compareAssessmentRefs,
      document.name,
      'useAssessments',
    );
    try {
      return SourceCatalogReleaseManifest(
        schemaVersion: '1.0',
        releaseId: _string(object['releaseId'], document.name, 'releaseId'),
        createdAtUtc: _string(
          object['createdAtUtc'],
          document.name,
          'createdAtUtc',
        ),
        canonicalJsonProfileRef: _profile(
          object['canonicalJsonProfileRef'],
          document.name,
          'canonicalJsonProfileRef',
        ),
        governanceSnapshotRef: _governanceRef(
          object['governanceSnapshotRef'],
          document.name,
          'governanceSnapshotRef',
        ),
        contextRegistryReleaseRef: _contextRef(
          object['contextRegistryReleaseRef'],
          document.name,
          'contextRegistryReleaseRef',
        ),
        sourceRecords: sourceRefs,
        useAssessments: assessmentRefs,
        manifestChecksum: expectedChecksum,
      );
    } on ArgumentError {
      throw _failure(
        SourceCatalogFailure.schemaViolation,
        document.name,
        'manifest',
      );
    }
  }

  static _RawRecord _inspect(_Document document) {
    final object = document.object;
    _version(object, document.name);
    final wireType = _string(object['recordType'], document.name, 'recordType');
    final type = _recordType(wireType, document.name);
    final (idField, id) = switch (type) {
      _RecordType.sourceRecord => (
        'sourceId',
        _string(object['sourceId'], document.name, 'sourceId'),
      ),
      _RecordType.sourceUseAssessment => (
        'useAssessmentId',
        _string(object['useAssessmentId'], document.name, 'useAssessmentId'),
      ),
    };
    return _RawRecord(
      document: document,
      type: type,
      id: id,
      idField: idField,
      revision: _integer(object['revision'], document.name, 'revision'),
    );
  }

  static SourceRecord _parseSourceRecord(_Document document) {
    final object = document.object;
    _shape(
      object,
      required: const {
        'schemaVersion',
        'recordType',
        'sourceId',
        'revision',
        'canonicalJsonProfileRef',
        'sourceClass',
        'title',
        'creators',
        'publication',
        'languages',
        'identifiers',
        'access',
        'rights',
        'culturalCoverage',
        'integrity',
      },
      allowed: const {
        'schemaVersion',
        'recordType',
        'sourceId',
        'revision',
        'canonicalJsonProfileRef',
        'sourceClass',
        'title',
        'creators',
        'publication',
        'languages',
        'identifiers',
        'access',
        'rights',
        'culturalCoverage',
        'integrity',
      },
      document: document.name,
      field: 'record',
    );
    final creators = _creators(object['creators'], document.name);
    final identifiers = _identifiers(object['identifiers'], document.name);
    final coverage = _coverage(object['culturalCoverage'], document.name);
    _strictOrder(creators, _compareCreators, document.name, 'creators');
    _strictOrder(
      identifiers,
      _compareIdentifiers,
      document.name,
      'identifiers',
    );
    _strictStrings(
      coverage.contextIds,
      document.name,
      'culturalCoverage.contextIds',
    );
    try {
      return SourceRecord(
        schemaVersion: '1.0',
        sourceId: _string(object['sourceId'], document.name, 'sourceId'),
        revision: _integer(object['revision'], document.name, 'revision'),
        canonicalJsonProfileRef: _profile(
          object['canonicalJsonProfileRef'],
          document.name,
          'canonicalJsonProfileRef',
        ),
        sourceClass: _enumValue(
          SourceClass.values,
          _string(object['sourceClass'], document.name, 'sourceClass'),
          document.name,
          'sourceClass',
        ),
        title: _string(object['title'], document.name, 'title'),
        creators: creators,
        publication: _publication(object['publication'], document.name),
        languages: _languages(object['languages'], document.name),
        identifiers: identifiers,
        access: _access(object['access'], document.name),
        rights: _rights(object['rights'], document.name),
        culturalCoverage: coverage,
        integrity: _integrity(object['integrity'], document.name),
      );
    } on ArgumentError {
      throw _failure(
        SourceCatalogFailure.schemaViolation,
        document.name,
        'record',
      );
    }
  }

  static SourceUseAssessment _parseAssessment(_Document document) {
    final object = document.object;
    _shape(
      object,
      required: const {
        'schemaVersion',
        'recordType',
        'useAssessmentId',
        'revision',
        'canonicalJsonProfileRef',
        'targetRef',
        'sourceRef',
        'evidenceRole',
        'supportRelation',
        'independenceGroupId',
        'independenceRationale',
        'qualityDimensions',
        'assessmentOutcome',
        'limitations',
        'rationale',
      },
      allowed: const {
        'schemaVersion',
        'recordType',
        'useAssessmentId',
        'revision',
        'canonicalJsonProfileRef',
        'targetRef',
        'sourceRef',
        'evidenceRole',
        'supportRelation',
        'independenceGroupId',
        'independenceRationale',
        'qualityDimensions',
        'assessmentOutcome',
        'limitations',
        'rationale',
      },
      document: document.name,
      field: 'assessment',
    );
    final limitations = _stringList(
      object['limitations'],
      document.name,
      'limitations',
    );
    _strictStrings(limitations, document.name, 'limitations');
    try {
      return SourceUseAssessment(
        schemaVersion: '1.0',
        useAssessmentId: _string(
          object['useAssessmentId'],
          document.name,
          'useAssessmentId',
        ),
        revision: _integer(object['revision'], document.name, 'revision'),
        canonicalJsonProfileRef: _profile(
          object['canonicalJsonProfileRef'],
          document.name,
          'canonicalJsonProfileRef',
        ),
        targetRef: _targetRef(object['targetRef'], document.name, 'targetRef'),
        sourceRef: _sourceRef(object['sourceRef'], document.name, 'sourceRef'),
        evidenceRole: _enumValue(
          SourceEvidenceRole.values,
          _string(object['evidenceRole'], document.name, 'evidenceRole'),
          document.name,
          'evidenceRole',
        ),
        supportRelation: _enumValue(
          SourceSupportRelation.values,
          _string(object['supportRelation'], document.name, 'supportRelation'),
          document.name,
          'supportRelation',
        ),
        independenceGroupId: _string(
          object['independenceGroupId'],
          document.name,
          'independenceGroupId',
        ),
        independenceRationale: _string(
          object['independenceRationale'],
          document.name,
          'independenceRationale',
        ),
        qualityDimensions: _quality(object['qualityDimensions'], document.name),
        assessmentOutcome: _enumValue(
          SourceAssessmentOutcome.values,
          _string(
            object['assessmentOutcome'],
            document.name,
            'assessmentOutcome',
          ),
          document.name,
          'assessmentOutcome',
        ),
        limitations: limitations,
        rationale: _string(object['rationale'], document.name, 'rationale'),
      );
    } on ArgumentError {
      throw _failure(
        SourceCatalogFailure.schemaViolation,
        document.name,
        'assessment',
      );
    }
  }

  static _Document _decode(Uint8List bytes, String name) {
    final atlas.AtlasCanonicalJsonResult result;
    try {
      result = _canonicalizer.canonicalizeUtf8(bytes);
    } on atlas.AtlasCanonicalJsonException catch (error) {
      throw SourceCatalogException(
        SourceCatalogFailure.canonicalJsonRejected,
        document: name,
        canonicalFailure: error.code,
      );
    }
    final Object? decoded = jsonDecode(utf8.decode(result.canonicalBytes));
    return _Document(name, _object(decoded, name, 'root'), result.checksum);
  }

  static void _requireChecksum(_RawRecord raw, String expected) {
    if (raw.document.checksum != expected) {
      throw _failure(
        SourceCatalogFailure.checksumMismatch,
        raw.document.name,
        raw.idField,
      );
    }
  }

  static atlas.AtlasCanonicalJsonResult _canonicalizeValue(
    Object? value,
    String document,
    String field,
  ) {
    try {
      return _canonicalizer.canonicalizeValue(value);
    } on atlas.AtlasCanonicalJsonException catch (error) {
      throw SourceCatalogException(
        SourceCatalogFailure.canonicalJsonRejected,
        document: document,
        field: field,
        canonicalFailure: error.code,
      );
    }
  }

  static CanonicalJsonProfileRef _profile(
    Object? value,
    String document,
    String field,
  ) {
    final object = _object(value, document, field);
    _shape(
      object,
      required: const {'profileId', 'revision', 'checksum'},
      allowed: const {'profileId', 'revision', 'checksum'},
      document: document,
      field: field,
    );
    final profile = atlas.AtlasCanonicalJsonProfile.revision1;
    if (_string(object['profileId'], document, '$field.profileId') !=
            profile.profileId ||
        _integer(object['revision'], document, '$field.revision') !=
            profile.revision ||
        _string(object['checksum'], document, '$field.checksum') !=
            profile.checksum) {
      throw _failure(
        SourceCatalogFailure.unsupportedCanonicalProfile,
        document,
        field,
      );
    }
    return CanonicalJsonProfileRef(
      profileId: profile.profileId,
      revision: profile.revision,
      checksum: profile.checksum,
    );
  }

  static GovernanceSnapshotRef _governanceRef(
    Object? value,
    String document,
    String field,
  ) {
    final object = _exactObject(value, document, field, 'snapshotId');
    return _construct(
      () => GovernanceSnapshotRef(
        snapshotId: _string(
          object['snapshotId'],
          document,
          '$field.snapshotId',
        ),
        checksum: _string(object['checksum'], document, '$field.checksum'),
      ),
      document,
      field,
    );
  }

  static ContextRegistryReleaseRef _contextRef(
    Object? value,
    String document,
    String field,
  ) {
    final object = _exactObject(value, document, field, 'releaseId');
    return _construct(
      () => ContextRegistryReleaseRef(
        releaseId: _string(object['releaseId'], document, '$field.releaseId'),
        checksum: _string(object['checksum'], document, '$field.checksum'),
      ),
      document,
      field,
    );
  }

  static DomainTargetRef _targetRef(
    Object? value,
    String document,
    String field,
  ) {
    final object = _object(value, document, field);
    _shape(
      object,
      required: const {'recordType', 'recordId', 'revision', 'checksum'},
      allowed: const {
        'recordType',
        'recordId',
        'revision',
        'checksum',
        'targetPath',
      },
      document: document,
      field: field,
    );
    return _construct(
      () => DomainTargetRef(
        recordType: _string(
          object['recordType'],
          document,
          '$field.recordType',
        ),
        recordId: _string(object['recordId'], document, '$field.recordId'),
        revision: _integer(object['revision'], document, '$field.revision'),
        checksum: _string(object['checksum'], document, '$field.checksum'),
        targetPath: object.containsKey('targetPath')
            ? _string(object['targetPath'], document, '$field.targetPath')
            : null,
      ),
      document,
      field,
    );
  }

  static SourceRef _sourceRef(Object? value, String document, String field) {
    final object = _object(value, document, field);
    _shape(
      object,
      required: const {'sourceId', 'revision'},
      allowed: const {'sourceId', 'revision', 'locator'},
      document: document,
      field: field,
    );
    return _construct(
      () => SourceRef(
        sourceId: _string(object['sourceId'], document, '$field.sourceId'),
        revision: _integer(object['revision'], document, '$field.revision'),
        locator: object.containsKey('locator')
            ? _string(object['locator'], document, '$field.locator')
            : null,
      ),
      document,
      field,
    );
  }

  static List<SourceRecordReleaseRef> _sourceRecordRefs(
    Object? value,
    String document,
  ) {
    final values = _list(value, document, 'sourceRecords');
    final result = <SourceRecordReleaseRef>[];
    for (var index = 0; index < values.length; index++) {
      final field = 'sourceRecords[$index]';
      final object = _object(values[index], document, field);
      _shape(
        object,
        required: const {'sourceId', 'revision', 'checksum'},
        allowed: const {'sourceId', 'revision', 'checksum'},
        document: document,
        field: field,
      );
      result.add(
        _construct(
          () => SourceRecordReleaseRef(
            sourceId: _string(object['sourceId'], document, '$field.sourceId'),
            revision: _integer(object['revision'], document, '$field.revision'),
            checksum: _string(object['checksum'], document, '$field.checksum'),
          ),
          document,
          field,
        ),
      );
    }
    return result;
  }

  static List<SourceUseAssessmentReleaseRef> _assessmentRefs(
    Object? value,
    String document,
  ) {
    final values = _list(value, document, 'useAssessments');
    final result = <SourceUseAssessmentReleaseRef>[];
    for (var index = 0; index < values.length; index++) {
      final field = 'useAssessments[$index]';
      final object = _object(values[index], document, field);
      _shape(
        object,
        required: const {'useAssessmentId', 'revision', 'checksum'},
        allowed: const {'useAssessmentId', 'revision', 'checksum'},
        document: document,
        field: field,
      );
      result.add(
        _construct(
          () => SourceUseAssessmentReleaseRef(
            useAssessmentId: _string(
              object['useAssessmentId'],
              document,
              '$field.useAssessmentId',
            ),
            revision: _integer(object['revision'], document, '$field.revision'),
            checksum: _string(object['checksum'], document, '$field.checksum'),
          ),
          document,
          field,
        ),
      );
    }
    return result;
  }

  static List<SourceAgent> _creators(Object? value, String document) {
    final values = _list(value, document, 'creators');
    return [
      for (var index = 0; index < values.length; index++)
        _parseCreator(values[index], document, 'creators[$index]'),
    ];
  }

  static SourceAgent _parseCreator(
    Object? value,
    String document,
    String field,
  ) {
    final object = _object(value, document, field);
    _shape(
      object,
      required: const {'agentType', 'displayName', 'role'},
      allowed: const {'agentType', 'displayName', 'role'},
      document: document,
      field: field,
    );
    return _construct(
      () => SourceAgent(
        agentType: _enumValue(
          SourceAgentType.values,
          _string(object['agentType'], document, '$field.agentType'),
          document,
          '$field.agentType',
        ),
        displayName: _string(
          object['displayName'],
          document,
          '$field.displayName',
        ),
        role: _string(object['role'], document, '$field.role'),
      ),
      document,
      field,
    );
  }

  static PublicationInfo _publication(Object? value, String document) {
    const fields = {
      'publicationDate',
      'publisher',
      'containerTitle',
      'edition',
      'volume',
      'issue',
      'pages',
    };
    final object = _object(value, document, 'publication');
    _shape(
      object,
      required: const {},
      allowed: fields,
      document: document,
      field: 'publication',
    );
    return _construct(
      () => PublicationInfo(
        publicationDate: _optionalString(
          object,
          'publicationDate',
          document,
          'publication',
        ),
        publisher: _optionalString(
          object,
          'publisher',
          document,
          'publication',
        ),
        containerTitle: _optionalString(
          object,
          'containerTitle',
          document,
          'publication',
        ),
        edition: _optionalString(object, 'edition', document, 'publication'),
        volume: _optionalString(object, 'volume', document, 'publication'),
        issue: _optionalString(object, 'issue', document, 'publication'),
        pages: _optionalString(object, 'pages', document, 'publication'),
      ),
      document,
      'publication',
    );
  }

  static LanguageInfo _languages(Object? value, String document) {
    final object = _object(value, document, 'languages');
    _shape(
      object,
      required: const {'consultedLanguage'},
      allowed: const {'consultedLanguage', 'originalLanguage'},
      document: document,
      field: 'languages',
    );
    return _construct(
      () => LanguageInfo(
        consultedLanguage: _string(
          object['consultedLanguage'],
          document,
          'languages.consultedLanguage',
        ),
        originalLanguage: _optionalString(
          object,
          'originalLanguage',
          document,
          'languages',
        ),
      ),
      document,
      'languages',
    );
  }

  static List<SourceIdentifier> _identifiers(Object? value, String document) {
    final values = _list(value, document, 'identifiers');
    final result = <SourceIdentifier>[];
    for (var index = 0; index < values.length; index++) {
      final field = 'identifiers[$index]';
      final object = _object(values[index], document, field);
      _shape(
        object,
        required: const {'identifierType', 'value'},
        allowed: const {'identifierType', 'value'},
        document: document,
        field: field,
      );
      result.add(
        _construct(
          () => SourceIdentifier(
            identifierType: _enumValue(
              SourceIdentifierType.values,
              _string(
                object['identifierType'],
                document,
                '$field.identifierType',
              ),
              document,
              '$field.identifierType',
            ),
            value: _string(object['value'], document, '$field.value'),
          ),
          document,
          field,
        ),
      );
    }
    return result;
  }

  static AccessInfo _access(Object? value, String document) {
    final object = _object(value, document, 'access');
    _shape(
      object,
      required: const {'accessMode'},
      allowed: const {'accessMode', 'accessedAtUtc', 'repository'},
      document: document,
      field: 'access',
    );
    return _construct(
      () => AccessInfo(
        accessMode: _string(
          object['accessMode'],
          document,
          'access.accessMode',
        ),
        accessedAtUtc: _optionalString(
          object,
          'accessedAtUtc',
          document,
          'access',
        ),
        repository: _optionalString(object, 'repository', document, 'access'),
      ),
      document,
      'access',
    );
  }

  static RightsInfo _rights(Object? value, String document) {
    final object = _object(value, document, 'rights');
    _shape(
      object,
      required: const {'rightsStatus'},
      allowed: const {'rightsStatus', 'licenseId', 'permissionRef'},
      document: document,
      field: 'rights',
    );
    return _construct(
      () => RightsInfo(
        rightsStatus: _enumValue(
          RightsStatus.values,
          _string(object['rightsStatus'], document, 'rights.rightsStatus'),
          document,
          'rights.rightsStatus',
        ),
        licenseId: _optionalString(object, 'licenseId', document, 'rights'),
        permissionRef: _optionalString(
          object,
          'permissionRef',
          document,
          'rights',
        ),
      ),
      document,
      'rights',
    );
  }

  static CulturalCoverage _coverage(Object? value, String document) {
    final object = _object(value, document, 'culturalCoverage');
    _shape(
      object,
      required: const {'contextIds', 'basis'},
      allowed: const {'contextIds', 'basis', 'note'},
      document: document,
      field: 'culturalCoverage',
    );
    return _construct(
      () => CulturalCoverage(
        contextIds: _stringList(
          object['contextIds'],
          document,
          'culturalCoverage.contextIds',
        ),
        basis: _enumValue(
          CulturalCoverageBasis.values,
          _string(object['basis'], document, 'culturalCoverage.basis'),
          document,
          'culturalCoverage.basis',
        ),
        note: _optionalString(object, 'note', document, 'culturalCoverage'),
      ),
      document,
      'culturalCoverage',
    );
  }

  static IntegrityInfo _integrity(Object? value, String document) {
    final object = _object(value, document, 'integrity');
    _shape(
      object,
      required: const {'manifestationType'},
      allowed: const {
        'manifestationType',
        'capturedAtUtc',
        'contentChecksum',
        'archivedIdentifier',
      },
      document: document,
      field: 'integrity',
    );
    return _construct(
      () => IntegrityInfo(
        manifestationType: _enumValue(
          SourceManifestationType.values,
          _string(
            object['manifestationType'],
            document,
            'integrity.manifestationType',
          ),
          document,
          'integrity.manifestationType',
        ),
        capturedAtUtc: _optionalString(
          object,
          'capturedAtUtc',
          document,
          'integrity',
        ),
        contentChecksum: _optionalString(
          object,
          'contentChecksum',
          document,
          'integrity',
        ),
        archivedIdentifier: _optionalString(
          object,
          'archivedIdentifier',
          document,
          'integrity',
        ),
      ),
      document,
      'integrity',
    );
  }

  static QualityDimensions _quality(Object? value, String document) {
    final object = _object(value, document, 'qualityDimensions');
    const fields = {
      'provenance',
      'attribution',
      'editorialControl',
      'methodTransparency',
      'sourceStability',
      'culturalProximity',
    };
    _shape(
      object,
      required: fields,
      allowed: fields,
      document: document,
      field: 'qualityDimensions',
    );
    return QualityDimensions(
      provenance: _enumValue(
        ProvenanceQuality.values,
        _string(object['provenance'], document, 'qualityDimensions.provenance'),
        document,
        'qualityDimensions.provenance',
      ),
      attribution: _enumValue(
        AttributionQuality.values,
        _string(
          object['attribution'],
          document,
          'qualityDimensions.attribution',
        ),
        document,
        'qualityDimensions.attribution',
      ),
      editorialControl: _enumValue(
        EditorialControlQuality.values,
        _string(
          object['editorialControl'],
          document,
          'qualityDimensions.editorialControl',
        ),
        document,
        'qualityDimensions.editorialControl',
      ),
      methodTransparency: _enumValue(
        MethodTransparencyQuality.values,
        _string(
          object['methodTransparency'],
          document,
          'qualityDimensions.methodTransparency',
        ),
        document,
        'qualityDimensions.methodTransparency',
      ),
      sourceStability: _enumValue(
        SourceStabilityQuality.values,
        _string(
          object['sourceStability'],
          document,
          'qualityDimensions.sourceStability',
        ),
        document,
        'qualityDimensions.sourceStability',
      ),
      culturalProximity: _enumValue(
        CulturalProximityQuality.values,
        _string(
          object['culturalProximity'],
          document,
          'qualityDimensions.culturalProximity',
        ),
        document,
        'qualityDimensions.culturalProximity',
      ),
    );
  }

  static Map<String, Object?> _exactObject(
    Object? value,
    String document,
    String field,
    String idField,
  ) {
    final object = _object(value, document, field);
    _shape(
      object,
      required: {idField, 'checksum'},
      allowed: {idField, 'checksum'},
      document: document,
      field: field,
    );
    return object;
  }

  static Map<String, Object?> _object(
    Object? value,
    String document,
    String field,
  ) {
    if (value is! Map<Object?, Object?>) throw _schema(document, field);
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key is! String) throw _schema(document, field);
      result[entry.key! as String] = entry.value;
    }
    return result;
  }

  static List<Object?> _list(Object? value, String document, String field) {
    if (value is! List<Object?>) throw _schema(document, field);
    return value;
  }

  static List<String> _stringList(
    Object? value,
    String document,
    String field,
  ) => [
    for (final item in _list(value, document, field))
      _string(item, document, field),
  ];

  static String _string(Object? value, String document, String field) {
    if (value is! String) throw _schema(document, field);
    return value;
  }

  static int _integer(Object? value, String document, String field) {
    if (value is! int) throw _schema(document, field);
    return value;
  }

  static String? _optionalString(
    Map<String, Object?> object,
    String key,
    String document,
    String field,
  ) => object.containsKey(key)
      ? _string(object[key], document, '$field.$key')
      : null;

  static T _enumValue<T extends Enum>(
    Iterable<T> values,
    String value,
    String document,
    String field,
  ) {
    for (final item in values) {
      if (item.name == value) return item;
    }
    throw _schema(document, field);
  }

  static _RecordType _recordType(String value, String document) {
    for (final type in _RecordType.values) {
      if (type.wireName == value) return type;
    }
    throw _failure(
      SourceCatalogFailure.unsupportedRecordType,
      document,
      'recordType',
    );
  }

  static void _version(Map<String, Object?> object, String document) {
    if (_string(object['schemaVersion'], document, 'schemaVersion') != '1.0') {
      throw _failure(
        SourceCatalogFailure.unsupportedSchemaVersion,
        document,
        'schemaVersion',
      );
    }
  }

  static void _shape(
    Map<String, Object?> object, {
    required Set<String> required,
    required Set<String> allowed,
    required String document,
    required String field,
  }) {
    if (!object.keys.toSet().containsAll(required) ||
        object.keys.any((key) => !allowed.contains(key))) {
      throw _schema(document, field);
    }
  }

  static void _strictOrder<T>(
    List<T> values,
    int Function(T, T) compare,
    String document,
    String field,
  ) {
    for (var index = 1; index < values.length; index++) {
      final order = compare(values[index - 1], values[index]);
      if (order == 0) {
        throw _failure(
          SourceCatalogFailure.duplicateIdentity,
          document,
          '$field[$index]',
        );
      }
      if (order > 0) {
        throw _failure(
          SourceCatalogFailure.nonCanonicalOrder,
          document,
          '$field[$index]',
        );
      }
    }
  }

  static void _strictStrings(
    List<String> values,
    String document,
    String field,
  ) => _strictOrder(values, (a, b) => a.compareTo(b), document, field);

  static int _compareSourceRefs(
    SourceRecordReleaseRef first,
    SourceRecordReleaseRef second,
  ) {
    final id = first.sourceId.compareTo(second.sourceId);
    return id != 0 ? id : first.revision.compareTo(second.revision);
  }

  static int _compareAssessmentRefs(
    SourceUseAssessmentReleaseRef first,
    SourceUseAssessmentReleaseRef second,
  ) {
    final id = first.useAssessmentId.compareTo(second.useAssessmentId);
    return id != 0 ? id : first.revision.compareTo(second.revision);
  }

  static int _compareCreators(SourceAgent first, SourceAgent second) {
    final role = first.role.compareTo(second.role);
    if (role != 0) return role;
    final type = first.agentType.name.compareTo(second.agentType.name);
    if (type != 0) return type;
    return first.displayName.compareTo(second.displayName);
  }

  static int _compareIdentifiers(
    SourceIdentifier first,
    SourceIdentifier second,
  ) {
    final type = first.identifierType.name.compareTo(
      second.identifierType.name,
    );
    return type != 0 ? type : first.value.compareTo(second.value);
  }

  static T _construct<T>(
    T Function() construct,
    String document,
    String field,
  ) {
    try {
      return construct();
    } on ArgumentError {
      throw _schema(document, field);
    }
  }

  static Never _schema(String document, String field) =>
      throw _failure(SourceCatalogFailure.schemaViolation, document, field);

  static SourceCatalogException _failure(
    SourceCatalogFailure failure,
    String document,
    String field,
  ) => SourceCatalogException(failure, document: document, field: field);
}

final class _Document {
  const _Document(this.name, this.object, this.checksum);
  final String name;
  final Map<String, Object?> object;
  final String checksum;
}

final class _RawRecord {
  const _RawRecord({
    required this.document,
    required this.type,
    required this.id,
    required this.idField,
    required this.revision,
  });

  final _Document document;
  final _RecordType type;
  final String id;
  final String idField;
  final int revision;
}
