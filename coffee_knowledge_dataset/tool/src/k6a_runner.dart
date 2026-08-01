import 'dart:io';
import 'dart:typed_data';

import 'package:coffee_pattern/coffee_pattern.dart';
import 'package:coffee_vision/coffee_vision.dart';

import 'k6a_dataset.dart';
import 'k6a_models.dart';

typedef K6aVisionAnalyzer =
    Future<VisionFeatureSet> Function(VisionImageInput input);
typedef K6aPatternAnalyzer =
    Future<PatternAnalysisResult> Function(VisionFeatureSet featureSet);
typedef K6aProgressListener =
    void Function(int completed, int total, K6aImageObservation observation);

final class K6aObservationRunner {
  K6aObservationRunner({
    K6aDatasetPreflight preflight = const K6aDatasetPreflight(),
    K6aVisionAnalyzer? visionAnalyzer,
    K6aPatternAnalyzer? patternAnalyzer,
    K6aProgressListener? progressListener,
  }) : _preflight = preflight,
       _visionAnalyzer =
           visionAnalyzer ?? const CoffeeVisionEngine().analyzeFeatures,
       _patternAnalyzer =
           patternAnalyzer ?? const PatternEngine().analyzePatterns,
       _progressListener = progressListener;

  final K6aDatasetPreflight _preflight;
  final K6aVisionAnalyzer _visionAnalyzer;
  final K6aPatternAnalyzer _patternAnalyzer;
  final K6aProgressListener? _progressListener;

  Future<K6aObservationReport> run({
    required String datasetRoot,
    required String manifestPath,
    required String freezePath,
    required int repeatCount,
    String researchId = 'kdr-001',
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

    final frozenDataset = await _preflight.validate(
      datasetRoot: datasetRoot,
      manifestPath: manifestPath,
      freezePath: freezePath,
    );
    final records = <K6aImageObservation>[];
    for (var index = 0; index < frozenDataset.entries.length; index++) {
      final entry = frozenDataset.entries[index];
      final observation = entry.enabled
          ? await _analyzeEntry(
              datasetRoot: datasetRoot,
              entry: entry,
              repeatCount: repeatCount,
            )
          : K6aImageObservation(
              sourceId: entry.sourceId,
              surfaceType: entry.surfaceType,
              analysisStatus: K6aAnalysisStatus.skippedDisabled,
              determinismStatus: K6aDeterminismStatus.notRun,
              repeatsPerformed: 0,
              mismatchedRepeatIndexes: const [],
              candidates: const [],
            );
      records.add(observation);
      _progressListener?.call(
        index + 1,
        frozenDataset.entries.length,
        observation,
      );
    }

    return K6aObservationReport(
      researchId: researchId,
      sourceDatasetVersion: frozenDataset.datasetVersion,
      sourceManifestChecksum: frozenDataset.manifestChecksum,
      repeatCount: repeatCount,
      summary: _summarize(records),
      records: records,
    );
  }

  Future<K6aImageObservation> _analyzeEntry({
    required String datasetRoot,
    required K6aDatasetEntry entry,
    required int repeatCount,
  }) async {
    final Uint8List bytes;
    try {
      bytes = await File(
        _resolveRelativePath(datasetRoot, entry.relativePath),
      ).readAsBytes();
    } on FileSystemException {
      return _failedEntry(
        entry: entry,
        repeatsPerformed: 0,
        category: K6aFailureCategory.fileReadFailure,
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
    PatternAnalysisResult? referenceResult;
    List<K6aCandidateObservation>? referenceCandidates;
    final mismatchedRepeatIndexes = <int>[];

    for (var repeatIndex = 1; repeatIndex <= repeatCount; repeatIndex++) {
      final VisionFeatureSet featureSet;
      try {
        featureSet = await _visionAnalyzer(input);
      } on FormatException catch (error) {
        return _failedEntry(
          entry: entry,
          repeatsPerformed: repeatIndex,
          category: error.message.contains('Unsupported image format')
              ? K6aFailureCategory.unsupportedImage
              : K6aFailureCategory.corruptedImage,
        );
      } on Object {
        return _failedEntry(
          entry: entry,
          repeatsPerformed: repeatIndex,
          category: K6aFailureCategory.visionFailure,
        );
      }

      final PatternAnalysisResult patternResult;
      try {
        patternResult = await _patternAnalyzer(featureSet);
        _validateResultContext(patternResult, entry);
        final currentCandidates = _snapshotCandidates(patternResult);
        if (referenceResult == null) {
          referenceResult = patternResult;
          referenceCandidates = currentCandidates;
        } else if (patternResult != referenceResult) {
          mismatchedRepeatIndexes.add(repeatIndex);
        }
      } on Object {
        return _failedEntry(
          entry: entry,
          repeatsPerformed: repeatIndex,
          category: K6aFailureCategory.patternFailure,
        );
      }
    }

    final deterministic = mismatchedRepeatIndexes.isEmpty;
    return K6aImageObservation(
      sourceId: entry.sourceId,
      surfaceType: entry.surfaceType,
      analysisStatus: K6aAnalysisStatus.success,
      determinismStatus: deterministic
          ? K6aDeterminismStatus.deterministic
          : K6aDeterminismStatus.nonDeterministic,
      repeatsPerformed: repeatCount,
      mismatchedRepeatIndexes: mismatchedRepeatIndexes,
      candidates: referenceCandidates!,
      failureCategory: deterministic
          ? null
          : K6aFailureCategory.nonDeterministicResult,
    );
  }

  static List<K6aCandidateObservation> _snapshotCandidates(
    PatternAnalysisResult result,
  ) {
    return List<K6aCandidateObservation>.unmodifiable(
      result.candidates.map((candidate) {
        final geometry = candidate.geometry;
        final topology = candidate.topology;
        if (geometry == null || topology == null) {
          throw StateError(
            'K6A requires complete engine-produced Pattern candidates.',
          );
        }
        return K6aCandidateObservation(
          candidateId: candidate.id,
          evidence: candidate.evidence,
          geometry: geometry,
          topology: topology,
        );
      }),
    );
  }

  static void _validateResultContext(
    PatternAnalysisResult result,
    K6aDatasetEntry entry,
  ) {
    final expectedSurface = switch (entry.surfaceType) {
      K6aSurfaceType.cup => PatternSurfaceType.cup,
      K6aSurfaceType.saucer => PatternSurfaceType.saucer,
    };
    if (result.sourceId != entry.sourceId ||
        result.surfaceType != expectedSurface) {
      throw StateError('Pattern result context does not match its input.');
    }
  }

  static K6aImageObservation _failedEntry({
    required K6aDatasetEntry entry,
    required int repeatsPerformed,
    required K6aFailureCategory category,
  }) {
    return K6aImageObservation(
      sourceId: entry.sourceId,
      surfaceType: entry.surfaceType,
      analysisStatus: K6aAnalysisStatus.failed,
      determinismStatus: K6aDeterminismStatus.notRun,
      repeatsPerformed: repeatsPerformed,
      mismatchedRepeatIndexes: const [],
      candidates: const [],
      failureCategory: category,
    );
  }

  static K6aObservationSummary _summarize(List<K6aImageObservation> records) {
    final enabled = records
        .where(
          (record) =>
              record.analysisStatus != K6aAnalysisStatus.skippedDisabled,
        )
        .toList(growable: false);
    final successful = enabled
        .where((record) => record.analysisStatus == K6aAnalysisStatus.success)
        .toList(growable: false);
    final candidateCount = successful.fold<int>(
      0,
      (sum, record) => sum + record.candidates.length,
    );
    final cupCandidateCount = successful
        .where((record) => record.surfaceType == K6aSurfaceType.cup)
        .fold<int>(0, (sum, record) => sum + record.candidates.length);

    return K6aObservationSummary(
      totalEntries: records.length,
      enabledEntries: enabled.length,
      disabledEntries: records.length - enabled.length,
      successfulEntries: successful.length,
      failedEntries: enabled.length - successful.length,
      deterministicEntries: successful
          .where(
            (record) =>
                record.determinismStatus == K6aDeterminismStatus.deterministic,
          )
          .length,
      nonDeterministicEntries: successful
          .where(
            (record) =>
                record.determinismStatus ==
                K6aDeterminismStatus.nonDeterministic,
          )
          .length,
      cupEntries: enabled
          .where((record) => record.surfaceType == K6aSurfaceType.cup)
          .length,
      saucerEntries: enabled
          .where((record) => record.surfaceType == K6aSurfaceType.saucer)
          .length,
      candidateCount: candidateCount,
      cupCandidateCount: cupCandidateCount,
      saucerCandidateCount: candidateCount - cupCandidateCount,
    );
  }

  static String _resolveRelativePath(String root, String relativePath) {
    return [
      Directory(root).absolute.path,
      ...relativePath.split('/'),
    ].join(Platform.pathSeparator);
  }
}
