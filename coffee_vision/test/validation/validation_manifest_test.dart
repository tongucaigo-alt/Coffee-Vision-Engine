import 'dart:convert';
import 'dart:io';

import 'package:coffee_vision/coffee_vision.dart';
import 'package:test/test.dart';

import '../../tool/validation/src/validation_manifest_parser.dart';
import '../../tool/validation/src/content_checksum.dart';
import 'validation_test_support.dart';

void main() {
  const parser = ValidationManifestParser();

  group('ValidationManifestParser', () {
    test('accepts the canonical synthetic manifest and fixture checksums', () {
      final source = File(
        'validation/manifests/synthetic_manifest.json',
      ).readAsStringSync();
      final manifest = parser.parse(source);

      expect(manifest.entries.length, 2);
      for (final entry in manifest.entries) {
        final bytes = File(
          'test/fixtures/${entry.relativePath}',
        ).readAsBytesSync();
        expect(
          contentChecksumMatches(bytes, entry.contentChecksum),
          isTrue,
          reason: entry.sourceId,
        );
      }
    });

    test('parses strict ordered cup and saucer entries', () {
      final cup = createEntry(sourceId: 'cup-001');
      final saucer = createEntry(
        sourceId: 'saucer-001',
        surfaceType: VisionSurfaceType.saucer,
      );

      final manifest = parser.parse(manifestJson([cup, saucer]));

      expect(manifest.schemaVersion, '1.0');
      expect(manifest.entries, [cup, saucer]);
      expect(() => manifest.entries.clear(), throwsUnsupportedError);
    });

    test('validates disabled entries without removing them', () {
      final entry = createEntry(enabled: false);

      final manifest = parser.parse(manifestJson([entry]));

      expect(manifest.entries.single.enabled, isFalse);
    });

    test('rejects malformed JSON and unsupported schema version', () {
      expect(
        () => parser.parse('{'),
        throwsA(isA<ValidationManifestException>()),
      );
      expect(
        () => parser.parse(
          jsonEncode(<String, Object?>{
            'schemaVersion': '2.0',
            'entries': <Object?>[],
          }),
        ),
        throwsA(isA<ValidationManifestException>()),
      );
    });

    test('rejects unknown and missing root fields', () {
      final validEntry = entryJson(createEntry());
      expect(
        () => parser.parse(
          jsonEncode(<String, Object?>{
            'schemaVersion': '1.0',
            'entries': [validEntry],
            'unknown': true,
          }),
        ),
        throwsA(isA<ValidationManifestException>()),
      );
      expect(
        () =>
            parser.parse(jsonEncode(<String, Object?>{'schemaVersion': '1.0'})),
        throwsA(isA<ValidationManifestException>()),
      );
    });

    test('rejects unknown and missing entry fields', () {
      final unknown = entryJson(createEntry())..['unknown'] = true;
      final missing = entryJson(createEntry())..remove('consent');

      expect(() => parser.parse(_manifestWith(unknown)), _manifestError);
      expect(() => parser.parse(_manifestWith(missing)), _manifestError);
    });

    test('rejects duplicate and blank source ids', () {
      final entry = createEntry();
      expect(() => parser.parse(manifestJson([entry, entry])), _manifestError);
      final blank = entryJson(entry)..['sourceId'] = '  ';
      expect(() => parser.parse(_manifestWith(blank)), _manifestError);
    });

    test('accepts only cup or saucer and png or jpeg', () {
      final invalidSurface = entryJson(createEntry())
        ..['surfaceType'] = 'plate';
      final invalidFormat = entryJson(createEntry())..['format'] = 'webp';

      expect(() => parser.parse(_manifestWith(invalidSurface)), _manifestError);
      expect(() => parser.parse(_manifestWith(invalidFormat)), _manifestError);
    });

    test('rejects unsafe absolute, drive, UNC, dot, and parent paths', () {
      for (final path in <String>[
        '/absolute.png',
        r'C:\sample.png',
        r'C:sample.png',
        r'\\server\share\sample.png',
        './sample.png',
        '../sample.png',
        'folder//sample.png',
      ]) {
        final entry = entryJson(createEntry())..['relativePath'] = path;
        expect(
          () => parser.parse(_manifestWith(entry)),
          _manifestError,
          reason: path,
        );
      }
    });

    test('normalizes safe backslash path separators', () {
      final entry = entryJson(createEntry())
        ..['relativePath'] = r'folder\sample.png';

      final manifest = parser.parse(_manifestWith(entry));

      expect(manifest.entries.single.relativePath, 'folder/sample.png');
    });

    test('requires non-empty ownership and consent', () {
      final ownership = entryJson(createEntry())..['ownership'] = ' ';
      final consent = entryJson(createEntry())..['consent'] = '';

      expect(() => parser.parse(_manifestWith(ownership)), _manifestError);
      expect(() => parser.parse(_manifestWith(consent)), _manifestError);
    });

    test('requires exact lowercase sha256 checksum form', () {
      final zeros = List.filled(64, '0').join();
      final uppercase = List.filled(64, 'A').join();
      for (final checksum in <String>[
        'sha256:abc',
        'SHA256:$zeros',
        'sha256:$uppercase',
        'md5:$zeros',
      ]) {
        final entry = entryJson(createEntry())..['contentChecksum'] = checksum;
        expect(() => parser.parse(_manifestWith(entry)), _manifestError);
      }
    });

    test('requires exact JSON value types', () {
      final enabled = entryJson(createEntry())..['enabled'] = 'true';
      final sourceId = entryJson(createEntry())..['sourceId'] = 1;

      expect(() => parser.parse(_manifestWith(enabled)), _manifestError);
      expect(() => parser.parse(_manifestWith(sourceId)), _manifestError);
    });
  });
}

final _manifestError = throwsA(isA<ValidationManifestException>());

String _manifestWith(Map<String, Object?> entry) {
  return jsonEncode(<String, Object?>{
    'schemaVersion': '1.0',
    'entries': [entry],
  });
}
