import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

import '../tool/src/k6a_dataset.dart';

void main() {
  group('K6A dataset preflight', () {
    test('validates a frozen manifest and preserves manifest order', () async {
      final fixture = await _DatasetFixture.create();
      addTearDown(fixture.dispose);

      final dataset = await const K6aDatasetPreflight().validate(
        datasetRoot: fixture.root.path,
        manifestPath: fixture.manifest.path,
        freezePath: fixture.freeze.path,
      );

      expect(dataset.datasetVersion, 'm5b-test');
      expect(dataset.entries.map((entry) => entry.sourceId), [
        'cup-001',
        'saucer-001',
      ]);
      expect(
        () => dataset.entries.add(dataset.entries.first),
        throwsUnsupportedError,
      );
    });

    test('rejects a manifest checksum that differs from freeze', () async {
      final fixture = await _DatasetFixture.create(
        freezeManifestChecksum:
            'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      );
      addTearDown(fixture.dispose);

      await expectLater(
        const K6aDatasetPreflight().validate(
          datasetRoot: fixture.root.path,
          manifestPath: fixture.manifest.path,
          freezePath: fixture.freeze.path,
        ),
        throwsA(
          isA<K6aDatasetException>().having(
            (error) => error.message,
            'message',
            contains('Manifest checksum'),
          ),
        ),
      );
    });

    test('rejects content checksum mismatch', () async {
      final fixture = await _DatasetFixture.create(
        firstContentChecksum:
            'sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      );
      addTearDown(fixture.dispose);

      await expectLater(
        const K6aDatasetPreflight().validate(
          datasetRoot: fixture.root.path,
          manifestPath: fixture.manifest.path,
          freezePath: fixture.freeze.path,
        ),
        throwsA(
          isA<K6aDatasetException>().having(
            (error) => error.message,
            'message',
            contains('Checksum mismatch'),
          ),
        ),
      );
    });

    test('rejects duplicate physical checksums', () async {
      final fixture = await _DatasetFixture.create(useSameBytes: true);
      addTearDown(fixture.dispose);

      await expectLater(
        const K6aDatasetPreflight().validate(
          datasetRoot: fixture.root.path,
          manifestPath: fixture.manifest.path,
          freezePath: fixture.freeze.path,
        ),
        throwsA(
          isA<K6aDatasetException>().having(
            (error) => error.message,
            'message',
            contains('Duplicate physical checksum'),
          ),
        ),
      );
    });

    test('rejects empty ownership before analysis', () async {
      final fixture = await _DatasetFixture.create(ownership: '  ');
      addTearDown(fixture.dispose);

      await expectLater(
        const K6aDatasetPreflight().validate(
          datasetRoot: fixture.root.path,
          manifestPath: fixture.manifest.path,
          freezePath: fixture.freeze.path,
        ),
        throwsA(isA<K6aDatasetException>()),
      );
    });

    test('rejects unknown manifest fields', () async {
      final fixture = await _DatasetFixture.create(includeUnknownField: true);
      addTearDown(fixture.dispose);

      await expectLater(
        const K6aDatasetPreflight().validate(
          datasetRoot: fixture.root.path,
          manifestPath: fixture.manifest.path,
          freezePath: fixture.freeze.path,
        ),
        throwsA(
          isA<K6aDatasetException>().having(
            (error) => error.message,
            'message',
            contains('unknown fields'),
          ),
        ),
      );
    });
  });
}

final class _DatasetFixture {
  const _DatasetFixture({
    required this.root,
    required this.manifest,
    required this.freeze,
  });

  final Directory root;
  final File manifest;
  final File freeze;

  static Future<_DatasetFixture> create({
    bool useSameBytes = false,
    String ownership = 'user-owned',
    String? freezeManifestChecksum,
    String? firstContentChecksum,
    bool includeUnknownField = false,
  }) async {
    final root = await Directory.systemTemp.createTemp('atlas-k6a-dataset-');
    final cupDirectory = Directory(
      '${root.path}${Platform.pathSeparator}images'
      '${Platform.pathSeparator}cup',
    );
    final saucerDirectory = Directory(
      '${root.path}${Platform.pathSeparator}images'
      '${Platform.pathSeparator}saucer',
    );
    await cupDirectory.create(recursive: true);
    await saucerDirectory.create(recursive: true);

    final cupBytes = await File(
      '..${Platform.pathSeparator}coffee_vision'
      '${Platform.pathSeparator}test${Platform.pathSeparator}fixtures'
      '${Platform.pathSeparator}valid_2x3.png',
    ).readAsBytes();
    final saucerBytes = useSameBytes
        ? cupBytes
        : await File(
            '..${Platform.pathSeparator}coffee_vision'
            '${Platform.pathSeparator}test${Platform.pathSeparator}fixtures'
            '${Platform.pathSeparator}valid_3x2.jpg',
          ).readAsBytes();
    await File(
      '${cupDirectory.path}${Platform.pathSeparator}cup.png',
    ).writeAsBytes(cupBytes);
    await File(
      '${saucerDirectory.path}${Platform.pathSeparator}saucer.jpg',
    ).writeAsBytes(saucerBytes);

    final firstEntry = <String, Object?>{
      'sourceId': 'cup-001',
      'relativePath': 'images/cup/cup.png',
      'surfaceType': 'cup',
      'format': 'png',
      'ownership': ownership,
      'consent': 'local-validation',
      'enabled': true,
      'contentChecksum':
          firstContentChecksum ?? 'sha256:${sha256.convert(cupBytes)}',
      if (includeUnknownField) 'unknown': true,
    };
    final secondEntry = <String, Object?>{
      'sourceId': 'saucer-001',
      'relativePath': 'images/saucer/saucer.jpg',
      'surfaceType': 'saucer',
      'format': 'jpeg',
      'ownership': 'user-owned',
      'consent': 'local-validation',
      'enabled': true,
      'contentChecksum': 'sha256:${sha256.convert(saucerBytes)}',
    };
    final manifestSource =
        '${const JsonEncoder.withIndent('  ').convert({
          'schemaVersion': '1.0',
          'entries': [firstEntry, secondEntry],
        })}\n';
    final manifest = File(
      '${root.path}${Platform.pathSeparator}manifests'
      '${Platform.pathSeparator}dataset_manifest.json',
    );
    await manifest.parent.create(recursive: true);
    await manifest.writeAsString(manifestSource);
    final manifestChecksum =
        freezeManifestChecksum ??
        'sha256:${sha256.convert(utf8.encode(manifestSource))}';
    final freeze = File(
      '${root.path}${Platform.pathSeparator}records'
      '${Platform.pathSeparator}dataset_freeze.txt',
    );
    await freeze.parent.create(recursive: true);
    await freeze.writeAsString('''
datasetVersion=m5b-test
physicalCupCount=1
physicalSaucerCount=1
physicalTotalCount=2
enabledCupCount=1
enabledSaucerCount=1
enabledTotalCount=2
disabledCount=0
duplicateCount=0
manifestSha256=$manifestChecksum
manifestRelativePath=manifests/dataset_manifest.json
''');
    return _DatasetFixture(root: root, manifest: manifest, freeze: freeze);
  }

  Future<void> dispose() => root.delete(recursive: true);
}
