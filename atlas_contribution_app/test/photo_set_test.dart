import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:atlas_contribution_app/src/models.dart';
import 'package:atlas_contribution_app/src/gallery_import.dart';
import 'package:atlas_contribution_app/src/local_store.dart';
import 'package:atlas_contribution_app/src/offline_contribution.dart';
import 'package:atlas_contribution_app/src/ai/ai_bridge.dart';
import 'package:atlas_contribution_app/src/ai/ai_contract.dart';
import 'package:atlas_contribution_app/src/ai/ai_store.dart';
import 'package:atlas_contribution_app/src/mvp/review_controller.dart';
import 'package:atlas_contribution_app/src/mvp/review_models.dart';
import 'package:atlas_contribution_app/src/mvp/review_store.dart';
import 'ai_test.dart' show contextData;
import 'mvp_review_test.dart' show fakeEngine;

Uint8List setImage(int i) => img.encodePng(
  img.Image(width: 160, height: 200)
    ..clear(img.ColorRgb8(70 + i * 30, 90, 100)),
);

class SetPicker implements MultiGalleryPicker {
  List<Uint8List> items = [];
  @override
  Future<List<Uint8List>> pickMany() async => items;
  @override
  Future<List<Uint8List>> recoverMany() async => items;
  @override
  Future<Uint8List?> pick() async => items.firstOrNull;
  @override
  Future<Uint8List?> recover() async => items.firstOrNull;
}

ContributionDraft setDraft({bool gallery = true}) {
  final now = DateTime.now().toUtc().toIso8601String();
  return ContributionDraft(
    id: 'set-one',
    rootId: 'set-one',
    groupId: 'same-cup',
    createdAt: now,
    consentedAt: now,
    kind: ContributionKind.photoSet,
    galleryStart: gallery,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late DraftStore source;
  late ReviewStore reviews;
  late SetPicker picker;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('atlas-photo-set-');
    source = DraftStore(Directory('${root.path}/source'));
    reviews = ReviewStore(
      Directory('${root.path}/reviews'),
      contributionStore: source,
    );
    await source.initialize();
    await reviews.initialize();
    picker = SetPicker();
  });
  tearDown(() => root.delete(recursive: true));

  for (var cups = 1; cups <= 3; cups++) {
    for (final saucer in [false, true]) {
      test(
        '$cups gallery cups with saucer=$saucer roundtrip, analyze and export',
        () async {
          var draft = setDraft();
          await source.save(draft);
          picker.items = [for (var i = 0; i < cups; i++) setImage(i)];
          final importer = PhotoSetGallery(source, picker);
          draft = (await importer.select(draft))!;
          expect(draft.cups.length, cups);
          expect(
            draft.cups.every((p) => p.angle == null && p.origin == 'gallery'),
            true,
          );
          if (saucer) {
            picker.items = [setImage(4)];
            draft = (await importer.select(
              draft,
              surface: PhotoSurface.saucer,
            ))!;
          }
          final marker = RegionAnnotation(
            id: 'bird',
            label: 'bird',
            box: RegionBox(.2, .25, .15, .15),
          );
          draft = draft.copy(
            cupSelectionDone: true,
            saucerDecided: true,
            photos: draft.photos.map(
              (p) => p.annotated([marker], PhotoDecision.marked),
            ),
          );
          await source.save(draft);
          expect((await source.load())!.toJson(), draft.toJson());
          final row = await OfflineContributionService(source).submit(
            draft,
            (p) => source.file(p.localName).readAsBytes(),
            (_) {},
          );
          await source.saveReceipt(row);
          final bridge = AiBridge(
            source,
            reviews,
            AiStore(Directory('${root.path}/ai')),
          );
          final session = await bridge.importReceipt(row, fresh: true);
          expect(
            session.photos
                .where((p) => p.surface == ReviewSurface.saucer)
                .length,
            saucer ? 1 : 0,
          );
          final controller = ReviewController(
            store: reviews,
            session: session,
            loadEngine: () async => fakeEngine(),
          );
          await controller.save(
            session.next(
              sameSample: true,
              researchAllowed: true,
              photos: session.photos.map(
                (p) => p.update(
                  confirmedAt: DateTime.now().toUtc().toIso8601String(),
                ),
              ),
            ),
          );
          await controller.analyze();
          expect(controller.session.currentInitialObservation, isNotNull);
          final payload = validateAiContext(
            Map<String, dynamic>.from(
              controller.session.preparedInput!['payload'] as Map,
            ),
          );
          expect((payload['photos'] as List).length, cups + (saucer ? 1 : 0));
          expect(jsonEncode(payload), isNot(contains('localName')));
          await controller.close();
          controller.dispose();
          const channel = MethodChannel('test.photo-set-export');
          late Uint8List bytes;
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, (call) async {
                bytes = await File(
                  (call.arguments as Map)['sourcePath'] as String,
                ).readAsBytes();
                return 'content://fixture';
              });
          addTearDown(
            () => TestDefaultBinaryMessengerBinding
                .instance
                .defaultBinaryMessenger
                .setMockMethodCallHandler(channel, null),
          );
          await OfflineContributionExporter(
            source,
            reviewStore: reviews,
            channel: channel,
            temporaryDirectory: () async => root,
          ).exportToDownloads();
          final zip = ZipDecoder().decodeBytes(bytes);
          final manifest = jsonDecode(
            utf8.decode(zip.findFile('manifest.json')!.content),
          );
          expect(manifest['version'], 4);
          expect(
            zip.files
                .where((f) => f.name.endsWith('.jpg'))
                .map((f) => f.name)
                .toSet()
                .length,
            draft.photos.length,
          );
        },
      );
    }
  }
  test(
    'batch deduplicates; cancellation and overflow retain prior photos',
    () async {
      var draft = setDraft();
      await source.save(draft);
      picker.items = [setImage(0), setImage(0), setImage(1)];
      final importer = PhotoSetGallery(source, picker);
      draft = (await importer.select(draft))!;
      expect(draft.cups.length, 2);
      picker.items = [];
      expect(await importer.select(draft), isNull);
      expect((await source.load())!.toJson(), draft.toJson());
      picker.items = [setImage(2), setImage(3)];
      await expectLater(importer.select(draft), throwsArgumentError);
      expect((await source.load())!.toJson(), draft.toJson());
    },
  );
  test(
    'picker recovery imports once; replacement preserves other images and labels',
    () async {
      var draft = setDraft();
      await source.save(draft);
      await source.saveSetGalleryPending({
        'operation': 'photoSet',
        'draft': draft.toJson(),
        'surface': 'cup',
        'replaceId': null,
      });
      picker.items = [setImage(0), setImage(1)];
      draft = (await GalleryImport(source, picker).recover())!;
      final first = draft.cups.first;
      draft = draft.withPhoto(first.asSetPhoto(angle: CaptureRole.handleRight));
      await source.save(draft);
      picker.items = [setImage(3)];
      final next = (await PhotoSetGallery(
        source,
        picker,
      ).select(draft, replaceId: first.id))!;
      expect(next.cups.first.id, first.id);
      expect(next.cups.first.angle, CaptureRole.handleRight);
      expect(next.cups.last.toJson(), draft.cups.last.toJson());
      expect(next.cups.first.checksum, isNot(first.checksum));
      expect(
        (await GalleryImport(source, picker).recover())!.toJson(),
        next.toJson(),
      );
    },
  );
  test(
    'adding a saucer keeps the linked root and immutable first observations',
    () async {
      var draft = setDraft();
      await source.save(draft);
      picker.items = [setImage(0)];
      draft = (await PhotoSetGallery(source, picker).select(draft))!;
      draft = draft.copy(
        cupSelectionDone: true,
        saucerDecided: true,
        photos: draft.photos.map((p) => p.annotated([], PhotoDecision.skipped)),
      );
      final service = OfflineContributionService(source);
      Future<Map<String, dynamic>> receipt(ContributionDraft d) async {
        final row = await service.submit(
          d,
          (p) => source.file(p.localName).readAsBytes(),
          (_) {},
        );
        await source.saveReceipt(row);
        return row;
      }

      final bridge = AiBridge(
        source,
        reviews,
        AiStore(Directory('${root.path}/ai')),
      );
      var session = await bridge.importReceipt(
        await receipt(draft),
        fresh: true,
      );
      final controller = ReviewController(
        store: reviews,
        session: session,
        loadEngine: () async => fakeEngine(),
      );
      await controller.save(
        session.next(
          sameSample: true,
          photos: session.photos.map(
            (p) =>
                p.update(confirmedAt: DateTime.now().toUtc().toIso8601String()),
          ),
        ),
      );
      await controller.analyze();
      session = controller.session;
      final first = jsonEncode(session.initialObservations);
      await controller.close();
      controller.dispose();
      final saucer = (await source.importGallery(setImage(4)))
          .asSetPhoto(type: PhotoSurface.saucer)
          .annotated([], PhotoDecision.skipped);
      final revised = ContributionDraft(
        id: 'set-two',
        rootId: draft.rootId,
        groupId: draft.groupId,
        createdAt: draft.createdAt,
        consentedAt: draft.consentedAt,
        revision: 2,
        supersedesId: draft.id,
        kind: ContributionKind.photoSet,
        galleryStart: true,
        cupSelectionDone: true,
        saucerDecided: true,
        photos: [...draft.photos, saucer],
      );
      final next = await bridge.importReceipt(
        await receipt(revised),
        fresh: true,
      );
      expect(next.id, session.id);
      expect(jsonEncode(next.initialObservations), first);
      expect(next.preparedInput, isNull);
      expect(await bridge.isCurrent(session), false);
      expect((await reviews.sessions()).length, 1);
      expect(next.photos.last.surface, ReviewSurface.saucer);
    },
  );
  test('context count matrix rejects saucer-only, excess and posed saucer', () {
    for (var cups = 0; cups <= 4; cups++) {
      for (var saucers = 0; saucers <= 2; saucers++) {
        final context = contextData();
        final template = Map<String, dynamic>.from(context['photos'][0] as Map);
        context['photos'] = [
          for (var i = 0; i < cups + saucers; i++)
            {
              ...template,
              'photoNumber': i + 1,
              'surface': i < cups ? 'cup' : 'saucer',
              'declaredRole': null,
            },
        ];
        if (cups >= 1 && cups <= 3 && saucers <= 1) {
          expect(validateAiContext(context), isNotNull);
        } else {
          expect(() => validateAiContext(context), throwsFormatException);
        }
      }
    }
    final context = contextData();
    context['photos'][0]['surface'] = 'saucer';
    expect(() => validateAiContext(context), throwsFormatException);
  });
}
