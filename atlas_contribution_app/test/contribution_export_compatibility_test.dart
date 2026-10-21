import 'dart:io';

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
    ContributionKind.photoSet => throw ArgumentError('Use photo-set fixtures'),
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
    'local free-angle, legacy and gallery records retain photos and marks',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'atlas-local-compat-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final store = DraftStore(directory);
      await store.initialize();
      final crop = PhotoCrop(.2, .1, .6, .7);
      final drafts = [
        await _saveOfflineRecord(
          store,
          id: 'new-free',
          kind: ContributionKind.freeThreeAngle,
          crop: crop,
        ),
        await _saveOfflineRecord(
          store,
          id: 'legacy-top',
          kind: ContributionKind.threeAngle,
        ),
        await _saveOfflineRecord(
          store,
          id: 'legacy-gallery',
          kind: ContributionKind.gallerySingle,
        ),
      ];
      final reopened = DraftStore(directory);
      final rows = await reopened.receipts();
      expect(rows, hasLength(3));
      for (final draft in drafts) {
        final document = Map<String, dynamic>.from(
          rows.singleWhere((r) => r['id'] == draft.id)['document'] as Map,
        );
        final restored = ContributionDraft.fromJson(document);
        expect(restored.toJson(), draft.toJson());
        for (final photo in restored.photos) {
          final bytes = await reopened.file(photo.localName).readAsBytes();
          expect(bytes.length, photo.byteLength);
          expect('sha256:${sha256.convert(bytes)}', photo.checksum);
          expect(photo.regions.single.label, 'bird');
        }
      }
      await store.queueDelete(drafts.first.rootId);
      await store.acknowledgeDelete(drafts.first.rootId);
      expect(
        (await reopened.receipts()).map((r) => r['id']),
        containsAll(['legacy-top', 'legacy-gallery']),
      );
      expect(await reopened.receipts(), hasLength(2));
    },
  );

  test(
    'cropped legacy record retains its original full image and crop',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'atlas-local-crop-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final store = DraftStore(directory);
      await store.initialize();
      final crop = PhotoCrop(.2, .1, .6, .7);
      final saved = await _saveOfflineRecord(
        store,
        id: 'cropped-top',
        kind: ContributionKind.threeAngle,
        crop: crop,
      );
      final row = (await DraftStore(directory).receipts()).single;
      final restored = ContributionDraft.fromJson(
        Map<String, dynamic>.from(row['document'] as Map),
      );
      expect(restored.toJson(), saved.toJson());
      for (final photo in restored.photos) {
        expect(photo.displayCrop!.toJson(), crop.toJson());
        expect([photo.width, photo.height], [160, 200]);
        expect(
          photo.regions.single.box.toJson(),
          crop.toFullBox(RegionBox(.1, .2, .3, .4)).toJson(),
        );
        expect(
          'sha256:${sha256.convert(await store.file(photo.localName).readAsBytes())}',
          photo.checksum,
        );
      }
    },
  );
}
