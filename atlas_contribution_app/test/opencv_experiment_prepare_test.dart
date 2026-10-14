import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/local_store.dart';
import 'package:atlas_contribution_app/src/opencv_traces.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final manifest = Platform.environment['ATLAS_TRACE_FIXTURES'];
  test(
    'experiment uses unchanged gallery import and trace preparation',
    () async {
      final source = File(manifest!);
      final rows = jsonDecode(await source.readAsString()) as List;
      final output = Directory('${source.parent.path}/prepared');
      await output.create(recursive: true);
      for (final row in rows) {
        final photo = preparePhoto(
          await File(row['source'] as String).readAsBytes(),
        );
        final png = prepareTraceImage({
          'bytes': photo['bytes'] as Uint8List,
          'area': (row['crop'] as List)
              .cast<num>()
              .map((v) => v.toDouble())
              .toList(),
        });
        await File('${output.path}/${row['id']}.png').writeAsBytes(png);
      }
      expect(rows.length, 24);
    },
    skip: manifest == null ? 'Optional external comparison fixtures' : false,
  );
}
