import 'dart:io';
import 'dart:typed_data';

import 'package:atlas_canonical_json/atlas_canonical_json.dart';

void main(List<String> arguments) {
  if (arguments.length != 1) {
    stderr.writeln('Usage: dart run tool/profile_checksum.dart <descriptor>');
    exitCode = 64;
    return;
  }
  final bytes = File(arguments.single).readAsBytesSync();
  final result = const AtlasCanonicalJson().canonicalizeUtf8(
    Uint8List.fromList(bytes),
  );
  stdout.writeln(result.checksum);
}
