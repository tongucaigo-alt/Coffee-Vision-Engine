/// Immutable identity of Atlas Canonical JSON Profile revision 1.
final class AtlasCanonicalJsonProfile {
  const AtlasCanonicalJsonProfile._({
    required this.profileId,
    required this.revision,
    required this.checksum,
  });

  /// Exact identity of the immutable revision-1 bootstrap descriptor.
  static const revision1 = AtlasCanonicalJsonProfile._(
    profileId: 'atlas-canonical-json',
    revision: 1,
    checksum:
        'sha256:16e9e10eb848828a863a7eca1c0b7e7c84e1a485065d00f938c6af356cd54ad7',
  );

  final String profileId;
  final int revision;
  final String checksum;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AtlasCanonicalJsonProfile &&
          other.profileId == profileId &&
          other.revision == revision &&
          other.checksum == checksum;

  @override
  int get hashCode => Object.hash(profileId, revision, checksum);

  @override
  String toString() =>
      'AtlasCanonicalJsonProfile(profileId: $profileId, revision: $revision, '
      'checksum: $checksum)';
}
