import 'knowledge_constraint.dart';

/// Immutable externally defined set of physical Pattern expectations.
final class KnowledgeRecord {
  factory KnowledgeRecord({
    required String id,
    required Iterable<KnowledgeConstraint> constraints,
  }) {
    final validatedId = validateKnowledgeRecordId(id);
    final canonical = constraints.toList(growable: false)
      ..sort((first, second) => first.key.index.compareTo(second.key.index));
    if (canonical.isEmpty) {
      throw ArgumentError.value(
        constraints,
        'constraints',
        'must not be empty',
      );
    }
    for (var index = 1; index < canonical.length; index++) {
      if (canonical[index - 1].key == canonical[index].key) {
        throw ArgumentError.value(
          canonical[index].key,
          'constraints',
          'must contain at most one constraint for each key',
        );
      }
    }
    return KnowledgeRecord._(
      id: validatedId,
      constraints: List<KnowledgeConstraint>.unmodifiable(canonical),
    );
  }

  const KnowledgeRecord._({required this.id, required this.constraints});

  /// Stable opaque identity within an external knowledge dataset.
  final String id;

  /// Canonically ordered required physical constraints.
  final List<KnowledgeConstraint> constraints;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is KnowledgeRecord &&
            other.id == id &&
            _sameList(other.constraints, constraints);
  }

  @override
  int get hashCode => Object.hash(id, Object.hashAll(constraints));

  @override
  String toString() {
    return 'KnowledgeRecord(id: $id, constraintCount: ${constraints.length})';
  }

  static bool _sameList<T>(List<T> first, List<T> second) {
    if (identical(first, second)) return true;
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }
}

String validateKnowledgeRecordId(String value) {
  if (value.isEmpty || value.trim() != value) {
    throw ArgumentError.value(
      value,
      'id',
      'must be non-empty and contain no surrounding whitespace',
    );
  }
  return value;
}
