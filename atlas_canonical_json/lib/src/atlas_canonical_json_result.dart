import 'dart:collection';

/// Immutable canonical bytes and their Atlas-formatted SHA-256 checksum.
final class AtlasCanonicalJsonResult {
  AtlasCanonicalJsonResult.internal({
    required List<int> canonicalBytes,
    required this.checksum,
  }) : canonicalBytes = UnmodifiableListView<int>(List<int>.of(canonicalBytes));

  final List<int> canonicalBytes;
  final String checksum;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AtlasCanonicalJsonResult || other.checksum != checksum) {
      return false;
    }
    if (other.canonicalBytes.length != canonicalBytes.length) return false;
    for (var index = 0; index < canonicalBytes.length; index++) {
      if (other.canonicalBytes[index] != canonicalBytes[index]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(checksum, Object.hashAll(canonicalBytes));

  @override
  String toString() =>
      'AtlasCanonicalJsonResult(byteLength: ${canonicalBytes.length}, '
      'checksum: $checksum)';
}
