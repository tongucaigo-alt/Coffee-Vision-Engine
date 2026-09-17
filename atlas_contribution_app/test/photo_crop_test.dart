import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'package:atlas_contribution_app/src/photo_crop.dart';

void main() {
  test(
    'display crop round trips with explicit full-photo coordinate space',
    () {
      final crop = PhotoCrop(.2, .1, .6, .5);
      expect(PhotoCrop.fromJson(crop.toJson()).toJson(), crop.toJson());
      expect(crop.toJson()['version'], 'atlas-display-crop-v1');
      expect(crop.toJson()['coordinateSpace'], 'orientedFullPhotoNormalized');
      expect(crop.aspectRatio(160, 200), closeTo(.96, 1e-12));
      expect(PhotoCrop.full.aspectRatio(160, 200), .8);
    },
  );

  test('invalid crop metadata is rejected', () {
    for (final values in [
      [-.1, 0.0, .5, .5],
      [0.0, double.nan, .5, .5],
      [0.0, 0.0, double.infinity, .5],
      [0.0, 0.0, 0.0, .5],
      [.8, 0.0, .3, .5],
      [0.0, .8, .5, .3],
    ]) {
      expect(
        () => PhotoCrop(values[0], values[1], values[2], values[3]),
        throwsArgumentError,
      );
    }
    final valid = PhotoCrop.full.toJson();
    expect(
      () => PhotoCrop.fromJson({...valid, 'version': 'unknown'}),
      throwsFormatException,
    );
    expect(
      () => PhotoCrop.fromJson({...valid, 'coordinateSpace': 'screen'}),
      throwsFormatException,
    );
    expect(() => PhotoCrop.full.aspectRatio(0, 10), throwsArgumentError);
  });

  test('display box maps to full photo and back without changing bounds', () {
    final crop = PhotoCrop(.2, .1, .6, .5);
    final display = RegionBox(.1, .2, .3, .4);
    final full = crop.toFullBox(display);
    expect(full.x, closeTo(.26, 1e-12));
    expect(full.y, closeTo(.2, 1e-12));
    expect(full.width, closeTo(.18, 1e-12));
    expect(full.height, closeTo(.2, 1e-12));
    expect(crop.containsBox(full), isTrue);
    final restored = crop.toDisplayBox(full);
    for (final field in ['x', 'y', 'width', 'height']) {
      expect(restored.toJson()[field], closeTo(display.toJson()[field], 1e-12));
    }
    expect(PhotoCrop.full.toFullBox(display), same(display));
    expect(PhotoCrop.full.toDisplayBox(display), same(display));
  });

  test(
    'outside boxes are rejected instead of clipped; boundary boxes survive',
    () {
      final crop = PhotoCrop(.2, .1, .6, .5);
      final outside = RegionBox(.15, .2, .2, .1);
      expect(crop.containsBox(outside), isFalse);
      expect(() => crop.toDisplayBox(outside), throwsArgumentError);
      final exact = crop.toDisplayBox(RegionBox(.2, .1, .6, .5));
      expect(exact.toJson(), RegionBox(0, 0, 1, 1).toJson());
    },
  );
}
