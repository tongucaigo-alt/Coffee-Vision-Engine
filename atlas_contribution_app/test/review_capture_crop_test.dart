import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:atlas_contribution_app/src/local_store.dart';
import 'package:atlas_contribution_app/src/mvp/review_capture_crop.dart';
import 'package:coffee_camera/coffee_camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

Uint8List _quadrants({int orientation = 1, int width = 96, int height = 64}) {
  final photo = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final left = x < width / 2;
      final top = y < height / 2;
      photo.setPixelRgb(
        x,
        y,
        top ? (left ? 240 : 20) : (left ? 20 : 240),
        top ? (left ? 20 : 240) : (left ? 20 : 240),
        top ? 20 : (left ? 240 : 20),
      );
    }
  }
  photo.exif.imageIfd.orientation = orientation;
  return img.encodeJpg(photo, quality: 100);
}

Future<({int width, int height, Uint8List rgba})> _uiPixels(
  Uint8List bytes,
) async {
  final codec = await ui.instantiateImageCodec(bytes);
  try {
    final frame = await codec.getNextFrame();
    try {
      final pixels = await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      return (
        width: frame.image.width,
        height: frame.image.height,
        rgba: pixels!.buffer.asUint8List(),
      );
    } finally {
      frame.image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

CameraCaptureResult _capture(
  Uint8List bytes, {
  int width = 96,
  int height = 64,
  ui.Rect? rect = const ui.Rect.fromLTWH(12, 8, 24, 16),
  String? cropPath = 'approved-crop.png',
  int? cropWidth,
}) => CameraCaptureResult(
  filePath: 'source.jpg',
  croppedCupPath: cropPath,
  cropRect: rect,
  widthPixels: width,
  heightPixels: height,
  fileSizeBytes: bytes.length,
  croppedWidthPixels:
      cropWidth ?? (rect == null ? null : math.max(1, rect.width.round())),
  croppedHeightPixels: rect == null ? null : math.max(1, rect.height.round()),
  capturedAt: DateTime.utc(2026, 9, 16),
  qualityScore: 90,
  coffeePresenceScore: .9,
  mode: CameraCaptureMode.manual,
);

void _expectRgb(List<int> actual, List<int> expected) {
  for (var c = 0; c < 3; c++) {
    expect(actual[c], closeTo(expected[c], 10));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final expectedTopLeft = <int, List<int>>{
    1: [240, 20, 20],
    2: [20, 240, 20],
    3: [240, 240, 20],
    4: [20, 20, 240],
    5: [240, 20, 20],
    6: [20, 20, 240],
    7: [240, 240, 20],
    8: [20, 240, 20],
  };
  for (final orientation in expectedTopLeft.keys) {
    test(
      'approved crop preserves tagged quadrant for EXIF $orientation',
      () async {
        final source = _quadrants(orientation: orientation);
        final preview = await _uiPixels(source);
        final prepared = preparePhoto(source);
        final rect = ui.Rect.fromLTWH(
          preview.width / 8,
          preview.height / 8,
          preview.width / 4,
          preview.height / 4,
        );
        final crop = await reviewCaptureCrop(
          source,
          _capture(
            source,
            width: preview.width,
            height: preview.height,
            rect: rect,
          ),
          photoWidth: prepared['width']! as int,
          photoHeight: prepared['height']! as int,
        );
        expect(
          [crop!.x, crop.y, crop.width, crop.height],
          [.125, .125, .25, .25],
        );
        final uiIndex =
            ((rect.center.dy.floor() * preview.width) +
                rect.center.dx.floor()) *
            4;
        _expectRgb(
          preview.rgba.sublist(uiIndex, uiIndex + 3),
          expectedTopLeft[orientation]!,
        );
        final persisted = img.decodeImage(prepared['bytes']! as Uint8List)!;
        final markedPixel = persisted.getPixel(
          ((crop.x + crop.width / 2) * persisted.width).floor(),
          ((crop.y + crop.height / 2) * persisted.height).floor(),
        );
        _expectRgb([
          markedPixel.r.toInt(),
          markedPixel.g.toInt(),
          markedPixel.b.toInt(),
        ], expectedTopLeft[orientation]!);
      },
    );
  }

  test('normalized crop survives oriented 2048 resize and rounding', () async {
    final source = _quadrants(orientation: 6, width: 2051, height: 99);
    final prepared = preparePhoto(source);
    expect(prepared['height'], 2048);
    expect(prepared['width'], 99);
    final crop = await reviewCaptureCrop(
      source,
      _capture(
        source,
        width: 99,
        height: 2051,
        rect: const ui.Rect.fromLTWH(9.9, 205.1, 49.5, 1025.5),
      ),
      photoWidth: prepared['width']! as int,
      photoHeight: prepared['height']! as int,
    );
    expect(crop!.x, closeTo(.1, 1e-12));
    expect(crop.y, closeTo(.1, 1e-12));
    expect(crop.width, closeTo(.5, 1e-12));
    expect(crop.height, closeTo(.5, 1e-12));
  });

  test(
    'already mapped mirrored-preview crop is not flipped a second time',
    () async {
      final source = _quadrants();
      final crop = await reviewCaptureCrop(
        source,
        _capture(source, rect: const ui.Rect.fromLTWH(60, 8, 24, 16)),
        photoWidth: 96,
        photoHeight: 64,
      );
      expect(crop!.x, .625);
      final original = img.decodeImage(source)!;
      final p = original.getPixel(((crop.x + crop.width / 2) * 96).floor(), 16);
      _expectRgb([p.r.toInt(), p.g.toInt(), p.b.toInt()], [20, 240, 20]);
    },
  );

  test('no preview crop preserves full-image fallback', () async {
    final source = _quadrants();
    expect(
      await reviewCaptureCrop(
        source,
        _capture(source, rect: null, cropPath: null),
        photoWidth: 96,
        photoHeight: 64,
      ),
      isNull,
    );
  });

  test(
    'right and bottom edge normalization contains floating-point rounding',
    () async {
      const size = 1080;
      const edge = 16.425108852412535;
      const rect = ui.Rect.fromLTRB(edge, edge, 1080, 1080);
      expect(rect.left / size + rect.width / size, greaterThan(1));
      expect(rect.top / size + rect.height / size, greaterThan(1));
      final source = _quadrants(width: size, height: size);
      final crop = await reviewCaptureCrop(
        source,
        _capture(source, width: size, height: size, rect: rect),
        photoWidth: size,
        photoHeight: size,
      );
      expect(crop!.x, edge / size);
      expect(crop.y, edge / size);
      expect(crop.width, 1 - crop.x);
      expect(crop.height, 1 - crop.y);
      expect(crop.x + crop.width, 1);
      expect(crop.y + crop.height, 1);
    },
  );

  test(
    'missing crop geometry or preview file rejects mismatched approval',
    () async {
      final source = _quadrants();
      for (final capture in [
        _capture(source, rect: null),
        _capture(source, cropPath: null),
      ]) {
        await expectLater(
          reviewCaptureCrop(source, capture, photoWidth: 96, photoHeight: 64),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'out-of-bounds or empty crop is rejected instead of silently clamped',
    () async {
      final source = _quadrants();
      for (final rect in [
        const ui.Rect.fromLTWH(-1, 8, 24, 16),
        const ui.Rect.fromLTWH(80, 8, 24, 16),
        const ui.Rect.fromLTWH(12, 8, 0, 16),
      ]) {
        await expectLater(
          reviewCaptureCrop(
            source,
            _capture(source, rect: rect),
            photoWidth: 96,
            photoHeight: 64,
          ),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'stale source dimensions, crop output dimensions and aspect fail',
    () async {
      final source = _quadrants();
      for (final capture in [
        _capture(source, width: 64, height: 96),
        _capture(source, cropWidth: 25),
      ]) {
        await expectLater(
          reviewCaptureCrop(source, capture, photoWidth: 96, photoHeight: 64),
          throwsFormatException,
        );
      }
      await expectLater(
        reviewCaptureCrop(
          source,
          _capture(source),
          photoWidth: 64,
          photoHeight: 96,
        ),
        throwsFormatException,
      );
      await expectLater(
        reviewCaptureCrop(
          Uint8List.fromList([...source, 0]),
          _capture(source),
          photoWidth: 96,
          photoHeight: 64,
        ),
        throwsFormatException,
      );
    },
  );
}
