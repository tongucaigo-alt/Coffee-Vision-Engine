// Replays actual V34 rules over existing diagnostic measurements. No images,
// network requests, model inference or production settings are changed.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/photo_suitability.dart';
import 'package:atlas_contribution_app/src/mvp/photo_residue_check.dart';

void main() {
  final source = Platform.environment['ATLAS_REPLAY_INPUT'];
  final output = Platform.environment['ATLAS_REPLAY_OUTPUT'];
  test('replay frozen V34 decisions from diagnostic scores', () async {
    final document = jsonDecode(await File(source!).readAsString()) as Map;
    for (final row in document['rows'] as List) {
      if (row['candidateStatus'] == 'error') continue;
      final object = classifySuitability(row['scores'] as Map);
      row['candidateStatus'] = object == 'unsuitable'
          ? object
          : residueDecision(
              row['scores'] as Map,
              Map<String, dynamic>.from(row['physical'] as Map),
              saucer: row['surface'] == 'saucer',
            );
    }
    document['version'] = suitabilityVersion;
    document['measurementNote'] =
        'V34 decision replay over V35 device scores; not fresh V34 inference. '
        'V35 native EXIF handling differs. Boundary fields are ignored.';
    await File(output!).writeAsString(jsonEncode(document));
  }, skip: source == null || output == null);
}
