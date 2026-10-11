// Run with flutter test; transforms only an explicitly supplied scratch set.
// Uses exactly the same orientation/resize/metadata stripping/JPEG path as import.
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/local_store.dart';

void main() {
  const sourcePath = String.fromEnvironment('ATLAS_SCREEN_FIXTURES');
  const targetPath = String.fromEnvironment('ATLAS_SCREEN_PREPARED');
  test(
    'prepare frozen fixtures through the real gallery/camera storage path',
    () async {
      expect(sourcePath.isNotEmpty && targetPath.isNotEmpty, isTrue);
      expect(
        Directory(sourcePath).absolute.path,
        isNot(Directory(targetPath).absolute.path),
      );
      final source = Directory(sourcePath);
      final target = Directory(targetPath);
      await target.create(recursive: true);
      final manifest =
          jsonDecode(await File('${source.path}/manifest.json').readAsString())
              as List;
      final rows = <Map<String, dynamic>>[];
      for (final raw in manifest) {
        final row = Map<String, dynamic>.from(raw as Map);
        final name = row['file'] as String;
        expect(RegExp(r'^sample-[0-9]+\.jpg$').hasMatch(name), isTrue);
        final input = await File('${source.path}/$name').readAsBytes();
        expect(sha256.convert(input).toString(), row['sha256']);
        final prepared = preparePhoto(input);
        final bytes = prepared['bytes'] as List<int>;
        await File('${target.path}/$name').writeAsBytes(bytes);
        row.addAll({
          'sourceSha256': row['sha256'],
          'sha256': sha256.convert(bytes).toString(),
          'width': prepared['width'],
          'height': prepared['height'],
          'inputPipeline':
              'actual preparePhoto: orientation; max side 2048; metadata removed; JPEG90',
        });
        rows.add(row);
      }
      await File(
        '${target.path}/manifest.json',
      ).writeAsString(jsonEncode(rows));
      expect(rows.length, manifest.length);
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
