import 'package:coffee_pattern/coffee_pattern.dart';

import 'k6a_models.dart';
import 'lf1_profiles.dart';

final class Lf1CandidateObservation {
  Lf1CandidateObservation({
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

final class Lf1ProfileObservation {
  Lf1ProfileObservation({
    required this.profileId,
    required this.sourceId,
    required this.surfaceType,
    required this.analysisStatus,
    required this.determinismStatus,
    required this.repeatsPerformed,
    required Iterable<int> mismatchedRepeatIndexes,
    required Iterable<Lf1CandidateObservation> candidates,
    this.failureCategory,
  }) : mismatchedRepeatIndexes = List<int>.unmodifiable(
         mismatchedRepeatIndexes,
       ),
       candidates = List<Lf1CandidateObservation>.unmodifiable(candidates);

  final String profileId;
  final String sourceId;
  final K6aSurfaceType surfaceType;
  final K6aAnalysisStatus analysisStatus;
  final K6aDeterminismStatus determinismStatus;
  final int repeatsPerformed;
  final List<int> mismatchedRepeatIndexes;
  final List<Lf1CandidateObservation> candidates;
  final K6aFailureCategory? failureCategory;
}

final class Lf1ProfileSummary {
  const Lf1ProfileSummary({
    required this.profileId,
    required this.enabledImageCount,
    required this.successfulImageCount,
    required this.failedImageCount,
    required this.deterministicImageCount,
    required this.nonDeterministicImageCount,
    required this.candidateBudgetImageCount,
    required this.totalCandidateCount,
  });

  final String profileId;
  final int enabledImageCount;
  final int successfulImageCount;
  final int failedImageCount;
  final int deterministicImageCount;
  final int nonDeterministicImageCount;
  final int candidateBudgetImageCount;
  final int totalCandidateCount;

  double get candidateBudgetRate => enabledImageCount == 0
      ? 0.0
      : candidateBudgetImageCount / enabledImageCount;
}

final class Lf1ObservationReport {
  Lf1ObservationReport({
    required this.researchId,
    required this.sourceDatasetVersion,
    required this.sourceManifestChecksum,
    required this.workingResolution,
    required this.repeatCount,
    required Iterable<Lf1ProfileDefinition> profiles,
    required Iterable<Lf1ProfileSummary> profileSummaries,
    required Iterable<Lf1ProfileObservation> observations,
  }) : profiles = List<Lf1ProfileDefinition>.unmodifiable(profiles),
       profileSummaries = List<Lf1ProfileSummary>.unmodifiable(
         profileSummaries,
       ),
       observations = List<Lf1ProfileObservation>.unmodifiable(observations);

  final String researchId;
  final String sourceDatasetVersion;
  final String sourceManifestChecksum;
  final int workingResolution;
  final int repeatCount;
  final List<Lf1ProfileDefinition> profiles;
  final List<Lf1ProfileSummary> profileSummaries;
  final List<Lf1ProfileObservation> observations;

  bool get succeeded => observations.every(
    (observation) =>
        observation.analysisStatus != K6aAnalysisStatus.failed &&
        observation.determinismStatus != K6aDeterminismStatus.nonDeterministic,
  );
}
