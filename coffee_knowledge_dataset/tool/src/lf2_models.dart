import 'k6a_models.dart';
import 'lf2_profiles.dart';

enum Lf2Polarity { residue, negativeSpace }

enum Lf2FailureCategory {
  fileReadFailure,
  unsupportedImage,
  corruptedImage,
  visionFailure,
  morphologyFailure,
  nonDeterministicResult,
  residueConservationFailure,
}

final class Lf2PixelBounds {
  const Lf2PixelBounds({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final int left;
  final int top;
  final int right;
  final int bottom;

  int get width => right - left;
  int get height => bottom - top;
  int get pixelCount => width * height;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Lf2PixelBounds &&
          other.left == left &&
          other.top == top &&
          other.right == right &&
          other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);
}

final class Lf2CandidateObservation {
  const Lf2CandidateObservation({
    required this.candidateId,
    required this.polarity,
    required this.supportIdentity,
    required this.minimumRowMajorPixelIndex,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.centroidX,
    required this.centroidY,
    required this.pixelCount,
    required this.areaRatio,
    required this.residueContactSectorCount,
    required this.pixelFingerprint,
  });

  final int candidateId;
  final Lf2Polarity polarity;
  final String supportIdentity;
  final int minimumRowMajorPixelIndex;
  final double left;
  final double top;
  final double right;
  final double bottom;
  final double centroidX;
  final double centroidY;
  final int pixelCount;
  final double areaRatio;
  final int residueContactSectorCount;
  final String pixelFingerprint;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Lf2CandidateObservation &&
          other.candidateId == candidateId &&
          other.polarity == polarity &&
          other.supportIdentity == supportIdentity &&
          other.minimumRowMajorPixelIndex == minimumRowMajorPixelIndex &&
          other.left == left &&
          other.top == top &&
          other.right == right &&
          other.bottom == bottom &&
          other.centroidX == centroidX &&
          other.centroidY == centroidY &&
          other.pixelCount == pixelCount &&
          other.areaRatio == areaRatio &&
          other.residueContactSectorCount == residueContactSectorCount &&
          other.pixelFingerprint == pixelFingerprint;

  @override
  int get hashCode => Object.hash(
    candidateId,
    polarity,
    supportIdentity,
    minimumRowMajorPixelIndex,
    left,
    top,
    right,
    bottom,
    centroidX,
    centroidY,
    pixelCount,
    areaRatio,
    residueContactSectorCount,
    pixelFingerprint,
  );
}

final class Lf2ExtractionResult {
  Lf2ExtractionResult({
    required Iterable<Lf2CandidateObservation> candidates,
    required this.originalResiduePixelCount,
    required this.assignedResiduePixelCount,
    required this.emittedResiduePixelCount,
    required this.suppressedResiduePixelCount,
    required this.duplicateResidueAssignmentCount,
  }) : candidates = List<Lf2CandidateObservation>.unmodifiable(candidates);

  final List<Lf2CandidateObservation> candidates;
  final int originalResiduePixelCount;
  final int assignedResiduePixelCount;
  final int emittedResiduePixelCount;
  final int suppressedResiduePixelCount;
  final int duplicateResidueAssignmentCount;

  bool get residuePixelsConserved =>
      originalResiduePixelCount == assignedResiduePixelCount &&
      originalResiduePixelCount ==
          emittedResiduePixelCount + suppressedResiduePixelCount &&
      duplicateResidueAssignmentCount == 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Lf2ExtractionResult &&
          _same(other.candidates, candidates) &&
          other.originalResiduePixelCount == originalResiduePixelCount &&
          other.assignedResiduePixelCount == assignedResiduePixelCount &&
          other.emittedResiduePixelCount == emittedResiduePixelCount &&
          other.suppressedResiduePixelCount == suppressedResiduePixelCount &&
          other.duplicateResidueAssignmentCount ==
              duplicateResidueAssignmentCount;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(candidates),
    originalResiduePixelCount,
    assignedResiduePixelCount,
    emittedResiduePixelCount,
    suppressedResiduePixelCount,
    duplicateResidueAssignmentCount,
  );
}

final class Lf2ProfileObservation {
  Lf2ProfileObservation({
    required this.profileId,
    required this.sourceId,
    required this.surfaceType,
    required this.analysisStatus,
    required this.determinismStatus,
    required this.repeatsPerformed,
    required Iterable<int> mismatchedRepeatIndexes,
    required this.contentBounds,
    required Iterable<Lf2CandidateObservation> candidates,
    required this.originalResiduePixelCount,
    required this.assignedResiduePixelCount,
    required this.emittedResiduePixelCount,
    required this.suppressedResiduePixelCount,
    required this.duplicateResidueAssignmentCount,
    this.failureCategory,
  }) : mismatchedRepeatIndexes = List<int>.unmodifiable(
         mismatchedRepeatIndexes,
       ),
       candidates = List<Lf2CandidateObservation>.unmodifiable(candidates);

  final String profileId;
  final String sourceId;
  final K6aSurfaceType surfaceType;
  final K6aAnalysisStatus analysisStatus;
  final K6aDeterminismStatus determinismStatus;
  final int repeatsPerformed;
  final List<int> mismatchedRepeatIndexes;
  final Lf2PixelBounds? contentBounds;
  final List<Lf2CandidateObservation> candidates;
  final int originalResiduePixelCount;
  final int assignedResiduePixelCount;
  final int emittedResiduePixelCount;
  final int suppressedResiduePixelCount;
  final int duplicateResidueAssignmentCount;
  final Lf2FailureCategory? failureCategory;

  bool get residuePixelsConserved =>
      originalResiduePixelCount == assignedResiduePixelCount &&
      originalResiduePixelCount ==
          emittedResiduePixelCount + suppressedResiduePixelCount &&
      duplicateResidueAssignmentCount == 0;
}

final class Lf2ProfileSummary {
  const Lf2ProfileSummary({
    required this.profileId,
    required this.enabledImageCount,
    required this.successfulImageCount,
    required this.failedImageCount,
    required this.deterministicImageCount,
    required this.nonDeterministicImageCount,
    required this.candidateBudgetImageCount,
    required this.conservedImageCount,
    required this.totalCandidateCount,
  });

  final String profileId;
  final int enabledImageCount;
  final int successfulImageCount;
  final int failedImageCount;
  final int deterministicImageCount;
  final int nonDeterministicImageCount;
  final int candidateBudgetImageCount;
  final int conservedImageCount;
  final int totalCandidateCount;

  double get candidateBudgetRate => enabledImageCount == 0
      ? 0.0
      : candidateBudgetImageCount / enabledImageCount;
}

final class Lf2ObservationReport {
  Lf2ObservationReport({
    required this.researchId,
    required this.sourceDatasetVersion,
    required this.sourceManifestChecksum,
    required this.workingResolution,
    required this.repeatCount,
    required Iterable<Lf2ProfileDefinition> profiles,
    required Iterable<Lf2ProfileSummary> profileSummaries,
    required Iterable<Lf2ProfileObservation> observations,
  }) : profiles = List<Lf2ProfileDefinition>.unmodifiable(profiles),
       profileSummaries = List<Lf2ProfileSummary>.unmodifiable(
         profileSummaries,
       ),
       observations = List<Lf2ProfileObservation>.unmodifiable(observations);

  final String researchId;
  final String sourceDatasetVersion;
  final String sourceManifestChecksum;
  final int workingResolution;
  final int repeatCount;
  final List<Lf2ProfileDefinition> profiles;
  final List<Lf2ProfileSummary> profileSummaries;
  final List<Lf2ProfileObservation> observations;

  bool get succeeded => observations.every(
    (observation) =>
        observation.analysisStatus != K6aAnalysisStatus.failed &&
        observation.determinismStatus !=
            K6aDeterminismStatus.nonDeterministic &&
        observation.residuePixelsConserved,
  );
}

bool _same(Iterable<Object?> first, Iterable<Object?> second) {
  final firstIterator = first.iterator;
  final secondIterator = second.iterator;
  while (true) {
    final firstNext = firstIterator.moveNext();
    final secondNext = secondIterator.moveNext();
    if (firstNext != secondNext) return false;
    if (!firstNext) return true;
    if (firstIterator.current != secondIterator.current) return false;
  }
}
