import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:atlas_contribution_app/src/local_store.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'package:atlas_contribution_app/src/mvp/review_store.dart';
import 'package:atlas_contribution_app/src/offline_contribution.dart';
import 'package:atlas_contribution_app/src/photo_crop.dart';
import 'package:coffee_camera/coffee_camera.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

ContributionDraft _draft({
  ContributionKind kind = ContributionKind.freeThreeAngle,
  Iterable<ContributionPhoto> photos = const [],
}) {
  final legacy = testDraft();
  return ContributionDraft(
    id: legacy.id,
    rootId: legacy.rootId,
    groupId: legacy.groupId,
    createdAt: legacy.createdAt,
    consentedAt: legacy.consentedAt,
    kind: kind,
    photos: photos,
  );
}

ContributionPhoto _withCrop(ContributionPhoto photo, PhotoCrop crop) =>
    ContributionPhoto.fromJson({
      ...photo.toJson(),
      'displayCrop': crop.toJson(),
    });

CameraCaptureResult _capture(
  File source,
  Uint8List bytes, {
  bool invalid = false,
}) => CameraCaptureResult(
  filePath: source.path,
  croppedCupPath: '${source.path}.crop.png',
  cropRect: ui.Rect.fromLTWH(invalid ? 140 : 40, 50, 80, 100),
  widthPixels: 160,
  heightPixels: 200,
  fileSizeBytes: bytes.length,
  croppedWidthPixels: 80,
  croppedHeightPixels: 100,
  capturedAt: DateTime.now().toUtc(),
  qualityScore: 90,
  coffeePresenceScore: .9,
  mode: CameraCaptureMode.manual,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'free triple has its own ordered roles and rejects legacy replacement',
    () {
      final draft = _draft();
      expect(draft.captureRoles, [
        CaptureRole.free,
        CaptureRole.handleRight,
        CaptureRole.handleLeft,
      ]);
      expect(draft.requiredPhotos, 3);
      expect(draft.complete, false);
      expect(() => draft.captureRoles.clear(), throwsUnsupportedError);
      expect(
        () => draft.withPhoto(testPhoto(CaptureRole.top)),
        throwsArgumentError,
      );
      expect(
        () => draft.withPhoto(testPhoto(CaptureRole.handleRight)),
        throwsArgumentError,
      );
      final free = testPhoto(CaptureRole.free, decision: PhotoDecision.skipped);
      final right = testPhoto(
        CaptureRole.handleRight,
        decision: PhotoDecision.skipped,
      );
      final left = testPhoto(
        CaptureRole.handleLeft,
        decision: PhotoDecision.skipped,
      );
      final complete = draft.withPhoto(free).withPhoto(right).withPhoto(left);
      expect(complete.complete, true);
      expect(complete.reviewed, true);
      final replacement = testPhoto(CaptureRole.handleRight);
      final edited = complete.copy(queued: true).withPhoto(replacement);
      expect(edited.photos, [free, replacement, left]);
      expect(edited.queued, false);
      expect(edited.reviewed, false);
      expect(() => testDraft().withPhoto(free), throwsArgumentError);
      expect(testDraft().captureRoles, legacyCaptureRoles);
    },
  );

  test('free v3, gallery v2 and legacy JSON keep separate contracts', () {
    final free = _draft(photos: [testPhoto(CaptureRole.free)]);
    final gallery = _draft(kind: ContributionKind.gallerySingle);
    final legacy = testDraft(photos: [testPhoto(CaptureRole.top)]);
    expect(free.toJson()['kind'], 'freeThreeAngle');
    expect(free.toJson()['recordVersion'], 3);
    expect(gallery.toJson()['recordVersion'], 2);
    expect(gallery.captureRoles, isEmpty);
    expect(legacy.toJson().containsKey('kind'), false);
    expect(legacy.toJson().containsKey('recordVersion'), false);
    for (final draft in [free, gallery, legacy]) {
      expect(
        ContributionDraft.fromJson(
          jsonDecode(jsonEncode(draft.toJson())),
        ).toJson(),
        draft.toJson(),
      );
    }
    for (final json in [
      {...free.toJson(), 'recordVersion': 2},
      {...gallery.toJson(), 'recordVersion': 3},
      {...free.toJson(), 'kind': 'unknown'},
    ]) {
      expect(() => ContributionDraft.fromJson(json), throwsFormatException);
    }
    expect(() => _draft(photos: legacy.photos), throwsArgumentError);
    expect(
      () => _draft(
        photos: [
          testPhoto(CaptureRole.free),
          testPhoto(CaptureRole.handleLeft),
        ],
      ),
      throwsArgumentError,
    );
  });

  test(
    'crop survives annotation and JSON without hiding outside legacy boxes',
    () {
      final crop = PhotoCrop(.25, .25, .5, .5);
      final original = _withCrop(testPhoto(CaptureRole.free), crop);
      final inside = RegionAnnotation(
        id: 'inside',
        box: RegionBox(.3, .35, .1, .1),
        label: 'tree',
      );
      final marked = original.annotated([inside], PhotoDecision.marked);
      expect(marked.checksum, original.checksum);
      expect(marked.originalChecksum, original.originalChecksum);
      expect(marked.displayCrop!.toJson(), crop.toJson());
      expect(marked.visibleCrop.isFull, false);
      final reopened = ContributionPhoto.fromJson(
        jsonDecode(jsonEncode(marked.toJson())),
      );
      expect(reopened.toJson(), marked.toJson());
      final outside = RegionAnnotation(
        id: 'outside',
        box: RegionBox(.05, .05, .1, .1),
        label: 'bird',
      );
      final legacyMarks = reopened.annotated([outside], PhotoDecision.marked);
      expect(legacyMarks.visibleCrop.isFull, true);
      expect(legacyMarks.displayCrop!.toJson(), crop.toJson());
      expect(legacyMarks.regions.single.box.toJson(), outside.box.toJson());
      expect(
        testPhoto(CaptureRole.top).toJson().containsKey('displayCrop'),
        false,
      );
    },
  );

  group('capture persistence', () {
    late Directory directory;
    late Directory originals;
    late DraftStore store;
    late Uint8List input;
    late File source;
    setUp(() async {
      directory = await Directory.systemTemp.createTemp('atlas-free-store-');
      originals = await Directory.systemTemp.createTemp('atlas-free-source-');
      store = DraftStore(directory);
      input = testImage();
      source = File('${originals.path}/camera.png');
      await source.writeAsBytes(input);
    });
    tearDown(() async {
      await directory.delete(recursive: true);
      await originals.delete(recursive: true);
    });

    test(
      'offline import preserves canonical photo and crop across restart',
      () async {
        final photo = await store.importCapture(
          CaptureRole.free,
          _capture(source, input),
          preserveDisplayCrop: true,
        );
        final expected = preparePhoto(input);
        expect(
          photo.displayCrop!.toJson(),
          PhotoCrop(.25, .25, .5, .5).toJson(),
        );
        expect(photo.width, 160);
        expect(photo.height, 200);
        expect(photo.checksum, expected['checksum']);
        expect(photo.originalChecksum, expected['originalChecksum']);
        expect(
          await store.file(photo.localName).readAsBytes(),
          expected['bytes'],
        );
        expect(await source.readAsBytes(), input);
        final draft = _draft(photos: [photo]);
        await store.save(draft);
        final reopened = (await DraftStore(directory).load())!;
        expect(reopened.toJson(), draft.toJson());
        expect(reopened.photos.single.visibleCrop.isFull, false);
      },
    );

    test(
      'default online-compatible import adds no crop schema fields',
      () async {
        final photo = await store.importCapture(
          CaptureRole.top,
          _capture(source, input),
        );
        expect(photo.displayCrop, isNull);
        expect(photo.toJson().containsKey('displayCrop'), false);
        expect(testDraft(photos: [photo]).toJson().containsKey('kind'), false);
        expect(photo.checksum, preparePhoto(input)['checksum']);
      },
    );

    test(
      'invalid replacement crop leaves saved draft and images unchanged',
      () async {
        final old = await store.importCapture(
          CaptureRole.free,
          _capture(source, input),
          preserveDisplayCrop: true,
        );
        await store.save(_draft(photos: [old]));
        final document = await store.file('draft.json').readAsBytes();
        final oldBytes = await store.file(old.localName).readAsBytes();
        final names = (await directory.list().toList())
            .map((f) => f.path)
            .toSet();
        await expectLater(
          store.importCapture(
            CaptureRole.free,
            _capture(source, input, invalid: true),
            preserveDisplayCrop: true,
          ),
          throwsFormatException,
        );
        expect(await store.file('draft.json').readAsBytes(), document);
        expect(await store.file(old.localName).readAsBytes(), oldBytes);
        expect(
          (await directory.list().toList()).map((f) => f.path).toSet(),
          names,
        );
        expect(await source.readAsBytes(), input);
      },
    );

    test(
      'offline free triple survives cleanup and exports canonical images',
      () async {
        final photos = <ContributionPhoto>[];
        for (final role in freeCaptureRoles) {
          final imported = await store.importCapture(
            role,
            _capture(source, input),
            preserveDisplayCrop: true,
          );
          photos.add(imported.annotated(const [], PhotoDecision.skipped));
        }
        final draft = _draft(photos: photos);
        final receipt = await OfflineContributionService(
          store,
        ).submit(draft, (p) => store.file(p.localName).readAsBytes(), (_) {});
        await store.saveReceipt(receipt);
        await store.save(draft);
        await store.clear();
        expect(await store.load(), isNull);
        expect(
          ContributionDraft.fromJson(
            Map<String, dynamic>.from(
              (await store.receipts()).single['document'] as Map,
            ),
          ).kind,
          ContributionKind.freeThreeAngle,
        );
        const channel = MethodChannel('test.atlas/free-crop-export');
        Uint8List? exported;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              exported = await File(
                (call.arguments as Map)['sourcePath'] as String,
              ).readAsBytes();
              return 'content://downloads/free-crop-export';
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null),
        );
        final result = await OfflineContributionExporter(
          store,
          channel: channel,
          temporaryDirectory: () async => directory,
          reviewStore: ReviewStore(
            Directory('${directory.path}/export-reviews'),
          ),
        ).exportToDownloads();
        expect(result.recordCount, 1);
        final archive = ZipDecoder().decodeBytes(exported!);
        final record =
            jsonDecode(
                  utf8.decode(
                    archive.files
                            .singleWhere(
                              (f) =>
                                  f.name == 'records/${draft.id}/record.json',
                            )
                            .content
                        as List<int>,
                  ),
                )
                as Map;
        expect(record['document']['kind'], 'freeThreeAngle');
        expect(record['document']['recordVersion'], 3);
        for (final p in photos) {
          final bytes =
              archive.files
                      .singleWhere(
                        (f) =>
                            f.name == 'records/${draft.id}/${p.role!.name}.jpg',
                      )
                      .content
                  as List<int>;
          expect('sha256:${sha256.convert(bytes)}', p.checksum);
          expect(await store.file(p.localName).exists(), true);
        }
        expect(
          (record['document']['photos'] as List).every(
            (p) => p['displayCrop']['version'] == PhotoCrop.version,
          ),
          true,
        );
      },
    );
  });
}
