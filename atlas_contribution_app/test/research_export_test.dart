import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:atlas_contribution_app/src/local_store.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'package:atlas_contribution_app/src/mvp/review_models.dart';
import 'package:atlas_contribution_app/src/mvp/review_store.dart';
import 'package:atlas_contribution_app/src/offline_contribution.dart';
import 'package:atlas_contribution_app/src/research_export.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

Matcher fails(ExportFailureCode code) =>
    throwsA(isA<ExportFailure>().having((e) => e.code, 'code', code));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test.atlas/research-export');
  late Directory root;
  late Directory stagingRoot;
  late DraftStore store;
  late ReviewStore reviews;
  late ContributionDraft draft;
  late Map<String, dynamic> receipt;
  late List<Uint8List> saved;
  late List<String> sources;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('atlas-research-export-test-');
    stagingRoot = await Directory('${root.path}/cache').create();
    store = DraftStore(Directory('${root.path}/offline-contributions'));
    reviews = ReviewStore(
      Directory('${root.path}/mvp-reviews'),
      contributionStore: store,
    );
    await store.initialize();
    await reviews.initialize();
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
          capturedAt: DateTime.now().toUtc().toIso8601String(),
          decision: PhotoDecision.skipped,
        ),
      );
    }
    draft = testDraft(photos: photos);
    receipt = await OfflineContributionService(
      store,
    ).submit(draft, (p) => store.file(p.localName).readAsBytes(), (_) {});
    saved = [];
    sources = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'saveToDownloads');
          final arguments = call.arguments as Map;
          final source = arguments['sourcePath'] as String;
          expect(
            source,
            startsWith('${stagingRoot.path}${Platform.pathSeparator}'),
          );
          expect(
            arguments['fileName'],
            matches(r'^atlas-(katki|reviews)-[A-Za-z0-9._-]+\.zip$'),
          );
          sources.add(source);
          saved.add(await File(source).readAsBytes());
          return 'content://downloads/synthetic-${saved.length}';
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await root.delete(recursive: true);
  });

  ReviewSession session({bool consent = true, bool linked = true, String? id}) {
    final now = DateTime.now().toUtc().toIso8601String();
    return ReviewSession(
      id: id ?? (linked ? 'linked-${draft.rootId}' : 'independent-review'),
      groupId: draft.groupId,
      createdAtUtc: now,
      localConsentAtUtc: now,
      researchConsentAtUtc: consent ? now : null,
    );
  }

  OfflineContributionExporter exporter({
    Future<Map<String, dynamic>> Function(String)? audit,
  }) => OfflineContributionExporter(
    store,
    channel: channel,
    temporaryDirectory: () async => stagingRoot,
    exposureAudit: audit,
  );

  Future<dynamic> reviewExport() => reviews.exportToDownloads(
    channel: channel,
    temporaryDirectory: () async => stagingRoot,
  );

  test(
    'AI-off fallback honors exact linked root, all revisions and tombstones',
    () async {
      await store.saveReceipt(receipt);
      // Same group must not grant consent to this contribution's different root.
      await reviews.save(session(id: 'linked-other-root'));
      final first = await exporter().exportToDownloads();
      expect(first.recordCount, 1);
      final linked = session(consent: false);
      await reviews.save(linked);
      await store.saveReceipt({...receipt, 'id': 'second-receipt'});
      await expectLater(
        exporter().exportToDownloads(),
        fails(ExportFailureCode.noPermission),
      );
      final allowed = linked.next(researchAllowed: true);
      await reviews.save(allowed);
      expect((await exporter().exportToDownloads()).recordCount, 2);
      await reviews.delete(allowed);
      await expectLater(
        exporter().exportToDownloads(),
        fails(ExportFailureCode.noPermission),
      );
      expect(await stagingRoot.list().toList(), isEmpty);
    },
  );

  test(
    'both ZIPs retain manifests, checksum and save locations and clean staging',
    () async {
      await store.saveReceipt(receipt);
      await reviews.save(session());
      final contribution = await exporter().exportToDownloads();
      final review = await reviewExport();
      expect(contribution.checksum, 'sha256:${sha256.convert(saved.first)}');
      expect(review.checksum, 'sha256:${sha256.convert(saved.last)}');
      expect(review.location, 'content://downloads/synthetic-2');
      final contributionZip = ZipDecoder().decodeBytes(saved.first);
      final reviewZip = ZipDecoder().decodeBytes(saved.last);
      expect(
        jsonDecode(
          utf8.decode(contributionZip.findFile('manifest.json')!.content),
        )['format'],
        'atlas-contribution-offline-export',
      );
      expect(
        jsonDecode(
          utf8.decode(reviewZip.findFile('manifest.json')!.content),
        )['version'],
        'atlas-review-export-v3',
      );
      expect(
        contributionZip.files.where((f) => f.name.endsWith('.jpg')),
        hasLength(3),
      );
      for (final source in sources) {
        expect(await File(source).exists(), isFalse);
      }
      expect(await stagingRoot.list().toList(), isEmpty);
    },
  );

  test(
    'empty records and denied research consent have separate failures',
    () async {
      await expectLater(
        exporter().exportToDownloads(),
        fails(ExportFailureCode.noRecords),
      );
      await expectLater(reviewExport(), fails(ExportFailureCode.noRecords));
      await reviews.save(session(consent: false, linked: false));
      await expectLater(reviewExport(), fails(ExportFailureCode.noPermission));
      expect(saved, isEmpty);
    },
  );

  test(
    'review export releases queue while packaging and rechecks withdrawal from another instance',
    () async {
      final original = session(linked: false);
      await reviews.save(original);
      reviews.aiExposureAudit = (_) async {
        final other = ReviewStore(reviews.directory, contributionStore: store);
        await other.save(original.next(researchAllowed: false));
        return {};
      };
      await expectLater(reviewExport(), fails(ExportFailureCode.noPermission));
      expect(saved, isEmpty);
      expect(await stagingRoot.list().toList(), isEmpty);
    },
  );

  for (final action in ['withdraw', 'delete']) {
    test(
      'contribution final validation prevents $action during preparation',
      () async {
        await store.saveReceipt(receipt);
        final linked = session();
        await reviews.save(linked);
        final operation = exporter(
          audit: (_) async {
            if (action == 'withdraw') {
              await reviews.save(linked.next(researchAllowed: false));
            } else if (action == 'delete') {
              final other = DraftStore(store.directory);
              await other.queueDelete(draft.rootId);
            } else {
              await store.saveReceipt({
                ...receipt,
                'expires_at': '2000-01-01T00:00:00Z',
              });
            }
            return {};
          },
        );
        await expectLater(
          operation.exportToDownloads(),
          fails(
            action == 'withdraw'
                ? ExportFailureCode.noPermission
                : ExportFailureCode.noRecords,
          ),
        );
        expect(saved, isEmpty);
        expect(await stagingRoot.list().toList(), isEmpty);
      },
    );
  }

  test(
    'linked review source deletion and expiry are checked again before saving',
    () async {
      await store.saveReceipt(receipt);
      await reviews.save(session());
      reviews.aiExposureAudit = (_) async {
        await store.queueDelete(draft.rootId);
        return {};
      };
      await expectLater(reviewExport(), fails(ExportFailureCode.noRecords));
      expect(saved, isEmpty);
      await store.saveReceipt({
        ...receipt,
        'expires_at': '2000-01-01T00:00:00Z',
      });
      await expectLater(reviewExport(), fails(ExportFailureCode.noRecords));
    },
  );

  test(
    'corrupt linked registry fails closed and missing photo reports integrity',
    () async {
      await store.saveReceipt(receipt);
      await reviews.file('review-invalid-1.json').writeAsString('not-json');
      await expectLater(
        exporter().exportToDownloads(),
        fails(ExportFailureCode.integrity),
      );
      await reviews.file('review-invalid-1.json').delete();
      await store.file(draft.photos.first.localName).delete();
      await expectLater(
        exporter().exportToDownloads(),
        fails(ExportFailureCode.integrity),
      );
      expect(saved, isEmpty);
      expect(await stagingRoot.list().toList(), isEmpty);
    },
  );

  test(
    'native rejection is a safe save error and staging is removed',
    () async {
      await store.saveReceipt(receipt);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async {
            throw PlatformException(
              code: 'invalid_export',
              message: '/private/secret/path',
            );
          });
      await expectLater(
        exporter().exportToDownloads(),
        fails(ExportFailureCode.save),
      );
      expect(
        exportFailureMessage(PlatformException(code: 'secret')),
        isNot(contains('secret')),
      );
      expect(await stagingRoot.list().toList(), isEmpty);
      expect(
        exportDestinationLabel('content://downloads/1'),
        'İndirilenler klasörüne',
      );
      expect(
        exportDestinationLabel('/app/files/Download/export.zip'),
        'uygulamanın İndirilenler klasörüne',
      );
    },
  );
}
