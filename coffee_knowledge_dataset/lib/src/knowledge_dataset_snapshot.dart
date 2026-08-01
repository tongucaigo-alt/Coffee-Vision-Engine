import 'package:coffee_knowledge/coffee_knowledge.dart';

/// Immutable runtime view of one validated physical Knowledge dataset.
final class KnowledgeDatasetSnapshot {
  factory KnowledgeDatasetSnapshot({
    required String schemaVersion,
    required String datasetVersion,
    required Iterable<KnowledgeRecord> activeRecords,
    required int totalRecordCount,
  }) {
    if (schemaVersion != '1.0') {
      throw ArgumentError.value(
        schemaVersion,
        'schemaVersion',
        'must equal "1.0"',
      );
    }
    if (datasetVersion.isEmpty || datasetVersion.trim() != datasetVersion) {
      throw ArgumentError.value(
        datasetVersion,
        'datasetVersion',
        'must be non-empty with no surrounding whitespace',
      );
    }

    final canonicalRecords = activeRecords.toList(growable: false)
      ..sort((first, second) => first.id.compareTo(second.id));
    for (var index = 1; index < canonicalRecords.length; index++) {
      if (canonicalRecords[index - 1].id == canonicalRecords[index].id) {
        throw ArgumentError.value(
          canonicalRecords[index].id,
          'activeRecords',
          'must contain unique KnowledgeRecord IDs',
        );
      }
    }
    if (totalRecordCount < canonicalRecords.length) {
      throw ArgumentError.value(
        totalRecordCount,
        'totalRecordCount',
        'must not be smaller than the active record count',
      );
    }

    return KnowledgeDatasetSnapshot._(
      schemaVersion: schemaVersion,
      datasetVersion: datasetVersion,
      activeRecords: List<KnowledgeRecord>.unmodifiable(canonicalRecords),
      totalRecordCount: totalRecordCount,
    );
  }

  const KnowledgeDatasetSnapshot._({
    required this.schemaVersion,
    required this.datasetVersion,
    required this.activeRecords,
    required this.totalRecordCount,
  });

  final String schemaVersion;
  final String datasetVersion;

  /// Enabled records in case-sensitive [String.compareTo] order.
  final List<KnowledgeRecord> activeRecords;

  /// Enabled and disabled records present in the source document.
  final int totalRecordCount;

  int get disabledRecordCount => totalRecordCount - activeRecords.length;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is KnowledgeDatasetSnapshot &&
            other.schemaVersion == schemaVersion &&
            other.datasetVersion == datasetVersion &&
            other.totalRecordCount == totalRecordCount &&
            _sameList(other.activeRecords, activeRecords);
  }

  @override
  int get hashCode => Object.hash(
    schemaVersion,
    datasetVersion,
    totalRecordCount,
    Object.hashAll(activeRecords),
  );

  @override
  String toString() {
    return 'KnowledgeDatasetSnapshot('
        'datasetVersion: $datasetVersion, '
        'activeRecordCount: ${activeRecords.length}, '
        'disabledRecordCount: $disabledRecordCount)';
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
