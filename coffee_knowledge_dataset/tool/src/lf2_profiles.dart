/// One immutable LF-2 research profile over the frozen public residue mask.
final class Lf2ProfileDefinition {
  const Lf2ProfileDefinition({
    required this.id,
    required this.closingRadius,
    required this.minimumRegionRatio,
  });

  final String id;
  final int closingRadius;
  final double minimumRegionRatio;
}

/// The fixed LF-2 matrix. Values must not be tuned after research starts.
const List<Lf2ProfileDefinition> lf2Profiles = [
  Lf2ProfileDefinition(
    id: 'lf2-p00-r04-a0005',
    closingRadius: 4,
    minimumRegionRatio: 0.0005,
  ),
  Lf2ProfileDefinition(
    id: 'lf2-p01-r08-a0005',
    closingRadius: 8,
    minimumRegionRatio: 0.0005,
  ),
  Lf2ProfileDefinition(
    id: 'lf2-p02-r16-a0005',
    closingRadius: 16,
    minimumRegionRatio: 0.0005,
  ),
  Lf2ProfileDefinition(
    id: 'lf2-p03-r24-a0005',
    closingRadius: 24,
    minimumRegionRatio: 0.0005,
  ),
  Lf2ProfileDefinition(
    id: 'lf2-p04-r04-a0020',
    closingRadius: 4,
    minimumRegionRatio: 0.002,
  ),
  Lf2ProfileDefinition(
    id: 'lf2-p05-r08-a0020',
    closingRadius: 8,
    minimumRegionRatio: 0.002,
  ),
  Lf2ProfileDefinition(
    id: 'lf2-p06-r16-a0020',
    closingRadius: 16,
    minimumRegionRatio: 0.002,
  ),
  Lf2ProfileDefinition(
    id: 'lf2-p07-r24-a0020',
    closingRadius: 24,
    minimumRegionRatio: 0.002,
  ),
];
