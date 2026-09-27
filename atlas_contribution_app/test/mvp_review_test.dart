import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:atlas_contribution_app/src/gallery_import.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'package:atlas_contribution_app/src/research_export.dart';
import 'package:atlas_contribution_app/src/mvp/review_controller.dart';
import 'package:atlas_contribution_app/src/mvp/review_engine.dart';
import 'package:atlas_contribution_app/src/mvp/review_gallery.dart';
import 'package:atlas_contribution_app/src/mvp/review_models.dart';
import 'package:atlas_contribution_app/src/mvp/review_preparation.dart';
import 'package:atlas_contribution_app/src/mvp/review_store.dart';
import 'package:crypto/crypto.dart';
import 'package:coffee_knowledge/coffee_knowledge.dart';
import 'package:coffee_knowledge_dataset/coffee_knowledge_dataset.dart';
import 'package:coffee_pattern/coffee_pattern.dart';
import 'package:coffee_symbol/coffee_symbol.dart';
import 'package:coffee_vision/coffee_vision.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:archive/archive.dart';

import 'fixtures.dart';

const timestamp = '2026-09-14T00:00:00Z';
ReviewSession review({
  List<ReviewPhoto> photos = const [],
  bool consent = false,
}) => ReviewSession(
  id: 'test-review',
  groupId: 'test-group',
  createdAtUtc: timestamp,
  localConsentAtUtc: timestamp,
  sameSampleDeclared: true,
  researchConsentAtUtc: consent ? timestamp : null,
  photos: photos,
);

VisionFeatureSet features(VisionImageInput input) => VisionFeatureSet(
  surfaceType: input.surfaceType,
  sourceId: input.sourceId,
  imageProvenance: VisionFeatureImageProvenance(
    sourceFormat: VisionImageFormat.jpeg,
    sourceWidth: 160,
    sourceHeight: 200,
    workingFormat: VisionImageFormat.png,
    workingWidth: 512,
    workingHeight: 512,
    workingResolution: 512,
    contentRect: VisionRect(left: .1, top: 0, right: .9, bottom: 1),
  ),
);

PatternCandidate candidate(int id) => PatternCandidate.withGeometryAndTopology(
  id: id,
  evidence: [PatternEvidence.connectedStructure(id)],
  geometry: PatternGeometry(
    left: .2,
    top: .1,
    right: .8,
    bottom: .9,
    centroidX: .5,
    centroidY: .5,
  ),
  topology: PatternTopology(nodeCount: 1, directedEdgeCount: 0),
);

ReviewEngine fakeEngine({
  int candidates = 1,
  ReviewFeatureAnalyzer? vision,
  ReviewResolver? resolver,
  List<String>? events,
}) => ReviewEngine(
  dataset: KnowledgeDatasetSnapshot(
    schemaVersion: '1.0',
    datasetVersion: 'test-kds',
    totalRecordCount: 1,
    activeRecords: [
      KnowledgeRecord(
        id: 'test-record',
        constraints: [
          KnowledgeConstraint.integerRange(
            key: KnowledgeConstraintKey.topologyNodeCount,
            minimum: 1,
            maximum: 1,
          ),
        ],
      ),
    ],
  ),
  release: KnowledgeDatasetReleaseRef(
    releaseId: 'test-kds',
    checksum: 'sha256:${'a' * 64}',
  ),
  analyzeFeatures:
      vision ??
      (input) async {
        events?.add('vision:${input.sourceId}:${input.surfaceType.name}');
        return features(input);
      },
  analyzePatterns: (f) async {
    events?.add('pattern');
    return PatternAnalysisResult(
      surfaceType: f.surfaceType == VisionSurfaceType.cup
          ? PatternSurfaceType.cup
          : PatternSurfaceType.saucer,
      candidates: List.generate(candidates, (i) => candidate(i + 1)),
    );
  },
  match: ({required candidate, required records}) {
    events?.add('match:${candidate.id}');
    return const KnowledgeRecordCollectionMatcher().match(
      candidate: candidate,
      records: records,
    );
  },
  resolve:
      resolver ??
      ({
        required knowledgeRelease,
        required knowledgeMatches,
        required definitions,
        required bindings,
      }) {
        events?.add('symbol:${knowledgeMatches.length}');
        expect(definitions, isEmpty);
        expect(bindings, isEmpty);
        return const SymbolCandidateResolver().resolve(
          knowledgeRelease: knowledgeRelease,
          knowledgeMatches: knowledgeMatches,
          definitions: definitions,
          bindings: bindings,
        );
      },
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late ReviewStore store;
  Future<ReviewPhoto> photo({
    CaptureRole? role,
    ReviewSurface surface = ReviewSurface.cup,
  }) async => (await store.importPhoto(
    testImage(),
    surface: surface,
    declaredRole: role,
  )).update(confirmedAt: timestamp);
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('atlas-mvp-test-');
    store = ReviewStore(temp);
  });
  tearDown(() async {
    await temp.delete(recursive: true);
  });

  test('exact shipped baseline validates, mutated bytes fail closed', () async {
    expect(
      await File('.gitattributes').readAsString(),
      contains('assets/mvp/knowledge_dataset.json -text'),
    );
    final bytes = await File('assets/mvp/knowledge_dataset.json').readAsBytes();
    expect(
      ReviewEngine.fromBaseline(bytes).release.checksum,
      mvpKnowledgeChecksum,
    );
    bytes[bytes.length - 1] ^= 1;
    expect(
      () => ReviewEngine.fromBaseline(bytes),
      throwsA(isA<ReviewEngineFailure>()),
    );
  });
  test(
    'cup roles, unknown role and optional saucer have stable order',
    () async {
      final unknown = await photo();
      final left = await photo(role: CaptureRole.handleLeft);
      final top = await photo(role: CaptureRole.top);
      final saucer = await photo(surface: ReviewSurface.saucer);
      final s = review(photos: [unknown, left, saucer, top]);
      expect(s.orderedPhotos, [top, left, unknown, saucer]);
      expect(unknown.photo.capturedAt, isNull);
      expect(unknown.declaredRole, isNull);
      expect(() => s.photos.clear(), throwsUnsupportedError);
      expect(() => s.orderedPhotos.clear(), throwsUnsupportedError);
      expect(() => review(photos: [top, top]), throwsFormatException);
      final saucer2 = await photo(surface: ReviewSurface.saucer);
      expect(() => review(photos: [saucer, saucer2]), throwsFormatException);
    },
  );
  test(
    'session needs cup, declaration and confirmation, not three photos',
    () async {
      final p = await photo();
      expect(review(photos: [p]).ready, true);
      expect(review(photos: [p]).next(sameSample: false).ready, false);
      expect(
        review(photos: [await photo(surface: ReviewSurface.saucer)]).ready,
        false,
      );
      expect(review().ready, false);
    },
  );
  test('revisions persist without rewriting older contributions', () async {
    final s = review(photos: [await photo()]);
    await store.save(s);
    final first = await store.file('review-test-review-1.json').readAsBytes();
    await store.save(s.next(researchAllowed: true));
    expect(await store.file('review-test-review-1.json').readAsBytes(), first);
    expect((await ReviewStore(temp).sessions()).single.revision, 2);
    await expectLater(store.save(s.next()), throwsStateError);
    expect(() => store.file('../old.jpg'), throwsFormatException);
  });
  test(
    'corrupt revision is not silently treated as an empty session',
    () async {
      await store.save(review());
      await store.file('review-test-review-1.json').writeAsString('{}');
      await expectLater(store.sessions(), throwsA(anything));
    },
  );
  test('technical file integrity precedes Vision', () async {
    final p = await photo();
    var called = false;
    final engine = fakeEngine(
      vision: (input) async {
        called = true;
        return features(input);
      },
    );
    await expectLater(
      engine.analyze(p, () async => Uint8List(2)),
      throwsA(isA<ReviewEngineFailure>()),
    );
    expect(called, false);
  });
  test(
    'one read, Vision, Pattern, resolver; every candidate evaluated',
    () async {
      final p = await photo();
      final events = <String>[];
      final output = await fakeEngine(candidates: 2, events: events).analyze(
        p,
        () async {
          events.add('read');
          return store.readPhoto(p);
        },
      );
      expect(events, [
        'read',
        'vision:${p.id}:cup',
        'pattern',
        'match:1',
        'match:2',
        'symbol:2',
      ]);
      expect(output.document['outcome'], 'insufficientSymbolEvidence');
      expect(output.document['symbolAvailability'], 'notConfigured');
      expect(output.matches, hasLength(2));
      expect(() => output.matches.clear(), throwsUnsupportedError);
      expect(
        () => (output.document['knowledgeMatches'] as List).clear(),
        throwsUnsupportedError,
      );
      expect(
        (output.document['knowledgeMatches'] as List)
            .first['constraintResults'],
        hasLength(1),
      );
    },
  );
  test(
    'empty Pattern still resolves symbols once and produces noMatch',
    () async {
      final p = await photo();
      final events = <String>[];
      final result = await fakeEngine(
        candidates: 0,
        events: events,
      ).analyze(p, () => store.readPhoto(p));
      expect(events.last, 'symbol:0');
      expect(result.document['outcome'], 'noMatch');
    },
  );
  test(
    'test-only positive resolution retains exact supports and definitions',
    () async {
      final p = await photo();
      SymbolCandidate? exact;
      final output = await fakeEngine(
        resolver:
            ({
              required knowledgeRelease,
              required knowledgeMatches,
              required definitions,
              required bindings,
            }) {
              final profile = CanonicalJsonProfileRef(
                profileId: 'test-profile',
                revision: 1,
                checksum: 'sha256:${'a' * 64}',
              );
              final definition = SymbolDefinition(
                symbolRef: SymbolRevisionRef(
                  symbolId: 'test-symbol',
                  revision: 1,
                  checksum: 'sha256:${'b' * 64}',
                ),
                canonicalJsonProfileRef: profile,
                preferredNames: [
                  SourcedLocalizedText(
                    language: 'en',
                    value: 'Test-only symbol',
                    sourceRefs: [
                      SourceRef(sourceId: 'test-source', revision: 1),
                    ],
                  ),
                ],
                neutralDefinitions: [
                  SourcedLocalizedText(
                    language: 'en',
                    value: 'Synthetic test-only definition.',
                    sourceRefs: [
                      SourceRef(sourceId: 'test-source', revision: 1),
                    ],
                  ),
                ],
              );
              final binding = SymbolEvidenceBinding(
                bindingId: 'test-binding',
                revision: 1,
                canonicalJsonProfileRef: profile,
                symbolRef: definition.symbolRef,
                knowledgeTargetRef: KnowledgeTargetRef(
                  knowledgeRelease: knowledgeRelease,
                  knowledgeRecordId: 'test-record',
                ),
                evidenceAssessmentRefs: [
                  EvidenceAssessmentRef(
                    assessmentId: 'test-assessment',
                    revision: 1,
                    assessmentType: EvidenceAssessmentType.holdoutValidation,
                    checksum: 'sha256:${'c' * 64}',
                  ),
                ],
              );
              exact = SymbolCandidate(
                patternCandidateId: 1,
                definition: definition,
                supports: [
                  SymbolCandidateSupport(
                    binding: binding,
                    knowledgeMatch: knowledgeMatches.single,
                  ),
                ],
              );
              return [exact!];
            },
      ).analyze(p, () => store.readPhoto(p));
      expect(identical(output.symbols.single, exact), true);
      expect(
        identical(
          output.symbols.single.supports.single.knowledgeMatch,
          output.matches.single,
        ),
        true,
      );
      expect(output.document['outcome'], 'symbolCandidatesAvailable');
      final persisted = output.document['symbols'][0];
      expect(persisted['supports'][0]['binding']['bindingId'], 'test-binding');
      expect(
        persisted['supports'][0]['knowledgeMatch']['constraintResults'],
        hasLength(1),
      );
      expect(persisted['definition']['neutralDefinitions'], hasLength(1));
      expect(persisted['symbolRef']['symbolId'], 'test-symbol');
    },
  );
  test(
    'failure contains only stage, never downstream partial results or secret',
    () async {
      final p = await photo();
      await expectLater(
        fakeEngine(
          vision: (_) async => throw StateError('/private/path'),
        ).analyze(p, () => store.readPhoto(p)),
        throwsA(
          isA<ReviewEngineFailure>()
              .having((e) => e.stage, 'stage', 'vision')
              .having((e) => e.toString(), 'safe', isNot(contains('private'))),
        ),
      );
    },
  );
  test(
    'sequential processing continues, retry preserves successful exact instances',
    () async {
      final a = await photo(role: CaptureRole.top),
          b = await photo(role: CaptureRole.handleRight),
          c = await photo(role: CaptureRole.handleLeft),
          d = await photo(surface: ReviewSurface.saucer);
      final s = review(photos: [d, c, b, a]);
      await store.save(s);
      var fail = true;
      final order = <String>[];
      final controller = ReviewController(
        store: store,
        session: s,
        loadEngine: () async => fakeEngine(
          vision: (input) async {
            order.add(input.sourceId!);
            if (input.sourceId == b.id && fail) throw StateError('test');
            return features(input);
          },
        ),
      );
      await controller.analyze();
      expect(order, [a.id, b.id, c.id, d.id]);
      expect(
        controller.session.photos.singleWhere((p) => p.id == b.id).failed,
        true,
      );
      final successful = controller.liveResults[a.id];
      final successfulPhoto = controller.session.photos.singleWhere(
        (p) => p.id == a.id,
      );
      fail = false;
      await controller.analyze(retryPhotoId: b.id);
      expect(order, [a.id, b.id, c.id, d.id, b.id]);
      expect(identical(controller.liveResults[a.id], successful), true);
      expect(
        identical(
          controller.session.photos.singleWhere((p) => p.id == a.id),
          successfulPhoto,
        ),
        true,
      );
      expect(controller.session.photos.every((p) => !p.failed), true);
      expect(() => controller.analyze(retryPhotoId: a.id), throwsStateError);
      await controller.close();
      controller.dispose();
    },
  );
  test(
    'close prevents stale publication and subsequent photo execution',
    () async {
      final p = await photo();
      final s = review(photos: [p]);
      await store.save(s);
      final blocked = Completer<VisionFeatureSet>();
      final entered = Completer<VisionImageInput>();
      final c = ReviewController(
        store: store,
        session: s,
        loadEngine: () async => fakeEngine(
          vision: (input) {
            entered.complete(input);
            return blocked.future;
          },
        ),
      );
      final running = c.analyze();
      final input = await entered.future;
      final closing = c.close();
      blocked.complete(features(input));
      await running;
      await closing;
      expect(c.session.photos.single.analysis, isNull);
      final saved = (await store.sessions()).single;
      expect(saved.revision, 2);
      expect(saved.currentInitialObservation, isNotNull);
      expect(saved.preparedInput, isNull);
      c.dispose();
    },
  );
  test('working image letterbox is reversed without assigning ROI density', () {
    final box = sourceBox(
      candidate(1).geometry,
      VisionRect(left: .1, top: 0, right: .9, bottom: 1),
    )!;
    expect(box.x, closeTo(.125, 1e-10));
    expect(box.width, closeTo(.75, 1e-10));
    expect(
      sourceBox(null, VisionRect(left: 0, top: 0, right: 1, bottom: 1)),
      isNull,
    );
  });
  test(
    'skip is durable before engine loading and survives reopening',
    () async {
      final s = review(photos: [await photo()]);
      await store.save(s);
      final controller = ReviewController(
        store: store,
        session: s,
        loadEngine: () async {
          final saved = (await store.sessions()).single;
          expect(saved.currentInitialObservation, isNotNull);
          expect(saved.photos.single.photo.decision, PhotoDecision.skipped);
          return fakeEngine();
        },
      );
      await controller.analyze();
      final reopened = (await ReviewStore(temp).sessions()).single;
      expect(reopened.currentInitialObservation, isNotNull);
      expect(reopened.preparedInput!['status'], 'empty');
      expect(reopened.photos.single.photo.regions, isEmpty);
      await controller.close();
      controller.dispose();
    },
  );
  test(
    'edits invalidate preparation and preserve the first observations',
    () async {
      final p = await photo();
      final s = review(photos: [p]);
      await store.save(s);
      final controller = ReviewController(
        store: store,
        session: s,
        loadEngine: () async => fakeEngine(),
      );
      await controller.analyze();
      final first = jsonEncode(controller.session.initialObservations);
      final analyzed = controller.session.photos.single;
      await controller.save(
        controller.session.withPhoto(
          analyzed.update(
            photo: analyzed.photo.annotated([
              RegionAnnotation(
                id: 'later-tree',
                box: RegionBox(.1, .1, .15, .15),
                label: 'tree',
              ),
            ], PhotoDecision.marked),
          ),
        ),
      );
      expect(controller.session.preparedInput, isNull);
      expect(jsonEncode(controller.session.initialObservations), first);
      await controller.analyze();
      expect(controller.session.preparedInput!['status'], 'ready');
      expect(jsonEncode(controller.session.initialObservations), first);
      final beforeConsent = controller.session.preparedInput;
      await controller.save(controller.session.next(researchAllowed: true));
      expect(controller.session.preparedInput, beforeConsent);
      await expectLater(
        store.save(controller.session.next(initialObservations: [])),
        throwsStateError,
      );
      await controller.close();
      controller.dispose();
    },
  );
  test(
    'v1 history is unknown and original revision bytes stay unchanged',
    () async {
      final s = review(photos: [await photo()]);
      final old = s.toJson()
        ..['version'] = 'atlas-local-review-v1'
        ..remove('observationHistory')
        ..remove('initialObservations')
        ..remove('preparedInput');
      final bytes = utf8.encode(
        jsonEncode({
          'document': old,
          'checksum': 'sha256:${sha256.convert(utf8.encode(jsonEncode(old)))}',
        }),
      );
      await store.file('review-${s.id}-1.json').writeAsBytes(bytes);
      final legacy = (await store.sessions()).single;
      expect(legacy.observationHistory, 'unknown');
      final captured = captureInitialObservations(
        legacy,
        capturedAtUtc: timestamp,
      );
      await store.save(captured);
      expect(
        (await store.sessions()).single.toJson()['version'],
        reviewVersion,
      );
      expect((await store.sessions()).single.observationHistory, 'unknown');
      expect(await store.file('review-${s.id}-1.json').readAsBytes(), bytes);
    },
  );
  test('setup failure preserves user input and can be retried', () async {
    final original = await photo();
    final p = original.update(
      photo: original.photo.annotated([
        RegionAnnotation(
          id: 'user-bird',
          box: RegionBox(.1, .1, .15, .15),
          label: 'bird',
        ),
      ], PhotoDecision.marked),
    );
    final s = review(photos: [p]);
    await store.save(s);
    var fail = true;
    final controller = ReviewController(
      store: store,
      session: s,
      loadEngine: () async {
        if (fail) throw StateError('fixture setup failure');
        return fakeEngine();
      },
    );
    await controller.analyze();
    expect(controller.setupError, isNotNull);
    expect(controller.session.currentInitialObservation, isNotNull);
    expect(controller.session.photos.single.analysis, isNull);
    expect(controller.session.preparedInput!['status'], 'analysisPending');
    final payload = controller.session.preparedInput!['payload'] as Map;
    final outputPhoto = (payload['photos'] as List).single as Map;
    expect(outputPhoto['globalPhysicalMeasurements'], isNull);
    expect(
      (outputPhoto['userObservations'] as List).single['symbolName'],
      'Kuş',
    );
    final first = jsonEncode(controller.session.initialObservations);
    fail = false;
    await controller.analyze();
    expect(controller.setupError, isNull);
    expect(controller.session.preparedInput!['status'], 'ready');
    expect(jsonEncode(controller.session.initialObservations), first);
    await controller.close();
    controller.dispose();
  });
  test(
    'user Tree is never an engine candidate, null label stays in audit',
    () async {
      var p = await photo();
      p = p.update(
        photo: p.photo.annotated([
          RegionAnnotation(
            id: 'test-region',
            box: RegionBox(.1, .1, .2, .2),
            label: 'tree',
          ),
          RegionAnnotation(
            id: 'test-uncertain',
            box: RegionBox(.4, .4, .2, .2),
          ),
        ], PhotoDecision.marked),
      );
      final context = interpretationInput(review(photos: [p]));
      expect(context['status'], 'analysisPending');
      expect(context['acceptedEngineCandidates'], isEmpty);
      expect(context['userObservations'], hasLength(1));
      expect(context['audit'], hasLength(1));
      final json = jsonEncode(context);
      expect(json, isNot(contains(p.photo.localName)));
      expect(json, isNot(contains('localName')));
      expect(context['userObservations'][0]['regionDensity'], isNull);
      expect(
        () => (context['userObservations'] as List).clear(),
        throwsUnsupportedError,
      );
      expect(interpretationInput(review())['status'], 'noSelectedSymbols');
    },
  );
  test(
    'all candidate answers and exposure survive, stale feedback is rejected',
    () async {
      final p = await photo();
      final doc = {
        'version': 'atlas-local-analysis-v1',
        'runId': 'test-run',
        'photoId': p.id,
        'photoChecksum': p.photo.checksum,
        'surface': 'cup',
        'outcome': 'symbolCandidatesAvailable',
        'symbols': [
          for (var i = 0; i < 4; i++)
            {'key': 'test-candidate-$i', 'name': 'Test symbol $i'},
        ],
      };
      final withFeedback = p
          .update(analysis: doc)
          .update(
            feedback: [
              for (var i = 0; i < 4; i++)
                CandidateFeedback(
                  candidateKey: 'test-candidate-$i',
                  runId: 'test-run',
                  answer: CandidateAnswer.values[i],
                  exposedAtUtc: timestamp,
                ),
            ],
          );
      final restored = ReviewPhoto.fromJson(withFeedback.toJson());
      expect(restored.feedback.map((f) => f.answer), CandidateAnswer.values);
      final context = interpretationInput(review(photos: [restored]));
      expect(context['acceptedEngineCandidates'], hasLength(1));
      expect(context['audit'], hasLength(3));
      expect(
        () => p.update(feedback: restored.feedback),
        throwsFormatException,
      );
      final mutable = Map<String, dynamic>.from(doc);
      mutable['photoChecksum'] = 'sha256:${'b' * 64}';
      expect(() => p.update(analysis: mutable), throwsFormatException);
      expect(
        withFeedback
            .update(analysis: {...doc, 'runId': 'test-new-run'})
            .feedback,
        isEmpty,
      );
    },
  );
  test(
    'gallery cancellation and corrupt input preserve previous revision',
    () async {
      final s = review(photos: [await photo()]);
      await store.save(s);
      final picker = _Picker();
      final gallery = ReviewGallery(store, picker);
      await gallery.select(
        s,
        ReviewSurface.cup,
        null,
        replaceId: s.photos.single.id,
      );
      expect((await store.sessions()).single.revision, 1);
      picker.bytes = Uint8List(3);
      await expectLater(
        gallery.select(s, ReviewSurface.cup, null),
        throwsA(anything),
      );
      expect((await store.sessions()).single.revision, 1);
      expect(await store.pendingGallery(), isNull);
    },
  );
  test('gallery lost selection recovers once with exact intent', () async {
    final s = review();
    await store.save(s);
    await store.galleryIntent({
      'id': s.id,
      'revision': 1,
      'surface': 'cup',
      'role': null,
      'replaceId': null,
    });
    final picker = _Picker()..bytes = testImage();
    final gallery = ReviewGallery(store, picker);
    final recovered = await gallery.recover();
    expect(recovered!.photos, hasLength(1));
    expect(recovered.photos.single.declaredRole, isNull);
    await gallery.recover();
    expect(picker.recoveries, 1);
    expect((await store.sessions()).single.revision, 2);
  });
  test(
    'ZIP includes only consented records, verified bytes and context',
    () async {
      final p = await photo();
      var s = review(photos: [p], consent: true);
      await store.save(s);
      s = captureInitialObservations(s, capturedAtUtc: timestamp);
      await store.save(s);
      s = s.next(
        preparedInput: prepareReviewInput(s, preparedAtUtc: timestamp),
      );
      await store.save(s);
      const channel = MethodChannel('test.mvp.export');
      Uint8List? archiveBytes;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            archiveBytes = await File(
              (call.arguments as Map)['sourcePath'] as String,
            ).readAsBytes();
            return 'test-download';
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final result = await store.exportToDownloads(
        channel: channel,
        temporaryDirectory: () async => temp,
      );
      expect(result.count, 1);
      final archive = ZipDecoder().decodeBytes(archiveBytes!);
      expect(
        archive.files.map((f) => f.name),
        contains('reviews/test-review/interpretation-input.json'),
      );
      expect(
        archive.files.map((f) => f.name),
        containsAll([
          'reviews/test-review/initial-observations.json',
          'reviews/test-review/prepared-input.json',
        ]),
      );
      final snapshotFile = archive.files.singleWhere(
        (f) => f.name == 'reviews/test-review/initial-observations.json',
      );
      final exported = jsonDecode(
        utf8.decode(snapshotFile.content as List<int>),
      );
      expect(exported['snapshots'], s.initialObservations);
      await store.save(s.next(researchAllowed: false));
      await expectLater(
        store.exportToDownloads(
          channel: channel,
          temporaryDirectory: () async => temp,
        ),
        throwsA(
          isA<ExportFailure>().having(
            (e) => e.code,
            'code',
            ExportFailureCode.noPermission,
          ),
        ),
      );
    },
  );
  test('missing media cannot block withdrawal and deletion', () async {
    final s = review(photos: [await photo()], consent: true);
    await store.save(s);
    await store.file(s.photos.single.photo.localName).delete();
    final withdrawn = s.next(researchAllowed: false);
    await store.save(withdrawn);
    expect((await store.sessions()).single.researchConsentAtUtc, isNull);
    await store.delete(withdrawn);
    expect((await store.sessions()).single.deleted, true);
  });
  test(
    'replaced first-observation photos export with exact verified media',
    () async {
      final original = await photo();
      var s = review(photos: [original], consent: true);
      await store.save(s);
      s = captureInitialObservations(s, capturedAtUtc: timestamp);
      await store.save(s);
      final first = jsonEncode(s.initialObservations);
      final replacement = await photo();
      s = s.next(photos: [replacement]);
      expect(s.currentInitialObservation, isNull);
      expect(s.preparedInput, isNull);
      await store.save(s);
      s = captureInitialObservations(s, capturedAtUtc: timestamp);
      await store.save(s);
      expect(jsonEncode(s.initialObservations.take(1).toList()), first);
      const channel = MethodChannel('test.part1.history.export');
      Uint8List? archiveBytes;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            archiveBytes = await File(
              (call.arguments as Map)['sourcePath'] as String,
            ).readAsBytes();
            return 'test-download';
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      await store.exportToDownloads(
        channel: channel,
        temporaryDirectory: () async => temp,
      );
      final archive = ZipDecoder().decodeBytes(archiveBytes!);
      final snapshots =
          jsonDecode(
                utf8.decode(
                  archive.files
                          .singleWhere(
                            (f) =>
                                f.name.endsWith('/initial-observations.json'),
                          )
                          .content
                      as List<int>,
                ),
              )
              as Map;
      final media = snapshots['media'] as List;
      expect(media, hasLength(2));
      for (final reference in media) {
        final exported = archive.files.singleWhere(
          (f) => f.name == reference['path'],
        );
        expect(
          'sha256:${sha256.convert(exported.content as List<int>)}',
          reference['photoChecksum'],
        );
      }
      await store.file(original.photo.localName).writeAsBytes([1, 2, 3]);
      await expectLater(
        store.exportToDownloads(
          channel: channel,
          temporaryDirectory: () async => temp,
        ),
        throwsA(
          isA<ExportFailure>().having(
            (e) => e.code,
            'code',
            ExportFailureCode.integrity,
          ),
        ),
      );
      await store.delete(s);
      expect(await store.file(original.photo.localName).exists(), false);
      expect(await store.file(replacement.photo.localName).exists(), false);
      await expectLater(
        store.exportToDownloads(
          channel: channel,
          temporaryDirectory: () async => temp,
        ),
        throwsA(
          isA<ExportFailure>().having(
            (e) => e.code,
            'code',
            ExportFailureCode.noRecords,
          ),
        ),
      );
    },
  );
  test(
    'earlier revisions retain named exposure after a photo is replaced',
    () async {
      final original = await photo();
      final output = await fakeEngine().analyze(
        original,
        () => store.readPhoto(original),
      );
      final shown = original.update(analysis: output.document, exposed: true);
      final s = review(photos: [shown]);
      await store.save(s);
      final replaced = s.next(photos: [await photo()]);
      await store.save(replaced);
      final exposures = await store.knownGroupExposures(replaced);
      expect(exposures.any((e) => e['photoId'] == original.id), true);
      final captured = captureInitialObservations(
        replaced,
        capturedAtUtc: timestamp,
        priorExposures: exposures,
      );
      await store.save(captured);
      expect(captured.currentInitialObservation!['priorExposures'], isNotEmpty);
    },
  );
  test(
    'deletion tombstone excludes all revisions and removes owned media',
    () async {
      final s = review(photos: [await photo()], consent: true);
      await store.save(s);
      await store.delete(s);
      expect((await store.sessions()).single.deleted, true);
      expect(await store.file(s.photos.single.photo.localName).exists(), false);
      expect(
        () => interpretationInput((s.next(deleted: true))),
        throwsStateError,
      );
      await expectLater(store.save(s.next()), throwsStateError);
    },
  );
}

class _Picker implements GalleryPicker {
  Uint8List? bytes;
  int recoveries = 0;
  @override
  Future<Uint8List?> pick() async => bytes;
  @override
  Future<Uint8List?> recover() async {
    recoveries++;
    return bytes;
  }
}
