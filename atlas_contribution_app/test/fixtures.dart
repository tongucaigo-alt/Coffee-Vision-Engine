import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:atlas_contribution_app/src/models.dart';

Uint8List testImage() => img.encodePng(
  img.Image(width: 160, height: 200)..clear(img.ColorRgb8(230, 236, 232)),
);
ContributionPhoto testPhoto(
  CaptureRole role, {
  PhotoDecision decision = PhotoDecision.unreviewed,
  List<RegionAnnotation> regions = const [],
}) => ContributionPhoto(
  role: role,
  localName: '${role.name}.jpg',
  checksum: 'sha256:${'a' * 64}',
  originalChecksum: 'sha256:${'b' * 64}',
  width: 160,
  height: 200,
  byteLength: 1000,
  capturedAt: DateTime.now().toUtc().toIso8601String(),
  decision: decision,
  regions: regions,
);
ContributionDraft testDraft({List<ContributionPhoto> photos = const []}) =>
    ContributionDraft(
      id: '00000000-0000-4000-8000-000000000001',
      rootId: '00000000-0000-4000-8000-000000000001',
      groupId: '00000000-0000-4000-8000-000000000002',
      createdAt: DateTime.now().toUtc().toIso8601String(),
      consentedAt: DateTime.now().toUtc().toIso8601String(),
      photos: photos,
    );
