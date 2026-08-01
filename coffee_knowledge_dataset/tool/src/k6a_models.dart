import 'package:coffee_pattern/coffee_pattern.dart';

enum K6aSurfaceType { cup, saucer }

enum K6aAnalysisStatus { success, failed, skippedDisabled }

enum K6aDeterminismStatus { deterministic, nonDeterministic, notRun }

enum K6aFailureCategory {
  fileReadFailure,
  unsupportedImage,
  corruptedImage,
  visionFailure,
  patternFailure,
  nonDeterministicResult,
}

final class K6aDatasetEntry {
  const K6aDatasetEntry({
    required this.sourceId,
    required this.relativePath,
    required this.surfaceType,
    required this.format,
    required this.ownership,
    required this.consent,
    required this.enabled,
    required this.contentChecksum,
  });

  final String sourceId;
  final String relativePath;
  final K6aSurfaceType surfaceType;
  final String format;
  final String ownership;
  final String consent;
  final bool enabled;
  final String contentChecksum;
}

final class K6aFrozenDataset {
  K6aFrozenDataset({
    required this.datasetVersion,
    required this.manifestChecksum,
    required Iterable<K6aDatasetEntry> entries,
  }) : entries = List<K6aDatasetEntry>.unmodifiable(entries);

  final String datasetVersion;
  final String manifestChecksum;
  final List<K6aDatasetEntry> entries;
}

final class K6aCandidateObservation {
  K6aCandidateObservation({
    required this.candidateId,
    required Iterable<PatternEvidence> evidence,
    required this.geometry,
    required this.topology,
  }) : evidence = List<PatternEvidence>.unmodifiable(evidence);

  final int candidateId;
  final List<PatternEvidence> evidence;
  final PatternGeometry geometry;
  final PatternTopology topology;
}

final class K6aImageObservation {
  K6aImageObservation({
    required this.sourceId,
    required this.surfaceType,
    required this.analysisStatus,
    required this.determinismStatus,
    required this.repeatsPerformed,
    required Iterable<int> mismatchedRepeatIndexes,
    required Iterable<K6aCandidateObservation> candidates,
    this.failureCategory,
  }) : mismatchedRepeatIndexes = List<int>.unmodifiable(
         mismatchedRepeatIndexes,
       ),
       candidates = List<K6aCandidateObservation>.unmodifiable(candidates);

  final String sourceId;
  final K6aSurfaceType surfaceType;
  final K6aAnalysisStatus analysisStatus;
  final K6aDeterminismStatus determinismStatus;
  final int repeatsPerformed;
  final List<int> mismatchedRepeatIndexes;
  final List<K6aCandidateObservation> candidates;
  final K6aFailureCategory? failureCategory;
}

final class K6aObservationSummary {
  const K6aObservationSummary({
    required this.totalEntries,
    required this.enabledEntries,
    required this.disabledEntries,
    required this.successfulEntries,
    required this.failedEntries,
    required this.deterministicEntries,
    required this.nonDeterministicEntries,
    required this.cupEntries,
    required this.saucerEntries,
    required this.candidateCount,
    required this.cupCandidateCount,
    required this.saucerCandidateCount,
  });

  final int totalEntries;
  final int enabledEntries;
  final int disabledEntries;
  final int successfulEntries;
  final int failedEntries;
  final int deterministicEntries;
  final int nonDeterministicEntries;
  final int cupEntries;
  final int saucerEntries;
  final int candidateCount;
  final int cupCandidateCount;
  final int saucerCandidateCount;
}

final class K6aObservationReport {
  K6aObservationReport({
    required this.researchId,
    required this.sourceDatasetVersion,
    required this.sourceManifestChecksum,
    required this.repeatCount,
    required this.summary,
    required Iterable<K6aImageObservation> records,
  }) : records = List<K6aImageObservation>.unmodifiable(records);

  final String researchId;
  final String sourceDatasetVersion;
  final String sourceManifestChecksum;
  final int repeatCount;
  final K6aObservationSummary summary;
  final List<K6aImageObservation> records;

  bool get succeeded =>
      summary.failedEntries == 0 && summary.nonDeterministicEntries == 0;
}
