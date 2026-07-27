import 'pattern_candidate.dart';
import 'pattern_evidence.dart';
import 'pattern_surface_type.dart';

/// Canonical immutable output contract of the Pattern Engine.
final class PatternAnalysisResult {
  factory PatternAnalysisResult({
    required PatternSurfaceType surfaceType,
    String? sourceId,
    required Iterable<PatternCandidate> candidates,
  }) {
    final candidateList = candidates.toList(growable: false);
    for (var index = 0; index < candidateList.length; index++) {
      final expectedId = index + 1;
      if (candidateList[index].id != expectedId) {
        throw ArgumentError.value(
          candidateList[index].id,
          'candidates',
          'must preserve canonical one-based candidate order; '
              'expected $expectedId',
        );
      }
      for (var previousIndex = 0; previousIndex < index; previousIndex++) {
        if (_sameEvidence(
          candidateList[previousIndex].evidence,
          candidateList[index].evidence,
        )) {
          throw ArgumentError.value(
            candidateList[index],
            'candidates',
            'must not contain duplicate evidence-defined candidates',
          );
        }
      }
    }

    return PatternAnalysisResult._(
      surfaceType: surfaceType,
      sourceId: sourceId,
      candidates: List<PatternCandidate>.unmodifiable(candidateList),
    );
  }

  const PatternAnalysisResult._({
    required this.surfaceType,
    this.sourceId,
    required this.candidates,
  });

  final PatternSurfaceType surfaceType;
  final String? sourceId;
  final List<PatternCandidate> candidates;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PatternAnalysisResult &&
            other.surfaceType == surfaceType &&
            other.sourceId == sourceId &&
            _sameCandidates(other.candidates, candidates);
  }

  @override
  int get hashCode =>
      Object.hash(surfaceType, sourceId, Object.hashAll(candidates));

  @override
  String toString() {
    return 'PatternAnalysisResult(surfaceType: $surfaceType, '
        'sourceIdPresent: ${sourceId != null}, '
        'candidateCount: ${candidates.length})';
  }

  static bool _sameCandidates(
    List<PatternCandidate> first,
    List<PatternCandidate> second,
  ) {
    if (identical(first, second)) return true;
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  static bool _sameEvidence(
    List<PatternEvidence> first,
    List<PatternEvidence> second,
  ) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }
}
