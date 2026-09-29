import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'models.dart';
import 'photo_crop.dart';

const suitabilityVersion = 'atlas-suitability-lite0-v1';
// Must remain false until the documented real-image release gate passes.
const suitabilityBlockingValidated = false;

String classifySuitability(Map<dynamic, dynamic> scores) {
  final full = (scores['full'] as List).cast<Map>();
  final crop = (scores['crop'] as List).cast<Map>();
  bool cup(Map c) => RegExp(
    r'(^|, )(cup|coffee mug|espresso|soup bowl|plate|dish)(,|$)',
  ).hasMatch(c['label'] as String);
  if ([...full, ...crop].any(cup)) return 'supported';
  const excluded = [
    'computer keyboard',
    'typewriter keyboard',
    'mouse',
    'monitor',
    'screen',
    'desktop computer',
  ];
  bool negative(Map c) =>
      excluded.any((s) => (c['label'] as String).split(', ').contains(s)) &&
      (c['score'] as num) >= .90;
  if (full.isNotEmpty &&
      crop.isNotEmpty &&
      negative(full.first) &&
      negative(crop.first) &&
      full.first['label'] == crop.first['label']) {
    return 'unsuitable';
  }
  return 'uncertain';
}

bool suitabilityAccepted(
  Map<String, dynamic>? value,
  ContributionPhoto photo,
) =>
    value?['version'] == suitabilityVersion &&
    value?['checksum'] == photo.checksum &&
    value?['cropKey'] ==
        jsonEncode((photo.displayCrop ?? PhotoCrop.full).toJson()) &&
    (value?['status'] == 'supported' ||
        (value?['continuedAtUtc'] != null &&
            !(suitabilityBlockingValidated &&
                value?['status'] == 'unsuitable')));

class PhotoSuitability {
  PhotoSuitability(this.directory);
  final Directory directory;
  static const channel = MethodChannel('atlas.photo/suitability');
  String _key(ContributionPhoto p) => sha256
      .convert(
        utf8.encode(
          '$suitabilityVersion|${p.checksum}|${jsonEncode((p.displayCrop ?? PhotoCrop.full).toJson())}',
        ),
      )
      .toString();
  File _file(ContributionPhoto p) => File('${directory.path}/${_key(p)}.json');
  Future<Map<String, dynamic>?> read(ContributionPhoto p) async {
    final file = _file(p);
    if (!await file.exists()) return null;
    try {
      return Map<String, dynamic>.from(
        jsonDecode(await file.readAsString()) as Map,
      );
    } on FormatException {
      return null;
    }
  }

  Future<void> _save(ContributionPhoto p, Map<String, dynamic> value) async {
    await directory.create(recursive: true);
    final file = _file(p);
    final pending = File('${file.path}.pending');
    await pending.writeAsString(jsonEncode(value), flush: true);
    await pending.rename(file.path);
  }

  Future<Map<String, dynamic>> assess(
    File file,
    ContributionPhoto p, {
    bool retry = false,
  }) async {
    final cached = await read(p);
    if (!retry &&
        cached != null &&
        cached['version'] == suitabilityVersion &&
        (cached['status'] != 'error' || suitabilityAccepted(cached, p))) {
      return cached;
    }
    final crop = p.displayCrop ?? PhotoCrop.full;
    final value = <String, dynamic>{
      'version': suitabilityVersion,
      'checksum': p.checksum,
      'cropKey': jsonEncode(crop.toJson()),
      'checkedAtUtc': DateTime.now().toUtc().toIso8601String(),
      'experimental': !suitabilityBlockingValidated,
    };
    try {
      final bytes = await file.readAsBytes();
      if ('sha256:${sha256.convert(bytes)}' != p.checksum) {
        throw const FormatException('Photo mismatch');
      }
      final scores = await channel.invokeMapMethod<dynamic, dynamic>(
        'classify',
        {
          'path': file.absolute.path,
          'crop': [crop.x, crop.y, crop.width, crop.height],
        },
      );
      value['status'] = classifySuitability(scores!);
    } catch (_) {
      value['status'] = 'error';
    }
    await _save(p, value);
    return value;
  }

  Future<Map<String, dynamic>> continueWith(
    ContributionPhoto p,
    Map<String, dynamic> value,
  ) async {
    final next = {
      ...value,
      'continuedAtUtc': DateTime.now().toUtc().toIso8601String(),
    };
    await _save(p, next);
    return next;
  }
}

Future<Map<String, dynamic>?> ensurePhotoSuitability(
  BuildContext context,
  PhotoSuitability checker,
  File file,
  ContributionPhoto photo,
) async {
  var value = await checker.assess(file, photo);
  while (context.mounted && !suitabilityAccepted(value, photo)) {
    final error = value['status'] == 'error';
    final blocked =
        value['status'] == 'unsuitable' && suitabilityBlockingValidated;
    if (!context.mounted) return null;
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          blocked ? 'Fincan fotoğrafı gerekli' : 'Fotoğrafı kontrol et',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.file(file, height: 160, fit: BoxFit.contain),
              const SizedBox(height: 12),
              Text(
                error
                    ? 'Fotoğraf kontrolü tamamlanamadı. Fincan veya ona ait tabağı seçtiğinden emin ol.'
                    : 'Bu fotoğrafta kahve telvesini güvenle ayırt edemedik. Fincanın içini daha yakından çekebilirsin.${suitabilityBlockingValidated ? '' : " Fotoğraf kontrolü şu anda deneme aşamasında."}',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'replace'),
            child: const Text('Tekrar seç'),
          ),
          if (error)
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'retry'),
              child: const Text('Yeniden kontrol et'),
            ),
          if (!blocked)
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'continue'),
              child: const Text('Bu fotoğrafla devam et'),
            ),
        ],
      ),
    );
    if (action == 'continue') return checker.continueWith(photo, value);
    if (action != 'retry') return null;
    value = await checker.assess(file, photo, retry: true);
  }
  return context.mounted ? value : null;
}
