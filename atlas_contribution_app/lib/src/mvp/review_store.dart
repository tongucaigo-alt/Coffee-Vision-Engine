import 'dart:convert';
import 'dart:io';

import 'package:coffee_camera/coffee_camera.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import '../local_store.dart';
import '../models.dart';
import 'review_models.dart';
import 'review_capture_crop.dart';

final class ReviewStore {
  ReviewStore(this.directory, {DraftStore? contributionStore})
    : contributionStore =
          contributionStore ??
          DraftStore(
            Directory(
              path.join(directory.parent.path, 'offline-contributions'),
            ),
          );
  final Directory directory;
  final DraftStore contributionStore;
  Future<List<Map<String, dynamic>>> Function(String groupId)?
  additionalExposures;
  Future<void> Function(String sessionId)? onDelete;
  static final Map<String, Future<void>> _tails = {};

  Future<T> _serial<T>(Future<T> Function() operation) {
    final normalized = path.normalize(directory.absolute.path);
    final key = Platform.isWindows ? normalized.toLowerCase() : normalized;
    final next = (_tails[key] ?? Future<void>.value()).then((_) => operation());
    late final Future<void> tail;
    void clear() {
      if (identical(_tails[key], tail)) _tails.remove(key);
    }

    tail = next.then<void>(
      (_) => clear(),
      onError: (Object _, StackTrace _) => clear(),
    );
    _tails[key] = tail;
    return next;
  }

  File file(String name) {
    if (!RegExp(r'^[a-zA-Z0-9_-]+\.(json|jpg|pending)$').hasMatch(name)) {
      throw const FormatException('Unsafe review path');
    }
    return File(path.join(directory.path, name));
  }

  Future<void> initialize() async => directory.create(recursive: true);

  Future<void> galleryIntent(Map<String, dynamic>? intent) async {
    await file(
      'gallery-intent.pending',
    ).writeAsString(jsonEncode(intent), flush: true);
    await file(
      'gallery-intent.pending',
    ).rename(file('gallery-intent.json').path);
  }

  Future<Map<String, dynamic>?> pendingGallery() async {
    final target = file('gallery-intent.json');
    if (!await target.exists()) return null;
    final value = jsonDecode(await target.readAsString());
    return value == null ? null : Map<String, dynamic>.from(value as Map);
  }

  Future<List<ReviewSession>> _revisions() async {
    final result = <ReviewSession>[];
    await for (final entry in directory.list(followLinks: false)) {
      if (entry is! File ||
          !path.basename(entry.path).startsWith('review-') ||
          !entry.path.endsWith('.json')) {
        continue;
      }
      final envelope = jsonDecode(await entry.readAsString()) as Map;
      final document = Map<String, dynamic>.from(envelope['document'] as Map);
      if ('sha256:${sha256.convert(utf8.encode(jsonEncode(document)))}' !=
          envelope['checksum']) {
        throw const FormatException('Review record integrity failure');
      }
      final session = ReviewSession.fromJson(document);
      if (path.basename(entry.path) !=
          'review-${session.id}-${session.revision}.json') {
        throw const FormatException('Review identity mismatch');
      }
      result.add(session);
    }
    return result;
  }

  Future<List<ReviewSession>> sessions() async {
    final latest = <String, ReviewSession>{};
    for (final session in await _revisions()) {
      if ((latest[session.id]?.revision ?? 0) < session.revision) {
        latest[session.id] = session;
      }
    }
    final result = latest.values.toList()
      ..sort((a, b) => b.createdAtUtc.compareTo(a.createdAtUtc));
    return List.unmodifiable(result);
  }

  /// Includes earlier revisions: replacing a photo must not erase exposure.
  Future<List<Map<String, dynamic>>> knownGroupExposures(
    ReviewSession session,
  ) async {
    final found = <String, Map<String, dynamic>>{};
    for (final record in await _revisions()) {
      if (record.groupId != session.groupId) continue;
      if (record.observationHistory == 'unknown') {
        found['${record.id}:unknown'] = {
          'sessionId': record.id,
          'exposureHistory': 'unknown',
        };
      }
      for (final photo in record.photos) {
        for (final feedback in photo.feedback) {
          final key =
              '${record.id}:${photo.id}:${feedback.runId}:${feedback.candidateKey}';
          found[key] = {
            'sessionId': record.id,
            'photoId': photo.id,
            'runId': feedback.runId,
            'candidateKey': feedback.candidateKey,
            'exposedAtUtc': feedback.exposedAtUtc,
            'kind': 'engineCandidate',
          };
        }
        if (photo.observationExposureRunId != null) {
          found['${record.id}:${photo.id}:observation'] = {
            'sessionId': record.id,
            'photoId': photo.id,
            'runId': photo.observationExposureRunId,
            'kind': 'priorObservationExposure',
          };
        }
      }
    }
    for (final exposure
        in await additionalExposures?.call(session.groupId) ??
            <Map<String, dynamic>>[]) {
      found['ai:${exposure['resultId']}'] = exposure;
    }
    final keys = found.keys.toList()..sort();
    return List.unmodifiable([
      for (final key in keys) immutableDocument(found[key]!),
    ]);
  }

  Future<void> save(ReviewSession session) => _serial(() async {
    final all = await sessions();
    final old = all.where((s) => s.id == session.id).firstOrNull;
    if (old?.deleted == true || session.revision != (old?.revision ?? 0) + 1) {
      throw StateError('Stale review revision');
    }
    if (old != null &&
        (old.groupId != session.groupId ||
            old.observationHistory != session.observationHistory ||
            session.initialObservations.length <
                old.initialObservations.length ||
            jsonEncode(
                  session.initialObservations
                      .take(old.initialObservations.length)
                      .toList(),
                ) !=
                jsonEncode(old.initialObservations))) {
      throw StateError('Initial observation history is immutable');
    }
    if (old == null &&
        !session.id.startsWith('linked-') &&
        all
                .where(
                  (s) =>
                      !s.deleted &&
                      s.id.startsWith('linked-') ==
                          session.id.startsWith('linked-'),
                )
                .length >=
            30) {
      throw StateError('Review capacity reached');
    }
    for (final p in session.photos) {
      final previous = old?.photos.where((e) => e.id == p.id).firstOrNull;
      if (previous != null &&
          jsonEncode(previous.displayCrop?.toJson()) !=
              jsonEncode(p.displayCrop?.toJson())) {
        throw StateError('A saved photo crop is immutable; retake the photo');
      }
    }
    // Missing media must not prevent consent withdrawal or a deletion tombstone.
    // New media is checked here; every analysis/export checks it again.
    if (!session.deleted) {
      for (final p in session.photos) {
        final unchanged =
            old?.photos.any(
              (previous) =>
                  previous.id == p.id &&
                  previous.photo.localName == p.photo.localName &&
                  previous.photo.checksum == p.photo.checksum &&
                  previous.photo.byteLength == p.photo.byteLength,
            ) ??
            false;
        if (!unchanged) {
          await readPhoto(p);
        }
      }
    }
    final name = 'review-${session.id}-${session.revision}';
    final document = session.toJson();
    final checksum =
        'sha256:${sha256.convert(utf8.encode(jsonEncode(document)))}';
    await file('$name.pending').writeAsString(
      jsonEncode({'document': document, 'checksum': checksum}),
      flush: true,
    );
    // Publishing one immutable revision is the transaction commit point.
    await file('$name.pending').rename(file('$name.json').path);
  });

  Future<Uint8List> readPhoto(ReviewPhoto photo) async {
    final target = file(photo.photo.localName);
    final resolved = await target.resolveSymbolicLinks();
    final root = await directory.resolveSymbolicLinks();
    if (!path.isWithin(root, resolved)) {
      throw const FormatException('Photo outside review storage');
    }
    final bytes = await target.readAsBytes();
    if (bytes.length != photo.photo.byteLength ||
        'sha256:${sha256.convert(bytes)}' != photo.photo.checksum) {
      throw const FormatException('Photo integrity failure');
    }
    return bytes;
  }

  Future<ReviewPhoto> importPhoto(
    Uint8List source, {
    required ReviewSurface surface,
    CaptureRole? declaredRole,
    CameraCaptureResult? capture,
  }) async {
    if (surface == ReviewSurface.saucer && capture != null) {
      throw ArgumentError('Gallery-only saucer');
    }
    if (capture != null && declaredRole == null) {
      throw ArgumentError('Camera requires declared role');
    }
    final prepared = await compute(preparePhoto, source);
    final displayCrop = capture == null
        ? null
        : await reviewCaptureCrop(
            source,
            capture,
            photoWidth: prepared['width']! as int,
            photoHeight: prepared['height']! as int,
          );
    final bytes = prepared['bytes']! as Uint8List;
    final id = const Uuid().v4();
    final name = '$id.jpg';
    await file('$id.pending').writeAsBytes(bytes, flush: true);
    await file('$id.pending').rename(file(name).path);
    return ReviewPhoto(
      id: id,
      surface: surface,
      declaredRole: declaredRole,
      displayCrop: displayCrop,
      quality: capture == null
          ? const {'source': 'gallery', 'automaticUsability': 'unknown'}
          : {
              'source': 'camera',
              'qualityScore': capture.qualityScore,
              'coffeePresenceScore': capture.coffeePresenceScore,
              'coffeeDetected': capture.coffeeDetected,
              'scope': 'captureQualityNotSymbolConfidence',
            },
      photo: ContributionPhoto(
        role: capture == null ? null : declaredRole,
        localName: name,
        checksum: prepared['checksum']! as String,
        originalChecksum: prepared['originalChecksum']! as String,
        width: prepared['width']! as int,
        height: prepared['height']! as int,
        byteLength: bytes.length,
        capturedAt: capture?.capturedAt.toUtc().toIso8601String(),
        importedAt: capture == null
            ? DateTime.now().toUtc().toIso8601String()
            : null,
      ),
    );
  }

  Future<void> delete(ReviewSession session) async {
    await onDelete?.call(session.id);
    // Tombstone is durable before media cleanup and survives archive restoration.
    if (!session.deleted) {
      await save(session.next(deleted: true, researchAllowed: false));
    }
    final names = <String>{};
    await for (final entry in directory.list(followLinks: false)) {
      if (entry is! File ||
          !path.basename(entry.path).startsWith('review-${session.id}-') ||
          !entry.path.endsWith('.json')) {
        continue;
      }
      final envelope = jsonDecode(await entry.readAsString()) as Map;
      final record = ReviewSession.fromJson(
        Map<String, dynamic>.from(envelope['document'] as Map),
      );
      names.addAll(record.photos.map((p) => p.photo.localName));
    }
    final live = (await sessions())
        .where((s) => !s.deleted)
        .expand((s) => s.photos)
        .map((p) => p.photo.localName)
        .toSet();
    for (final name in names.difference(live)) {
      final target = file(name);
      if (await FileSystemEntity.type(target.path, followLinks: false) !=
          FileSystemEntityType.file) {
        continue;
      }
      if (path.isWithin(
        await directory.resolveSymbolicLinks(),
        await target.resolveSymbolicLinks(),
      )) {
        await target.delete();
      }
    }
  }
}
