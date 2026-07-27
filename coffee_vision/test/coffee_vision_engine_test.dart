import 'dart:io';
import 'dart:typed_data';

import 'package:coffee_vision/coffee_vision.dart';
import 'package:test/test.dart';

void main() {
  group('CoffeeVisionEngine', () {
    test('can be created', () {
      expect(const CoffeeVisionEngine(), isA<CoffeeVisionEngine>());
    });

    test('rejects empty image bytes', () {
      expect(
        () => VisionImageInput(
          imageBytes: Uint8List(0),
          surfaceType: VisionSurfaceType.cup,
        ),
        throwsArgumentError,
      );
    });

    test('accepts valid input and returns the matching surface type', () async {
      final result = await _analyzeFixture(
        'valid_2x3.png',
        surfaceType: VisionSurfaceType.saucer,
      );

      expect(result, isA<VisionObservation>());
      expect(result.surfaceType, VisionSurfaceType.saucer);
    });

    test(
      'returns an honest technical note without symbols or fortune',
      () async {
        final result = await _analyzeFixture('valid_2x3.png');
        final normalizedNotes = result.notes.join(' ').toLowerCase();

        expect(result.notes, const [
          'Image metadata analysis completed; further Coffee Vision analysis '
              'is not implemented.',
        ]);
        expect(normalizedNotes, isNot(contains('symbol')));
        expect(normalizedNotes, isNot(contains('fortune')));
        expect(normalizedNotes, isNot(contains('fal')));
        expect(normalizedNotes, isNot(contains('sembol')));
      },
    );

    test('keeps mutable inputs and observation notes isolated', () {
      final originalBytes = Uint8List.fromList([4, 5, 6]);
      final input = VisionImageInput(
        imageBytes: originalBytes,
        surfaceType: VisionSurfaceType.cup,
      );
      originalBytes[0] = 99;
      final exposedBytes = input.imageBytes;
      exposedBytes[1] = 88;

      final observation = VisionObservation(
        surfaceType: VisionSurfaceType.cup,
        confidence: 0.5,
        notes: const ['technical'],
        imageMetadata: VisionImageMetadata(
          format: VisionImageFormat.png,
          width: 2,
          height: 3,
        ),
      );

      expect(input.imageBytes, [4, 5, 6]);
      expect(() => observation.notes.add('changed'), throwsUnsupportedError);
    });

    test('rejects confidence outside the normalized range', () {
      expect(
        () => VisionObservation(
          surfaceType: VisionSurfaceType.cup,
          confidence: 1.01,
          notes: const [],
          imageMetadata: VisionImageMetadata(
            format: VisionImageFormat.png,
            width: 2,
            height: 3,
          ),
        ),
        throwsArgumentError,
      );
    });

    test('reads PNG format', () async {
      final result = await _analyzeFixture('valid_2x3.png');

      expect(result.imageMetadata.format, VisionImageFormat.png);
    });

    test('reports resized PNG width and height', () async {
      final result = await _analyzeFixture('valid_2x3.png');

      expect(result.imageMetadata.width, 512);
      expect(result.imageMetadata.height, 512);
    });

    test('reads JPEG format', () async {
      final result = await _analyzeFixture('valid_3x2.jpg');

      expect(result.imageMetadata.format, VisionImageFormat.jpeg);
    });

    test('reports resized JPEG width and height', () async {
      final result = await _analyzeFixture('valid_3x2.jpg');

      expect(result.imageMetadata.width, 512);
      expect(result.imageMetadata.height, 512);
    });

    test('rejects corrupt PNG', () async {
      await expectLater(
        _analyzeFixture('corrupt.png'),
        throwsA(_formatExceptionContaining('Corrupt PNG')),
      );
    });

    test('rejects corrupt JPEG', () async {
      await expectLater(
        _analyzeFixture('corrupt.jpg'),
        throwsA(_formatExceptionContaining('Corrupt JPEG')),
      );
    });

    test('rejects unsupported formats', () async {
      await expectLater(
        _analyzeFixture('unsupported.gif'),
        throwsA(_formatExceptionContaining('Unsupported image format')),
      );
    });

    test('rejects incomplete image headers', () async {
      await expectLater(
        _analyzeFixture('incomplete_header.bin'),
        throwsA(_formatExceptionContaining('Image header is incomplete')),
      );
    });

    test('keeps confidence at zero after metadata analysis', () async {
      final result = await _analyzeFixture('valid_3x2.jpg');

      expect(result.confidence, 0.0);
    });

    test('rejects non-positive metadata dimensions', () {
      expect(
        () => VisionImageMetadata(
          format: VisionImageFormat.jpeg,
          width: 0,
          height: 2,
        ),
        throwsArgumentError,
      );
    });
  });
}

Future<VisionObservation> _analyzeFixture(
  String name, {
  VisionSurfaceType surfaceType = VisionSurfaceType.cup,
}) async {
  final bytes = await File('test/fixtures/$name').readAsBytes();
  return const CoffeeVisionEngine().analyze(
    VisionImageInput(
      imageBytes: bytes,
      surfaceType: surfaceType,
      sourceId: name,
    ),
  );
}

Matcher _formatExceptionContaining(String message) {
  return isA<FormatException>().having(
    (error) => error.message.toString(),
    'message',
    contains(message),
  );
}
