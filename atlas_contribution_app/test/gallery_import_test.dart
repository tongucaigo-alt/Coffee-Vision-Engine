import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:atlas_contribution_app/src/gallery_import.dart';
import 'package:atlas_contribution_app/src/local_store.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'package:atlas_contribution_app/src/offline_contribution.dart';
import 'fixtures.dart';

class FakeGallery implements GalleryPicker {
  Uint8List? selection, lost;
  int calls = 0;
  @override
  Future<Uint8List?> pick() async {
    calls++;
    return selection;
  }

  @override
  Future<Uint8List?> recover() async => lost;
}

ContributionDraft galleryDraft() {
  final old = testDraft();
  return ContributionDraft(
    id: old.id,
    rootId: old.rootId,
    groupId: old.groupId,
    createdAt: old.createdAt,
    consentedAt: old.consentedAt,
    kind: ContributionKind.gallerySingle,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late DraftStore store;
  late FakeGallery picker;
  late GalleryImport importer;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('atlas-gallery-test-');
    store = DraftStore(directory);
    picker = FakeGallery();
    importer = GalleryImport(store, picker);
  });
  tearDown(() async => directory.delete(recursive: true));

  test('legacy camera JSON round-trips without new cloud fields', () {
    final json = testDraft(photos: [testPhoto(CaptureRole.top)]).toJson();
    expect(ContributionDraft.fromJson(json).toJson(), json);
    expect(json.containsKey('kind'), false);
    expect((json['photos'] as List).single.containsKey('origin'), false);
  });

  test('single gallery photo has no angle or invented capture time', () async {
    picker.selection = testImage();
    final draft = (await importer.select(galleryDraft()))!;
    expect(picker.calls, 1);
    expect(draft.complete, true);
    expect(draft.reviewed, false);
    final p = draft.photos.single;
    expect(p.role, isNull);
    expect(p.capturedAt, isNull);
    expect(DateTime.parse(p.importedAt!).isUtc, true);
    expect(p.toJson()['origin'], 'gallery');
    expect(draft.toJson()['physicalIndependence'], 'unverified');
    expect(ContributionDraft.fromJson(draft.toJson()).toJson(), draft.toJson());
    expect((await DraftStore(directory).load())!.toJson(), draft.toJson());
    expect(() => testDraft(photos: [p]), throwsArgumentError);
    expect(
      () => galleryDraft().withPhoto(testPhoto(CaptureRole.top)),
      throwsArgumentError,
    );
  });

  test(
    'cancel and corrupt replacement leave exact old draft and photo intact',
    () async {
      picker.selection = testImage();
      final original = (await importer.select(galleryDraft()))!;
      final before = await store.file('draft.json').readAsBytes();
      final photoBytes = await store
          .file(original.photos.single.localName)
          .readAsBytes();
      picker.selection = null;
      expect(await importer.select(original), isNull);
      expect(await store.file('draft.json').readAsBytes(), before);
      picker.selection = Uint8List.fromList([0, 1, 2]);
      await expectLater(importer.select(original), throwsFormatException);
      expect(await store.file('draft.json').readAsBytes(), before);
      expect(
        await store.file(original.photos.single.localName).readAsBytes(),
        photoBytes,
      );
    },
  );

  test(
    'replacement retains previous backup and resets annotations only in new copy',
    () async {
      picker.selection = testImage();
      final first = (await importer.select(galleryDraft()))!;
      final marked = first.withPhoto(
        first.photos.single.annotated([
          RegionAnnotation(
            id: 'test-region',
            box: RegionBox(.1, .1, .3, .3),
            label: 'bird',
          ),
        ], PhotoDecision.marked),
      );
      await store.save(marked);
      final next = (await importer.select(marked))!;
      expect(
        next.photos.single.localName,
        isNot(marked.photos.single.localName),
      );
      expect(next.photos.single.regions, isEmpty);
      expect(marked.photos.single.regions, hasLength(1));
      expect(await store.file(marked.photos.single.localName).exists(), true);
    },
  );

  test(
    'lost picker result restores pending session and never duplicates committed import',
    () async {
      await store.saveGalleryPending(galleryDraft());
      picker.lost = testImage();
      final recovered = (await importer.recover())!;
      expect(recovered.isGallery, true);
      await store.saveGalleryPending(galleryDraft());
      final again = (await importer.recover())!;
      expect(again.toJson(), recovered.toJson());
      expect(
        directory.listSync().where((f) => f.path.endsWith('.jpg')),
        hasLength(1),
      );
    },
  );

  test('orphan lost result cannot replace an unrelated camera draft', () async {
    final camera = testDraft(photos: [testPhoto(CaptureRole.top)]);
    await store.save(camera);
    picker.lost = testImage();
    expect((await importer.recover())!.toJson(), camera.toJson());
    expect(directory.listSync().where((f) => f.path.endsWith('.jpg')), isEmpty);
  });

  test(
    'gallery and camera share the 30-record quota and cannot bypass checksum validation',
    () async {
      picker.selection = testImage();
      final imported = (await importer.select(galleryDraft()))!;
      final draft = imported.withPhoto(
        imported.photos.single.annotated([], PhotoDecision.skipped),
      );
      final service = OfflineContributionService(store);
      var reads = 0;
      await store
          .file('receipts.json')
          .writeAsString(
            jsonEncode({
              'rows': [
                for (var i = 0; i < 30; i++)
                  {
                    'root_id': 'test-existing-$i',
                    'expires_at': DateTime.now()
                        .toUtc()
                        .add(const Duration(days: 1))
                        .toIso8601String(),
                  },
              ],
            }),
          );
      await expectLater(
        service.submit(draft, (p) async {
          reads++;
          return store.file(p.localName).readAsBytes();
        }, (_) {}),
        throwsA(isA<Exception>()),
      );
      expect(reads, 0);
      await store.file('receipts.json').writeAsString('{"rows":[]}');
      await expectLater(
        service.submit(draft, (_) async => Uint8List(10), (_) {}),
        throwsA(isA<Exception>()),
      );
      expect(await store.receipts(), isEmpty);
    },
  );

  test('image derivative bakes orientation and removes metadata', () async {
    final image = img.Image(width: 2400, height: 1200);
    image.exif.imageIfd.orientation = 6;
    image.exif.imageIfd.make = 'private-test-device';
    final bytes = img.encodeJpg(image);
    final p = await store.importGallery(bytes);
    expect(p.width, 1024);
    expect(p.height, 2048);
    expect(p.originalChecksum, 'sha256:${sha256.convert(bytes)}');
    final derivative = img.decodeJpg(
      await store.file(p.localName).readAsBytes(),
    )!;
    expect(derivative.exif.imageIfd.make, isNull);
    expect(derivative.exif.imageIfd.orientation, isNull);
  });

  test(
    'gallery completion and export v2 preserve exact checksum inventory',
    () async {
      picker.selection = testImage();
      final imported = (await importer.select(galleryDraft()))!;
      final draft = imported.withPhoto(
        imported.photos.single.annotated([], PhotoDecision.notSeen),
      );
      final row = await OfflineContributionService(
        store,
      ).submit(draft, (p) => store.file(p.localName).readAsBytes(), (_) {});
      await store.saveReceipt(row);
      await store.clear();
      const channel = MethodChannel('test.gallery/export');
      Uint8List? zipped;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            zipped = await File(
              (call.arguments as Map)['sourcePath'],
            ).readAsBytes();
            return 'content://downloads/test';
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      await OfflineContributionExporter(
        store,
        channel: channel,
      ).exportToDownloads();
      final zip = ZipDecoder().decodeBytes(zipped!);
      final manifest = jsonDecode(
        utf8.decode(zip.findFile('manifest.json')!.content),
      );
      expect(manifest['version'], 2);
      expect(zip.findFile('records/${draft.id}/gallery.jpg'), isNotNull);
      for (final item in manifest['files']) {
        final content = zip.findFile(item['path'])!.content;
        expect(item['sha256'], 'sha256:${sha256.convert(content)}');
        expect(item['bytes'], content.length);
      }
      expect(await store.receipts(), hasLength(1));
    },
  );
}
