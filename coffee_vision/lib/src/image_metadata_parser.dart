import 'dart:typed_data';

import 'models/vision_image_metadata.dart';

const _pngSignature = <int>[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];

VisionImageMetadata parseImageMetadata(Uint8List bytes) {
  if (_startsWith(bytes, _pngSignature)) {
    return _parsePng(bytes);
  }
  if (_isStrictPrefix(bytes, _pngSignature)) {
    throw const FormatException(
      'Image header is incomplete: PNG signature is truncated.',
    );
  }
  if (bytes.length >= 2 && bytes[0] == 0xff && bytes[1] == 0xd8) {
    return _parseJpeg(bytes);
  }
  if (bytes.length == 1 && bytes[0] == 0xff) {
    throw const FormatException(
      'Image header is incomplete: JPEG SOI marker is truncated.',
    );
  }
  throw const FormatException(
    'Unsupported image format: only JPEG and PNG are supported.',
  );
}

VisionImageMetadata _parsePng(Uint8List bytes) {
  const completeHeaderLength = 33;
  if (bytes.length < completeHeaderLength) {
    throw const FormatException('Corrupt PNG: IHDR chunk is incomplete.');
  }

  final data = ByteData.sublistView(bytes);
  final chunkLength = data.getUint32(8, Endian.big);
  if (chunkLength != 13) {
    throw const FormatException('Corrupt PNG: IHDR length must be 13 bytes.');
  }
  if (bytes[12] != 0x49 ||
      bytes[13] != 0x48 ||
      bytes[14] != 0x44 ||
      bytes[15] != 0x52) {
    throw const FormatException('Corrupt PNG: first chunk is not IHDR.');
  }

  final expectedChecksum = data.getUint32(29, Endian.big);
  final actualChecksum = _crc32(bytes, 12, 29);
  if (expectedChecksum != actualChecksum) {
    throw const FormatException('Corrupt PNG: IHDR checksum is invalid.');
  }

  final width = data.getUint32(16, Endian.big);
  final height = data.getUint32(20, Endian.big);
  if (width <= 0 || height <= 0) {
    throw const FormatException(
      'Corrupt PNG: width and height must be greater than zero.',
    );
  }
  return VisionImageMetadata(
    format: VisionImageFormat.png,
    width: width,
    height: height,
  );
}

VisionImageMetadata _parseJpeg(Uint8List bytes) {
  if (bytes.length < 4) {
    throw const FormatException('Corrupt JPEG: marker header is incomplete.');
  }

  var offset = 2;
  while (offset < bytes.length) {
    if (bytes[offset] != 0xff) {
      throw const FormatException(
        'Corrupt JPEG: expected a marker before image dimensions.',
      );
    }
    while (offset < bytes.length && bytes[offset] == 0xff) {
      offset++;
    }
    if (offset >= bytes.length) {
      throw const FormatException('Corrupt JPEG: marker code is incomplete.');
    }

    final marker = bytes[offset++];
    if (marker == 0x00) {
      throw const FormatException(
        'Corrupt JPEG: unexpected stuffed marker before image dimensions.',
      );
    }
    if (marker == 0xd9) {
      throw const FormatException(
        'Corrupt JPEG: image ended before dimensions were found.',
      );
    }
    if (_isStandaloneJpegMarker(marker)) {
      continue;
    }
    if (offset + 2 > bytes.length) {
      throw const FormatException(
        'Corrupt JPEG: segment length is incomplete.',
      );
    }

    final segmentLength = (bytes[offset] << 8) | bytes[offset + 1];
    if (segmentLength < 2) {
      throw const FormatException('Corrupt JPEG: invalid segment length.');
    }
    final segmentEnd = offset + segmentLength;
    if (segmentEnd > bytes.length) {
      throw const FormatException('Corrupt JPEG: segment is truncated.');
    }

    if (_isStartOfFrameMarker(marker)) {
      if (segmentLength < 8) {
        throw const FormatException(
          'Corrupt JPEG: start-of-frame segment is incomplete.',
        );
      }
      final height = (bytes[offset + 3] << 8) | bytes[offset + 4];
      final width = (bytes[offset + 5] << 8) | bytes[offset + 6];
      if (width <= 0 || height <= 0) {
        throw const FormatException(
          'Corrupt JPEG: width and height must be greater than zero.',
        );
      }
      return VisionImageMetadata(
        format: VisionImageFormat.jpeg,
        width: width,
        height: height,
      );
    }
    if (marker == 0xda) {
      throw const FormatException(
        'Corrupt JPEG: scan data started before dimensions were found.',
      );
    }
    offset = segmentEnd;
  }

  throw const FormatException(
    'Corrupt JPEG: no supported start-of-frame segment was found.',
  );
}

bool _startsWith(Uint8List bytes, List<int> signature) {
  if (bytes.length < signature.length) return false;
  for (var index = 0; index < signature.length; index++) {
    if (bytes[index] != signature[index]) return false;
  }
  return true;
}

bool _isStrictPrefix(Uint8List bytes, List<int> signature) {
  if (bytes.isEmpty || bytes.length >= signature.length) return false;
  for (var index = 0; index < bytes.length; index++) {
    if (bytes[index] != signature[index]) return false;
  }
  return true;
}

bool _isStandaloneJpegMarker(int marker) {
  return marker == 0x01 || marker == 0xd8 || (marker >= 0xd0 && marker <= 0xd7);
}

bool _isStartOfFrameMarker(int marker) {
  return (marker >= 0xc0 && marker <= 0xc3) ||
      (marker >= 0xc5 && marker <= 0xc7) ||
      (marker >= 0xc9 && marker <= 0xcb) ||
      (marker >= 0xcd && marker <= 0xcf);
}

int _crc32(Uint8List bytes, int start, int end) {
  var checksum = 0xffffffff;
  for (var index = start; index < end; index++) {
    checksum ^= bytes[index];
    for (var bit = 0; bit < 8; bit++) {
      checksum = (checksum & 1) != 0
          ? (checksum >> 1) ^ 0xedb88320
          : checksum >> 1;
    }
  }
  return (checksum ^ 0xffffffff) & 0xffffffff;
}
