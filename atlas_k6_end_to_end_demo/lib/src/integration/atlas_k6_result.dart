import 'package:coffee_camera/coffee_camera.dart';
import 'package:coffee_knowledge/coffee_knowledge.dart';
import 'package:coffee_pattern/coffee_pattern.dart';
import 'package:coffee_vision/coffee_vision.dart';

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
    required Duration processingDuration,
  }) {
    final candidates = candidateResults.toList(growable: false);
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
    return AtlasK6SurfaceResult._(
      featureSet: featureSet,
      patternResult: patternResult,
      candidateResults: List<AtlasK6CandidateResult>.unmodifiable(candidates),
      processingDuration: processingDuration,
    );
  }

  const AtlasK6SurfaceResult._({
    required this.featureSet,
    required this.patternResult,
    required this.candidateResults,
    required this.processingDuration,
  });

  final VisionFeatureSet featureSet;
  final PatternAnalysisResult patternResult;
  final List<AtlasK6CandidateResult> candidateResults;
  final Duration processingDuration;

  int get matchedRecordCount => candidateResults.fold(
    0,
    (total, candidate) => total + candidate.matchedRecordCount,
  );
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
}
