import 'package:coffee_camera/coffee_camera.dart';
import 'package:coffee_knowledge/coffee_knowledge.dart';
import 'package:coffee_pattern/coffee_pattern.dart';
import 'package:coffee_symbol/coffee_symbol.dart';
import 'package:coffee_vision/coffee_vision.dart';

enum AtlasK6AggregateOutcome {
  noMatch,
  insufficientSymbolEvidence,
  symbolCandidatesAvailable,
  technicalError,
}

final class AtlasK6CandidateResult {
  factory AtlasK6CandidateResult({
    required PatternCandidate candidate,
    required Iterable<KnowledgeMatchResult> matches,
  }) {
    final matchList = matches.toList(growable: false);
    for (final match in matchList) {
      if (match.candidateId != candidate.id) {
        throw ArgumentError.value(
          match.candidateId,
          'matches',
          'must reference the candidate identity',
        );
      }
    }
    return AtlasK6CandidateResult._(
      candidate: candidate,
      matches: List<KnowledgeMatchResult>.unmodifiable(matchList),
    );
  }

  const AtlasK6CandidateResult._({
    required this.candidate,
    required this.matches,
  });

  final PatternCandidate candidate;
  final List<KnowledgeMatchResult> matches;

  int get matchedRecordCount => matches.where((match) => match.matched).length;
}

final class AtlasK6SurfaceResult {
  factory AtlasK6SurfaceResult({
    required VisionFeatureSet featureSet,
    required PatternAnalysisResult patternResult,
    required Iterable<AtlasK6CandidateResult> candidateResults,
    required Iterable<SymbolCandidate> symbolCandidates,
    required Duration processingDuration,
  }) {
    final candidates = candidateResults.toList(growable: false);
    final symbols = symbolCandidates.toList(growable: false);
    if (candidates.length != patternResult.candidates.length) {
      throw ArgumentError.value(
        candidates,
        'candidateResults',
        'must contain one result for every Pattern candidate',
      );
    }
    for (var index = 0; index < candidates.length; index++) {
      if (!identical(
        candidates[index].candidate,
        patternResult.candidates[index],
      )) {
        throw ArgumentError.value(
          candidates[index].candidate,
          'candidateResults',
          'must preserve the exact Pattern candidate order and instances',
        );
      }
    }
    final completeMatches = <KnowledgeMatchResult>[
      for (final candidate in candidates) ...candidate.matches,
    ];
    for (final symbol in symbols) {
      if (!candidates.any(
        (candidate) => candidate.candidate.id == symbol.patternCandidateId,
      )) {
        throw ArgumentError.value(
          symbol.patternCandidateId,
          'symbolCandidates',
          'must reference a Pattern candidate in this surface result',
        );
      }
      for (final support in symbol.supports) {
        if (!completeMatches.any(
          (match) => identical(match, support.knowledgeMatch),
        )) {
          throw ArgumentError.value(
            support.knowledgeMatch,
            'symbolCandidates',
            'must preserve an exact Knowledge match from this result',
          );
        }
      }
    }
    return AtlasK6SurfaceResult._(
      featureSet: featureSet,
      patternResult: patternResult,
      candidateResults: List<AtlasK6CandidateResult>.unmodifiable(candidates),
      symbolCandidates: List<SymbolCandidate>.unmodifiable(symbols),
      processingDuration: processingDuration,
    );
  }

  const AtlasK6SurfaceResult._({
    required this.featureSet,
    required this.patternResult,
    required this.candidateResults,
    required this.symbolCandidates,
    required this.processingDuration,
  });

  final VisionFeatureSet featureSet;
  final PatternAnalysisResult patternResult;
  final List<AtlasK6CandidateResult> candidateResults;
  final List<SymbolCandidate> symbolCandidates;
  final Duration processingDuration;

  int get matchedRecordCount => candidateResults.fold(
    0,
    (total, candidate) => total + candidate.matchedRecordCount,
  );

  int get symbolCandidateCount => symbolCandidates.length;

  AtlasK6AggregateOutcome get outcome {
    if (matchedRecordCount == 0) return AtlasK6AggregateOutcome.noMatch;
    if (symbolCandidateCount == 0) {
      return AtlasK6AggregateOutcome.insufficientSymbolEvidence;
    }
    return AtlasK6AggregateOutcome.symbolCandidatesAvailable;
  }
}

final class AtlasK6EndToEndResult {
  const AtlasK6EndToEndResult({
    required this.captureResult,
    required this.datasetVersion,
    required this.cupResult,
    required this.saucerResult,
  });

  final CoffeeCameraCaptureResult captureResult;
  final String datasetVersion;
  final AtlasK6SurfaceResult cupResult;
  final AtlasK6SurfaceResult saucerResult;

  int get matchedRecordCount =>
      cupResult.matchedRecordCount + saucerResult.matchedRecordCount;

  int get symbolCandidateCount =>
      cupResult.symbolCandidateCount + saucerResult.symbolCandidateCount;

  AtlasK6AggregateOutcome get outcome {
    if (matchedRecordCount == 0) return AtlasK6AggregateOutcome.noMatch;
    if (symbolCandidateCount == 0) {
      return AtlasK6AggregateOutcome.insufficientSymbolEvidence;
    }
    return AtlasK6AggregateOutcome.symbolCandidatesAvailable;
  }
}
