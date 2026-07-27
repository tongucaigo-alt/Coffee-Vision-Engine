/// Canonical physical Pattern field that a knowledge constraint may reference.
enum KnowledgeConstraintKey {
  geometryLeft,
  geometryTop,
  geometryRight,
  geometryBottom,
  geometryCentroidX,
  geometryCentroidY,
  geometryWidth,
  geometryHeight,
  geometryAspectRatio,
  geometryTouchesWorkingImageBorder,
  topologyNodeCount,
  topologyDirectedEdgeCount,
  topologyIsIsolated,
}

/// The value contract used by one physical knowledge constraint.
enum KnowledgeConstraintKind { doubleRange, integerRange, booleanEquals }

/// Immutable physical expectation over one approved Pattern field.
///
/// A constraint defines expected physical values. It never stores observed
/// Pattern evidence, semantic labels, scores, confidence, or interpretation.
final class KnowledgeConstraint {
  factory KnowledgeConstraint.doubleRange({
    required KnowledgeConstraintKey key,
    required double minimum,
    required double maximum,
  }) {
    if (!isDoubleConstraintKey(key)) {
      throw ArgumentError.value(
        key,
        'key',
        'must reference a double-valued Pattern field',
      );
    }
    if (!minimum.isFinite || !maximum.isFinite) {
      throw ArgumentError('Double range bounds must be finite.');
    }
    if (minimum > maximum) {
      throw ArgumentError.value(
        minimum,
        'minimum',
        'must not be greater than maximum',
      );
    }
    validateDoubleRangeDomain(key: key, minimum: minimum, maximum: maximum);
    return KnowledgeConstraint._(
      key: key,
      kind: KnowledgeConstraintKind.doubleRange,
      minimumDouble: minimum,
      maximumDouble: maximum,
    );
  }

  factory KnowledgeConstraint.integerRange({
    required KnowledgeConstraintKey key,
    required int minimum,
    required int maximum,
  }) {
    if (!isIntegerConstraintKey(key)) {
      throw ArgumentError.value(
        key,
        'key',
        'must reference an integer-valued Pattern field',
      );
    }
    if (minimum > maximum) {
      throw ArgumentError.value(
        minimum,
        'minimum',
        'must not be greater than maximum',
      );
    }
    validateIntegerRangeDomain(key: key, minimum: minimum, maximum: maximum);
    return KnowledgeConstraint._(
      key: key,
      kind: KnowledgeConstraintKind.integerRange,
      minimumInteger: minimum,
      maximumInteger: maximum,
    );
  }

  factory KnowledgeConstraint.booleanEquals({
    required KnowledgeConstraintKey key,
    required bool expected,
  }) {
    if (!isBooleanConstraintKey(key)) {
      throw ArgumentError.value(
        key,
        'key',
        'must reference a boolean-valued Pattern field',
      );
    }
    return KnowledgeConstraint._(
      key: key,
      kind: KnowledgeConstraintKind.booleanEquals,
      expectedBoolean: expected,
    );
  }

  const KnowledgeConstraint._({
    required this.key,
    required this.kind,
    this.minimumDouble,
    this.maximumDouble,
    this.minimumInteger,
    this.maximumInteger,
    this.expectedBoolean,
  });

  final KnowledgeConstraintKey key;
  final KnowledgeConstraintKind kind;
  final double? minimumDouble;
  final double? maximumDouble;
  final int? minimumInteger;
  final int? maximumInteger;
  final bool? expectedBoolean;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is KnowledgeConstraint &&
            other.key == key &&
            other.kind == kind &&
            other.minimumDouble == minimumDouble &&
            other.maximumDouble == maximumDouble &&
            other.minimumInteger == minimumInteger &&
            other.maximumInteger == maximumInteger &&
            other.expectedBoolean == expectedBoolean;
  }

  @override
  int get hashCode => Object.hash(
    key,
    kind,
    minimumDouble,
    maximumDouble,
    minimumInteger,
    maximumInteger,
    expectedBoolean,
  );

  @override
  String toString() {
    return 'KnowledgeConstraint(key: $key, kind: $kind)';
  }
}

bool isDoubleConstraintKey(KnowledgeConstraintKey key) {
  return switch (key) {
    KnowledgeConstraintKey.geometryLeft ||
    KnowledgeConstraintKey.geometryTop ||
    KnowledgeConstraintKey.geometryRight ||
    KnowledgeConstraintKey.geometryBottom ||
    KnowledgeConstraintKey.geometryCentroidX ||
    KnowledgeConstraintKey.geometryCentroidY ||
    KnowledgeConstraintKey.geometryWidth ||
    KnowledgeConstraintKey.geometryHeight ||
    KnowledgeConstraintKey.geometryAspectRatio => true,
    _ => false,
  };
}

bool isIntegerConstraintKey(KnowledgeConstraintKey key) {
  return switch (key) {
    KnowledgeConstraintKey.topologyNodeCount ||
    KnowledgeConstraintKey.topologyDirectedEdgeCount => true,
    _ => false,
  };
}

bool isBooleanConstraintKey(KnowledgeConstraintKey key) {
  return switch (key) {
    KnowledgeConstraintKey.geometryTouchesWorkingImageBorder ||
    KnowledgeConstraintKey.topologyIsIsolated => true,
    _ => false,
  };
}

bool isGeometryConstraintKey(KnowledgeConstraintKey key) {
  return key.index <=
      KnowledgeConstraintKey.geometryTouchesWorkingImageBorder.index;
}

void validateDoubleRangeDomain({
  required KnowledgeConstraintKey key,
  required double minimum,
  required double maximum,
}) {
  switch (key) {
    case KnowledgeConstraintKey.geometryLeft:
    case KnowledgeConstraintKey.geometryTop:
    case KnowledgeConstraintKey.geometryRight:
    case KnowledgeConstraintKey.geometryBottom:
    case KnowledgeConstraintKey.geometryCentroidX:
    case KnowledgeConstraintKey.geometryCentroidY:
      if (minimum < 0.0 || maximum > 1.0) {
        throw ArgumentError(
          'Normalized coordinate bounds must stay between 0.0 and 1.0.',
        );
      }
    case KnowledgeConstraintKey.geometryWidth:
    case KnowledgeConstraintKey.geometryHeight:
      if (minimum < 0.0 || maximum <= 0.0 || maximum > 1.0) {
        throw ArgumentError(
          'Normalized extent bounds must overlap the range (0.0, 1.0].',
        );
      }
    case KnowledgeConstraintKey.geometryAspectRatio:
      if (minimum < 0.0 || maximum <= 0.0) {
        throw ArgumentError(
          'Aspect-ratio bounds must overlap the positive range.',
        );
      }
    case KnowledgeConstraintKey.geometryTouchesWorkingImageBorder:
    case KnowledgeConstraintKey.topologyNodeCount:
    case KnowledgeConstraintKey.topologyDirectedEdgeCount:
    case KnowledgeConstraintKey.topologyIsIsolated:
      throw ArgumentError.value(key, 'key', 'does not support a double range');
  }
}

void validateIntegerRangeDomain({
  required KnowledgeConstraintKey key,
  required int minimum,
  required int maximum,
}) {
  switch (key) {
    case KnowledgeConstraintKey.topologyNodeCount:
      if (minimum < 1 || maximum < 1) {
        throw ArgumentError('Topology node-count bounds must be positive.');
      }
    case KnowledgeConstraintKey.topologyDirectedEdgeCount:
      if (minimum < 0 || maximum < 0) {
        throw ArgumentError('Directed-edge-count bounds must not be negative.');
      }
    case KnowledgeConstraintKey.geometryLeft:
    case KnowledgeConstraintKey.geometryTop:
    case KnowledgeConstraintKey.geometryRight:
    case KnowledgeConstraintKey.geometryBottom:
    case KnowledgeConstraintKey.geometryCentroidX:
    case KnowledgeConstraintKey.geometryCentroidY:
    case KnowledgeConstraintKey.geometryWidth:
    case KnowledgeConstraintKey.geometryHeight:
    case KnowledgeConstraintKey.geometryAspectRatio:
    case KnowledgeConstraintKey.geometryTouchesWorkingImageBorder:
    case KnowledgeConstraintKey.topologyIsIsolated:
      throw ArgumentError.value(
        key,
        'key',
        'does not support an integer range',
      );
  }
}

void validateObservedDouble({
  required KnowledgeConstraintKey key,
  required double value,
}) {
  if (!value.isFinite) {
    throw ArgumentError.value(value, 'observedValue', 'must be finite');
  }
  final valid = switch (key) {
    KnowledgeConstraintKey.geometryLeft ||
    KnowledgeConstraintKey.geometryTop => value >= 0.0 && value < 1.0,
    KnowledgeConstraintKey.geometryRight ||
    KnowledgeConstraintKey.geometryBottom => value > 0.0 && value <= 1.0,
    KnowledgeConstraintKey.geometryCentroidX ||
    KnowledgeConstraintKey.geometryCentroidY => value >= 0.0 && value <= 1.0,
    KnowledgeConstraintKey.geometryWidth ||
    KnowledgeConstraintKey.geometryHeight => value > 0.0 && value <= 1.0,
    KnowledgeConstraintKey.geometryAspectRatio => value > 0.0,
    _ => false,
  };
  if (!valid) {
    throw ArgumentError.value(
      value,
      'observedValue',
      'must satisfy the physical domain for $key',
    );
  }
}

void validateObservedInteger({
  required KnowledgeConstraintKey key,
  required int value,
}) {
  final valid = switch (key) {
    KnowledgeConstraintKey.topologyNodeCount => value >= 1,
    KnowledgeConstraintKey.topologyDirectedEdgeCount => value >= 0,
    _ => false,
  };
  if (!valid) {
    throw ArgumentError.value(
      value,
      'observedValue',
      'must satisfy the physical domain for $key',
    );
  }
}
