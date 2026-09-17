import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:atlas_contribution_app/src/local_store.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'package:atlas_contribution_app/src/offline_contribution.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'offline completion survives draft cleanup and exports verified ZIP',
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

      const channel = MethodChannel('test.atlas/export');
      Uint8List? exported;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'saveToDownloads');
            final source = File(
              (call.arguments as Map)['sourcePath'] as String,
            );
            exported = await source.readAsBytes();
            return 'content://downloads/test-export';
          });
      final result = await OfflineContributionExporter(
        store,
        channel: channel,
      ).exportToDownloads();
      expect(result.recordCount, 1);
      expect(result.location, startsWith('content://downloads/'));
      final archive = ZipDecoder().decodeBytes(exported!);
      final names = archive.files.map((file) => file.name).toSet();
      expect(names, contains('manifest.json'));
      expect(
        names,
        containsAll([
          for (final role in legacyCaptureRoles)
            'records/${draft.id}/${role.name}.jpg',
          'records/${draft.id}/record.json',
        ]),
      );
      final manifestFile = archive.files.singleWhere(
        (file) => file.name == 'manifest.json',
      );
      final manifest = jsonDecode(
        utf8.decode(manifestFile.content as List<int>),
      );
      expect(manifest['recordCount'], 1);
      expect(manifest['researchOnly'], true);
      expect(manifest['files'], hasLength(4));

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      await directory.delete(recursive: true);
    },
  );
}
