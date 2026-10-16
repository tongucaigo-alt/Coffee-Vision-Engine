import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import 'models.dart';
import 'photo_crop.dart';

const openCvTracesEnabled = bool.fromEnvironment(
  'ATLAS_OPENCV_TRACES',
  defaultValue: true,
);
// The optional contrast experiment keeps its own cache identity.
const adaptiveTracesEnabled = bool.fromEnvironment('ATLAS_OPENCV_ADAPTIVE');
const adaptiveTraceAlgorithm = 'opencv-4.13-traces-v4-rim-domain-selective';
const traceAlgorithm = adaptiveTracesEnabled
    ? adaptiveTraceAlgorithm
    : 'opencv-4.13-traces-v4-rim-domain';
const traceColors = [
  Color(0xff0eae98),
  Color(0xffdf4a78),
  Color(0xff4388df),
  Color(0xffe1aa19),
];

Uint8List prepareTraceImage(Map<String, dynamic> input) {
  final decoded = img.decodeImage(input['bytes'] as Uint8List);
  if (decoded == null) throw const FormatException('Unreadable photo');
  final oriented = img.bakeOrientation(decoded);
  final area = (input['area'] as List).cast<double>();
  final x = (area[0] * oriented.width).floor();
  final y = (area[1] * oriented.height).floor();
  final width = math.min(
    oriented.width - x,
    (area[2] * oriented.width).round(),
  );
  final height = math.min(
    oriented.height - y,
    (area[3] * oriented.height).round(),
  );
  final crop = img.copyCrop(oriented, x: x, y: y, width: width, height: height);
  final scale = 512 / math.max(width, height);
  final resized = img.copyResize(
    crop,
    width: math.max(41, (width * scale).round()),
    height: math.max(41, (height * scale).round()),
    interpolation: img.Interpolation.linear,
  );
  return Uint8List.fromList(img.encodePng(resized));
}

class TraceCandidate {
  TraceCandidate(this.photoIndex, this.result, this.data, this.area);
  final int photoIndex;
  final Map<String, dynamic> result, data;
  final PhotoCrop area;
  double get score => (data['score'] as num).toDouble();
  int get width => result['width'] as int;
  int get height => result['height'] as int;
  List<int> get pixels => (data['pixels'] as List).cast<int>();
  List<int> get boundary => (data['boundary'] as List).cast<int>();
  Rect get box {
    final b = (data['box'] as List).cast<num>();
    return Rect.fromLTWH(
      b[0].toDouble(),
      b[1].toDouble(),
      b[2].toDouble(),
      b[3].toDouble(),
    );
  }

  PhotoCrop get closeup {
    final b = box
        .inflate(10)
        .intersect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));
    return PhotoCrop(
      area.x + b.left / width * area.width,
      area.y + b.top / height * area.height,
      b.width / width * area.width,
      b.height / height * area.height,
    );
  }
}

/// Up to four distinct regions per photo. Another angle never consumes its slots.
List<TraceCandidate> selectTraces(List<TraceCandidate> input) {
  final selected = <TraceCandidate>[];
  final photos = input.map((c) => c.photoIndex).toSet().toList()..sort();
  for (final photo in photos) {
    final ranked = input.where((c) => c.photoIndex == photo).toList()
      ..sort((a, b) {
        final score = b.score.compareTo(a.score);
        return score != 0
            ? score
            : (a.data['id'] as int).compareTo(b.data['id'] as int);
      });
    final distinct = <TraceCandidate>[];
    bool duplicate(TraceCandidate item) => distinct.any((other) {
      final overlap = item.box.intersect(other.box);
      if (overlap.isEmpty) return false;
      final a = item.pixels, b = other.pixels;
      var i = 0, j = 0, common = 0;
      while (i < a.length && j < b.length) {
        if (a[i] == b[j]) {
          common++;
          i++;
          j++;
        } else if (a[i] < b[j]) {
          i++;
        } else {
          j++;
        }
      }
      return common / math.min(a.length, b.length) > .25;
    });
    // Deduplicate by score before reserving an interior slot; an interior
    // duplicate must not displace a higher-quality view of the same pixels.
    for (final item in ranked) {
      if (!duplicate(item)) distinct.add(item);
    }
    bool interior(TraceCandidate item) {
      final boundary = item.result['cupBoundary'];
      if (boundary is! List || boundary.length != 5) return false;
      final cx = (boundary[0] as num).toDouble(),
          cy = (boundary[1] as num).toDouble();
      final rx = (boundary[2] as num).toDouble() * .65 / 2;
      final ry = (boundary[3] as num).toDouble() * .65 / 2;
      if (rx <= 0 || ry <= 0) return false;
      final angle = (boundary[4] as num) * math.pi / 180;
      final pixels = item.pixels;
      if (pixels.isEmpty) return false;
      var sx = 0.0, sy = 0.0;
      for (final pixel in pixels) {
        sx += pixel % item.width;
        sy += pixel ~/ item.width;
      }
      final dx = sx / pixels.length - cx, dy = sy / pixels.length - cy;
      final x = (dx * math.cos(angle) + dy * math.sin(angle)) / rx;
      final y = (-dx * math.sin(angle) + dy * math.cos(angle)) / ry;
      return x * x + y * y <= 1;
    }

    final local = <TraceCandidate>[];
    final inner = distinct.where(interior).firstOrNull;
    if (inner != null) local.add(inner);
    for (final item in distinct) {
      if (!identical(item, inner)) local.add(item);
      if (local.length == 4) break;
    }
    selected.addAll(local);
  }
  return selected;
}

/// Strict bounds validation for both platform replies and untrusted cache files.
Map<String, dynamic> validateTraceResult(Object? value) {
  if (value is! Map) throw const FormatException('Invalid trace result');
  final result = Map<String, dynamic>.from(
    jsonDecode(jsonEncode(value)) as Map,
  );
  final w = result['width'], h = result['height'];
  if (w is! int || h is! int || w < 41 || h < 41 || w > 512 || h > 512) {
    throw const FormatException('Invalid trace dimensions');
  }
  final cupBoundary = result['cupBoundary'];
  if (cupBoundary != null &&
      (cupBoundary is! List ||
          (cupBoundary.isNotEmpty &&
              (cupBoundary.length != 5 ||
                  cupBoundary.any((v) => v is! num || !v.isFinite) ||
                  cupBoundary[2] <= 0 ||
                  cupBoundary[3] <= 0)))) {
    throw const FormatException('Invalid cup boundary');
  }
  final candidates = result['candidates'];
  if (candidates is! List || candidates.length > 24) {
    throw const FormatException('Invalid trace candidates');
  }
  for (final row in candidates) {
    if (row is! Map) throw const FormatException('Invalid trace');
    final box = row['box'], pixels = row['pixels'], boundary = row['boundary'];
    final signature = row['signature'],
        score = row['score'],
        aspect = row['aspect'];
    if (box is! List ||
        box.length != 4 ||
        box.any((v) => v is! int) ||
        box[0] < 0 ||
        box[1] < 0 ||
        box[2] < 1 ||
        box[3] < 1 ||
        box[0] + box[2] > w ||
        box[1] + box[3] > h ||
        pixels is! List ||
        pixels.isEmpty ||
        pixels.length > w * h ||
        boundary is! List ||
        boundary.length > pixels.length ||
        signature is! List ||
        signature.length != 64 ||
        signature.any((v) => v is! num || !v.isFinite || v < 0) ||
        score is! num ||
        !score.isFinite ||
        score < 0 ||
        aspect is! num ||
        !aspect.isFinite ||
        aspect <= 0) {
      throw const FormatException('Invalid trace geometry');
    }
    var previous = -1;
    final region = <int>{};
    for (final pixel in pixels) {
      if (pixel is! int ||
          pixel <= previous ||
          pixel >= w * h ||
          pixel % w < box[0] ||
          pixel % w >= box[0] + box[2] ||
          pixel ~/ w < box[1] ||
          pixel ~/ w >= box[1] + box[3]) {
        throw const FormatException('Invalid trace pixel');
      }
      previous = pixel;
      region.add(pixel);
    }
    previous = -1;
    for (final pixel in boundary) {
      if (pixel is! int || pixel <= previous || !region.contains(pixel)) {
        throw const FormatException('Invalid trace boundary');
      }
      previous = pixel;
    }
  }
  return result;
}

String tracePhotoIdentity(ContributionPhoto photo) =>
    '${photo.fileKey}|${photo.checksum}|${jsonEncode(photo.visibleCrop.toJson())}';

/// A display-only snapshot. It is never serialized into review or AI documents.
class TraceSet {
  TraceSet(this.photos, this.selected, {this.failures = 0});
  final List<ContributionPhoto> photos;
  final List<TraceCandidate> selected;
  final int failures;
  int indexOf(ContributionPhoto photo) => photos.indexWhere(
    (p) => tracePhotoIdentity(p) == tracePhotoIdentity(photo),
  );
  static final empty = TraceSet(const [], const []);
}

class TraceService {
  TraceService(
    this.directory, {
    this.timeout = const Duration(seconds: 12),
    this.adaptive = adaptiveTracesEnabled,
  });
  final Directory directory;
  final Duration timeout;
  final bool adaptive;
  static const channel = MethodChannel('atlas.opencv/traces');
  final _deleted = <String>{};
  final _pending = <String, Future<Map<String, dynamic>>>{};
  Future<Map<String, dynamic>?>? _native;
  Future<void> _queue = Future.value();
  Directory _owner(String owner) =>
      Directory('${directory.path}/${sha256.convert(utf8.encode(owner))}');

  Future<void> deleteOwner(String owner) async {
    _deleted.add(owner); // Prevent an in-flight native reply recreating files.
    final folder = _owner(owner);
    if (await folder.exists()) await folder.delete(recursive: true);
  }

  Future<Map<String, dynamic>> analyze(
    String owner,
    File file,
    ContributionPhoto photo,
  ) async {
    if (_deleted.contains(owner)) {
      throw const FormatException('Deleted trace owner');
    }
    final bytes = await file.readAsBytes();
    final checksum = 'sha256:${sha256.convert(bytes)}';
    if (checksum != photo.checksum) {
      throw const FormatException('Photo changed');
    }
    final area = photo.visibleCrop;
    final algorithm = adaptive
        ? adaptiveTraceAlgorithm
        : 'opencv-4.13-traces-v4-rim-domain';
    final identity = '$checksum|$algorithm|${jsonEncode(area.toJson())}';
    final name = sha256.convert(utf8.encode(identity)).toString();
    final key = '$owner/$name';
    final existing = _pending[key];
    if (existing != null) return existing;
    final task = _queue.then((_) => _analyze(owner, name, bytes, photo, area));
    _queue = task.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    _pending[key] = task;
    try {
      return await task;
    } finally {
      if (identical(_pending[key], task)) _pending.remove(key);
    }
  }

  Future<Map<String, dynamic>> _analyze(
    String owner,
    String name,
    Uint8List bytes,
    ContributionPhoto photo,
    PhotoCrop area,
  ) async {
    if (_deleted.contains(owner)) {
      throw const FormatException('Deleted trace owner');
    }
    final cache = File('${_owner(owner).path}/$name.json');
    try {
      if (await cache.exists()) {
        return validateTraceResult(jsonDecode(await cache.readAsString()));
      }
    } catch (_) {
      // Partial or invalid cache is recomputed; source photos stay untouched.
    }
    final png = await compute(prepareTraceImage, {
      'bytes': bytes,
      'area': [area.x, area.y, area.width, area.height],
    }).timeout(timeout);
    if (_deleted.contains(owner)) {
      throw const FormatException('Deleted trace owner');
    }
    // Keep the native slot occupied until its actual reply, even after timeout.
    // A stalled native call must never cause unbounded repeated submissions.
    if (_native != null) {
      await _native!
          .then((r) => r, onError: (Object _) => null)
          .timeout(timeout);
    }
    final native = channel.invokeMapMethod<String, dynamic>('analyze', {
      'png': png,
      'photoId': photo.fileKey,
      'coordinateSpace': PhotoCrop.coordinateSpace,
      if (adaptive) 'adaptive': true,
    });
    _native = native;
    unawaited(
      native.then<void>(
        (_) {
          if (identical(_native, native)) _native = null;
        },
        onError: (Object _, StackTrace stack) {
          if (identical(_native, native)) _native = null;
        },
      ),
    );
    final result = validateTraceResult(await native.timeout(timeout));
    if (_deleted.contains(owner)) {
      throw const FormatException('Deleted trace owner');
    }
    try {
      await _owner(owner).create(recursive: true);
      if (_deleted.contains(owner)) {
        await deleteOwner(owner);
      } else {
        final temp = File('${cache.path}.tmp');
        await temp.writeAsString(jsonEncode(result), flush: true);
        if (_deleted.contains(owner)) {
          await deleteOwner(owner);
        } else {
          await temp.rename(cache.path);
        }
      }
    } on FileSystemException {
      // Cache is optional; a valid result remains usable in memory.
    }
    return result;
  }

  Future<TraceSet> loadSet({
    required String owner,
    required List<ContributionPhoto> photos,
    required File Function(ContributionPhoto) fileFor,
    bool Function()? isCancelled,
    void Function(TraceSet set, ContributionPhoto photo)? onUpdate,
  }) async {
    final cups = photos.where((p) => p.surface == PhotoSurface.cup).toList();
    final candidates = <TraceCandidate>[];
    var failures = 0;
    for (var i = 0; i < cups.length; i++) {
      if (isCancelled?.call() == true || _deleted.contains(owner)) break;
      final photo = cups[i];
      // Announce the photograph before computation, without invented findings.
      onUpdate?.call(
        TraceSet(cups, selectTraces(candidates), failures: failures),
        photo,
      );
      try {
        final result = await analyze(owner, fileFor(photo), photo);
        if (isCancelled?.call() == true || _deleted.contains(owner)) break;
        for (final row in result['candidates'] as List) {
          candidates.add(
            TraceCandidate(
              i,
              result,
              Map<String, dynamic>.from(row as Map),
              photo.visibleCrop,
            ),
          );
        }
      } catch (_) {
        failures++;
      }
      if (isCancelled?.call() == true || _deleted.contains(owner)) break;
      onUpdate?.call(
        TraceSet(cups, selectTraces(candidates), failures: failures),
        photo,
      );
    }
    return TraceSet(
      List.unmodifiable(cups),
      List.unmodifiable(selectTraces(candidates)),
      failures: failures,
    );
  }
}
