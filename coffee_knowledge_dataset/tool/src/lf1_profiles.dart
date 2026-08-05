import 'package:coffee_vision/coffee_vision.dart';

/// One immutable LF-1 research profile over the frozen Vision edge selector.
final class Lf1ProfileDefinition {
  const Lf1ProfileDefinition({required this.id, required this.profile});

  final String id;
  final VisionEdgeSelectionProfile profile;
}

/// The fixed LF-1 matrix. Values must not be tuned after research starts.
const List<Lf1ProfileDefinition> lf1Profiles = [
  Lf1ProfileDefinition(
    id: 'p00-pass-through',
    profile: VisionEdgeSelectionProfile(),
  ),
  Lf1ProfileDefinition(
    id: 'p01-outgoing-1',
    profile: VisionEdgeSelectionProfile(maxOutgoingPerSource: 1),
  ),
  Lf1ProfileDefinition(
    id: 'p02-outgoing-2',
    profile: VisionEdgeSelectionProfile(maxOutgoingPerSource: 2),
  ),
  Lf1ProfileDefinition(
    id: 'p03-touch-only-outgoing-2',
    profile: VisionEdgeSelectionProfile(
      requireBoundingBoxTouch: true,
      maxOutgoingPerSource: 2,
    ),
  ),
  Lf1ProfileDefinition(
    id: 'p04-zero-gap-outgoing-2',
    profile: VisionEdgeSelectionProfile(
      maxBoundingBoxDistance: 0.0,
      maxOutgoingPerSource: 2,
    ),
  ),
  Lf1ProfileDefinition(
    id: 'p05-gap-2px-outgoing-2',
    profile: VisionEdgeSelectionProfile(
      maxBoundingBoxDistance: 0.00390625,
      maxOutgoingPerSource: 2,
    ),
  ),
  Lf1ProfileDefinition(
    id: 'p06-gap-4px-outgoing-2',
    profile: VisionEdgeSelectionProfile(
      maxBoundingBoxDistance: 0.0078125,
      maxOutgoingPerSource: 2,
    ),
  ),
  Lf1ProfileDefinition(
    id: 'p07-gap-8px-outgoing-2',
    profile: VisionEdgeSelectionProfile(
      maxBoundingBoxDistance: 0.015625,
      maxOutgoingPerSource: 2,
    ),
  ),
];

/// The founder-approved twenty-image physical review panel.
const List<String> lf1ReviewPanelSourceIds = [
  'apc-cup-001',
  'apc-cup-003',
  'apc-cup-004',
  'apc-cup-005',
  'apc-cup-014',
  'apc-cup-016',
  'apc-cup-020',
  'apc-cup-021',
  'apc-cup-022',
  'apc-cup-026',
  'apc-cup-023',
  'apc-cup-024',
  'apc-cup-009',
  'apc-cup-010',
  'apc-cup-017',
  'apc-cup-019',
  'apc-saucer-002',
  'apc-saucer-003',
  'apc-saucer-007',
  'apc-saucer-010',
];
