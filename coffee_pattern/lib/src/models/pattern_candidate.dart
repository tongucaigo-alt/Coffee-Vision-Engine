import 'pattern_evidence.dart';
import 'pattern_geometry.dart';
import 'pattern_topology.dart';

/// Immutable physical-pattern candidate with canonical evidence references.
final class PatternCandidate {
  factory PatternCandidate({
    required int id,
    required Iterable<PatternEvidence> evidence,
  }) => _create(id: id, evidence: evidence);

  /// Creates a fully described physical pattern with normalized geometry.
  factory PatternCandidate.withGeometry({
    required int id,
    required Iterable<PatternEvidence> evidence,
    required PatternGeometry geometry,
  }) => _create(id: id, evidence: evidence, geometry: geometry);

  /// Creates a complete physical pattern with geometry and topology.
  factory PatternCandidate.withGeometryAndTopology({
    required int id,
    required Iterable<PatternEvidence> evidence,
    required PatternGeometry geometry,
    required PatternTopology topology,
  }) => _create(
    id: id,
    evidence: evidence,
    geometry: geometry,
    topology: topology,
  );

  static PatternCandidate _create({
    required int id,
    required Iterable<PatternEvidence> evidence,
    PatternGeometry? geometry,
    PatternTopology? topology,
  }) {
    if (id <= 0) {
      throw ArgumentError.value(id, 'id', 'must be greater than zero');
    }

    final evidenceList = evidence.toList(growable: false);
    if (evidenceList.isEmpty) {
      throw ArgumentError.value(evidence, 'evidence', 'must not be empty');
    }
    for (var index = 1; index < evidenceList.length; index++) {
      final comparison = _compareEvidence(
        evidenceList[index - 1],
        evidenceList[index],
      );
      if (comparison == 0) {
        throw ArgumentError.value(
          evidence,
          'evidence',
          'must not contain duplicate canonical references',
        );
      }
      if (comparison > 0) {
        throw ArgumentError.value(
          evidence,
          'evidence',
          'must already follow canonical evidence order',
        );
      }
    }

    return PatternCandidate._(
      id: id,
      evidence: List<PatternEvidence>.unmodifiable(evidenceList),
      geometry: geometry,
      topology: topology,
    );
  }

  const PatternCandidate._({
    required this.id,
    required this.evidence,
    required this.geometry,
    required this.topology,
  });

  /// Canonical one-based identity assigned once by pattern extraction.
  final int id;

  /// Canonically ordered identity-only evidence references.
  final List<PatternEvidence> evidence;

  /// Normalized physical form, or `null` for a legacy pre-M8C candidate.
  final PatternGeometry? geometry;

  /// Canonical structural measurements, or `null` before M8D.
  final PatternTopology? topology;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PatternCandidate &&
            other.id == id &&
            _sameList(other.evidence, evidence) &&
            other.geometry == geometry &&
            other.topology == topology;
  }

  @override
  int get hashCode =>
      Object.hash(id, Object.hashAll(evidence), geometry, topology);

  @override
  String toString() {
    return 'PatternCandidate(id: $id, evidenceCount: ${evidence.length}, '
        'geometryPresent: ${geometry != null}, '
        'topologyPresent: ${topology != null})';
  }

  static int _compareEvidence(PatternEvidence first, PatternEvidence second) {
    final kindComparison = first.kind.index.compareTo(second.kind.index);
    if (kindComparison != 0) return kindComparison;

    switch (first.kind) {
      case PatternEvidenceKind.globalFeatures:
      case PatternEvidenceKind.graphStatistics:
        return 0;
      case PatternEvidenceKind.regionFeature:
        return first.regionId!.index.compareTo(second.regionId!.index);
      case PatternEvidenceKind.componentFeature:
        return first.componentId!.compareTo(second.componentId!);
      case PatternEvidenceKind.spatialRelationFeature:
        final sourceComparison = first.sourceComponentId!.compareTo(
          second.sourceComponentId!,
        );
        if (sourceComparison != 0) return sourceComparison;
        return first.targetComponentId!.compareTo(second.targetComponentId!);
      case PatternEvidenceKind.connectedStructure:
        return first.structureId!.compareTo(second.structureId!);
    }
  }

  static bool _sameList<T>(List<T> first, List<T> second) {
    if (identical(first, second)) return true;
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }
}
