import 'dart:io';
import 'dart:typed_data';

import 'package:coffee_vision/coffee_vision.dart';
import 'package:coffee_vision/src/working_image_factory.dart';
import 'package:test/test.dart';

void main() {
  group('VisionConfig', () {
    test('uses 512 as the default working resolution', () {
      expect(
        const VisionConfig().workingResolution,
        VisionConfig.defaultWorkingResolution,
      );
      expect(VisionConfig.defaultWorkingResolution, 512);
    });

    test('accepts a different positive working resolution', () {
      expect(const VisionConfig(workingResolution: 256).workingResolution, 256);
    });

    test('rejects a zero working resolution', () {
      expect(
        () => VisionConfig(workingResolution: 0),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rejects a negative working resolution', () {
      expect(
        () => VisionConfig(workingResolution: -1),
        throwsA(isA<AssertionError>()),
      );
    });

    test('keeps equality and hashCode consistent', () {
      const first = VisionConfig(workingResolution: 256);
      const second = VisionConfig(workingResolution: 256);

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });
  });

  group('WorkingImage', () {
    final metadata = VisionImageMetadata(
      format: VisionImageFormat.png,
      width: 2,
      height: 3,
    );

    test('can be created with valid data', () {
      final image = WorkingImage(
        bytes: Uint8List.fromList([1, 2, 3]),
        metadata: metadata,
        resolution: 512,
      );

      expect(image.bytes, [1, 2, 3]);
      expect(image.resolution, 512);
    });

    test('rejects empty bytes', () {
      expect(
        () => WorkingImage(
          bytes: Uint8List(0),
          metadata: metadata,
          resolution: 512,
        ),
        throwsArgumentError,
      );
    });

    test('rejects a zero resolution', () {
      expect(
        () => WorkingImage(
          bytes: Uint8List.fromList([1]),
          metadata: metadata,
          resolution: 0,
        ),
        throwsArgumentError,
      );
    });

    test('rejects a negative resolution', () {
      expect(
        () => WorkingImage(
          bytes: Uint8List.fromList([1]),
          metadata: metadata,
          resolution: -1,
        ),
        throwsArgumentError,
      );
    });

    test('preserves the metadata reference', () {
      final image = WorkingImage(
        bytes: Uint8List.fromList([1]),
        metadata: metadata,
        resolution: 512,
      );

      expect(identical(image.metadata, metadata), isTrue);
      expect(identical(image.sourceMetadata, metadata), isTrue);
      expect(identical(image.workingMetadata, metadata), isTrue);
      expect(
        image.contentRect,
        VisionRect(left: 0.0, top: 0.0, right: 1.0, bottom: 1.0),
      );
    });

    test('preserves explicit source, working, and content metadata', () {
      final sourceMetadata = VisionImageMetadata(
        format: VisionImageFormat.png,
        width: 3,
        height: 2,
      );
      final workingMetadata = VisionImageMetadata(
        format: VisionImageFormat.png,
        width: 8,
        height: 8,
      );
      final contentRect = VisionRect(
        left: 0.0,
        top: 0.125,
        right: 1.0,
        bottom: 0.75,
      );

      final image = WorkingImage(
        bytes: Uint8List.fromList([1, 2, 3]),
        metadata: workingMetadata,
        sourceMetadata: sourceMetadata,
        workingMetadata: workingMetadata,
        contentRect: contentRect,
        resolution: 8,
      );

      expect(identical(image.sourceMetadata, sourceMetadata), isTrue);
      expect(identical(image.workingMetadata, workingMetadata), isTrue);
      expect(identical(image.metadata, workingMetadata), isTrue);
      expect(identical(image.contentRect, contentRect), isTrue);
    });

    test('defensively isolates byte data', () {
      final original = Uint8List.fromList([1, 2, 3]);
      final image = WorkingImage(
        bytes: original,
        metadata: metadata,
        resolution: 512,
      );
      original[0] = 99;
      final exposed = image.bytes;
      exposed[1] = 88;

      expect(image.bytes, [1, 2, 3]);
    });

    test('keeps equality and hashCode consistent', () {
      final first = WorkingImage(
        bytes: Uint8List.fromList([1, 2, 3]),
        metadata: metadata,
        resolution: 512,
      );
      final second = WorkingImage(
        bytes: Uint8List.fromList([1, 2, 3]),
        metadata: VisionImageMetadata(
          format: VisionImageFormat.png,
          width: 2,
          height: 3,
        ),
        resolution: 512,
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });
  });

  group('WorkingImageFactory', () {
    test('creates a working image from a valid PNG', () async {
      final image = await _createWorkingImage('valid_2x3.png');

      expect(image.metadata.format, VisionImageFormat.png);
    });

    test('creates a working image from a valid JPEG', () async {
      final image = await _createWorkingImage('valid_3x2.jpg');

      expect(image.metadata.format, VisionImageFormat.jpeg);
    });

    test('does not modify the original byte data', () async {
      final bytes = await _fixtureBytes('valid_2x3.png');
      final before = Uint8List.fromList(bytes);
      final input = VisionImageInput(
        imageBytes: bytes,
        surfaceType: VisionSurfaceType.cup,
      );

      const WorkingImageFactory(config: VisionConfig()).create(input);

      expect(bytes, before);
    });

    test('stores source and working metadata', () async {
      final image = await _createWorkingImage('valid_3x2.jpg');

      expect(image.sourceMetadata.width, 3);
      expect(image.sourceMetadata.height, 2);
      expect(image.workingMetadata.width, 512);
      expect(image.workingMetadata.height, 512);
      expect(image.metadata.width, 512);
      expect(image.metadata.height, 512);
      expect(image.resolution, 512);
    });

    test('transfers the configured target resolution', () async {
      final image = await _createWorkingImage(
        'valid_2x3.png',
        config: const VisionConfig(workingResolution: 256),
      );

      expect(image.resolution, 256);
      expect(image.workingMetadata.width, 256);
      expect(image.workingMetadata.height, 256);
    });

    test('preserves controlled errors for corrupt images', () async {
      final bytes = await _fixtureBytes('corrupt.png');
      final input = VisionImageInput(
        imageBytes: bytes,
        surfaceType: VisionSurfaceType.cup,
      );

      expect(
        () => const WorkingImageFactory(config: VisionConfig()).create(input),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message.toString(),
            'message',
            contains('Corrupt PNG'),
          ),
        ),
      );
    });
  });

  group('CoffeeVisionEngine working-image integration', () {
    test('works with the default config', () async {
      const engine = CoffeeVisionEngine();

      expect(engine.config, const VisionConfig());
      expect(await _analyze(engine, 'valid_2x3.png'), isA<VisionObservation>());
    });

    test('works with a custom config', () async {
      const config = VisionConfig(workingResolution: 256);
      const engine = CoffeeVisionEngine(config: config);

      expect(engine.config, config);
      expect(await _analyze(engine, 'valid_3x2.jpg'), isA<VisionObservation>());
    });

    test('prepares valid PNG and JPEG inputs through the public API', () async {
      const engine = CoffeeVisionEngine();

      final png = await _prepare(engine, 'valid_2x3.png');
      final jpeg = await _prepare(engine, 'valid_3x2.jpg');

      expect(png.workingMetadata.format, VisionImageFormat.png);
      expect(jpeg.workingMetadata.format, VisionImageFormat.jpeg);
    });

    test('exposes default working metadata and actual contentRect', () async {
      final image = await _prepare(const CoffeeVisionEngine(), 'valid_2x3.png');

      expect(image.sourceMetadata.width, 2);
      expect(image.sourceMetadata.height, 3);
      expect(image.workingMetadata.width, 512);
      expect(image.workingMetadata.height, 512);
      expect(image.resolution, 512);
      expect(
        image.contentRect,
        VisionRect(left: 85 / 512, top: 0.0, right: 426 / 512, bottom: 1.0),
      );
    });

    test('applies custom config through the public API', () async {
      const engine = CoffeeVisionEngine(
        config: VisionConfig(workingResolution: 256),
      );

      final image = await _prepare(engine, 'valid_3x2.jpg');

      expect(image.sourceMetadata.width, 3);
      expect(image.sourceMetadata.height, 2);
      expect(image.workingMetadata.width, 256);
      expect(image.workingMetadata.height, 256);
      expect(image.resolution, 256);
      expect(
        image.contentRect,
        VisionRect(left: 0.0, top: 42 / 256, right: 1.0, bottom: 213 / 256),
      );
    });

    test('does not modify input bytes during public preparation', () async {
      final bytes = await _fixtureBytes('valid_2x3.png');
      final before = Uint8List.fromList(bytes);

      await const CoffeeVisionEngine().prepareWorkingImage(
        VisionImageInput(imageBytes: bytes, surfaceType: VisionSurfaceType.cup),
      );

      expect(bytes, before);
    });

    test('preserves controlled corrupt-image errors', () async {
      final bytes = await _fixtureBytes('corrupt.png');

      await expectLater(
        const CoffeeVisionEngine().prepareWorkingImage(
          VisionImageInput(
            imageBytes: bytes,
            surfaceType: VisionSurfaceType.cup,
          ),
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message.toString(),
            'message',
            contains('Corrupt PNG'),
          ),
        ),
      );
    });

    test('preserves controlled unsupported-format errors', () async {
      final bytes = await _fixtureBytes('unsupported.gif');

      await expectLater(
        const CoffeeVisionEngine().prepareWorkingImage(
          VisionImageInput(
            imageBytes: bytes,
            surfaceType: VisionSurfaceType.saucer,
          ),
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message.toString(),
            'message',
            contains('Unsupported image format'),
          ),
        ),
      );
    });

    test('analyze uses the same public working-image pipeline', () async {
      const engine = CoffeeVisionEngine();
      final prepared = await _prepare(engine, 'valid_3x2.jpg');
      final observation = await _analyze(engine, 'valid_3x2.jpg');

      expect(observation.imageMetadata.format, prepared.metadata.format);
      expect(observation.imageMetadata.width, prepared.metadata.width);
      expect(observation.imageMetadata.height, prepared.metadata.height);
    });

    test('uses the working-image metadata pipeline', () async {
      final result = await _analyze(
        const CoffeeVisionEngine(),
        'valid_3x2.jpg',
      );

      expect(result.imageMetadata.format, VisionImageFormat.jpeg);
      expect(result.imageMetadata.width, 512);
      expect(result.imageMetadata.height, 512);
    });

    test('keeps the placeholder observation unchanged', () async {
      final result = await _analyze(
        const CoffeeVisionEngine(),
        'valid_2x3.png',
      );

      expect(result.confidence, 0.0);
      expect(result.notes, const [
        'Image metadata analysis completed; further Coffee Vision analysis '
            'is not implemented.',
      ]);
    });

    test('keeps the original constructor usage working', () async {
      const engine = CoffeeVisionEngine();
      final result = await _analyze(engine, 'valid_2x3.png');

      expect(result.surfaceType, VisionSurfaceType.cup);
    });
  });
}

Future<WorkingImage> _createWorkingImage(
  String fixtureName, {
  VisionConfig config = const VisionConfig(),
}) async {
  final bytes = await _fixtureBytes(fixtureName);
  final input = VisionImageInput(
    imageBytes: bytes,
    surfaceType: VisionSurfaceType.cup,
  );
  return WorkingImageFactory(config: config).create(input);
}

Future<VisionObservation> _analyze(
  CoffeeVisionEngine engine,
  String fixtureName,
) async {
  final bytes = await _fixtureBytes(fixtureName);
  return engine.analyze(
    VisionImageInput(imageBytes: bytes, surfaceType: VisionSurfaceType.cup),
  );
}

Future<WorkingImage> _prepare(
  CoffeeVisionEngine engine,
  String fixtureName,
) async {
  final bytes = await _fixtureBytes(fixtureName);
  return engine.prepareWorkingImage(
    VisionImageInput(imageBytes: bytes, surfaceType: VisionSurfaceType.cup),
  );
}

Future<Uint8List> _fixtureBytes(String name) {
  return File('test/fixtures/$name').readAsBytes();
}
