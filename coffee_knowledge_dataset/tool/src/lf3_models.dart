import 'dart:typed_data';

import 'k6a_models.dart';
import 'lf2_models.dart';
import 'lf3_profiles.dart';

enum Lf3FailureCategory {
  fileReadFailure,
  unsupportedImage,
  corruptedImage,
  visionFailure,
  evidenceDecodeFailure,
  supportUnavailable,
  morphologyFailure,
  nonDeterministicResult,
  residueConservationFailure,
}

final class Lf3SupportEvidence {
  Lf3SupportEvidence({
    required this.centerX,
    required this.centerY,
    required this.radiusX,
    required this.radiusY,
    required this.visibleSampleCount,
    required this.edgeSampleCount,
    required this.edgeContinuity,
    required this.meanBoundaryContrast,
    required Uint8List pixels,
  }) : _pixels = Uint8List.fromList(pixels),
       pixelCount = pixels.fold<int>(0, (total, value) => total + value);

  final double centerX;
  final double centerY;
  final double radiusX;
  final double radiusY;
  final int visibleSampleCount;
  final int edgeSampleCount;
  final double edgeContinuity;
  final double meanBoundaryContrast;
  final int pixelCount;
  final Uint8List _pixels;

  Uint8List get pixels => Uint8List.fromList(_pixels);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Lf3SupportEvidence &&
          other.centerX == centerX &&
          other.centerY == centerY &&
          other.radiusX == radiusX &&
          other.radiusY == radiusY &&
          other.visibleSampleCount == visibleSampleCount &&
          other.edgeSampleCount == edgeSampleCount &&
          other.edgeContinuity == edgeContinuity &&
          other.meanBoundaryContrast == meanBoundaryContrast &&
          _sameBytes(other._pixels, _pixels);

  @override
  int get hashCode => Object.hash(
    centerX,
    centerY,
    radiusX,
    radiusY,
    visibleSampleCount,
    edgeSampleCount,
    edgeContinuity,
    meanBoundaryContrast,
    Object.hashAll(_pixels),
  );
}

final class Lf3EvidenceFrame {
  Lf3EvidenceFrame({
    required this.width,
    required this.height,
    required this.contentBounds,
    required this.globalBackgroundLuminance,
    required Uint8List luminance,
    required Uint8List globalContrast,
    required Uint8List localContrast,
    required Uint8List fusion,
    required this.support,
  }) : _luminance = Uint8List.fromList(luminance),
       _globalContrast = Uint8List.fromList(globalContrast),
       _localContrast = Uint8List.fromList(localContrast),
       _fusion = Uint8List.fromList(fusion) {
    final expectedLength = width * height;
    if (width <= 0 ||
        height <= 0 ||
        _luminance.length != expectedLength ||
        _globalContrast.length != expectedLength ||
        _localContrast.length != expectedLength ||
        _fusion.length != expectedLength) {
      throw ArgumentError('LF-3 evidence dimensions are inconsistent.');
    }
  }

  final int width;
  final int height;
  final Lf2PixelBounds contentBounds;
  final int globalBackgroundLuminance;
  final Lf3SupportEvidence? support;
  final Uint8List _luminance;
  final Uint8List _globalContrast;
  final Uint8List _localContrast;
  final Uint8List _fusion;

  Uint8List get luminance => Uint8List.fromList(_luminance);
  Uint8List get globalContrast => Uint8List.fromList(_globalContrast);
  Uint8List get localContrast => Uint8List.fromList(_localContrast);
  Uint8List get fusion => Uint8List.fromList(_fusion);

  Uint8List evidence(Lf3EvidenceKind kind) => Uint8List.fromList(switch (kind) {
    Lf3EvidenceKind.binary => throw ArgumentError(
      'Binary evidence comes from the canonical ResidueMask.',
    ),
    Lf3EvidenceKind.globalContrast => _globalContrast,
    Lf3EvidenceKind.localContrast => _localContrast,
    Lf3EvidenceKind.fusion => _fusion,
  });
}

final class Lf3ProfileObservation {
  Lf3ProfileObservation({
    required this.profile,
    required this.sourceId,
    required this.surfaceType,
    required this.analysisStatus,
    required this.determinismStatus,
    required this.repeatsPerformed,
    required Iterable<int> mismatchedRepeatIndexes,
    required this.contentBounds,
    required this.support,
    required this.inputEvidencePixelCount,
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

  final Lf3ProfileDefinition profile;
  final String sourceId;
  final K6aSurfaceType surfaceType;
  final K6aAnalysisStatus analysisStatus;
  final K6aDeterminismStatus determinismStatus;
  final int repeatsPerformed;
  final List<int> mismatchedRepeatIndexes;
  final Lf2PixelBounds? contentBounds;
  final Lf3SupportEvidence? support;
  final int inputEvidencePixelCount;
  final List<Lf2CandidateObservation> candidates;
  final int originalResiduePixelCount;
  final int assignedResiduePixelCount;
  final int emittedResiduePixelCount;
  final int suppressedResiduePixelCount;
  final int duplicateResidueAssignmentCount;
  final Lf3FailureCategory? failureCategory;

  String get profileId => profile.id;

  bool get residuePixelsConserved =>
      originalResiduePixelCount == assignedResiduePixelCount &&
      originalResiduePixelCount ==
          emittedResiduePixelCount + suppressedResiduePixelCount &&
      duplicateResidueAssignmentCount == 0;
}

final class Lf3ProfileSummary {
  const Lf3ProfileSummary({
    required this.profileId,
    required this.enabledImageCount,
    required this.successfulImageCount,
    required this.failedImageCount,
    required this.deterministicImageCount,
    required this.nonDeterministicImageCount,
    required this.candidateBudgetImageCount,
    required this.conservedImageCount,
    required this.supportAvailableImageCount,
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
  final int supportAvailableImageCount;
  final int totalCandidateCount;

  double get candidateBudgetRate => enabledImageCount == 0
      ? 0.0
      : candidateBudgetImageCount / enabledImageCount;
}

final class Lf3ObservationReport {
  Lf3ObservationReport({
    required this.researchId,
    required this.sourceDatasetVersion,
    required this.sourceManifestChecksum,
    required this.workingResolution,
    required this.repeatCount,
    required Iterable<Lf3ProfileDefinition> profiles,
    required Iterable<Lf3ProfileSummary> profileSummaries,
    required Iterable<Lf3ProfileObservation> observations,
  }) : profiles = List<Lf3ProfileDefinition>.unmodifiable(profiles),
       profileSummaries = List<Lf3ProfileSummary>.unmodifiable(
         profileSummaries,
       ),
       observations = List<Lf3ProfileObservation>.unmodifiable(observations);

  final String researchId;
  final String sourceDatasetVersion;
  final String sourceManifestChecksum;
  final int workingResolution;
  final int repeatCount;
  final List<Lf3ProfileDefinition> profiles;
  final List<Lf3ProfileSummary> profileSummaries;
  final List<Lf3ProfileObservation> observations;

  bool get succeeded => observations.every(
    (observation) =>
        observation.analysisStatus != K6aAnalysisStatus.failed &&
        observation.determinismStatus !=
            K6aDeterminismStatus.nonDeterministic &&
        observation.residuePixelsConserved,
  );
}

bool _sameBytes(Uint8List first, Uint8List second) {
  if (identical(first, second)) return true;
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) return false;
  }
  return true;
}
