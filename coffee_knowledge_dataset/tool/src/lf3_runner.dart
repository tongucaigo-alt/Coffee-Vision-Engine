import 'dart:io';
import 'dart:typed_data';

import 'package:coffee_vision/coffee_vision.dart';

import 'k6a_dataset.dart';
import 'k6a_models.dart';
import 'lf2_models.dart';
import 'lf2_morphology.dart';
import 'lf2_profiles.dart';
import 'lf3_evidence.dart';
import 'lf3_models.dart';
import 'lf3_profiles.dart';

typedef Lf3WorkingImagePreparer =
    Future<WorkingImage> Function(VisionImageInput input);
typedef Lf3ResidueMaskCreator =
    Future<ResidueMask> Function(WorkingImage workingImage);
typedef Lf3EvidenceOperation =
    Lf3EvidenceFrame Function(WorkingImage workingImage);
typedef Lf3MaskOperation =
    ResidueMask? Function({
      required ResidueMask baseline,
      required Lf3EvidenceFrame evidence,
      required Lf3ProfileDefinition profile,
    });
typedef Lf3ExtractionOperation =
    Lf2ExtractionResult Function({
      required String profileId,
      required String sourceId,
      required ResidueMask mask,
      required VisionRect contentRect,
      required Lf2ProfileDefinition profile,
    });
typedef Lf3ProgressListener =
    void Function(int completed, int total, Lf3ProfileObservation observation);

final class Lf3EvidenceRunner {
  Lf3EvidenceRunner({
    K6aDatasetPreflight preflight = const K6aDatasetPreflight(),
    Iterable<Lf3ProfileDefinition> profiles = lf3Profiles,
    Lf3WorkingImagePreparer? workingImagePreparer,
    Lf3ResidueMaskCreator? residueMaskCreator,
    Lf3EvidenceOperation? evidenceOperation,
    Lf3MaskOperation? maskOperation,
    Lf3ExtractionOperation? extractionOperation,
    Lf3ProgressListener? progressListener,
  }) : _preflight = preflight,
       _profiles = _canonicalProfiles(profiles),
       _workingImagePreparer =
           workingImagePreparer ??
           const CoffeeVisionEngine().prepareWorkingImage,
       _residueMaskCreator =
           residueMaskCreator ??
           ((workingImage) => const CoffeeVisionEngine().createResidueMask(
             workingImage: workingImage,
           )),
       _evidenceOperation =
           evidenceOperation ?? const Lf3EvidenceBuilder().build,
       _maskOperation = maskOperation ?? const Lf3MaskFactory().create,
       _extractionOperation =
           extractionOperation ?? const Lf2MorphologyExtractor().extract,
       _progressListener = progressListener;

  final K6aDatasetPreflight _preflight;
  final List<Lf3ProfileDefinition> _profiles;
  final Lf3WorkingImagePreparer _workingImagePreparer;
  final Lf3ResidueMaskCreator _residueMaskCreator;
  final Lf3EvidenceOperation _evidenceOperation;
  final Lf3MaskOperation _maskOperation;
  final Lf3ExtractionOperation _extractionOperation;
  final Lf3ProgressListener? _progressListener;

  Future<Lf3ObservationReport> run({
    required String datasetRoot,
    required String manifestPath,
    required String freezePath,
    required int repeatCount,
    String researchId = 'lfr-003',
  }) async {
    if (repeatCount <= 0) {
      throw ArgumentError.value(
        repeatCount,
        'repeatCount',
        'must be greater than zero',
      );
    }
    if (researchId.isEmpty || researchId.trim() != researchId) {
      throw ArgumentError.value(
        researchId,
        'researchId',
        'must be non-empty with no surrounding whitespace',
      );
    }

    final dataset = await _preflight.validate(
      datasetRoot: datasetRoot,
      manifestPath: manifestPath,
      freezePath: freezePath,
    );
    final observations = <Lf3ProfileObservation>[];
    final total = dataset.entries.length * _profiles.length;
    var completed = 0;
    for (final entry in dataset.entries) {
      final entryObservations = await _analyzeEntry(
        datasetRoot: datasetRoot,
        entry: entry,
        repeatCount: repeatCount,
      );
      for (final observation in entryObservations) {
        observations.add(observation);
        completed++;
        _progressListener?.call(completed, total, observation);
      }
    }
    observations.sort(_compareObservations);

    return Lf3ObservationReport(
      researchId: researchId,
      sourceDatasetVersion: dataset.datasetVersion,
      sourceManifestChecksum: dataset.manifestChecksum,
      workingResolution: VisionConfig.defaultWorkingResolution,
      repeatCount: repeatCount,
      profiles: _profiles,
      profileSummaries: _summarize(dataset.entries, observations, _profiles),
      observations: observations,
    );
  }

  Future<List<Lf3ProfileObservation>> _analyzeEntry({
    required String datasetRoot,
    required K6aDatasetEntry entry,
    required int repeatCount,
  }) async {
    if (!entry.enabled) {
      return _emptyObservations(
        entry: entry,
        analysisStatus: K6aAnalysisStatus.skippedDisabled,
        determinismStatus: K6aDeterminismStatus.notRun,
      );
    }

    final Uint8List bytes;
    try {
      bytes = await File(
        _resolveRelativePath(datasetRoot, entry.relativePath),
      ).readAsBytes();
    } on FileSystemException {
      return _emptyObservations(
        entry: entry,
        analysisStatus: K6aAnalysisStatus.failed,
        determinismStatus: K6aDeterminismStatus.notRun,
        failureCategory: Lf3FailureCategory.fileReadFailure,
      );
    }

    final input = VisionImageInput(
      imageBytes: bytes,
      surfaceType: switch (entry.surfaceType) {
        K6aSurfaceType.cup => VisionSurfaceType.cup,
        K6aSurfaceType.saucer => VisionSurfaceType.saucer,
      },
      sourceId: entry.sourceId,
    );
    Map<String, _Lf3ProfileRun>? references;
    Lf2PixelBounds? referenceBounds;
    Lf3SupportEvidence? referenceSupport;
    final mismatches = <String, List<int>>{
      for (final profile in _profiles) profile.id: <int>[],
    };

    for (var repeat = 1; repeat <= repeatCount; repeat++) {
      final WorkingImage workingImage;
      final ResidueMask baseline;
      final Lf3EvidenceFrame evidence;
      try {
        workingImage = await _workingImagePreparer(input);
        baseline = await _residueMaskCreator(workingImage);
        if (baseline.width != workingImage.workingMetadata.width ||
            baseline.height != workingImage.workingMetadata.height) {
          throw StateError(
            'Residue mask dimensions do not match working image.',
          );
        }
        evidence = _evidenceOperation(workingImage);
        if (evidence.width != baseline.width ||
            evidence.height != baseline.height) {
          throw StateError(
            'LF-3 evidence dimensions do not match residue mask.',
          );
        }
      } on FormatException catch (error) {
        return _emptyObservations(
          entry: entry,
          analysisStatus: K6aAnalysisStatus.failed,
          determinismStatus: K6aDeterminismStatus.notRun,
          repeatsPerformed: repeat,
          failureCategory: error.message.contains('Unsupported image format')
              ? Lf3FailureCategory.unsupportedImage
              : Lf3FailureCategory.evidenceDecodeFailure,
        );
      } on Object {
        return _emptyObservations(
          entry: entry,
          analysisStatus: K6aAnalysisStatus.failed,
          determinismStatus: K6aDeterminismStatus.notRun,
          repeatsPerformed: repeat,
          failureCategory: Lf3FailureCategory.visionFailure,
        );
      }

      final currentBounds = evidence.contentBounds;
      final current = <String, _Lf3ProfileRun>{};
      for (final profile in _profiles) {
        try {
          final mask = _maskOperation(
            baseline: baseline,
            evidence: evidence,
            profile: profile,
          );
          if (mask == null) {
            current[profile.id] = const _Lf3ProfileRun.failure(
              Lf3FailureCategory.supportUnavailable,
            );
            continue;
          }
          final extraction = _extractionOperation(
            profileId: profile.id,
            sourceId: entry.sourceId,
            mask: mask,
            contentRect: workingImage.contentRect,
            profile: Lf2ProfileDefinition(
              id: profile.id,
              closingRadius: profile.closingRadius,
              minimumRegionRatio: profile.minimumRegionRatio,
            ),
          );
          current[profile.id] = _Lf3ProfileRun.success(
            mask: mask,
            extraction: extraction,
          );
        } on Object {
          current[profile.id] = const _Lf3ProfileRun.failure(
            Lf3FailureCategory.morphologyFailure,
          );
        }
      }

      if (references == null) {
        references = current;
        referenceBounds = currentBounds;
        referenceSupport = evidence.support;
      } else {
        for (final profile in _profiles) {
          if (currentBounds != referenceBounds ||
              (profile.supportRequired &&
                  evidence.support != referenceSupport) ||
              current[profile.id] != references[profile.id]) {
            mismatches[profile.id]!.add(repeat);
          }
        }
      }
    }

    return List<Lf3ProfileObservation>.unmodifiable(
      _profiles.map((profile) {
        final run = references![profile.id]!;
        final profileMismatches = mismatches[profile.id]!;
        final deterministic = profileMismatches.isEmpty;
        final extraction = run.extraction;
        final failure = !deterministic
            ? Lf3FailureCategory.nonDeterministicResult
            : run.failureCategory ??
                  (extraction != null && !extraction.residuePixelsConserved
                      ? Lf3FailureCategory.residueConservationFailure
                      : null);
        return Lf3ProfileObservation(
          profile: profile,
          sourceId: entry.sourceId,
          surfaceType: entry.surfaceType,
          analysisStatus: failure == null
              ? K6aAnalysisStatus.success
              : K6aAnalysisStatus.failed,
          determinismStatus: deterministic
              ? K6aDeterminismStatus.deterministic
              : K6aDeterminismStatus.nonDeterministic,
          repeatsPerformed: repeatCount,
          mismatchedRepeatIndexes: profileMismatches,
          contentBounds: referenceBounds,
          support: referenceSupport,
          inputEvidencePixelCount: run.mask?.residuePixelCount ?? 0,
          candidates: extraction?.candidates ?? const [],
          originalResiduePixelCount: extraction?.originalResiduePixelCount ?? 0,
          assignedResiduePixelCount: extraction?.assignedResiduePixelCount ?? 0,
          emittedResiduePixelCount: extraction?.emittedResiduePixelCount ?? 0,
          suppressedResiduePixelCount:
              extraction?.suppressedResiduePixelCount ?? 0,
          duplicateResidueAssignmentCount:
              extraction?.duplicateResidueAssignmentCount ?? 0,
          failureCategory: failure,
        );
      }),
    );
  }

  List<Lf3ProfileObservation> _emptyObservations({
    required K6aDatasetEntry entry,
    required K6aAnalysisStatus analysisStatus,
    required K6aDeterminismStatus determinismStatus,
    int repeatsPerformed = 0,
    Lf2PixelBounds? contentBounds,
    Lf3FailureCategory? failureCategory,
  }) {
    return List<Lf3ProfileObservation>.unmodifiable(
      _profiles.map(
        (profile) => Lf3ProfileObservation(
          profile: profile,
          sourceId: entry.sourceId,
          surfaceType: entry.surfaceType,
          analysisStatus: analysisStatus,
          determinismStatus: determinismStatus,
          repeatsPerformed: repeatsPerformed,
          mismatchedRepeatIndexes: const [],
          contentBounds: contentBounds,
          support: null,
          inputEvidencePixelCount: 0,
          candidates: const [],
          originalResiduePixelCount: 0,
          assignedResiduePixelCount: 0,
          emittedResiduePixelCount: 0,
          suppressedResiduePixelCount: 0,
          duplicateResidueAssignmentCount: 0,
          failureCategory: failureCategory,
        ),
      ),
    );
  }

  static List<Lf3ProfileSummary> _summarize(
    List<K6aDatasetEntry> entries,
    List<Lf3ProfileObservation> observations,
    List<Lf3ProfileDefinition> profiles,
  ) {
    final enabledCount = entries.where((entry) => entry.enabled).length;
    return List<Lf3ProfileSummary>.unmodifiable(
      profiles.map((profile) {
        final records = observations
            .where((record) => record.profileId == profile.id)
            .toList(growable: false);
        final successful = records
            .where(
              (record) => record.analysisStatus == K6aAnalysisStatus.success,
            )
            .toList(growable: false);
        return Lf3ProfileSummary(
          profileId: profile.id,
          enabledImageCount: enabledCount,
          successfulImageCount: successful.length,
          failedImageCount: records
              .where(
                (record) => record.analysisStatus == K6aAnalysisStatus.failed,
              )
              .length,
          deterministicImageCount: records
              .where(
                (record) =>
                    record.determinismStatus ==
                    K6aDeterminismStatus.deterministic,
              )
              .length,
          nonDeterministicImageCount: records
              .where(
                (record) =>
                    record.determinismStatus ==
                    K6aDeterminismStatus.nonDeterministic,
              )
              .length,
          candidateBudgetImageCount: successful
              .where(
                (record) =>
                    record.candidates.isNotEmpty &&
                    record.candidates.length <= 12,
              )
              .length,
          conservedImageCount: successful
              .where((record) => record.residuePixelsConserved)
              .length,
          supportAvailableImageCount: records
              .where((record) => record.support != null)
              .length,
          totalCandidateCount: successful.fold(
            0,
            (total, record) => total + record.candidates.length,
          ),
        );
      }),
    );
  }

  static List<Lf3ProfileDefinition> _canonicalProfiles(
    Iterable<Lf3ProfileDefinition> profiles,
  ) {
    final materialized = profiles.toList(growable: false);
    if (materialized.isEmpty) {
      throw ArgumentError.value(profiles, 'profiles', 'must not be empty');
    }
    final ids = <String>{};
    for (final profile in materialized) {
      if (!ids.add(profile.id)) {
        throw ArgumentError.value(
          profile.id,
          'profiles',
          'must contain unique profile IDs',
        );
      }
    }
    return List<Lf3ProfileDefinition>.of(materialized)
      ..sort((first, second) => first.id.compareTo(second.id));
  }

  static int _compareObservations(
    Lf3ProfileObservation first,
    Lf3ProfileObservation second,
  ) {
    final profile = first.profileId.compareTo(second.profileId);
    if (profile != 0) return profile;
    return first.sourceId.compareTo(second.sourceId);
  }

  static String _resolveRelativePath(String root, String relativePath) {
    final normalized = relativePath.replaceAll('/', Platform.pathSeparator);
    final rootPath = Directory(root).absolute.path;
    final resolved = File(
      [rootPath, normalized].join(Platform.pathSeparator),
    ).absolute.path;
    final prefix = rootPath.endsWith(Platform.pathSeparator)
        ? rootPath
        : '$rootPath${Platform.pathSeparator}';
    if (!resolved.toLowerCase().startsWith(prefix.toLowerCase())) {
      throw const FormatException('Dataset path escapes the dataset root.');
    }
    return resolved;
  }
}

final class _Lf3ProfileRun {
  const _Lf3ProfileRun.success({required this.mask, required this.extraction})
    : failureCategory = null;

  const _Lf3ProfileRun.failure(this.failureCategory)
    : mask = null,
      extraction = null;

  final ResidueMask? mask;
  final Lf2ExtractionResult? extraction;
  final Lf3FailureCategory? failureCategory;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _Lf3ProfileRun &&
          other.mask == mask &&
          other.extraction == extraction &&
          other.failureCategory == failureCategory;

  @override
  int get hashCode => Object.hash(mask, extraction, failureCategory);
}
