import 'dart:convert';
import 'dart:io';
import 'package:coffee_camera/coffee_camera.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'models.dart';
import 'mvp/review_capture_crop.dart';

Map<String, Object> preparePhoto(Uint8List bytes) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    throw const FormatException('Fotoğraf okunamadı.');
  }
  if (decoded == null) throw const FormatException('Fotoğraf okunamadı.');
  final oriented = img.bakeOrientation(decoded);
  final resized = oriented.width > 2048 || oriented.height > 2048
      ? img.copyResize(
          oriented,
          width: oriented.width >= oriented.height ? 2048 : null,
          height: oriented.height > oriented.width ? 2048 : null,
          interpolation: img.Interpolation.average,
        )
      : oriented;
  // A new pixel image excludes EXIF, ICC, text and device metadata.
  final clean = img.Image(
    width: resized.width,
    height: resized.height,
    numChannels: 3,
  );
  img.compositeImage(clean, resized);
  final encoded = img.encodeJpg(clean, quality: 90);
  if (encoded.length > 5 * 1024 * 1024) {
    throw const FormatException('Fotoğraf çok büyük. Yeniden çek.');
  }
  return {
    'bytes': encoded,
    'width': clean.width,
    'height': clean.height,
    'checksum': 'sha256:${sha256.convert(encoded)}',
    'originalChecksum': 'sha256:${sha256.convert(bytes)}',
  };
}

class DraftStore {
  DraftStore(this.directory);
  final Directory directory;
  Future<void> Function(String rootId)? onDeleteRoot;
  static final Map<String, Future<void>> _writes = {};
  Future<T> _mutate<T>(Future<T> Function() operation) {
    final normalized = path.normalize(directory.absolute.path);
    final key = Platform.isWindows ? normalized.toLowerCase() : normalized;
    final next = (_writes[key] ?? Future<void>.value()).then(
      (_) => operation(),
    );
    late final Future<void> tail;
    void clear() {
      if (identical(_writes[key], tail)) _writes.remove(key);
    }

    tail = next.then<void>(
      (_) => clear(),
      onError: (Object _, StackTrace _) => clear(),
    );
    _writes[key] = tail;
    return next;
  }

  /// Export commits use the same queue as withdrawal and receipt changes.
  Future<T> withExportRead<T>(Future<T> Function() operation) =>
      _mutate(operation);

  File file(String name) {
    if (!RegExp(r'^[a-zA-Z0-9_-]+\.(jpg|json|bak|pending)$').hasMatch(name)) {
      throw ArgumentError('Invalid private filename');
    }
    return File(path.join(directory.path, name));
  }

  Future<void> initialize() => directory.create(recursive: true);
  Future<void> _atomic(String name, Object data) async {
    final target = file(name);
    final temporary = file(name.replaceAll('.json', '.pending'));
    final backup = file(name.replaceAll('.json', '.bak'));
    await temporary.writeAsString(jsonEncode(data), flush: true);
    if (await target.exists()) await target.copy(backup.path);
    // rename is atomic on Android; the backup also handles interrupted replacement.
    await temporary.rename(target.path);
  }

  Future<Map<String, dynamic>?> _read(String name) async {
    for (final candidate in [name, name.replaceAll('.json', '.bak')]) {
      final source = file(candidate);
      if (!await source.exists()) continue;
      try {
        return Map<String, dynamic>.from(
          jsonDecode(await source.readAsString()) as Map,
        );
      } on FormatException {
        continue;
      }
    }
    if (await file(name).exists() ||
        await file(name.replaceAll('.json', '.bak')).exists()) {
      throw const FormatException('Taslak okunamadı. Dosyalar korundu.');
    }
    return null;
  }

  Future<ContributionDraft?> load() async {
    final json = await _read('draft.json');
    final draft = json == null || json['draft'] == null
        ? null
        : ContributionDraft.fromJson(
            Map<String, dynamic>.from(json['draft'] as Map),
          );
    if (draft != null &&
        DateTime.parse(
          draft.consentedAt,
        ).add(const Duration(days: 180)).isBefore(DateTime.now())) {
      await clear();
      return null;
    }
    return draft;
  }

  Future<void> pruneExpiredReceipts() => _mutate(() async {
    final rows = await receipts();
    await _atomic('receipts.json', {'rows': rows});
    await _atomic('receipts.json', {'rows': rows});
  });

  Future<void> save(ContributionDraft draft) =>
      _mutate(() => _atomic('draft.json', {'draft': draft.toJson()}));

  Future<Map<String, dynamic>?> galleryPending() => _read('gallery.json');
  Future<void> saveGalleryPending(ContributionDraft? draft) =>
      _mutate(() => _atomic('gallery.json', {'draft': draft?.toJson()}));

  Future<void> saveSetGalleryPending(Map<String, dynamic>? operation) =>
      _mutate(() => _atomic('gallery.json', operation ?? {'draft': null}));

  Future<ContributionPhoto> importGallery(Uint8List input) async {
    final data = await compute(preparePhoto, input);
    final name = '${const Uuid().v4()}.jpg';
    final bytes = data['bytes']! as Uint8List;
    await file(name).writeAsBytes(bytes, flush: true);
    return ContributionPhoto(
      role: null,
      localName: name,
      checksum: data['checksum']! as String,
      originalChecksum: data['originalChecksum']! as String,
      width: data['width']! as int,
      height: data['height']! as int,
      byteLength: bytes.length,
      capturedAt: null,
      importedAt: DateTime.now().toUtc().toIso8601String(),
    );
  }

  Future<void> clear() => _mutate(() async {
    await _atomic('draft.json', {'draft': null});
    await _atomic('draft.json', {'draft': null});
    await collectOrphans();
  });

  Future<void> saveReceipt(Map<String, dynamic> row) => _mutate(() async {
    final rows = await receipts();
    final local = row['local_only'] == true;
    await _atomic('receipts.json', {
      'rows': [
        row,
        ...rows.where(
          (r) => local ? r['id'] != row['id'] : r['root_id'] != row['root_id'],
        ),
      ],
    });
  });

  Future<List<Map<String, dynamic>>> receipts() async {
    final data = await _read('receipts.json');
    return (data?['rows'] as List? ?? [])
        .map((r) => Map<String, dynamic>.from(r as Map))
        .where(
          (r) =>
              DateTime.tryParse(
                r['expires_at'] as String? ?? '',
              )?.isAfter(DateTime.now()) ==
              true,
        )
        .toList();
  }

  Future<List<String>> pendingDeletes() async =>
      ((await _read('deletions.json'))?['ids'] as List? ?? []).cast<String>();
  Future<void> queueDelete(String rootId) => _mutate(() async {
    final ids = (await pendingDeletes()).toSet()..add(rootId);
    await _atomic('deletions.json', {'ids': ids.toList()});
  });

  Future<void> acknowledgeDelete(String rootId) => _mutate(() async {
    await onDeleteRoot?.call(rootId);
    final rows = (await receipts())
        .where((r) => r['root_id'] != rootId)
        .toList();
    await _atomic('receipts.json', {'rows': rows});
    await _atomic('receipts.json', {'rows': rows});
    final ids = (await pendingDeletes())..remove(rootId);
    await _atomic('deletions.json', {'ids': ids});
  });

  Future<ContributionPhoto> importCapture(
    CaptureRole role,
    CameraCaptureResult capture, {
    bool preserveDisplayCrop = false,
  }) async {
    final source = await File(capture.filePath).readAsBytes();
    final data = await compute(preparePhoto, source);
    final crop = preserveDisplayCrop
        ? await reviewCaptureCrop(
            source,
            capture,
            photoWidth: data['width']! as int,
            photoHeight: data['height']! as int,
          )
        : null;
    final name = '${const Uuid().v4()}.jpg';
    final bytes = data['bytes']! as Uint8List;
    await file(name).writeAsBytes(bytes, flush: true);
    return ContributionPhoto(
      role: role,
      localName: name,
      checksum: data['checksum']! as String,
      originalChecksum: data['originalChecksum']! as String,
      width: data['width']! as int,
      height: data['height']! as int,
      byteLength: bytes.length,
      capturedAt: capture.capturedAt.toUtc().toIso8601String(),
      displayCrop: crop,
    );
  }

  Future<void> removeUnreferencedPhotos(
    Iterable<ContributionDraft> live,
  ) async {
    final keep = live.expand((d) => d.photos).map((p) => p.localName).toSet();
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is File &&
          entity.path.endsWith('.jpg') &&
          !keep.contains(path.basename(entity.path))) {
        await entity.delete();
      }
    }
  }

  Future<void> collectOrphans() async {
    final live = <ContributionDraft>[];
    for (final name in ['draft.json', 'draft.bak']) {
      final f = file(name);
      if (!await f.exists()) continue;
      final data = jsonDecode(await f.readAsString()) as Map;
      if (data['draft'] != null) {
        live.add(
          ContributionDraft.fromJson(Map<String, dynamic>.from(data['draft'])),
        );
      }
    }
    for (final row in await receipts()) {
      if (row['local_only'] == true && row['document'] is Map) {
        live.add(
          ContributionDraft.fromJson(
            Map<String, dynamic>.from(row['document'] as Map),
          ),
        );
      }
    }
    await removeUnreferencedPhotos(live);
  }

  Future<void> releaseCapture(CameraCaptureResult capture) async {
    final root = path.normalize((await getTemporaryDirectory()).absolute.path);
    for (final value in {
      capture.filePath,
      capture.croppedCupPath,
      capture.croppedSaucerPath,
    }) {
      if (value == null) continue;
      final exact = path.normalize(File(value).absolute.path);
      if (!path.isWithin(root, exact)) continue;
      if (await FileSystemEntity.type(exact, followLinks: false) ==
          FileSystemEntityType.file) {
        final resolved = await File(exact).resolveSymbolicLinks();
        if (path.isWithin(root, resolved)) await File(exact).delete();
      }
    }
  }
}
