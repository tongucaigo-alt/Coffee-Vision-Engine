/// Immutable normalized image-plane geometry of one physical pattern.
///
/// Bounds and centroid coordinates use the working image coordinate space:
/// the top-left is `(0.0, 0.0)` and the bottom-right is `(1.0, 1.0)`.
final class PatternGeometry {
  factory PatternGeometry({
    required double left,
    required double top,
    required double right,
    required double bottom,
    required double centroidX,
    required double centroidY,
  }) {
    _validateNormalized(left, 'left');
    _validateNormalized(top, 'top');
    _validateNormalized(right, 'right');
    _validateNormalized(bottom, 'bottom');
    _validateNormalized(centroidX, 'centroidX');
    _validateNormalized(centroidY, 'centroidY');

    if (left >= right) {
      throw ArgumentError.value(right, 'right', 'must be greater than left');
    }
    if (top >= bottom) {
      throw ArgumentError.value(bottom, 'bottom', 'must be greater than top');
    }
    if (centroidX < left || centroidX > right) {
      throw ArgumentError.value(
        centroidX,
        'centroidX',
        'must be inside the horizontal bounds',
      );
    }
    if (centroidY < top || centroidY > bottom) {
      throw ArgumentError.value(
        centroidY,
        'centroidY',
        'must be inside the vertical bounds',
      );
    }

    final width = right - left;
    final height = bottom - top;
    final aspectRatio = width / height;
    if (!width.isFinite || width <= 0.0) {
      throw ArgumentError.value(width, 'width', 'must be finite and positive');
    }
    if (!height.isFinite || height <= 0.0) {
      throw ArgumentError.value(
        height,
        'height',
        'must be finite and positive',
      );
    }
    if (!aspectRatio.isFinite || aspectRatio <= 0.0) {
      throw ArgumentError.value(
        aspectRatio,
        'aspectRatio',
        'must be finite and positive',
      );
    }

    return PatternGeometry._(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      centroidX: centroidX,
      centroidY: centroidY,
    );
  }

  const PatternGeometry._({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.centroidX,
    required this.centroidY,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;
  final double centroidX;
  final double centroidY;

  double get width => right - left;
  double get height => bottom - top;
  double get aspectRatio => width / height;

  /// Whether the pattern reaches the outer working-image boundary.
  bool get touchesWorkingImageBorder =>
      left == 0.0 || top == 0.0 || right == 1.0 || bottom == 1.0;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PatternGeometry &&
            other.left == left &&
            other.top == top &&
            other.right == right &&
            other.bottom == bottom &&
            other.centroidX == centroidX &&
            other.centroidY == centroidY;
  }

  @override
  int get hashCode =>
      Object.hash(left, top, right, bottom, centroidX, centroidY);

  @override
  String toString() {
    return 'PatternGeometry('
        'left: $left, top: $top, right: $right, bottom: $bottom, '
        'centroidX: $centroidX, centroidY: $centroidY)';
  }

  static void _validateNormalized(double value, String name) {
    if (!value.isFinite || value < 0.0 || value > 1.0) {
      throw ArgumentError.value(
        value,
        name,
        'must be finite and between 0.0 and 1.0',
      );
    }
  }
}
