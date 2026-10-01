import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/ai/ai_contract.dart';
import 'package:atlas_contribution_app/src/ai/ai_bridge.dart';
import 'package:atlas_contribution_app/src/ai/ai_store.dart';
import 'package:atlas_contribution_app/src/local_store.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'package:atlas_contribution_app/src/mvp/review_preparation.dart';
import 'package:atlas_contribution_app/src/mvp/review_store.dart';

Map<String, dynamic> contextData() => {
  'version': 'atlas-fortune-context-v1',
  'language': 'tr',
  'status': 'ready',
  'photos': [
    for (var i = 0; i < 3; i++)
      {
        'photoNumber': i + 1,
        'surface': 'cup',
        'declaredRole': freeCaptureRoles[i].name,
        'analysisState': 'complete',
        'userObservations': [],
        'physicalMeasurementsStatus': 'available',
        'physicalMeasurementScope': 'wholeImageContentNotUserRegion',
        'globalPhysicalMeasurements': {
          'residuePixelCount': 30,
          'contentResidueRatio': .2,
          'componentCount': 3,
          'candidateRelationCount': 1,
          'selectedRelationCount': 0,
        },
      },
  ],
};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'cold start marks unfinished jobs without losing successful answers',
    () async {
      final temp = await Directory.systemTemp.createTemp('atlas-ai-recovery-');
      addTearDown(() => temp.delete(recursive: true));
      final store = AiStore(temp);
      await store.saveResult({
        'id': 'pending',
        'sessionId': 's',
        'state': 'running',
        'answers': [
          {
            'text': 'saved answer',
            'promptVersion': 'atlas-fortune-prompt-v1',
            'promptHash': 'prior-prompt-hash',
          },
        ],
      });
      final reopened = AiStore(temp);
      await reopened.recoverInterruptedResults();
      final result = (await reopened.results('s')).single;
      expect(result['state'], 'interrupted');
      expect(result['answers'], [
        {
          'text': 'saved answer',
          'promptVersion': 'atlas-fortune-prompt-v1',
          'promptHash': 'prior-prompt-hash',
        },
      ]);
      expect(await reopened.exposures('s'), isEmpty);
    },
  );
  test(
    'shared language cases distinguish reporting from visual evidence',
    () async {
      final fixtures =
          jsonDecode(
                await File(
                  '../atlas_ai_gateway/test/fixtures/fortune-quality-cases.json',
                ).readAsString(),
              )
              as Map;
      final padding = List.filled(
        fixtures['paddingRepeat'] as int,
        fixtures['paddingSentence'] as String,
      ).join();
      for (final c in fixtures['cases'] as List) {
        final context = contextData();
        context['photos'][0]['userObservations'] = [
          for (final name in c['symbols'] as List)
            {
              'origin': 'userObservation',
              'symbolName': name,
              'box': {'x': 0.1, 'y': 0.1, 'width': 0.2, 'height': 0.2},
            },
        ];
        expect(
          fortuneQualityError(
            '$padding${c['text']}',
            'stop',
            context: validateAiContext(context),
          ),
          c['error'],
          reason: c['id'] as String,
        );
      }
    },
  );
  test(
    'URL policy blocks public HTTP, phone localhost, credentials and redirects by design',
    () {
      expect(validateAiUrl('https://test.example/v1').host, 'test.example');
      expect(
        validateAiUrl('http://192.168.1.20:1234/v1', allowLan: true).port,
        1234,
      );
      for (final url in [
        'http://localhost:1234/v1',
        'http://127.0.0.1:1234/v1',
        'http://8.8.8.8/v1',
        'https://secret@example.com',
        'https://example.com?key=secret',
        'file:///secret',
      ]) {
        expect(() => validateAiUrl(url, allowLan: true), throwsFormatException);
      }
      expect(
        () => validateAiUrl('http://192.168.1.20/v1', allowLan: false),
        throwsFormatException,
      );
    },
  );
  test('outbound payload rejects private fields and invalid physical values', () {
    expect(validateAiContext(contextData())['photos'], hasLength(3));
    for (final mutate in <void Function(Map<String, dynamic>)>[
      (c) => c['sessionId'] = 'private',
      (c) => c['photos'][0]['filePath'] = 'secret.jpg',
      (c) => c['status'] = 'analysisPending',
      (c) =>
          c['photos'][0]['globalPhysicalMeasurements']['contentResidueRatio'] =
              2,
      (c) =>
          c['photos'][0]['globalPhysicalMeasurements']['selectedRelationCount'] =
              3,
    ]) {
      final c = contextData();
      mutate(c);
      expect(() => validateAiContext(c), throwsFormatException);
    }
  });
  test(
    'profile keys bind to exact server and quality rejects reasoning/certainty',
    () {
      const a = AiProfile(
        id: 'a',
        name: 'a',
        url: 'https://a.example',
        model: 'qwen',
        provider: AiProvider.atlas,
      );
      const b = AiProfile(
        id: 'a',
        name: 'a',
        url: 'https://b.example',
        model: 'qwen',
        provider: AiProvider.atlas,
      );
      expect(a.credentialKey, isNot(b.credentialKey));
      final good = List.filled(
        25,
        'Belki bu dağılım sana sakinlik için bir alan çağrıştırıyor.',
      ).join(' ');
      expect(fortuneQualityError(good, 'stop'), isNull);
      expect(fortuneQualityError(good, 'length'), isNotNull);
      expect(fortuneQualityError('<think>$good', 'stop'), isNotNull);
      expect(
        fortuneQualityError('$good Karşına çıkacak.', 'stop'),
        'certainty',
      );
      expect(
        fortuneQualityError('$good Kesinlikle kazanacaksın.', 'stop'),
        isNotNull,
      );
    },
  );
  test(
    'prompt is shared from asset; no private envelope reaches messages',
    () async {
      final prompt = FortunePrompt(
        await File('assets/fortune-prompt-v1.json').readAsString(),
      );
      final messages = prompt.messages(
        validateAiContext(contextData()),
        noThink: true,
      );
      expect(messages.last['content'], endsWith('/no_think'));
      expect(jsonEncode(messages), isNot(contains('sessionId')));
      expect(prompt.version, 'atlas-fortune-prompt-v6');
      expect(
        prompt.hash,
        sha256
            .convert(await File('assets/fortune-prompt-v1.json').readAsBytes())
            .toString(),
      );
      expect(
        messages.first['content'],
        contains('You have not seen any photo.'),
      );
      expect(messages.last['content'], isNot(contains('bunu açıkça söyle')));
      for (final reason in [
        'unsupported_absence_claim',
        'unsupported_symbol_claim',
      ]) {
        expect(
          prompt
              .messages(
                contextData(),
                noThink: false,
                repair: true,
                repairReason: reason,
              )
              .last['content'],
          contains(prompt.data['repairHints'][reason] as String),
        );
      }
    },
  );
  test(
    'bridge keeps byte identity, first observations, revisions, exposure and linked deletion',
    () async {
      final temp = await Directory.systemTemp.createTemp('atlas-ai-test-');
      addTearDown(() => temp.delete(recursive: true));
      final source = DraftStore(Directory('${temp.path}/source'));
      await source.initialize();
      final reviews = ReviewStore(Directory('${temp.path}/reviews'));
      await reviews.initialize();
      final ai = AiStore(Directory('${temp.path}/ai'));
      final bridge = AiBridge(source, reviews, ai);
      reviews.additionalExposures = ai.exposures;
      reviews.onDelete = ai.deleteSession;
      source.onDeleteRoot = bridge.deleteRoot;
      final photos = <ContributionPhoto>[];
      for (var i = 0; i < 3; i++) {
        final bytes = [1, 2, 3, i];
        await source.file('photo$i.jpg').writeAsBytes(bytes);
        photos.add(
          ContributionPhoto(
            role: freeCaptureRoles[i],
            localName: 'photo$i.jpg',
            checksum: 'sha256:${sha256.convert(bytes)}',
            originalChecksum: 'sha256:${sha256.convert(bytes)}',
            width: 100,
            height: 100,
            byteLength: bytes.length,
            capturedAt: '2026-09-17T10:00:00Z',
            decision: PhotoDecision.skipped,
          ),
        );
      }
      final draft = ContributionDraft(
        id: 'receipt1',
        rootId: 'root',
        groupId: 'group',
        createdAt: '2026-09-17T10:00:00Z',
        consentedAt: '2026-09-17T10:00:00Z',
        kind: ContributionKind.freeThreeAngle,
        photos: photos,
      );
      Map<String, dynamic> receipt(ContributionDraft d) => {
        'id': d.id,
        'root_id': d.rootId,
        'group_id': d.groupId,
        'expires_at': DateTime.now()
            .add(const Duration(days: 180))
            .toUtc()
            .toIso8601String(),
        'local_only': true,
        'document': d.toJson(),
      };
      final row = receipt(draft);
      await source.saveReceipt(row);
      var session = await bridge.importReceipt(row, fresh: true);
      expect(session.ready, isFalse);
      expect(session.observationHistory, 'known');
      expect((await bridge.importReceipt(row)).revision, session.revision);
      expect(await reviews.readPhoto(session.photos.first), [1, 2, 3, 0]);
      session = session.next(
        sameSample: true,
        photos: session.photos.map(
          (p) => p.update(confirmedAt: '2026-09-17T10:01:00Z'),
        ),
      );
      await reviews.save(session);
      session = captureInitialObservations(
        session,
        capturedAtUtc: '2026-09-17T10:02:00Z',
      );
      await reviews.save(session);
      final first = jsonEncode(session.initialObservations);
      final marked = photos.first.annotated([
        RegionAnnotation(
          id: 'region',
          box: RegionBox(.1, .1, .15, .15),
          label: 'bird',
        ),
      ], PhotoDecision.marked);
      final edit = ContributionDraft(
        id: 'receipt2',
        rootId: draft.rootId,
        groupId: draft.groupId,
        createdAt: draft.createdAt,
        consentedAt: draft.consentedAt,
        kind: draft.kind,
        revision: 2,
        supersedesId: draft.id,
        photos: [marked, ...photos.skip(1)],
      );
      await source.saveReceipt(receipt(edit));
      final updated = await bridge.importReceipt(row);
      expect(updated.photos.first.photo.regions.single.label, 'bird');
      expect(jsonEncode(updated.initialObservations), first);
      expect(await bridge.isCurrent(session), isFalse);
      final result = {
        'id': 'answer',
        'sessionId': session.id,
        'groupId': session.groupId,
        'answers': [
          {'text': 'private fortune'},
        ],
      };
      await ai.saveResult(result);
      await ai.expose(result);
      expect(
        await reviews.knownGroupExposures(updated),
        contains(containsPair('kind', 'aiNarrative')),
      );
      expect(await AiStore(ai.directory).results(session.id), hasLength(1));
      final expiringDraft = ContributionDraft.fromJson({
        ...draft.toJson(),
        'id': 'expiring-receipt',
        'rootId': 'expiring-root',
      });
      final expiringRow = receipt(expiringDraft);
      await source.saveReceipt(expiringRow);
      final expiring = await bridge.importReceipt(expiringRow);
      await ai.saveResult({
        ...result,
        'id': 'expiring-answer',
        'sessionId': expiring.id,
      });
      await source.saveReceipt({
        ...expiringRow,
        'expires_at': '2000-01-01T00:00:00Z',
      });
      await bridge.reconcile();
      expect(await ai.results(expiring.id), hasLength(1));
      expect(
        await reviews.file(expiring.photos.first.photo.localName).exists(),
        isTrue,
      );
      await source.queueDelete(draft.rootId);
      await source.acknowledgeDelete(draft.rootId);
      expect(await ai.results(session.id), isEmpty);
      expect((await reviews.sessions()).singleWhere((s) => s.id == session.id).deleted, isTrue);
      expect((await reviews.sessions()).singleWhere((s) => s.id == expiring.id).deleted, isFalse);
      expect(
        await reviews.file(session.photos.first.photo.localName).exists(),
        isFalse,
      );
      expect(() => ai.saveResult(result), throwsA(isA<AiFailure>()));
      expect(await bridge.isCurrent(session), isFalse);
    },
  );
}
