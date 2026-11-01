import 'dart:convert';
import '../local_revision_cache.dart';
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
    final next = (_tails[key] ?? Future<void>.value()).then((_) async {
      try {
        return await operation();
      } finally {
        markLocalDataChanged();
      }
    });
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

  // Bounded parsed metadata only. Every hit still reads and hashes the actual
  // file, so corruption, replacement and restored timestamps cannot bypass checks.
  final _verified =
      <String, ({String digest, ReviewSession session, int bytes})>{};
  int _verifiedBytes = 0;
  static const _maxVerifiedBytes = 4 * 1024 * 1024;
  static const _maxVerifiedRecords = 128;

  Future<List<ReviewSession>> _revisions({String? sessionId}) async {
    // Current-record operations verify that record's complete revision history.
    // Full listing/exposure audits still verify every historical document.
    // IDs may contain hyphens/digits, so a prefix alone is not an identity test.
    final selectedName = sessionId == null
        ? null
        : RegExp('^review-${RegExp.escape(sessionId)}--?[0-9]+\\.json\$');
    final result = <ReviewSession>[];
    final seen = <String>{};
    await for (final entry in directory.list(followLinks: false)) {
      if (entry is! File ||
          !path.basename(entry.path).startsWith('review-') ||
          !entry.path.endsWith('.json')) {
        continue;
      }
      if (selectedName != null &&
          !selectedName.hasMatch(path.basename(entry.path))) {
        continue;
      }
      seen.add(entry.path);
      final bytes = await entry.readAsBytes();
      final digest = sha256.convert(bytes).toString();
      final cached = _verified.remove(entry.path);
      if (cached != null) _verifiedBytes -= cached.bytes;
      if (cached?.digest == digest) {
        _verified[entry.path] = cached!;
        _verifiedBytes += cached.bytes;
        result.add(cached.session);
        continue;
      }
      final envelope = jsonDecode(utf8.decode(bytes)) as Map;
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
      if (bytes.length <= _maxVerifiedBytes) {
        _verified[entry.path] = (
          digest: digest,
          session: session,
          bytes: bytes.length,
        );
        _verifiedBytes += bytes.length;
        while (_verified.length > _maxVerifiedRecords ||
            _verifiedBytes > _maxVerifiedBytes) {
          _verifiedBytes -= _verified.remove(_verified.keys.first)!.bytes;
        }
      }
    }
    for (final key
        in _verified.keys
            .where(
              (key) =>
                  !seen.contains(key) &&
                  (selectedName == null ||
                      selectedName.hasMatch(path.basename(key))),
            )
            .toList()) {
      _verifiedBytes -= _verified.remove(key)!.bytes;
    }
    return result;
  }

  /// Fresh byte/checksum validation of every revision belonging to one record.
  /// No cached existence, revision number or file timestamp authorizes a result.
  Future<ReviewSession?> session(String id) async {
    safeReviewId(id);
    ReviewSession? latest;
    for (final item in await _revisions(sessionId: id)) {
      if (latest == null || item.revision > latest.revision) latest = item;
    }
    return latest;
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
    final old = await this.session(session.id);
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
        (await sessions())
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
