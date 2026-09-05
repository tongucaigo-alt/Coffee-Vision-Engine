import 'dart:io';
import 'dart:typed_data';

import 'package:coffee_knowledge/coffee_knowledge.dart';
import 'package:coffee_knowledge_dataset/coffee_knowledge_dataset.dart';
import 'package:coffee_pattern/coffee_pattern.dart';
import 'package:coffee_symbol/coffee_symbol.dart';
import 'package:coffee_symbol_dataset/coffee_symbol_dataset.dart';
import 'package:coffee_vision/coffee_vision.dart';

import 'atlas_k6_result.dart';

typedef AtlasFeatureAnalyzer =
    Future<VisionFeatureSet> Function(VisionImageInput input);
typedef AtlasPatternAnalyzer =
    Future<PatternAnalysisResult> Function(VisionFeatureSet featureSet);
typedef AtlasKnowledgeMatcher =
    List<KnowledgeMatchResult> Function({
      required PatternCandidate candidate,
      required Iterable<KnowledgeRecord> records,
    });
typedef AtlasFileReader = Future<Uint8List> Function(String path);
typedef AtlasSymbolResolver =
    List<SymbolCandidate> Function({
      required KnowledgeDatasetReleaseRef knowledgeRelease,
      required Iterable<KnowledgeMatchResult> knowledgeMatches,
      required Iterable<SymbolDefinition> definitions,
      required Iterable<SymbolEvidenceBinding> bindings,
    });

enum AtlasSurfaceProcessingStage {
  fileRead,
  vision,
  pattern,
  knowledge,
  symbol,
  resultAssembly,
}

final class AtlasSurfaceProcessingException implements Exception {
  const AtlasSurfaceProcessingException({
    required this.stage,
    required this.cause,
  });

  final AtlasSurfaceProcessingStage stage;
  final Object cause;

  String get safeMessage => switch (stage) {
    AtlasSurfaceProcessingStage.fileRead =>
      'Onaylanan fotoğraf okunamadı. Lütfen tekrar deneyin.',
    AtlasSurfaceProcessingStage.vision =>
      'Görüntü özellikleri çıkarılamadı. Lütfen tekrar deneyin.',
    AtlasSurfaceProcessingStage.pattern =>
      'Fiziksel adaylar oluşturulamadı. Lütfen tekrar deneyin.',
    AtlasSurfaceProcessingStage.knowledge =>
      'Fiziksel eşleştirme tamamlanamadı. Lütfen tekrar deneyin.',
    AtlasSurfaceProcessingStage.symbol =>
      'Sembol adayları çözümlenemedi. Lütfen tekrar deneyin.',
    AtlasSurfaceProcessingStage.resultAssembly =>
      'Açı sonucu tamamlanamadı. Lütfen tekrar deneyin.',
  };

  @override
  String toString() => 'AtlasSurfaceProcessingException(stage: ${stage.name})';
}

final class AtlasK6SurfaceProcessor {
  AtlasK6SurfaceProcessor({
    required this.dataset,
    required this.knowledgeRelease,
    required this.symbolDataset,
    CoffeeVisionEngine? visionEngine,
    PatternEngine? patternEngine,
    KnowledgeRecordCollectionMatcher? knowledgeMatcher,
    SymbolCandidateResolver? symbolResolver,
    AtlasFeatureAnalyzer? analyzeFeatures,
    AtlasPatternAnalyzer? analyzePatterns,
    AtlasKnowledgeMatcher? matchRecords,
    AtlasSymbolResolver? resolveSymbols,
    AtlasFileReader? readFile,
  }) : _analyzeFeatures =
           analyzeFeatures ??
           (visionEngine ?? CoffeeVisionEngine()).analyzeFeatures,
       _analyzePatterns =
           analyzePatterns ??
           (patternEngine ?? const PatternEngine()).analyzePatterns,
       _matchRecords =
           matchRecords ??
           (knowledgeMatcher ?? const KnowledgeRecordCollectionMatcher()).match,
       _resolveSymbols =
           resolveSymbols ??
           (symbolResolver ?? const SymbolCandidateResolver()).resolve,
       _readFile = readFile ?? _readFileBytes {
    if (dataset.datasetVersion != knowledgeRelease.releaseId) {
      throw ArgumentError.value(
        knowledgeRelease.releaseId,
        'knowledgeRelease',
        'must identify the supplied Knowledge dataset',
      );
    }
    final declaredRelease = symbolDataset.knowledgeRelease;
    if (declaredRelease != null && declaredRelease != knowledgeRelease) {
      throw ArgumentError.value(
        declaredRelease,
        'symbolDataset',
        'must target the supplied Knowledge release',
      );
    }
  }

  final KnowledgeDatasetSnapshot dataset;
  final KnowledgeDatasetReleaseRef knowledgeRelease;
  final SymbolDatasetSnapshot symbolDataset;
  final AtlasFeatureAnalyzer _analyzeFeatures;
  final AtlasPatternAnalyzer _analyzePatterns;
  final AtlasKnowledgeMatcher _matchRecords;
  final AtlasSymbolResolver _resolveSymbols;
  final AtlasFileReader _readFile;

  Future<AtlasK6SurfaceResult> process({
    required String path,
    required VisionSurfaceType surfaceType,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final bytes = await _run(
        AtlasSurfaceProcessingStage.fileRead,
        () => _readFile(path),
      );
      final featureSet = await _run(
        AtlasSurfaceProcessingStage.vision,
        () => _analyzeFeatures(
          VisionImageInput(imageBytes: bytes, surfaceType: surfaceType),
        ),
      );
      final patternResult = await _run(
        AtlasSurfaceProcessingStage.pattern,
        () => _analyzePatterns(featureSet),
      );
      final candidateResults = <AtlasK6CandidateResult>[];
      final knowledgeMatches = <KnowledgeMatchResult>[];
      await _run(AtlasSurfaceProcessingStage.knowledge, () async {
        for (final candidate in patternResult.candidates) {
          final candidateResult = AtlasK6CandidateResult(
            candidate: candidate,
            matches: _matchRecords(
              candidate: candidate,
              records: dataset.activeRecords,
            ),
          );
          candidateResults.add(candidateResult);
          knowledgeMatches.addAll(candidateResult.matches);
        }
      });
      final symbolCandidates = await _run(
        AtlasSurfaceProcessingStage.symbol,
        () async => _resolveSymbols(
          knowledgeRelease: knowledgeRelease,
          knowledgeMatches: knowledgeMatches,
          definitions: symbolDataset.definitions,
          bindings: symbolDataset.bindings,
        ),
      );
      stopwatch.stop();
      return await _run(
        AtlasSurfaceProcessingStage.resultAssembly,
        () async => AtlasK6SurfaceResult(
          featureSet: featureSet,
          patternResult: patternResult,
          candidateResults: candidateResults,
          symbolCandidates: symbolCandidates,
          processingDuration: stopwatch.elapsed,
        ),
      );
    } on AtlasSurfaceProcessingException {
      stopwatch.stop();
      rethrow;
    }
  }

  static Future<T> _run<T>(
    AtlasSurfaceProcessingStage stage,
    Future<T> Function() operation,
  ) async {
    try {
      return await operation();
    } catch (error) {
      throw AtlasSurfaceProcessingException(stage: stage, cause: error);
    }
  }

  static Future<Uint8List> _readFileBytes(String path) {
    return File(path).readAsBytes();
  }
}
