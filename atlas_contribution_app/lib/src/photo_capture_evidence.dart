import 'dart:convert';
import 'dart:io';

import 'package:coffee_camera/coffee_camera.dart';
import 'package:crypto/crypto.dart';

import 'models.dart';
import 'photo_crop.dart';

/// Optional evidence from an existing, fresh automatic camera capture.
/// It never changes the camera or the durable photo/record schema.
class PhotoCaptureEvidence {
  PhotoCaptureEvidence(this.directory);
  final Directory directory;
  static const version = 'atlas-automatic-capture-evidence-v1';

  String _crop(ContributionPhoto p) =>
      jsonEncode((p.displayCrop ?? PhotoCrop.full).toJson());
  File _file(ContributionPhoto p) => File(
    '${directory.path}/${sha256.convert(utf8.encode('$version|${p.checksum}|${p.originalChecksum}|${p.surface.name}|${_crop(p)}'))}.json',
  );

  Future<void> record(ContributionPhoto p, CameraCaptureResult capture) async {
    if (p.surface != PhotoSurface.cup ||
        p.origin != 'camera' ||
        capture.mode != CameraCaptureMode.automatic ||
        capture.requiresStrictPhotoVerification ||
        !capture.coffeeDetected ||
        !capture.coffeePresenceScore.isFinite ||
        capture.coffeePresenceScore <= 0 ||
        capture.coffeePresenceScore > 1 ||
        p.capturedAt != capture.capturedAt.toUtc().toIso8601String()) {
      return;
    }
    try {
      final original = await File(capture.filePath).readAsBytes();
      if (p.originalChecksum != 'sha256:${sha256.convert(original)}') return;
      await directory.create(recursive: true);
      final file = _file(p);
      final pending = File('${file.path}.pending');
      await pending.writeAsString(
        jsonEncode({
          'version': version,
          'checksum': p.checksum,
          'originalChecksum': p.originalChecksum,
          'cropKey': _crop(p),
          'surface': p.surface.name,
          'mode': capture.mode.name,
          'coffeeDetected': true,
          'coffeePresenceScore': capture.coffeePresenceScore,
          'capturedAtUtc': p.capturedAt,
        }),
        flush: true,
      );
      await pending.rename(file.path);
    } catch (_) {
      // Missing optional evidence must never lose an approved photo.
    }
  }

  Future<bool> supports(ContributionPhoto p) async {
    if (p.surface != PhotoSurface.cup || p.origin != 'camera') return false;
    try {
      final v = jsonDecode(await _file(p).readAsString()) as Map;
      final score = v['coffeePresenceScore'];
      return v['version'] == version &&
          v['checksum'] == p.checksum &&
          v['originalChecksum'] == p.originalChecksum &&
          v['cropKey'] == _crop(p) &&
          v['surface'] == p.surface.name &&
          v['mode'] == 'automatic' &&
          v['coffeeDetected'] == true &&
          v['capturedAtUtc'] == p.capturedAt &&
          score is num &&
          score.isFinite &&
          score > 0 &&
          score <= 1;
    } catch (_) {
      return false;
    }
  }
}
