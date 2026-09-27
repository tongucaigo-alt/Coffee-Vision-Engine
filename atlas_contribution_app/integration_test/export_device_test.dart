import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:atlas_contribution_app/src/local_store.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'package:atlas_contribution_app/src/mvp/review_models.dart';
import 'package:atlas_contribution_app/src/mvp/review_preparation.dart';
import 'package:atlas_contribution_app/src/mvp/review_store.dart';
import 'package:atlas_contribution_app/src/offline_contribution.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../test/fixtures.dart';

const _channel = MethodChannel('atlas.contribution/export');
const _timestamp = '2026-09-22T00:00:00Z';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('both research exporters save verified synthetic native ZIPs', (
    tester,
  ) async {
    // Production does not implement this method. Fail before opening any
    // directory or creating an export unless the diagnostic APK is running.
    await expectLater(
      _channel.invokeMethod<Uint8List>('readDiagnosticExport', {
        'location': 'unregistered-diagnostic-safety-probe',
      }),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'invalid_diagnostic_export',
        ),
      ),
      reason: 'This test requires the isolated diagnostic Android package.',
    );

    final cache = await getTemporaryDirectory();
    final root = await cache.createTemp('atlas-native-export-fixtures-');
    addTearDown(() => root.delete(recursive: true));
    final contributions = DraftStore(
      Directory(path.join(root.path, 'offline-contributions')),
    );
    final reviews = ReviewStore(
      Directory(path.join(root.path, 'mvp-reviews')),
      contributionStore: contributions,
    );
    await contributions.initialize();
    await reviews.initialize();

    final pendingDownloads = <String>{};
    void trackDownload(String location) {
      pendingDownloads.add(location);
      addTearDown(() async {
        if (pendingDownloads.contains(location)) {
          expect(
            await _channel.invokeMethod<bool>('deleteDiagnosticExport', {
              'location': location,
            }),
            isTrue,
          );
          pendingDownloads.remove(location);
        }
      });
    }

    Future<void> deleteDownload(String location) async {
      expect(
        await _channel.invokeMethod<bool>('deleteDiagnosticExport', {
          'location': location,
        }),
        isTrue,
      );
      pendingDownloads.remove(location);
      await expectLater(
        _channel.invokeMethod<Uint8List>('readDiagnosticExport', {
          'location': location,
        }),
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'invalid_diagnostic_export',
          ),
        ),
      );
    }

    final prepared = preparePhoto(testImage());
    final photoBytes = prepared['bytes']! as Uint8List;
    final marker = RegionAnnotation(
      id: 'synthetic-bird',
      label: 'bird',
      box: RegionBox(.3, .35, .15, .15),
    );
    ContributionPhoto photo(String name, {CaptureRole? role}) =>
        ContributionPhoto(
          role: role,
          localName: name,
          checksum: prepared['checksum']! as String,
          originalChecksum: prepared['originalChecksum']! as String,
          width: prepared['width']! as int,
          height: prepared['height']! as int,
          byteLength: photoBytes.length,
          capturedAt: role == null ? null : _timestamp,
          importedAt: role == null ? _timestamp : null,
          decision: PhotoDecision.marked,
          regions: [marker],
        );

    final photos = <ContributionPhoto>[];
    for (final role in legacyCaptureRoles) {
      final item = photo('${role.name}.jpg', role: role).asSetPhoto();
      await contributions.file(item.localName).writeAsBytes(photoBytes);
      photos.add(item);
    }
    final saucer = photo(
      'optional-saucer.jpg',
    ).asSetPhoto(type: PhotoSurface.saucer);
    await contributions.file(saucer.localName).writeAsBytes(photoBytes);
    photos.add(saucer);
    final base = testDraft();
    final draft = ContributionDraft(
      id: base.id,
      rootId: base.rootId,
      groupId: base.groupId,
      createdAt: base.createdAt,
      consentedAt: base.consentedAt,
      kind: ContributionKind.photoSet,
      galleryStart: false,
      cupSelectionDone: true,
      saucerDecided: true,
      photos: photos,
    );
    final receipt = await OfflineContributionService(contributions).submit(
      draft,
      (item) => contributions.file(item.localName).readAsBytes(),
      (_) {},
    );
    await contributions.saveReceipt(receipt);

    final contributionResult = await OfflineContributionExporter(
      contributions,
      reviewStore: reviews,
    ).exportToDownloads();
    trackDownload(contributionResult.location);
    expect(contributionResult.fileName, startsWith('atlas-katki-'));
    expect(contributionResult.recordCount, 1);
    final contributionBytes = await _readDownload(contributionResult.location);
    final contributionFiles = _verifyArchive(
      contributionBytes,
      contributionResult.checksum,
      checksumKey: 'sha256',
    );
    final contributionManifest = _document(contributionFiles['manifest.json']!);
    expect(contributionManifest['format'], 'atlas-contribution-offline-export');
    expect(contributionManifest['recordCount'], 1);
    expect(contributionManifest['version'], 4);
    expect(contributionManifest['researchOnly'], isTrue);
    expect(
      contributionFiles.keys,
      unorderedEquals([
        'manifest.json',
        'records/${draft.id}/record.json',
        for (final item in photos) 'records/${draft.id}/${item.fileKey}.jpg',
      ]),
    );
    expect(
      _document(contributionFiles['records/${draft.id}/record.json']!)['id'],
      draft.id,
    );
    for (final item in photos) {
      expect(
        contributionFiles['records/${draft.id}/${item.fileKey}.jpg'],
        orderedEquals(photoBytes),
      );
    }

    final reviewPhoto = ReviewPhoto(
      id: 'synthetic-photo',
      photo: photo('synthetic-review-photo.jpg'),
      surface: ReviewSurface.cup,
      usableConfirmedAtUtc: _timestamp,
      quality: const {'source': 'gallery', 'automaticUsability': 'unknown'},
    );
    await reviews.file(reviewPhoto.photo.localName).writeAsBytes(photoBytes);
    final initialReview = ReviewSession(
      id: 'synthetic-review',
      groupId: 'synthetic-review-group',
      createdAtUtc: _timestamp,
      localConsentAtUtc: _timestamp,
      researchConsentAtUtc: _timestamp,
      sameSampleDeclared: true,
      photos: [reviewPhoto],
    );
    await reviews.save(initialReview);
    final review = captureInitialObservations(
      initialReview,
      capturedAtUtc: _timestamp,
    );
    await reviews.save(review);
    final reviewResult = await reviews.exportToDownloads();
    trackDownload(reviewResult.location);
    expect(reviewResult.name, startsWith('atlas-reviews-'));
    expect(reviewResult.count, 1);
    final reviewBytes = await _readDownload(reviewResult.location);
    final reviewFiles = _verifyArchive(
      reviewBytes,
      reviewResult.checksum,
      checksumKey: 'checksum',
    );
    final reviewManifest = _document(reviewFiles['manifest.json']!);
    expect(reviewManifest['version'], 'atlas-review-export-v3');
    expect(reviewManifest['recordCount'], 1);
    expect(reviewManifest['researchOnly'], isTrue);
    expect(
      reviewFiles.keys,
      unorderedEquals([
        'manifest.json',
        'reviews/${review.id}/record.json',
        'reviews/${review.id}/interpretation-input.json',
        'reviews/${review.id}/initial-observations.json',
        'reviews/${review.id}/${reviewPhoto.id}.jpg',
      ]),
    );
    expect(
      _document(reviewFiles['reviews/${review.id}/record.json']!)['id'],
      review.id,
    );
    expect(
      reviewFiles['reviews/${review.id}/${reviewPhoto.id}.jpg'],
      orderedEquals(photoBytes),
    );
    final record = _document(reviewFiles['reviews/${review.id}/record.json']!);
    expect(record['photos'][0]['photo']['regions'][0], marker.toJson());
    expect(record['initialObservations'], review.initialObservations);

    Future<void> reject(String sourcePath, String fileName) async {
      try {
        final location = await _channel.invokeMethod<String>(
          'saveToDownloads',
          {'sourcePath': sourcePath, 'fileName': fileName},
        );
        if (location != null) trackDownload(location);
        fail(
          'Native validation unexpectedly accepted a synthetic invalid export.',
        );
      } on PlatformException catch (error) {
        expect(error.code, 'invalid_export');
        expect(error.details, isNull);
        expect(error.message, isNot(contains(sourcePath)));
      }
    }

    final source = File(path.join(root.path, 'synthetic-source.zip'));
    await source.writeAsBytes(contributionBytes);
    await reject(source.path, 'unknown-prefix.zip');
    await reject(source.path, '../atlas-katki-traversal.zip');
    await reject(root.path, 'atlas-katki-directory.zip');

    final support = await getApplicationSupportDirectory();
    final outside = await support.createTemp('atlas-native-export-outside-');
    addTearDown(() => outside.delete(recursive: true));
    final outsideSource = File(path.join(outside.path, 'synthetic-source.zip'));
    await outsideSource.writeAsBytes(contributionBytes);
    await reject(outsideSource.path, 'atlas-katki-outside.zip');
    final escapeLink = Link(path.join(root.path, 'escaping-source.zip'));
    await escapeLink.create(outsideSource.path);
    await reject(escapeLink.path, 'atlas-reviews-symlink.zip');

    final canonicalCache = Directory(await cache.resolveSymbolicLinks());
    final sibling = await canonicalCache.parent.createTemp(
      '${path.basename(canonicalCache.path)}-native-export-sibling-',
    );
    addTearDown(() => sibling.delete(recursive: true));
    final siblingSource = File(path.join(sibling.path, 'synthetic-source.zip'));
    await siblingSource.writeAsBytes(contributionBytes);
    await reject(siblingSource.path, 'atlas-katki-sibling.zip');
    await reject(
      '${canonicalCache.path}/../${path.basename(sibling.path)}/synthetic-source.zip',
      'atlas-reviews-traversal.zip',
    );

    await deleteDownload(contributionResult.location);
    await deleteDownload(reviewResult.location);
    binding.reportData = {
      'syntheticNativeExports': [
        {
          'name': contributionResult.fileName,
          'location': contributionResult.location,
          'checksum': contributionResult.checksum,
          'bytes': contributionBytes.length,
          'deleted': true,
        },
        {
          'name': reviewResult.name,
          'location': reviewResult.location,
          'checksum': reviewResult.checksum,
          'bytes': reviewBytes.length,
          'deleted': true,
        },
      ],
      'nativeValidation':
          'prefix, filename traversal, directory, outside cache, '
          'escaping symlink, sibling prefix, source traversal',
    };
    // Retain only synthetic evidence in the isolated diagnostic app so it can
    // be pulled and independently checked on the computer after this test.
    final evidence = Directory(path.join(support.path, 'export-validation'));
    await evidence.create(recursive: true);
    await File(
      path.join(evidence.path, 'contribution.zip'),
    ).writeAsBytes(contributionBytes);
    await File(
      path.join(evidence.path, 'review.zip'),
    ).writeAsBytes(reviewBytes);
    await File(
      path.join(evidence.path, 'report.json'),
    ).writeAsString(jsonEncode(binding.reportData));
  });
}

Future<Uint8List> _readDownload(String location) async {
  final bytes = await _channel.invokeMethod<Uint8List>('readDiagnosticExport', {
    'location': location,
  });
  expect(bytes, isNotNull);
  return bytes!;
}

Map<String, dynamic> _document(List<int> bytes) =>
    Map<String, dynamic>.from(jsonDecode(utf8.decode(bytes)) as Map);

Map<String, List<int>> _verifyArchive(
  Uint8List bytes,
  String expectedChecksum, {
  required String checksumKey,
}) {
  expect('sha256:${sha256.convert(bytes)}', expectedChecksum);
  final archive = ZipDecoder().decodeBytes(bytes, verify: true);
  final files = <String, List<int>>{
    for (final file in archive.files)
      if (file.isFile) file.name: file.content as List<int>,
  };
  expect(files.length, archive.files.where((file) => file.isFile).length);
  final manifest = _document(files['manifest.json']!);
  final inventory = (manifest['files'] as List).cast<Map>();
  expect(
    inventory.map((entry) => entry['path']),
    unorderedEquals(files.keys.where((name) => name != 'manifest.json')),
  );
  for (final entry in inventory) {
    final content = files[entry['path']]!;
    expect(content.length, entry['bytes']);
    expect('sha256:${sha256.convert(content)}', entry[checksumKey]);
  }
  return files;
}
