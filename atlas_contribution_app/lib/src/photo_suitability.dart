import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'mvp/photo_residue_check.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'models.dart';
import 'photo_crop.dart';

// Cache identity includes both the object model and application residue rules.
// Explicit build opt-in for the model whose independent device gate passed.
const localImageScreenEnabled = bool.fromEnvironment('ATLAS_IMAGE_SCREEN');
const diagnosticImageScreen =
    bool.fromEnvironment('ATLAS_DIAGNOSTIC') && localImageScreenEnabled;
const suitabilityVersion = localImageScreenEnabled
    ? 'atlas-diagnostic-mobilenet-17cb073e-expanded-v5'
    : 'atlas-suitability-lite0-residue-v4';
const suitabilityBlockingValidated = localImageScreenEnabled;

/// Whole-frame and preview-crop evidence must both be negative to reject.
/// A positive model margin cannot provide definite evidence against a photo.
String classifyLocalImageScreen(Map<dynamic, dynamic>? response) {
  final scores = response?['scores'];
  if (response?['modelSha256'] !=
          '17cb073e902c459ebc04fe9b14a2ba10ec968a4c378c40fbd8199f7c5b0ff5d4' ||
      scores is! List ||
      scores.length != 2 ||
      scores.any((value) => value is! num || !value.isFinite)) {
    throw const FormatException('Invalid diagnostic screening response');
  }
  if (scores.every((value) => (value as num) < -.4117240578933279)) {
    return 'unsuitable';
  }
  if (scores.any((value) => (value as num) > .27635831503150343)) {
    return 'supported';
  }
  return 'uncertain';
}

/// Validates native output before assigning a visual outcome. A malformed
/// model response is a technical failure, never evidence against the photo.
String classifySuitability(Map<dynamic, dynamic> scores) {
  List<Map> topResults(Object? value) {
    if (value is! List || value.isEmpty) {
      throw const FormatException('Missing classification results');
    }
    final rows = <Map>[];
    for (final entry in value) {
      if (entry is! Map ||
          entry['label'] is! String ||
          (entry['label'] as String).trim().isEmpty ||
          entry['score'] is! num) {
        throw const FormatException('Invalid classification result');
      }
      final score = entry['score'] as num;
      if (!score.isFinite || score < 0 || score > 1) {
        throw const FormatException('Invalid classification score');
      }
      rows.add(entry);
    }
    rows.sort((a, b) => (b['score'] as num).compareTo(a['score'] as num));
    return rows.take(3).toList();
  }

  final full = topResults(scores['full']);
  final crop = topResults(scores['crop']);
  bool cup(Map c) => RegExp(
    r'(^|, )(cup|coffee mug|espresso|soup bowl|plate|dish)(,|$)',
  ).hasMatch(c['label'] as String);
  if ([...full, ...crop].any(cup)) return 'uncertain';
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
    value?['surface'] == photo.surface.name &&
    value?['cropKey'] ==
        jsonEncode((photo.displayCrop ?? PhotoCrop.full).toJson()) &&
    ['supported', 'uncertain'].contains(value?['status']);

String suitabilityIdentity(ContributionPhoto photo) =>
    '${photo.checksum}|${photo.surface.name}|${jsonEncode((photo.displayCrop ?? PhotoCrop.full).toJson())}';

class PhotoSuitabilityFailure implements Exception {
  const PhotoSuitabilityFailure(this.photo, this.assessment);
  final ContributionPhoto photo;
  final Map<String, dynamic> assessment;
  bool get technical => assessment['status'] == 'error';
  String get message => technical
      ? 'Fotoğraf kontrolü tamamlanamadı. Kaydın korunuyor; kontrolü yeniden deneyebilirsin.'
      : 'Bu karede fincanının hikâyesine ulaşamadık. Telvenin göründüğü bir fotoğrafla yeniden deneyelim.';
}

/// Inline status shared by preview and fortune pages; never a confirmation modal.
class PhotoSuitabilityNotice extends StatelessWidget {
  const PhotoSuitabilityNotice({
    required this.photo,
    required this.value,
    this.onRetry,
    super.key,
  });
  final ContributionPhoto photo;
  final Map<String, dynamic>? value;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) {
    if (value == null) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Text('Fotoğraf kontrol ediliyor…'),
      );
    }
    final status = value!['status'];
    if (suitabilityAccepted(value, photo)) {
      return const SizedBox.shrink();
    }
    final failure = PhotoSuitabilityFailure(photo, value!);
    final experimental =
        value!['experimental'] == true && status == 'uncertain';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              '${photo.title}: ${failure.message}'
              '${experimental ? " Kontrol henüz deneme aşamasında; mevcut fotoğrafla devam edebilirsin." : ""}',
            ),
          ),
          if (failure.technical && onRetry != null)
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Kontrolü Yeniden Dene'),
            ),
        ],
      ),
    );
  }
}

/// An old saved record may need editing under the current model. The fortune
/// page offers a route back to the record, without repeating preview's warning.
class PhotoSuitabilityRecovery extends StatelessWidget {
  const PhotoSuitabilityRecovery({
    required this.failure,
    required this.onReviewPhotos,
    this.onRetry,
    super.key,
  });
  final PhotoSuitabilityFailure failure;
  final VoidCallback? onReviewPhotos;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) {
    if (failure.technical) {
      return PhotoSuitabilityNotice(
        photo: failure.photo,
        value: failure.assessment,
        onRetry: onRetry,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Kayıtlarım ekranında fotoğrafları gözden geçirebilirsin.'),
        OutlinedButton(
          onPressed: onReviewPhotos,
          child: const Text('Kayda dön'),
        ),
      ],
    );
  }
}

class PhotoSuitability {
  PhotoSuitability(this.directory);
  final Directory directory;
  static const channel = MethodChannel('atlas.photo/suitability');
  static const imageScreenChannel = MethodChannel('atlas.photo/image_screen');
  String _key(ContributionPhoto p) => sha256
      .convert(
        utf8.encode(
          '$suitabilityVersion|${p.surface.name}|${p.checksum}|${jsonEncode((p.displayCrop ?? PhotoCrop.full).toJson())}',
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

  static final _inflight = <String, Future<Map<String, dynamic>>>{};
  static Future<void> _tail = Future.value();

  Future<Map<String, dynamic>> assess(
    File file,
    ContributionPhoto p, {
    bool retry = false,
  }) {
    final key = '${directory.absolute.path}|${_key(p)}';
    return _inflight.putIfAbsent(key, () {
      // One complete worker at a time, including CPU processing off the UI isolate.
      final task = _tail.then((_) => _assess(file, p, retry: retry));
      _tail = task.then<void>((_) {}, onError: (Object _, StackTrace _) {});
      return task.whenComplete(() {
        _inflight.remove(key);
      });
    });
  }

  Future<Map<String, dynamic>> _assess(
    File file,
    ContributionPhoto p, {
    required bool retry,
  }) async {
    final crop = p.displayCrop ?? PhotoCrop.full;
    Map<String, dynamic> base() => {
      'version': suitabilityVersion,
      'checksum': p.checksum,
      'surface': p.surface.name,
      'cropKey': jsonEncode(crop.toJson()),
      'checkedAtUtc': DateTime.now().toUtc().toIso8601String(),
      'experimental':
          !(suitabilityBlockingValidated && p.surface == PhotoSurface.cup),
      'decisionSource': 'localSystem',
    };
    try {
      final cached = await read(p);
      if (!retry &&
          cached != null &&
          cached['version'] == suitabilityVersion &&
          cached['checksum'] == p.checksum &&
          cached['surface'] == p.surface.name &&
          cached['cropKey'] == jsonEncode(crop.toJson()) &&
          [
            'supported',
            'uncertain',
            'unsuitable',
            'residueFree',
            'error',
          ].contains(cached['status'])) {
        return cached;
      }
    } catch (_) {
      /* An unreadable cache is recomputed, not a visual decision. */
    }
    var value = base();
    for (var attempt = 0; attempt < 2; attempt++) {
      value = base();
      value['attempts'] = attempt + 1;
      try {
        final bytes = await file.readAsBytes();
        if ('sha256:${sha256.convert(bytes)}' != p.checksum) {
          throw const FormatException('Photo mismatch');
        }
        // The cup model has no independent saucer validation. Preserve the
        // existing saucer assessment rather than applying a cup-only head.
        if (localImageScreenEnabled && p.surface == PhotoSurface.cup) {
          final screen = await imageScreenChannel
              .invokeMapMethod<String, dynamic>('assess', {
                'path': file.absolute.path,
                'crop': [crop.x, crop.y, crop.width, crop.height],
              })
              .timeout(const Duration(seconds: 30));
          final status = classifyLocalImageScreen(screen);
          value.addAll({
            'candidateStatus': status,
            'status': status,
            'imageScreen': screen,
            'diagnosticOnly': diagnosticImageScreen,
          });
          await _save(p, value);
          return value;
        }
        final scores = await channel
            .invokeMapMethod<dynamic, dynamic>('classify', {
              'path': file.absolute.path,
              'crop': [crop.x, crop.y, crop.width, crop.height],
            })
            .timeout(const Duration(seconds: 30));
        final object = classifySuitability(scores!);
        final physical = await compute(measurePhotoResidue, <String, dynamic>{
          'bytes': bytes,
          'crop': [crop.x, crop.y, crop.width, crop.height],
        });
        final candidate = object == 'unsuitable'
            ? object
            : residueDecision(
                scores,
                physical,
                saucer: p.surface == PhotoSurface.saucer,
              );
        value.addAll({
          'objectAssessment': object, 'physical': physical,
          'candidateStatus': candidate,
          'residueAssessment': candidate == 'residueFree'
              ? 'lowEvidence'
              : 'measured',
          // The legacy module has no passing independent gate, including
          // saucers. Its negative candidates therefore remain non-blocking.
          'status': ['unsuitable', 'residueFree'].contains(candidate)
              ? 'uncertain'
              : candidate,
        });
        await _save(p, value);
        return value;
      } catch (error) {
        debugPrint('AtlasPhotoCheck: ${error.runtimeType}');
        value['status'] = 'error';
        value['residueAssessment'] = 'unavailable';
      }
    }
    try {
      await _save(p, value);
    } catch (_) {
      /* The UI must still report failure. */
    }
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
  ContributionPhoto photo, {
  bool retry = false,
}) async {
  final value = await checker.assess(file, photo, retry: retry);
  if (!context.mounted) return null;
  if (!suitabilityAccepted(value, photo)) {
    throw PhotoSuitabilityFailure(photo, value);
  }
  return value;
}
