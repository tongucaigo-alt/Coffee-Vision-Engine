import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:atlas_contribution_app/src/local_store.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'package:atlas_contribution_app/src/offline_contribution.dart';
import 'package:atlas_contribution_app/src/photo_crop.dart';
import 'package:atlas_contribution_app/src/service.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fixtures.dart';

ContributionDraft _draft(
  String id,
  ContributionKind kind,
  Iterable<ContributionPhoto> photos,
) => ContributionDraft(
  id: id,
  rootId: id,
  groupId: 'shared-sample',
  createdAt: DateTime.now().toUtc().toIso8601String(),
  consentedAt: DateTime.now().toUtc().toIso8601String(),
  kind: kind,
  photos: photos,
);

Future<ContributionDraft> _saveOfflineRecord(
  DraftStore store, {
  required String id,
  required ContributionKind kind,
  PhotoCrop? crop,
}) async {
  final prepared = preparePhoto(testImage());
  final bytes = prepared['bytes']! as Uint8List;
  final roles = switch (kind) {
    ContributionKind.freeThreeAngle => freeCaptureRoles,
    ContributionKind.threeAngle => legacyCaptureRoles,
    ContributionKind.gallerySingle => <CaptureRole?>[null],
  };
  final photos = <ContributionPhoto>[];
  final now = DateTime.now().toUtc().toIso8601String();
  for (final role in roles) {
    final name = '$id-${role?.name ?? 'gallery'}.jpg';
    await store.file(name).writeAsBytes(bytes, flush: true);
    photos.add(
      ContributionPhoto(
        role: role,
        localName: name,
        checksum: prepared['checksum']! as String,
        originalChecksum: prepared['originalChecksum']! as String,
        width: prepared['width']! as int,
        height: prepared['height']! as int,
        byteLength: bytes.length,
        capturedAt: role == null ? null : now,
        importedAt: role == null ? now : null,
        displayCrop: crop,
        decision: PhotoDecision.marked,
        regions: [
          RegionAnnotation(
            id: '$id-${role?.name ?? 'gallery'}-observation',
            label: 'bird',
            box: (crop ?? PhotoCrop.full).toFullBox(RegionBox(.1, .2, .3, .4)),
          ),
        ],
      ),
    );
  }
  final draft = _draft(id, kind, photos);
  await store.save(draft);
  final progress = <int>[];
  final receipt = await OfflineContributionService(store).submit(
    draft,
    (photo) => store.file(photo.localName).readAsBytes(),
    progress.add,
  );
  expect(progress, List.generate(photos.length, (i) => i + 1));
  await store.saveReceipt(receipt);
  await store.clear();
  return draft;
}

Map<String, dynamic> _archiveJson(Archive archive, String name) =>
    Map<String, dynamic>.from(
      jsonDecode(
            utf8.decode(
              archive.files.singleWhere((file) => file.name == name).content
                  as List<int>,
            ),
          )
          as Map,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final free in [true, false]) {
    test(
      '${free ? 'free-angle' : 'cropped legacy'} record cannot reach online reserve or photo reads',
      () async {
        var requests = 0, reads = 0, progress = 0;
        final client = SupabaseClient(
          'https://test.invalid',
          'test-key',
          httpClient: MockClient((_) async {
            requests++;
            return http.Response('{}', 500);
          }),
        );
        addTearDown(client.dispose);
        final roles = free ? freeCaptureRoles : legacyCaptureRoles;
        final photos = [
          for (final role in roles)
            ContributionPhoto.fromJson({
              ...testPhoto(role, decision: PhotoDecision.skipped).toJson(),
              if (!free) 'displayCrop': PhotoCrop(.2, .1, .6, .7).toJson(),
            }),
        ];
        final draft = _draft(
          'blocked-local-record',
          free ? ContributionKind.freeThreeAngle : ContributionKind.threeAngle,
          photos,
        );
        expect(draft.reviewed, isTrue);
        await expectLater(
          ContributionService(client).submit(draft, (_) async {
            reads++;
            return Uint8List(0);
          }, (_) => progress++),
          throwsA(
            isA<ContributionFailure>().having(
              (error) => error.message,
              'message',
              'Bu çekim kaydı yalnız telefonda saklanabilir.',
            ),
          ),
        );
        expect([requests, reads, progress], [0, 0, 0]);
      },
    );
  }

  test(
    'free-angle crop exports full photos and checksum inventory; withdrawn receipt is excluded',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'atlas-export-compat-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final store = DraftStore(directory);
      await store.initialize();
      final crop = PhotoCrop(.2, .1, .6, .7);
      final fresh = await _saveOfflineRecord(
        store,
        id: 'new-free',
        kind: ContributionKind.freeThreeAngle,
        crop: crop,
      );
      final legacy = await _saveOfflineRecord(
        store,
        id: 'legacy-top',
        kind: ContributionKind.threeAngle,
      );
      final gallery = await _saveOfflineRecord(
        store,
        id: 'legacy-gallery',
        kind: ContributionKind.gallerySingle,
      );

      const channel = MethodChannel('test.atlas/export-compatibility');
      final exports = <Uint8List>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'saveToDownloads');
            exports.add(
              await File(
                (call.arguments as Map)['sourcePath'] as String,
              ).readAsBytes(),
            );
            return 'content://downloads/export-compatibility';
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final exporter = OfflineContributionExporter(store, channel: channel);
      final result = await exporter.exportToDownloads();
      expect(result.recordCount, 3);
      expect(result.checksum, 'sha256:${sha256.convert(exports.last)}');
      final archive = ZipDecoder().decodeBytes(exports.last);
      final manifest = _archiveJson(archive, 'manifest.json');
      expect(manifest['version'], 3);
      expect(manifest['researchOnly'], isTrue);
      expect(manifest['recordCount'], 3);
      final record = _archiveJson(archive, 'records/${fresh.id}/record.json');
      final document = Map<String, dynamic>.from(record['document'] as Map);
      expect(document['kind'], 'freeThreeAngle');
      expect(document['recordVersion'], 3);
      final reloaded = ContributionDraft.fromJson(document);
      expect(reloaded.photos.map((p) => p.role), freeCaptureRoles);
      for (final photo in reloaded.photos) {
        expect(photo.displayCrop!.toJson(), crop.toJson());
        expect(
          photo.regions.single.box.toJson(),
          crop.toFullBox(RegionBox(.1, .2, .3, .4)).toJson(),
        );
        expect([photo.width, photo.height], [160, 200]);
        final archived = archive.files.singleWhere(
          (file) => file.name == 'records/${fresh.id}/${photo.fileKey}.jpg',
        );
        final bytes = archived.content as List<int>;
        expect(bytes, await store.file(photo.localName).readAsBytes());
        expect('sha256:${sha256.convert(bytes)}', photo.checksum);
      }
      expect(
        archive.files.map((f) => f.name),
        contains('records/${fresh.id}/free.jpg'),
      );
      expect(
        archive.files.map((f) => f.name),
        isNot(contains('records/${fresh.id}/top.jpg')),
      );
      for (final entry in (manifest['files'] as List).cast<Map>()) {
        final bytes =
            archive.files.singleWhere((f) => f.name == entry['path']).content
                as List<int>;
        expect(entry['bytes'], bytes.length);
        expect(entry['sha256'], 'sha256:${sha256.convert(bytes)}');
      }

      await store.queueDelete(fresh.rootId);
      await OfflineContributionService(store).delete(fresh.rootId);
      await store.acknowledgeDelete(fresh.rootId);
      final afterWithdrawal = await exporter.exportToDownloads();
      expect(afterWithdrawal.recordCount, 2);
      final remaining = ZipDecoder().decodeBytes(exports.last);
      expect(
        remaining.files.any((f) => f.name.startsWith('records/${fresh.id}/')),
        isFalse,
      );
      final remainingManifest = _archiveJson(remaining, 'manifest.json');
      expect(remainingManifest['version'], 2);
      final legacyDocument =
          _archiveJson(
                remaining,
                'records/${legacy.id}/record.json',
              )['document']
              as Map;
      expect(legacyDocument.containsKey('kind'), isFalse);
      expect(legacyDocument.containsKey('recordVersion'), isFalse);
      expect((legacyDocument['photos'] as List).first['role'], 'top');
      final galleryDocument =
          _archiveJson(
                remaining,
                'records/${gallery.id}/record.json',
              )['document']
              as Map;
      expect(galleryDocument['kind'], 'gallerySingle');
      expect(galleryDocument['recordVersion'], 2);
    },
  );

  test(
    'a cropped legacy record alone also requires export version 3',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'atlas-crop-export-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final store = DraftStore(directory);
      await store.initialize();
      await _saveOfflineRecord(
        store,
        id: 'cropped-top',
        kind: ContributionKind.threeAngle,
        crop: PhotoCrop(.2, .1, .6, .7),
      );
      const channel = MethodChannel('test.atlas/crop-export-version');
      Uint8List? exported;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            exported = await File(
              (call.arguments as Map)['sourcePath'] as String,
            ).readAsBytes();
            return 'content://downloads/cropped-top';
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      await OfflineContributionExporter(
        store,
        channel: channel,
      ).exportToDownloads();
      expect(
        _archiveJson(
          ZipDecoder().decodeBytes(exported!),
          'manifest.json',
        )['version'],
        3,
      );
    },
  );
}
