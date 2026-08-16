enum Lf3EvidenceKind { binary, globalContrast, localContrast, fusion }

final class Lf3ProfileDefinition {
  const Lf3ProfileDefinition({
    required this.id,
    required this.evidenceKind,
    required this.supportRequired,
    required this.threshold,
    required this.closingRadius,
    this.minimumRegionRatio = 0.002,
  });

  final String id;
  final Lf3EvidenceKind evidenceKind;
  final bool supportRequired;
  final int? threshold;
  final int closingRadius;
  final double minimumRegionRatio;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Lf3ProfileDefinition &&
          other.id == id &&
          other.evidenceKind == evidenceKind &&
          other.supportRequired == supportRequired &&
          other.threshold == threshold &&
          other.closingRadius == closingRadius &&
          other.minimumRegionRatio == minimumRegionRatio;

  @override
  int get hashCode => Object.hash(
    id,
    evidenceKind,
    supportRequired,
    threshold,
    closingRadius,
    minimumRegionRatio,
  );
}

const lf3Profiles = <Lf3ProfileDefinition>[
  Lf3ProfileDefinition(
    id: 'lf3-p00-binary-full-r04',
    evidenceKind: Lf3EvidenceKind.binary,
    supportRequired: false,
    threshold: null,
    closingRadius: 4,
  ),
  Lf3ProfileDefinition(
    id: 'lf3-p01-binary-full-r08',
    evidenceKind: Lf3EvidenceKind.binary,
    supportRequired: false,
    threshold: null,
    closingRadius: 8,
  ),
  Lf3ProfileDefinition(
    id: 'lf3-p02-binary-support-r04',
    evidenceKind: Lf3EvidenceKind.binary,
    supportRequired: true,
    threshold: null,
    closingRadius: 4,
  ),
  Lf3ProfileDefinition(
    id: 'lf3-p03-binary-support-r08',
    evidenceKind: Lf3EvidenceKind.binary,
    supportRequired: true,
    threshold: null,
    closingRadius: 8,
  ),
  Lf3ProfileDefinition(
    id: 'lf3-p04-global-t16-r04',
    evidenceKind: Lf3EvidenceKind.globalContrast,
    supportRequired: true,
    threshold: 16,
    closingRadius: 4,
  ),
  Lf3ProfileDefinition(
    id: 'lf3-p05-global-t16-r08',
    evidenceKind: Lf3EvidenceKind.globalContrast,
    supportRequired: true,
    threshold: 16,
    closingRadius: 8,
  ),
  Lf3ProfileDefinition(
    id: 'lf3-p06-global-t24-r04',
    evidenceKind: Lf3EvidenceKind.globalContrast,
    supportRequired: true,
    threshold: 24,
    closingRadius: 4,
  ),
  Lf3ProfileDefinition(
    id: 'lf3-p07-global-t24-r08',
    evidenceKind: Lf3EvidenceKind.globalContrast,
    supportRequired: true,
    threshold: 24,
    closingRadius: 8,
  ),
  Lf3ProfileDefinition(
    id: 'lf3-p08-local-t16-r04',
    evidenceKind: Lf3EvidenceKind.localContrast,
    supportRequired: true,
    threshold: 16,
    closingRadius: 4,
  ),
  Lf3ProfileDefinition(
    id: 'lf3-p09-local-t16-r08',
    evidenceKind: Lf3EvidenceKind.localContrast,
    supportRequired: true,
    threshold: 16,
    closingRadius: 8,
  ),
  Lf3ProfileDefinition(
    id: 'lf3-p10-local-t24-r04',
    evidenceKind: Lf3EvidenceKind.localContrast,
    supportRequired: true,
    threshold: 24,
    closingRadius: 4,
  ),
  Lf3ProfileDefinition(
    id: 'lf3-p11-local-t24-r08',
    evidenceKind: Lf3EvidenceKind.localContrast,
    supportRequired: true,
    threshold: 24,
    closingRadius: 8,
  ),
  Lf3ProfileDefinition(
    id: 'lf3-p12-fusion-t16-r04',
    evidenceKind: Lf3EvidenceKind.fusion,
    supportRequired: true,
    threshold: 16,
    closingRadius: 4,
  ),
  Lf3ProfileDefinition(
    id: 'lf3-p13-fusion-t16-r08',
    evidenceKind: Lf3EvidenceKind.fusion,
    supportRequired: true,
    threshold: 16,
    closingRadius: 8,
  ),
  Lf3ProfileDefinition(
    id: 'lf3-p14-fusion-t24-r04',
    evidenceKind: Lf3EvidenceKind.fusion,
    supportRequired: true,
    threshold: 24,
    closingRadius: 4,
  ),
  Lf3ProfileDefinition(
    id: 'lf3-p15-fusion-t24-r08',
    evidenceKind: Lf3EvidenceKind.fusion,
    supportRequired: true,
    threshold: 24,
    closingRadius: 8,
  ),
];
