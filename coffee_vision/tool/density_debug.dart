import 'dart:io';

import 'package:coffee_vision/coffee_vision.dart';

const _usage =
    'Usage: dart run tool/density_debug.dart <image-path> <cup|saucer>';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 2) {
    _fail(_usage, 64);
    return;
  }

  final surfaceType = _parseSurfaceType(arguments[1]);
  if (surfaceType == null) {
    _fail(
      'Invalid surface type "${arguments[1]}". Expected cup or saucer.\n'
      '$_usage',
      64,
    );
    return;
  }

  final imageFile = File(arguments[0]);
  try {
    if (!await imageFile.exists()) {
      _fail('Image file not found: ${imageFile.path}', 66);
      return;
    }

    final input = VisionImageInput(
      imageBytes: await imageFile.readAsBytes(),
      surfaceType: surfaceType,
      sourceId: imageFile.absolute.path,
    );
    const engine = CoffeeVisionEngine();
    final workingImage = await engine.prepareWorkingImage(input);
    final densities = await engine.analyzeRegionDensities(
      workingImage: workingImage,
      surfaceType: surfaceType,
    );

    _printResult(
      imageFile: imageFile,
      surfaceType: surfaceType,
      workingImage: workingImage,
      densities: densities,
    );
  } on FileSystemException catch (error) {
    _fail('Could not read image file: ${error.message}', 74);
  } on FormatException catch (error) {
    _fail('Invalid or unsupported image: ${error.message}', 65);
  } on ArgumentError catch (error) {
    _fail('Invalid image input: ${error.message}', 65);
  }
}

VisionSurfaceType? _parseSurfaceType(String value) {
  return switch (value.trim().toLowerCase()) {
    'cup' => VisionSurfaceType.cup,
    'saucer' => VisionSurfaceType.saucer,
    _ => null,
  };
}

void _printResult({
  required File imageFile,
  required VisionSurfaceType surfaceType,
  required WorkingImage workingImage,
  required List<VisionRegionDensity> densities,
}) {
  final densitiesByRegion = {
    for (final result in densities) result.regionId: result,
  };
  final contentRect = workingImage.contentRect;

  stdout
    ..writeln('Surface: ${surfaceType.name}')
    ..writeln('Image: ${_fileName(imageFile)}')
    ..writeln(
      'Source image: ${workingImage.sourceMetadata.format.name.toUpperCase()} '
      '${workingImage.sourceMetadata.width}x'
      '${workingImage.sourceMetadata.height}',
    )
    ..writeln(
      'Working image: ${workingImage.workingMetadata.width}x'
      '${workingImage.workingMetadata.height}',
    )
    ..writeln(
      'Content rect: left=${contentRect.left.toStringAsFixed(4)}, '
      'top=${contentRect.top.toStringAsFixed(4)}, '
      'right=${contentRect.right.toStringAsFixed(4)}, '
      'bottom=${contentRect.bottom.toStringAsFixed(4)}',
    );

  for (final regionId in VisionRegionId.values) {
    final result = densitiesByRegion[regionId];
    if (result == null) {
      throw StateError('Missing density result for ${regionId.name}.');
    }
    stdout.writeln('${regionId.name}: ${result.density.toStringAsFixed(4)}');
  }
}

String _fileName(File file) {
  final segments = file.absolute.uri.pathSegments.where(
    (segment) => segment.isNotEmpty,
  );
  return segments.isEmpty ? file.path : segments.last;
}

void _fail(String message, int code) {
  stderr.writeln(message);
  exitCode = code;
}
