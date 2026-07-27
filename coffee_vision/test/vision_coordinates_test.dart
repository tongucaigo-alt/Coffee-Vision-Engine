import 'package:coffee_vision/coffee_vision.dart';
import 'package:test/test.dart';

void main() {
  group('VisionPoint', () {
    test('can be created with normalized values', () {
      final point = VisionPoint(x: 0.25, y: 0.75);

      expect(point.x, 0.25);
      expect(point.y, 0.75);
      expect(point.toString(), 'VisionPoint(x: 0.25, y: 0.75)');
    });

    test('rejects an out-of-range x value', () {
      expect(() => VisionPoint(x: -0.01, y: 0.5), throwsArgumentError);
    });

    test('rejects an out-of-range y value', () {
      expect(() => VisionPoint(x: 0.5, y: 1.01), throwsArgumentError);
    });
  });

  group('VisionRect', () {
    test('can be created with normalized values', () {
      final rect = VisionRect(left: 0.1, top: 0.2, right: 0.8, bottom: 0.9);

      expect(rect.left, 0.1);
      expect(rect.top, 0.2);
      expect(rect.right, 0.8);
      expect(rect.bottom, 0.9);
      expect(
        rect.toString(),
        'VisionRect(left: 0.1, top: 0.2, right: 0.8, bottom: 0.9)',
      );
    });

    test('rejects left greater than right', () {
      expect(
        () => VisionRect(left: 0.8, top: 0.2, right: 0.1, bottom: 0.9),
        throwsArgumentError,
      );
    });

    test('rejects top greater than bottom', () {
      expect(
        () => VisionRect(left: 0.1, top: 0.9, right: 0.8, bottom: 0.2),
        throwsArgumentError,
      );
    });

    test('calculates width and height', () {
      final rect = VisionRect(left: 0.1, top: 0.2, right: 0.7, bottom: 0.9);

      expect(rect.width, closeTo(0.6, 1e-12));
      expect(rect.height, closeTo(0.7, 1e-12));
    });

    test('calculates center', () {
      final rect = VisionRect(left: 0.2, top: 0.1, right: 0.8, bottom: 0.9);

      expect(rect.center.x, closeTo(0.5, 1e-12));
      expect(rect.center.y, closeTo(0.5, 1e-12));
    });

    test('contains an inside point', () {
      final rect = VisionRect(left: 0.2, top: 0.2, right: 0.8, bottom: 0.8);

      expect(rect.contains(VisionPoint(x: 0.5, y: 0.5)), isTrue);
    });

    test('does not contain an outside point', () {
      final rect = VisionRect(left: 0.2, top: 0.2, right: 0.8, bottom: 0.8);

      expect(rect.contains(VisionPoint(x: 0.9, y: 0.5)), isFalse);
    });
  });

  group('VisionCoordinateMapper', () {
    final mapper = VisionCoordinateMapper(imageWidth: 400, imageHeight: 200);

    test('normalizes the pixel center', () {
      final point = mapper.normalizePoint(pixelX: 200, pixelY: 100);

      expect(point.x, closeTo(0.5, 1e-12));
      expect(point.y, closeTo(0.5, 1e-12));
    });

    test('normalizes the top-left boundary', () {
      final point = mapper.normalizePoint(pixelX: 0, pixelY: 0);

      expect(point, VisionPoint(x: 0, y: 0));
    });

    test('normalizes the bottom-right boundary', () {
      final point = mapper.normalizePoint(pixelX: 400, pixelY: 200);

      expect(point, VisionPoint(x: 1, y: 1));
    });

    test('rejects a negative pixel coordinate', () {
      expect(
        () => mapper.normalizePoint(pixelX: -0.01, pixelY: 100),
        throwsArgumentError,
      );
    });

    test('rejects a pixel coordinate beyond the image boundary', () {
      expect(
        () => mapper.normalizePoint(pixelX: 400.01, pixelY: 100),
        throwsArgumentError,
      );
    });

    test('normalizes a pixel rectangle', () {
      final rect = mapper.normalizeRect(
        left: 40,
        top: 20,
        right: 360,
        bottom: 180,
      );

      expect(rect.left, closeTo(0.1, 1e-12));
      expect(rect.top, closeTo(0.1, 1e-12));
      expect(rect.right, closeTo(0.9, 1e-12));
      expect(rect.bottom, closeTo(0.9, 1e-12));
    });

    test('preserves a pixel point through a normalize round trip', () {
      final normalized = mapper.normalizePoint(pixelX: 123.5, pixelY: 87.25);
      final pixel = mapper.denormalizePoint(normalized);

      expect(pixel.x, closeTo(123.5, 1e-10));
      expect(pixel.y, closeTo(87.25, 1e-10));
    });

    test('rejects non-positive image dimensions', () {
      expect(
        () => VisionCoordinateMapper(imageWidth: 0, imageHeight: 200),
        throwsArgumentError,
      );
    });
  });

  test('equality and hashCode stay consistent', () {
    final firstPoint = VisionPoint(x: 0.25, y: 0.75);
    final secondPoint = VisionPoint(x: 0.25, y: 0.75);
    final firstRect = VisionRect(left: 0.1, top: 0.2, right: 0.8, bottom: 0.9);
    final secondRect = VisionRect(left: 0.1, top: 0.2, right: 0.8, bottom: 0.9);

    expect(firstPoint, secondPoint);
    expect(firstPoint.hashCode, secondPoint.hashCode);
    expect(firstRect, secondRect);
    expect(firstRect.hashCode, secondRect.hashCode);
  });
}
