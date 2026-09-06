import 'package:coffee_source/coffee_source.dart';

final class SourceCatalogSnapshot {
  SourceCatalogSnapshot({
    required this.manifest,
    required Iterable<SourceRecord> sourceRecords,
    required Iterable<SourceUseAssessment> useAssessments,
  }) : sourceRecords = List<SourceRecord>.unmodifiable(sourceRecords),
       useAssessments = List<SourceUseAssessment>.unmodifiable(useAssessments);

  final SourceCatalogReleaseManifest manifest;
  final List<SourceRecord> sourceRecords;
  final List<SourceUseAssessment> useAssessments;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SourceCatalogSnapshot &&
          other.manifest == manifest &&
          _sameList(other.sourceRecords, sourceRecords) &&
          _sameList(other.useAssessments, useAssessments);

  @override
  int get hashCode => Object.hash(
    manifest,
    Object.hashAll(sourceRecords),
    Object.hashAll(useAssessments),
  );

  @override
  String toString() =>
      'SourceCatalogSnapshot(releaseId: ${manifest.releaseId}, '
      'sourceRecordCount: ${sourceRecords.length}, '
      'assessmentCount: ${useAssessments.length})';
}

bool _sameList<T>(List<T> first, List<T> second) {
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) return false;
  }
  return true;
}
