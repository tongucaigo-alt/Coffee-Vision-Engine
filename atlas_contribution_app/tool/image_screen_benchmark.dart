// Separate diagnostic package. No user records, network, or provider keys.
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:atlas_contribution_app/src/photo_suitability.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final progress = ValueNotifier<String>('Yerel model ölçülüyor');
  runApp(
    MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: ValueListenableBuilder<String>(
              valueListenable: progress,
              builder: (_, text, _) => Text(text),
            ),
          ),
        ),
      ),
    ),
  );
  try {
    if (!diagnosticImageScreen) throw StateError('Diagnostic flags required');
    const base = '/data/local/tmp/atlas-suitability/image-screen';
    final manifest =
        jsonDecode(await File('$base/manifest.json').readAsString()) as List;
    final root = await getApplicationSupportDirectory();
    final out = File(
      '${(await getExternalStorageDirectory())!.path}/image-screen-results.json',
    );
    final rows = <Map<String, dynamic>>[];
    for (final item in manifest) {
      final row = Map<String, dynamic>.from(item as Map);
      final name = row['file'] as String;
      if (!RegExp(r'^sample-[0-9]+\.jpg$').hasMatch(name)) {
        throw const FormatException('Fixture name');
      }
      final bytes = await File('$base/$name').readAsBytes();
      if (sha256.convert(bytes).toString() != row['sha256']) {
        throw const FormatException('Fixture checksum');
      }
      final local = await File('${root.path}/$name').writeAsBytes(bytes);
      final watch = Stopwatch()..start();
      try {
        final response = await PhotoSuitability.imageScreenChannel
            .invokeMapMethod<String, dynamic>('assess', {
              'path': local.path,
              'crop': [0.0, 0.0, 1.0, 1.0],
            })
            .timeout(const Duration(seconds: 30));
        row.addAll(response!);
        row['candidateStatus'] = classifyLocalImageScreen(response);
      } catch (error) {
        row.addAll({
          'candidateStatus': 'error',
          'errorType': error.runtimeType.toString(),
        });
      }
      row['milliseconds'] = watch.elapsedMilliseconds;
      rows.add(row);
      await out.writeAsString(
        jsonEncode({
          'rows': rows,
          'complete': rows.length == manifest.length,
          'version': suitabilityVersion,
          'blockingEnabled': false,
          'diagnosticOnly': true,
        }),
      );
      await local.delete();
      progress.value = '${rows.length}/${manifest.length} fotoğraf';
    }
    progress.value = 'Ölçüm tamamlandı · ${rows.length} fotoğraf';
  } catch (error) {
    progress.value = 'Ölçüm tamamlanamadı: ${error.runtimeType}';
  }
}
