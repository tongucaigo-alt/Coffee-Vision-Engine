import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
  onScreenshot: (name, bytes, [args]) async {
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(name)) return false;
    final folder = Directory('build/diagnostic-screenshots');
    await folder.create(recursive: true);
    await File('${folder.path}/$name.png').writeAsBytes(bytes, flush: true);
    return bytes.isNotEmpty;
  },
);
