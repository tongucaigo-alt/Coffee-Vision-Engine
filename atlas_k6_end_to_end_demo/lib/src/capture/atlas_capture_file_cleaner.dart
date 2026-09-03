import 'dart:io';

import 'package:coffee_camera/coffee_camera.dart';

final class AtlasCaptureFileCleaner {
  const AtlasCaptureFileCleaner();

  Future<void> release(Iterable<CameraCaptureResult> captures) async {
    final paths = <String>{};
    for (final capture in captures) {
      paths
        ..add(capture.filePath)
        ..addAll([?capture.croppedCupPath, ?capture.croppedSaucerPath]);
    }
    for (final path in paths) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } on FileSystemException {
        // Capture cleanup is best effort after application ownership ends.
      }
    }
  }
}
