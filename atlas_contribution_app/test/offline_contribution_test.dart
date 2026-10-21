import 'dart:io';

import 'package:atlas_contribution_app/src/local_store.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'package:atlas_contribution_app/src/offline_contribution.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'offline completion survives draft cleanup with exact photos and metadata',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'atlas-offline-test-',
      );
      final store = DraftStore(directory);
      await store.initialize();
      final prepared = preparePhoto(testImage());
      final bytes = prepared['bytes']! as Uint8List;
      final photos = <ContributionPhoto>[];
      for (final role in legacyCaptureRoles) {
        final name = '${role.name}.jpg';
        await store.file(name).writeAsBytes(bytes);
        photos.add(
          ContributionPhoto(
            role: role,
            localName: name,
            checksum: prepared['checksum']! as String,
            originalChecksum: prepared['originalChecksum']! as String,
            width: prepared['width']! as int,
            height: prepared['height']! as int,
            byteLength: bytes.length,
            capturedAt: DateTime.utc(2026, 9, 9).toIso8601String(),
            decision: PhotoDecision.skipped,
          ),
        );
      }
      final draft = testDraft(photos: photos);
      final service = OfflineContributionService(store);
      final progress = <int>[];
      final row = await service.submit(
        draft,
        (photo) => store.file(photo.localName).readAsBytes(),
        progress.add,
      );
      await store.saveReceipt(row);
      await store.save(draft);
      await store.clear();
      expect(progress, [1, 2, 3]);
      expect(await store.receipts(), hasLength(1));
      for (final photo in photos) {
        expect(await store.file(photo.localName).exists(), true);
      }

      final reloaded = ContributionDraft.fromJson(
        Map<String, dynamic>.from(
          (await DraftStore(directory).receipts()).single['document'] as Map,
        ),
      );
      expect(reloaded.toJson(), draft.toJson());
      for (final photo in reloaded.photos) {
        expect(
          await service.readPhoto(draft.id, photo),
          await store.file(photo.localName).readAsBytes(),
        );
      }
      await store.queueDelete(draft.rootId);
      expect(await store.pendingDeletes(), [draft.rootId]);

      await directory.delete(recursive: true);
    },
  );
}
