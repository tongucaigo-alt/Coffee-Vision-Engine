import 'package:coffee_source/coffee_source.dart';
import 'package:test/test.dart';

const _checksum =
    'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

void main() {
  group('SourceRecord', () {
    test('constructs a minimal anonymous draft manifestation', () {
      final record = _record();

      expect(record.schemaVersion, '1.0');
      expect(SourceRecord.recordType, 'atlas.sourceRecord');
      expect(record.sourceId, 'test-source-001');
      expect(record.revision, 1);
      expect(record.sourceRef, isA<SourceRef>());
      expect(record.creators, isEmpty);
      expect(record.publication, PublicationInfo());
      expect(record.rights.rightsStatus, RightsStatus.unknown);
      expect(
        record.integrity.manifestationType,
        SourceManifestationType.uncapturedMutable,
      );
    });

    test('constructs a complete fixed manifestation', () {
      final record = _record(
        sourceClass: SourceClass.monographOrBook,
        creators: [
          SourceAgent(
            agentType: SourceAgentType.person,
            displayName: 'Test Author',
            role: 'author',
          ),
        ],
        publication: PublicationInfo(
          publicationDate: '2026-08-20',
          publisher: 'Test Publisher',
          edition: 'First edition',
          pages: '10-20',
        ),
        languages: LanguageInfo(
          consultedLanguage: 'tr',
          originalLanguage: 'en',
        ),
        identifiers: [
          SourceIdentifier(
            identifierType: SourceIdentifierType.isbn,
            value: '978-0-00-000000-0',
          ),
        ],
        access: AccessInfo(accessMode: 'physical'),
        rights: RightsInfo(rightsStatus: RightsStatus.citationOnly),
        culturalCoverage: CulturalCoverage(
          contextIds: const ['test-context-tr'],
          basis: CulturalCoverageBasis.sourceDeclared,
          note: 'Test-only context note',
        ),
        integrity: IntegrityInfo(
          manifestationType: SourceManifestationType.fixedEdition,
          contentChecksum: _checksum,
          archivedIdentifier: 'test-copy-001',
        ),
      );

      expect(record.sourceClass, SourceClass.monographOrBook);
      expect(record.creators.single.displayName, 'Test Author');
      expect(record.languages.originalLanguage, 'en');
      expect(
        record.identifiers.single.identifierType,
        SourceIdentifierType.isbn,
      );
      expect(record.integrity.contentChecksum, _checksum);
    });

    test('preserves exact case-sensitive source identities', () {
      final lower = _record(sourceId: 'test-source');
      final upper = _record(sourceId: 'Test-source');

      expect(lower.sourceId, 'test-source');
      expect(upper.sourceId, 'Test-source');
      expect(lower, isNot(upper));
    });

    test('rejects unsupported schema, invalid ID, and revision', () {
      expect(() => _record(schemaVersion: '1.1'), throwsArgumentError);
      expect(() => _record(sourceId: ' test-source'), throwsArgumentError);
      expect(() => _record(revision: 0), throwsArgumentError);
    });

    test(
      'rejects empty, surrounding-whitespace, control, and decomposed text',
      () {
        expect(() => _record(title: ''), throwsArgumentError);
        expect(() => _record(title: ' Test'), throwsArgumentError);
        expect(() => _record(title: 'Test\nTitle'), throwsArgumentError);
        expect(() => _record(title: 'Ag\u0306ac'), throwsArgumentError);
        expect(
          () => SourceAgent(
            agentType: SourceAgentType.person,
            displayName: '',
            role: 'author',
          ),
          throwsArgumentError,
        );
      },
    );

    test('validates BCP-47 language values', () {
      expect(
        LanguageInfo(consultedLanguage: 'tr', originalLanguage: 'en-US'),
        isA<LanguageInfo>(),
      );
      expect(
        () => LanguageInfo(consultedLanguage: 'tr_TR'),
        throwsArgumentError,
      );
    });

    test('validates exact UTC timestamps and checksum values', () {
      expect(
        AccessInfo(accessMode: 'online', accessedAtUtc: '2026-08-20T12:30:45Z'),
        isA<AccessInfo>(),
      );
      expect(
        () => AccessInfo(
          accessMode: 'online',
          accessedAtUtc: '2026-02-30T12:30:45Z',
        ),
        throwsArgumentError,
      );
      expect(
        () => IntegrityInfo(
          manifestationType: SourceManifestationType.fixedEdition,
          contentChecksum: 'sha256:ABC',
        ),
        throwsArgumentError,
      );
    });

    test('requires exact capture evidence for captured mutable content', () {
      expect(
        () => IntegrityInfo(
          manifestationType: SourceManifestationType.capturedMutable,
        ),
        throwsArgumentError,
      );
      expect(
        IntegrityInfo(
          manifestationType: SourceManifestationType.capturedMutable,
          capturedAtUtc: '2026-08-20T12:00:00Z',
          contentChecksum: _checksum,
        ),
        isA<IntegrityInfo>(),
      );
      expect(
        IntegrityInfo(
          manifestationType: SourceManifestationType.uncapturedMutable,
        ),
        isA<IntegrityInfo>(),
      );
    });

    test('requires at least one recoverable identifier', () {
      expect(() => _record(identifiers: const []), throwsArgumentError);
    });

    test('rejects duplicate exact identifiers', () {
      final identifier = SourceIdentifier(
        identifierType: SourceIdentifierType.url,
        value: 'https://example.invalid/test',
      );

      expect(
        () => _record(identifiers: [identifier, identifier]),
        throwsArgumentError,
      );
    });

    test('rejects duplicate exact context IDs', () {
      expect(
        () => CulturalCoverage(
          contextIds: const ['test-context', 'test-context'],
          basis: CulturalCoverageBasis.unknown,
        ),
        throwsArgumentError,
      );
    });

    test('requires rights references for licensed and permitted content', () {
      expect(
        () => RightsInfo(rightsStatus: RightsStatus.licensed),
        throwsArgumentError,
      );
      expect(
        () => RightsInfo(rightsStatus: RightsStatus.permissionGranted),
        throwsArgumentError,
      );
      expect(
        RightsInfo(
          rightsStatus: RightsStatus.licensed,
          licenseId: 'test-license',
        ),
        isA<RightsInfo>(),
      );
      expect(
        RightsInfo(
          rightsStatus: RightsStatus.permissionGranted,
          permissionRef: 'test-permission',
        ),
        isA<RightsInfo>(),
      );
    });

    test('requires access timestamp for online mutable content', () {
      expect(
        () => _record(access: AccessInfo(accessMode: 'online')),
        throwsArgumentError,
      );
      expect(
        _record(
          access: AccessInfo(
            accessMode: 'online',
            accessedAtUtc: '2026-08-20T12:00:00Z',
          ),
        ),
        isA<SourceRecord>(),
      );
      expect(
        _record(
          access: AccessInfo(accessMode: 'physical'),
          integrity: IntegrityInfo(
            manifestationType: SourceManifestationType.uncapturedMutable,
          ),
        ),
        isA<SourceRecord>(),
      );
    });

    test('canonicalizes collections without mutating caller inputs', () {
      final firstCreator = SourceAgent(
        agentType: SourceAgentType.person,
        displayName: 'Second Name',
        role: 'editor',
      );
      final secondCreator = SourceAgent(
        agentType: SourceAgentType.organization,
        displayName: 'First Name',
        role: 'author',
      );
      final firstIdentifier = SourceIdentifier(
        identifierType: SourceIdentifierType.url,
        value: 'https://example.invalid/test',
      );
      final secondIdentifier = SourceIdentifier(
        identifierType: SourceIdentifierType.doi,
        value: '10.0000/test',
      );
      final creators = [firstCreator, secondCreator];
      final identifiers = [firstIdentifier, secondIdentifier];
      final contexts = ['test-context-z', 'test-context-a'];

      final record = _record(
        creators: creators,
        identifiers: identifiers,
        culturalCoverage: CulturalCoverage(
          contextIds: contexts,
          basis: CulturalCoverageBasis.unknown,
        ),
      );

      expect(creators, [firstCreator, secondCreator]);
      expect(identifiers, [firstIdentifier, secondIdentifier]);
      expect(contexts, ['test-context-z', 'test-context-a']);
      expect(record.creators, [secondCreator, firstCreator]);
      expect(record.identifiers, [secondIdentifier, firstIdentifier]);
      expect(record.culturalCoverage.contextIds, [
        'test-context-a',
        'test-context-z',
      ]);
    });

    test('returns runtime-unmodifiable collections', () {
      final record = _record(
        creators: [
          SourceAgent(
            agentType: SourceAgentType.person,
            displayName: 'Test Author',
            role: 'author',
          ),
        ],
        culturalCoverage: CulturalCoverage(
          contextIds: const ['test-context'],
          basis: CulturalCoverageBasis.unknown,
        ),
      );

      expect(() => record.creators.clear(), throwsUnsupportedError);
      expect(() => record.identifiers.clear(), throwsUnsupportedError);
      expect(
        () => record.culturalCoverage.contextIds.clear(),
        throwsUnsupportedError,
      );
    });

    test('has deterministic equality and hashes across input permutations', () {
      final creatorA = SourceAgent(
        agentType: SourceAgentType.person,
        displayName: 'Author A',
        role: 'author',
      );
      final creatorB = SourceAgent(
        agentType: SourceAgentType.person,
        displayName: 'Author B',
        role: 'author',
      );
      final identifierA = SourceIdentifier(
        identifierType: SourceIdentifierType.doi,
        value: '10.0000/a',
      );
      final identifierB = SourceIdentifier(
        identifierType: SourceIdentifierType.url,
        value: 'https://example.invalid/b',
      );

      final first = _record(
        creators: [creatorB, creatorA],
        identifiers: [identifierB, identifierA],
      );
      final second = _record(
        creators: [creatorA, creatorB],
        identifiers: [identifierA, identifierB],
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });

    test('exposes every frozen controlled vocabulary value', () {
      expect(SourceClass.values.map((value) => value.name), [
        'journalOrConferencePublication',
        'monographOrBook',
        'thesisOrDissertation',
        'institutionalPublication',
        'archivalMaterial',
        'referenceWork',
        'interview',
        'oralHistoryOrFieldRecord',
        'webPublication',
        'communityGeneratedContent',
      ]);
      expect(SourceAgentType.values, hasLength(2));
      expect(SourceIdentifierType.values, hasLength(7));
      expect(RightsStatus.values, hasLength(6));
      expect(CulturalCoverageBasis.values, hasLength(3));
      expect(SourceManifestationType.values, hasLength(5));
    });

    test(
      'toString omits titles, names, identifiers, and repository details',
      () {
        final record = _record(
          title: 'Sensitive Test Title',
          creators: [
            SourceAgent(
              agentType: SourceAgentType.person,
              displayName: 'Sensitive Test Name',
              role: 'author',
            ),
          ],
          identifiers: [
            SourceIdentifier(
              identifierType: SourceIdentifierType.url,
              value: 'https://example.invalid/sensitive',
            ),
          ],
          access: AccessInfo(
            accessMode: 'online',
            accessedAtUtc: '2026-08-20T12:00:00Z',
            repository: 'Sensitive Test Repository',
          ),
        );

        final text = record.toString();
        expect(text, contains('test-source-001'));
        expect(text, isNot(contains('Sensitive Test Title')));
        expect(text, isNot(contains('Sensitive Test Name')));
        expect(text, isNot(contains('example.invalid')));
        expect(text, isNot(contains('Sensitive Test Repository')));
      },
    );
  });
}

SourceRecord _record({
  String schemaVersion = '1.0',
  String sourceId = 'test-source-001',
  int revision = 1,
  SourceClass sourceClass = SourceClass.webPublication,
  String title = 'Synthetic Test Source',
  Iterable<SourceAgent> creators = const [],
  PublicationInfo? publication,
  LanguageInfo? languages,
  Iterable<SourceIdentifier>? identifiers,
  AccessInfo? access,
  RightsInfo? rights,
  CulturalCoverage? culturalCoverage,
  IntegrityInfo? integrity,
}) {
  return SourceRecord(
    schemaVersion: schemaVersion,
    sourceId: sourceId,
    revision: revision,
    canonicalJsonProfileRef: CanonicalJsonProfileRef(
      profileId: 'atlas-canonical-json',
      revision: 1,
      checksum: _checksum,
    ),
    sourceClass: sourceClass,
    title: title,
    creators: creators,
    publication: publication ?? PublicationInfo(),
    languages: languages ?? LanguageInfo(consultedLanguage: 'en'),
    identifiers:
        identifiers ??
        [
          SourceIdentifier(
            identifierType: SourceIdentifierType.url,
            value: 'https://example.invalid/test',
          ),
        ],
    access:
        access ??
        AccessInfo(accessMode: 'online', accessedAtUtc: '2026-08-20T12:00:00Z'),
    rights: rights ?? RightsInfo(rightsStatus: RightsStatus.unknown),
    culturalCoverage:
        culturalCoverage ??
        CulturalCoverage(
          contextIds: const [],
          basis: CulturalCoverageBasis.unknown,
        ),
    integrity:
        integrity ??
        IntegrityInfo(
          manifestationType: SourceManifestationType.uncapturedMutable,
        ),
  );
}
