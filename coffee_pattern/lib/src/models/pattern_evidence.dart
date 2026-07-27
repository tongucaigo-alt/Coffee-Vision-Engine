/// Identifies the canonical VisionFeatureSet entity referenced as evidence.
enum PatternEvidenceKind {
  globalFeatures,
  regionFeature,
  componentFeature,
  spatialRelationFeature,
  graphStatistics,
  connectedStructure,
}

/// Pattern-owned identity for one canonical Vision analysis region.
enum PatternRegionId { top, middle, bottom, left, center, right }

/// Immutable identity-only reference to existing VisionFeatureSet evidence.
///
/// Evidence contains no copied Vision measurement and no interpretation.
final class PatternEvidence {
  const PatternEvidence.globalFeatures()
    : kind = PatternEvidenceKind.globalFeatures,
      regionId = null,
      componentId = null,
      sourceComponentId = null,
      targetComponentId = null,
      structureId = null;

  const PatternEvidence.regionFeature(PatternRegionId regionId)
    : kind = PatternEvidenceKind.regionFeature,
      regionId = regionId,
      componentId = null,
      sourceComponentId = null,
      targetComponentId = null,
      structureId = null;

  factory PatternEvidence.componentFeature(int componentId) {
    return PatternEvidence._(
      kind: PatternEvidenceKind.componentFeature,
      componentId: _validatedPositiveId(componentId, 'componentId'),
    );
  }

  factory PatternEvidence.spatialRelationFeature({
    required int sourceComponentId,
    required int targetComponentId,
  }) {
    final source = _validatedPositiveId(sourceComponentId, 'sourceComponentId');
    final target = _validatedPositiveId(targetComponentId, 'targetComponentId');
    if (source == target) {
      throw ArgumentError.value(
        target,
        'targetComponentId',
        'must differ from sourceComponentId',
      );
    }
    return PatternEvidence._(
      kind: PatternEvidenceKind.spatialRelationFeature,
      sourceComponentId: source,
      targetComponentId: target,
    );
  }

  const PatternEvidence.graphStatistics()
    : kind = PatternEvidenceKind.graphStatistics,
      regionId = null,
      componentId = null,
      sourceComponentId = null,
      targetComponentId = null,
      structureId = null;

  factory PatternEvidence.connectedStructure(int structureId) {
    return PatternEvidence._(
      kind: PatternEvidenceKind.connectedStructure,
      structureId: _validatedPositiveId(structureId, 'structureId'),
    );
  }

  const PatternEvidence._({
    required this.kind,
    this.componentId,
    this.sourceComponentId,
    this.targetComponentId,
    this.structureId,
  }) : regionId = null;

  final PatternEvidenceKind kind;
  final PatternRegionId? regionId;
  final int? componentId;
  final int? sourceComponentId;
  final int? targetComponentId;
  final int? structureId;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PatternEvidence &&
            other.kind == kind &&
            other.regionId == regionId &&
            other.componentId == componentId &&
            other.sourceComponentId == sourceComponentId &&
            other.targetComponentId == targetComponentId &&
            other.structureId == structureId;
  }

  @override
  int get hashCode => Object.hash(
    kind,
    regionId,
    componentId,
    sourceComponentId,
    targetComponentId,
    structureId,
  );

  @override
  String toString() {
    return 'PatternEvidence(kind: $kind, regionId: $regionId, '
        'componentId: $componentId, sourceComponentId: $sourceComponentId, '
        'targetComponentId: $targetComponentId, structureId: $structureId)';
  }

  static int _validatedPositiveId(int value, String name) {
    if (value <= 0) {
      throw ArgumentError.value(value, name, 'must be greater than zero');
    }
    return value;
  }
}
