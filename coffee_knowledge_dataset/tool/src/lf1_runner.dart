import 'dart:io';
import 'dart:typed_data';

import 'package:coffee_pattern/coffee_pattern.dart';
import 'package:coffee_vision/coffee_vision.dart';

import 'k6a_dataset.dart';
import 'k6a_models.dart';
import 'lf1_models.dart';
import 'lf1_profiles.dart';

typedef Lf1VisionAnalyzer =
    Future<VisionFeatureSet> Function(
      VisionImageInput input,
      VisionEdgeSelectionProfile profile,
    );
typedef Lf1PatternAnalyzer =
    Future<PatternAnalysisResult> Function(VisionFeatureSet featureSet);
typedef Lf1ProgressListener =
    void Function(int completed, int total, Lf1ProfileObservation observation);

final class Lf1ProfileRunner {
  Lf1ProfileRunner({
    K6aDatasetPreflight preflight = const K6aDatasetPreflight(),
    Iterable<Lf1ProfileDefinition> profiles = lf1Profiles,
    Lf1VisionAnalyzer? visionAnalyzer,
    Lf1PatternAnalyzer? patternAnalyzer,
    Lf1ProgressListener? progressListener,
  }) : _preflight = preflight,
       _profiles = _canonicalProfiles(profiles),
       _visionAnalyzer =
           visionAnalyzer ??
           ((input, profile) => const CoffeeVisionEngine().analyzeFeatures(
             input,
             edgeSelectionProfile: profile,
           )),
       _patternAnalyzer =
           patternAnalyzer ?? const PatternEngine().analyzePatterns,
       _progressListener = progressListener;

  final K6aDatasetPreflight _preflight;
  final List<Lf1ProfileDefinition> _profiles;
  final Lf1VisionAnalyzer _visionAnalyzer;
  final Lf1PatternAnalyzer _patternAnalyzer;
  final Lf1ProgressListener? _progressListener;

  Future<Lf1ObservationReport> run({
    required String datasetRoot,
    required String manifestPath,
    required String freezePath,
    required int repeatCount,
    String researchId = 'lfr-001',
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
    final observations = <Lf1ProfileObservation>[];
    final total = dataset.entries.length * _profiles.length;
    var completed = 0;

    for (final entry in dataset.entries) {
      final observationsForEntry = await _analyzeEntry(
        datasetRoot: datasetRoot,
        entry: entry,
        repeatCount: repeatCount,
      );
      for (final observation in observationsForEntry) {
        observations.add(observation);
        completed++;
        _progressListener?.call(completed, total, observation);
      }
    }
    observations.sort(_compareObservations);

    return Lf1ObservationReport(
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

  Future<List<Lf1ProfileObservation>> _analyzeEntry({
    required String datasetRoot,
    required K6aDatasetEntry entry,
    required int repeatCount,
  }) async {
    if (!entry.enabled) {
      return [
        for (final profile in _profiles)
          _emptyObservation(
            profileId: profile.id,
            entry: entry,
            status: K6aAnalysisStatus.skippedDisabled,
            determinism: K6aDeterminismStatus.notRun,
          ),
      ];
    }

    final Uint8List bytes;
    try {
      bytes = await File(
        _resolveRelativePath(datasetRoot, entry.relativePath),
      ).readAsBytes();
    } on FileSystemException {
      return [
        for (final profile in _profiles)
          _emptyObservation(
            profileId: profile.id,
            entry: entry,
            status: K6aAnalysisStatus.failed,
            determinism: K6aDeterminismStatus.notRun,
            failure: K6aFailureCategory.fileReadFailure,
          ),
      ];
    }

    final input = VisionImageInput(
      imageBytes: bytes,
      surfaceType: switch (entry.surfaceType) {
        K6aSurfaceType.cup => VisionSurfaceType.cup,
        K6aSurfaceType.saucer => VisionSurfaceType.saucer,
      },
      sourceId: entry.sourceId,
    );
    final observations = <Lf1ProfileObservation>[];
    for (final profile in _profiles) {
      observations.add(
        await _analyzeProfile(
          input: input,
          entry: entry,
          definition: profile,
          repeatCount: repeatCount,
        ),
      );
    }
    return observations;
  }

  Future<Lf1ProfileObservation> _analyzeProfile({
    required VisionImageInput input,
    required K6aDatasetEntry entry,
    required Lf1ProfileDefinition definition,
    required int repeatCount,
  }) async {
    VisionFeatureSet? referenceFeatures;
    PatternAnalysisResult? referencePatterns;
    List<Lf1CandidateObservation>? candidates;
    final mismatches = <int>[];

    for (var repeat = 1; repeat <= repeatCount; repeat++) {
      final VisionFeatureSet featureSet;
      try {
        featureSet = await _visionAnalyzer(input, definition.profile);
      } on FormatException catch (error) {
        return _failure(
          definition.id,
          entry,
          repeat,
          error.message.contains('Unsupported image format')
              ? K6aFailureCategory.unsupportedImage
              : K6aFailureCategory.corruptedImage,
        );
      } on Object {
        return _failure(
          definition.id,
          entry,
          repeat,
          K6aFailureCategory.visionFailure,
        );
      }

      final PatternAnalysisResult patternResult;
      final List<Lf1CandidateObservation> currentCandidates;
      try {
        patternResult = await _patternAnalyzer(featureSet);
        _validateContext(patternResult, entry);
        currentCandidates = _snapshotCandidates(patternResult);
      } on Object {
        return _failure(
          definition.id,
          entry,
          repeat,
          K6aFailureCategory.patternFailure,
        );
      }

      if (referenceFeatures == null) {
        referenceFeatures = featureSet;
        referencePatterns = patternResult;
        candidates = currentCandidates;
      } else if (featureSet != referenceFeatures ||
          patternResult != referencePatterns) {
        mismatches.add(repeat);
      }
    }

    final deterministic = mismatches.isEmpty;
    return Lf1ProfileObservation(
      profileId: definition.id,
      sourceId: entry.sourceId,
      surfaceType: entry.surfaceType,
      analysisStatus: K6aAnalysisStatus.success,
      determinismStatus: deterministic
          ? K6aDeterminismStatus.deterministic
          : K6aDeterminismStatus.nonDeterministic,
      repeatsPerformed: repeatCount,
      mismatchedRepeatIndexes: mismatches,
      candidates: candidates!,
      failureCategory: deterministic
          ? null
          : K6aFailureCategory.nonDeterministicResult,
    );
  }

  static List<Lf1CandidateObservation> _snapshotCandidates(
    PatternAnalysisResult result,
  ) {
    return List<Lf1CandidateObservation>.unmodifiable(
      result.candidates.map((candidate) {
        final geometry = candidate.geometry;
        final topology = candidate.topology;
        if (geometry == null || topology == null) {
          throw StateError('LF-1 requires complete Pattern candidates.');
        }
        return Lf1CandidateObservation(
          candidateId: candidate.id,
          evidence: candidate.evidence,
          geometry: geometry,
          topology: topology,
        );
      }),
    );
  }

  static void _validateContext(
    PatternAnalysisResult result,
    K6aDatasetEntry entry,
  ) {
    final expectedSurface = switch (entry.surfaceType) {
      K6aSurfaceType.cup => PatternSurfaceType.cup,
      K6aSurfaceType.saucer => PatternSurfaceType.saucer,
    };
    if (result.sourceId != entry.sourceId ||
        result.surfaceType != expectedSurface) {
      throw StateError('Pattern result context does not match the input.');
    }
  }

  static Lf1ProfileObservation _failure(
    String profileId,
    K6aDatasetEntry entry,
    int repeatsPerformed,
    K6aFailureCategory category,
  ) {
    return _emptyObservation(
      profileId: profileId,
      entry: entry,
      status: K6aAnalysisStatus.failed,
      determinism: K6aDeterminismStatus.notRun,
      repeatsPerformed: repeatsPerformed,
      failure: category,
    );
  }

  static Lf1ProfileObservation _emptyObservation({
    required String profileId,
    required K6aDatasetEntry entry,
    required K6aAnalysisStatus status,
    required K6aDeterminismStatus determinism,
    int repeatsPerformed = 0,
    K6aFailureCategory? failure,
  }) {
    return Lf1ProfileObservation(
      profileId: profileId,
      sourceId: entry.sourceId,
      surfaceType: entry.surfaceType,
      analysisStatus: status,
      determinismStatus: determinism,
      repeatsPerformed: repeatsPerformed,
      mismatchedRepeatIndexes: const [],
      candidates: const [],
      failureCategory: failure,
    );
  }

  static List<Lf1ProfileSummary> _summarize(
    List<K6aDatasetEntry> entries,
    List<Lf1ProfileObservation> observations,
    List<Lf1ProfileDefinition> profiles,
  ) {
    final enabledCount = entries.where((entry) => entry.enabled).length;
    return List<Lf1ProfileSummary>.unmodifiable(
      profiles.map((definition) {
        final records = observations
            .where((record) => record.profileId == definition.id)
            .toList(growable: false);
        final successful = records.where(
          (record) => record.analysisStatus == K6aAnalysisStatus.success,
        );
        return Lf1ProfileSummary(
          profileId: definition.id,
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
          totalCandidateCount: successful.fold(
            0,
            (total, record) => total + record.candidates.length,
          ),
        );
      }),
    );
  }

  static List<Lf1ProfileDefinition> _canonicalProfiles(
    Iterable<Lf1ProfileDefinition> values,
  ) {
    final materialized = values.toList(growable: false);
    if (materialized.isEmpty) {
      throw ArgumentError.value(values, 'profiles', 'must not be empty');
    }
    final ids = <String>{};
    for (final definition in materialized) {
      if (!ids.add(definition.id)) {
        throw ArgumentError.value(
          definition.id,
          'profiles',
          'must contain unique profile IDs',
        );
      }
    }
    return List<Lf1ProfileDefinition>.of(materialized)
      ..sort((first, second) => first.id.compareTo(second.id));
  }

  static int _compareObservations(
    Lf1ProfileObservation first,
    Lf1ProfileObservation second,
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
      throw FormatException('Dataset path escapes the dataset root.');
    }
    return resolved;
  }
}
