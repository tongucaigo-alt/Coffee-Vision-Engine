// Diagnostic-only entrypoint. Never embeds a provider key or uses user records.
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:atlas_contribution_app/src/mvp/photo_residue_check.dart';
import 'package:atlas_contribution_app/src/photo_suitability.dart';

final progress = ValueNotifier<String>('Ölçüm başlıyor');
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: ValueListenableBuilder<String>(
              valueListenable: progress,
              builder: (_, value, _) => Text(value),
            ),
          ),
        ),
      ),
    ),
  );
  try {
    const base = '/data/local/tmp/atlas-suitability/v3';
    final manifest =
        jsonDecode(await File('$base/manifest.json').readAsString()) as List;
    final root = await getApplicationSupportDirectory();
    final output = File(
      '${(await getExternalStorageDirectory())!.path}/suitability-v3-results.json',
    );
    final rows = <Map<String, dynamic>>[];
    for (final item in manifest) {
      final name = item['file'] as String;
      if (!RegExp(r'^sample-[0-9]+\.jpg$').hasMatch(name)) {
        throw const FormatException('Fixture name');
      }
      final source = File('$base/$name');
      final bytes = await source.readAsBytes();
      if (sha256.convert(bytes).toString() != item['sha256']) {
        throw const FormatException('Fixture checksum');
      }
      final file = await File('${root.path}/$name').writeAsBytes(bytes);
      final clock = Stopwatch()..start();
      final row = Map<String, dynamic>.from(item as Map);
      try {
        final scores = await PhotoSuitability.channel
            .invokeMapMethod<dynamic, dynamic>('classify', {
              'path': file.path,
              'crop': [0.0, 0.0, 1.0, 1.0],
            });
        final object = classifySuitability(scores!);
        final physical = await compute(measurePhotoResidue, <String, dynamic>{
          'bytes': bytes,
          'crop': [0.0, 0.0, 1.0, 1.0],
        });
        row.addAll({
          'scores': scores,
          'physical': physical,
          'object': object,
          'candidateStatus': object == 'unsuitable'
              ? object
              : residueDecision(
                  scores,
                  physical,
                  saucer: item['surface'] == 'saucer',
                ),
        });
      } catch (e) {
        row['candidateStatus'] = 'error';
        row['errorType'] = e.runtimeType.toString();
      }
      row['milliseconds'] = clock.elapsedMilliseconds;
      rows.add(row);
      await output.writeAsString(
        jsonEncode({
          'version': suitabilityVersion,
          'blockingEnabled': suitabilityBlockingValidated,
          'rows': rows,
          'complete': rows.length == manifest.length,
        }),
      );
      await file.delete();
      progress.value = '${rows.length}/${manifest.length} fotoğraf ölçüldü';
    }
    progress.value = 'Ölçüm tamamlandı · ${rows.length} fotoğraf';
  } catch (e) {
    progress.value = 'Ölçüm tamamlanamadı: ${e.runtimeType}';
  }
}
