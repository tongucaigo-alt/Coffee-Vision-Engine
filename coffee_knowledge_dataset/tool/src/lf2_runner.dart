import 'dart:io';
import 'dart:typed_data';

import 'package:coffee_vision/coffee_vision.dart';

import 'k6a_dataset.dart';
import 'k6a_models.dart';
import 'lf2_models.dart';
import 'lf2_morphology.dart';
import 'lf2_profiles.dart';

typedef Lf2WorkingImagePreparer =
    Future<WorkingImage> Function(VisionImageInput input);
typedef Lf2ResidueMaskCreator =
    Future<ResidueMask> Function(WorkingImage workingImage);
typedef Lf2ExtractionOperation =
    Lf2ExtractionResult Function({
      required String profileId,
      required String sourceId,
      required ResidueMask mask,
      required VisionRect contentRect,
      required Lf2ProfileDefinition profile,
    });
typedef Lf2ProgressListener =
    void Function(int completed, int total, Lf2ProfileObservation observation);

final class Lf2EvidenceRunner {
  Lf2EvidenceRunner({
    K6aDatasetPreflight preflight = const K6aDatasetPreflight(),
    Iterable<Lf2ProfileDefinition> profiles = lf2Profiles,
    Lf2WorkingImagePreparer? workingImagePreparer,
    Lf2ResidueMaskCreator? residueMaskCreator,
    Lf2ExtractionOperation? extractionOperation,
    Lf2ProgressListener? progressListener,
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
       _extractionOperation =
           extractionOperation ?? const Lf2MorphologyExtractor().extract,
       _progressListener = progressListener;

  final K6aDatasetPreflight _preflight;
  final List<Lf2ProfileDefinition> _profiles;
  final Lf2WorkingImagePreparer _workingImagePreparer;
  final Lf2ResidueMaskCreator _residueMaskCreator;
  final Lf2ExtractionOperation _extractionOperation;
  final Lf2ProgressListener? _progressListener;

  Future<Lf2ObservationReport> run({
    required String datasetRoot,
    required String manifestPath,
    required String freezePath,
    required int repeatCount,
    String researchId = 'lfr-002',
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
    final observations = <Lf2ProfileObservation>[];
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

    return Lf2ObservationReport(
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

  Future<List<Lf2ProfileObservation>> _analyzeEntry({
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
        failureCategory: Lf2FailureCategory.fileReadFailure,
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
    Map<String, Lf2ExtractionResult>? references;
    Lf2PixelBounds? referenceBounds;
    final mismatches = <String, List<int>>{
      for (final profile in _profiles) profile.id: <int>[],
    };

    for (var repeat = 1; repeat <= repeatCount; repeat++) {
      final WorkingImage workingImage;
      final ResidueMask mask;
      try {
        workingImage = await _workingImagePreparer(input);
        mask = await _residueMaskCreator(workingImage);
        if (mask.width != workingImage.workingMetadata.width ||
            mask.height != workingImage.workingMetadata.height) {
          throw StateError(
            'Residue mask dimensions do not match working image.',
          );
        }
      } on FormatException catch (error) {
        return _emptyObservations(
          entry: entry,
          analysisStatus: K6aAnalysisStatus.failed,
          determinismStatus: K6aDeterminismStatus.notRun,
          repeatsPerformed: repeat,
          failureCategory: error.message.contains('Unsupported image format')
              ? Lf2FailureCategory.unsupportedImage
              : Lf2FailureCategory.corruptedImage,
        );
      } on Object {
        return _emptyObservations(
          entry: entry,
          analysisStatus: K6aAnalysisStatus.failed,
          determinismStatus: K6aDeterminismStatus.notRun,
          repeatsPerformed: repeat,
          failureCategory: Lf2FailureCategory.visionFailure,
        );
      }

      final currentBounds = _pixelBounds(
        workingImage.contentRect,
        width: mask.width,
        height: mask.height,
      );
      final current = <String, Lf2ExtractionResult>{};
      try {
        for (final profile in _profiles) {
          current[profile.id] = _extractionOperation(
            profileId: profile.id,
            sourceId: entry.sourceId,
            mask: mask,
            contentRect: workingImage.contentRect,
            profile: profile,
          );
        }
      } on Object {
        return _emptyObservations(
          entry: entry,
          analysisStatus: K6aAnalysisStatus.failed,
          determinismStatus: K6aDeterminismStatus.notRun,
          repeatsPerformed: repeat,
          contentBounds: currentBounds,
          failureCategory: Lf2FailureCategory.morphologyFailure,
        );
      }

      if (references == null) {
        references = current;
        referenceBounds = currentBounds;
      } else {
        for (final profile in _profiles) {
          if (currentBounds != referenceBounds ||
              current[profile.id] != references[profile.id]) {
            mismatches[profile.id]!.add(repeat);
          }
        }
      }
    }

    return List<Lf2ProfileObservation>.unmodifiable(
      _profiles.map((profile) {
        final extraction = references![profile.id]!;
        final profileMismatches = mismatches[profile.id]!;
        final deterministic = profileMismatches.isEmpty;
        final conserved = extraction.residuePixelsConserved;
        return Lf2ProfileObservation(
          profileId: profile.id,
          sourceId: entry.sourceId,
          surfaceType: entry.surfaceType,
          analysisStatus: K6aAnalysisStatus.success,
          determinismStatus: deterministic
              ? K6aDeterminismStatus.deterministic
              : K6aDeterminismStatus.nonDeterministic,
          repeatsPerformed: repeatCount,
          mismatchedRepeatIndexes: profileMismatches,
          contentBounds: referenceBounds,
          candidates: extraction.candidates,
          originalResiduePixelCount: extraction.originalResiduePixelCount,
          assignedResiduePixelCount: extraction.assignedResiduePixelCount,
          emittedResiduePixelCount: extraction.emittedResiduePixelCount,
          suppressedResiduePixelCount: extraction.suppressedResiduePixelCount,
          duplicateResidueAssignmentCount:
              extraction.duplicateResidueAssignmentCount,
          failureCategory: !deterministic
              ? Lf2FailureCategory.nonDeterministicResult
              : !conserved
              ? Lf2FailureCategory.residueConservationFailure
              : null,
        );
      }),
    );
  }

  List<Lf2ProfileObservation> _emptyObservations({
    required K6aDatasetEntry entry,
    required K6aAnalysisStatus analysisStatus,
    required K6aDeterminismStatus determinismStatus,
    int repeatsPerformed = 0,
    Lf2PixelBounds? contentBounds,
    Lf2FailureCategory? failureCategory,
  }) {
    return List<Lf2ProfileObservation>.unmodifiable(
      _profiles.map(
        (profile) => Lf2ProfileObservation(
          profileId: profile.id,
          sourceId: entry.sourceId,
          surfaceType: entry.surfaceType,
          analysisStatus: analysisStatus,
          determinismStatus: determinismStatus,
          repeatsPerformed: repeatsPerformed,
          mismatchedRepeatIndexes: const [],
          contentBounds: contentBounds,
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

  static List<Lf2ProfileSummary> _summarize(
    List<K6aDatasetEntry> entries,
    List<Lf2ProfileObservation> observations,
    List<Lf2ProfileDefinition> profiles,
  ) {
    final enabledCount = entries.where((entry) => entry.enabled).length;
    return List<Lf2ProfileSummary>.unmodifiable(
      profiles.map((profile) {
        final records = observations
            .where((record) => record.profileId == profile.id)
            .toList(growable: false);
        final successful = records
            .where(
              (record) => record.analysisStatus == K6aAnalysisStatus.success,
            )
            .toList(growable: false);
        return Lf2ProfileSummary(
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
          totalCandidateCount: successful.fold(
            0,
            (total, record) => total + record.candidates.length,
          ),
        );
      }),
    );
  }

  static List<Lf2ProfileDefinition> _canonicalProfiles(
    Iterable<Lf2ProfileDefinition> profiles,
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
    return List<Lf2ProfileDefinition>.of(materialized)
      ..sort((first, second) => first.id.compareTo(second.id));
  }

  static Lf2PixelBounds _pixelBounds(
    VisionRect rect, {
    required int width,
    required int height,
  }) {
    return Lf2PixelBounds(
      left: (rect.left * width).round(),
      top: (rect.top * height).round(),
      right: (rect.right * width).round(),
      bottom: (rect.bottom * height).round(),
    );
  }

  static int _compareObservations(
    Lf2ProfileObservation first,
    Lf2ProfileObservation second,
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
