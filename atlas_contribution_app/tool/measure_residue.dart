// Reuses the exact application adapter with captured native scores. Source
// files are never modified. Calibration is filtered before measurements run.
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:atlas_contribution_app/src/mvp/photo_residue_check.dart';

Future<void> main(List<String> args) async {
  if (args.length != 4 || !['calibration', 'validation'].contains(args[2])) {
    throw ArgumentError(
      'results.json fixture-directory calibration|validation out.json',
    );
  }
  final input = jsonDecode(await File(args[0]).readAsString()) as Map;
  final rows = <Map<String, dynamic>>[];
  for (final item in input['rows'] as List) {
    if (item['split'] != args[2]) continue;
    final row = Map<String, dynamic>.from(item as Map);
    if (!RegExp(r'^sample-[0-9]+\.jpg$').hasMatch(row['file'] as String)) {
      throw const FormatException('Fixture name');
    }
    final bytes = await File('${args[1]}/${row['file']}').readAsBytes();
    if (sha256.convert(bytes).toString() != row['sha256']) {
      throw const FormatException('Fixture checksum');
    }
    row['physical'] = await measurePhotoResidue({
      'bytes': bytes,
      'crop': [0.0, 0.0, 1.0, 1.0],
    });
    row['candidateStatus'] = row['object'] == 'unsuitable'
        ? 'unsuitable'
        : residueDecision(
            row['scores'] as Map,
            row['physical'] as Map<String, dynamic>,
            saucer: row['surface'] == 'saucer',
          );
    rows.add(row);
  }
  await File(args[3]).writeAsString(
    jsonEncode({
      'measurementVersion': 'atlas-residue-screen-v2',
      'complete': input['complete'],
      'blockingEnabled': false,
      'rows': rows,
    }),
  );
  stdout.writeln('${args[2]}: ${rows.length} measured');
}
