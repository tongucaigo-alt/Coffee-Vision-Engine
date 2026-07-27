/// Immutable global physical measurements projected from the vision pipeline.
///
/// These values describe residue and deterministic collection counts only.
/// They do not contain confidence, quality, semantic, symbol, or fortune data.
final class VisionGlobalFeatures {
  VisionGlobalFeatures({
    required int residuePixelCount,
    required double contentResidueRatio,
    required int componentCount,
    required int candidateRelationCount,
    required int selectedRelationCount,
  }) : residuePixelCount = _validatedNonNegative(
         residuePixelCount,
         'residuePixelCount',
       ),
       contentResidueRatio = _validatedRatio(contentResidueRatio),
       componentCount = _validatedNonNegative(componentCount, 'componentCount'),
       candidateRelationCount = _validatedNonNegative(
         candidateRelationCount,
         'candidateRelationCount',
       ),
       selectedRelationCount = _validatedSelectedRelationCount(
         selectedRelationCount,
         candidateRelationCount,
       );

  final int residuePixelCount;
  final double contentResidueRatio;
  final int componentCount;
  final int candidateRelationCount;
  final int selectedRelationCount;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is VisionGlobalFeatures &&
            other.residuePixelCount == residuePixelCount &&
            other.contentResidueRatio == contentResidueRatio &&
            other.componentCount == componentCount &&
            other.candidateRelationCount == candidateRelationCount &&
            other.selectedRelationCount == selectedRelationCount;
  }

  @override
  int get hashCode => Object.hash(
    residuePixelCount,
    contentResidueRatio,
    componentCount,
    candidateRelationCount,
    selectedRelationCount,
  );

  @override
  String toString() {
    return 'VisionGlobalFeatures('
        'residuePixelCount: $residuePixelCount, '
        'contentResidueRatio: $contentResidueRatio, '
        'componentCount: $componentCount, '
        'candidateRelationCount: $candidateRelationCount, '
        'selectedRelationCount: $selectedRelationCount)';
  }

  static int _validatedNonNegative(int value, String name) {
    if (value < 0) {
      throw ArgumentError.value(value, name, 'must not be negative');
    }
    return value;
  }

  static double _validatedRatio(double value) {
    if (!value.isFinite || value < 0.0 || value > 1.0) {
      throw ArgumentError.value(
        value,
        'contentResidueRatio',
        'must be finite and between 0.0 and 1.0',
      );
    }
    return value;
  }

  static int _validatedSelectedRelationCount(
    int value,
    int candidateRelationCount,
  ) {
    _validatedNonNegative(value, 'selectedRelationCount');
    if (value > candidateRelationCount) {
      throw ArgumentError.value(
        value,
        'selectedRelationCount',
        'must not exceed candidateRelationCount',
      );
    }
    return value;
  }
}
