final class VisionPoint {
  VisionPoint({required double x, required double y})
    : x = _validatedNormalizedCoordinate(x, 'x'),
      y = _validatedNormalizedCoordinate(y, 'y');

  final double x;
  final double y;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is VisionPoint && other.x == x && other.y == y;
  }

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'VisionPoint(x: $x, y: $y)';
}

final class VisionRect {
  VisionRect({
    required double left,
    required double top,
    required double right,
    required double bottom,
  }) : left = _validatedNormalizedCoordinate(left, 'left'),
       top = _validatedNormalizedCoordinate(top, 'top'),
       right = _validatedNormalizedCoordinate(right, 'right'),
       bottom = _validatedNormalizedCoordinate(bottom, 'bottom') {
    if (this.left > this.right) {
      throw ArgumentError.value(left, 'left', 'must not be greater than right');
    }
    if (this.top > this.bottom) {
      throw ArgumentError.value(top, 'top', 'must not be greater than bottom');
    }
  }

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;

  VisionPoint get center =>
      VisionPoint(x: left + width / 2, y: top + height / 2);

  bool contains(VisionPoint point) {
    return point.x >= left &&
        point.x <= right &&
        point.y >= top &&
        point.y <= bottom;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is VisionRect &&
            other.left == left &&
            other.top == top &&
            other.right == right &&
            other.bottom == bottom;
  }

  @override
  int get hashCode => Object.hash(left, top, right, bottom);

  @override
  String toString() {
    return 'VisionRect(left: $left, top: $top, right: $right, '
        'bottom: $bottom)';
  }
}

double _validatedNormalizedCoordinate(double value, String name) {
  if (!value.isFinite || value < 0.0 || value > 1.0) {
    throw ArgumentError.value(value, name, 'must be between 0.0 and 1.0');
  }
  return value;
}
