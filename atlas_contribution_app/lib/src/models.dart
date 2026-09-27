import 'dart:math' as math;

import 'photo_crop.dart';

const labelVersion = 'contribution-labels-v1';
const consentVersion = 'contribution-consent-v1';
const maxRegions = 10;

enum CaptureRole {
  top('Üst açı', 'Fincanın içini yukarıdan göster.'),
  handleRight(
    'Kulp sağda',
    'Fincanı sabit tut. Kamerayı kulp sağda kalacak şekilde taşı.',
  ),
  handleLeft('Kulp solda', 'Fincanı sabit tut. Kamerayı diğer yana taşı.'),
  free('Serbest açı', 'Telvenin en yoğun olduğu bölgeyi göster.');

  const CaptureRole(this.title, this.instruction);
  final String title;
  final String instruction;
}

// The original contribution/upload flow keeps its three-role contract.
const legacyCaptureRoles = [
  CaptureRole.top,
  CaptureRole.handleRight,
  CaptureRole.handleLeft,
];

const freeCaptureRoles = [
  CaptureRole.free,
  CaptureRole.handleRight,
  CaptureRole.handleLeft,
];

const contributionLabels = <String, String>{
  'bird': 'Kuş',
  'heart': 'Kalp',
  'fish': 'Balık',
  'snake': 'Yılan',
  'dog': 'Köpek',
  'butterfly': 'Kelebek',
  'tree': 'Ağaç',
  'horse': 'At',
  'eye': 'Göz',
  'crown': 'Taç',
  'ring': 'Yüzük',
  'road': 'Yol',
  'mountain': 'Dağ',
  'moon': 'Ay',
  'sun': 'Güneş',
  'anchor': 'Çapa',
  'house': 'Ev',
  'humanFigure': 'İnsan Figürü',
  'airplane': 'Uçak',
  'flower': 'Çiçek',
};

enum PhotoDecision { unreviewed, marked, uncertain, notSeen, skipped }

enum ContributionKind { threeAngle, gallerySingle, freeThreeAngle, photoSet }

enum PhotoSurface { cup, saucer }

final class RegionBox {
  RegionBox(this.x, this.y, this.width, this.height) {
    if (![x, y, width, height].every((v) => v.isFinite) ||
        x < 0 ||
        y < 0 ||
        width <= 0 ||
        height <= 0 ||
        x + width > 1.000001 ||
        y + height > 1.000001) {
      throw ArgumentError('Invalid normalized region');
    }
  }
  final double x, y, width, height;
  RegionBox move(double dx, double dy) => RegionBox(
    (x + dx).clamp(0, 1 - width),
    (y + dy).clamp(0, 1 - height),
    width,
    height,
  );
  RegionBox resize(double dx, double dy) => RegionBox(
    x,
    y,
    (width + dx).clamp(math.min(.04, 1 - x), 1 - x),
    (height + dy).clamp(math.min(.04, 1 - y), 1 - y),
  );
  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };
  factory RegionBox.fromJson(Map<String, dynamic> j) => RegionBox(
    (j['x'] as num).toDouble(),
    (j['y'] as num).toDouble(),
    (j['width'] as num).toDouble(),
    (j['height'] as num).toDouble(),
  );
}

final class RegionAnnotation {
  RegionAnnotation({required this.id, required this.box, this.label}) {
    if (label != null && !contributionLabels.containsKey(label)) {
      throw ArgumentError('Unknown contribution label');
    }
  }
  final String id;
  final RegionBox box;
  final String? label;
  String get title => contributionLabels[label] ?? 'Emin değilim';
  Map<String, dynamic> toJson() => {
    'id': id,
    'box': box.toJson(),
    'label': label,
  };
  factory RegionAnnotation.fromJson(Map<String, dynamic> j) => RegionAnnotation(
    id: j['id'] as String,
    box: RegionBox.fromJson(j['box'] as Map<String, dynamic>),
    label: j['label'] as String?,
  );
}

final class ContributionPhoto {
  ContributionPhoto({
    required this.role,
    required this.localName,
    required this.checksum,
    required this.originalChecksum,
    required this.width,
    required this.height,
    required this.byteLength,
    required this.capturedAt,
    this.importedAt,
    this.id,
    this.surface = PhotoSurface.cup,
    this.declaredRole,
    this.displayCrop,
    this.decision = PhotoDecision.unreviewed,
    Iterable<RegionAnnotation> regions = const [],
  }) : regions = List.unmodifiable(regions) {
    if (id != null) {
      if (!RegExp(r"^[a-zA-Z0-9_-]+$").hasMatch(id!) ||
          (capturedAt == null) == (importedAt == null) ||
          (surface == PhotoSurface.saucer && declaredRole != null)) {
        throw ArgumentError("Invalid set photo");
      }
    } else if ((role == null) != (importedAt != null) ||
        (role == null && capturedAt != null) ||
        (role != null && capturedAt == null)) {
      throw ArgumentError('Invalid photo origin');
    }
    if (this.regions.length > maxRegions ||
        this.regions.map((r) => r.id).toSet().length != this.regions.length) {
      throw ArgumentError('Invalid regions');
    }
    if ((decision == PhotoDecision.marked) != this.regions.isNotEmpty) {
      throw ArgumentError('Photo decision and regions disagree');
    }
  }
  final CaptureRole? role;
  final String localName, checksum, originalChecksum;
  final String? capturedAt, importedAt;
  final String? id;
  final PhotoSurface surface;
  final CaptureRole? declaredRole;
  CaptureRole? get angle => id == null ? role : declaredRole;
  String get origin => importedAt != null ? 'gallery' : 'camera';
  String get title => surface == PhotoSurface.saucer
      ? 'Tabak'
      : angle?.title ??
            (id == null ? 'Galeri fotoğrafı' : 'Fincan · Açı belirtilmedi');
  String get fileKey => id ?? role?.name ?? 'gallery';
  ContributionPhoto asSetPhoto({
    String? photoId,
    PhotoSurface? type,
    CaptureRole? angle,
    bool clearAngle = false,
  }) {
    final json = toJson();
    json['id'] = photoId ?? id ?? localName.replaceAll('.jpg', '');
    json['surface'] = (type ?? surface).name;
    json['origin'] = origin;
    json['declaredRole'] = (clearAngle || type == PhotoSurface.saucer)
        ? null
        : (angle ?? this.angle)?.name;
    return ContributionPhoto.fromJson(json);
  }

  final int width, height, byteLength;
  final PhotoDecision decision;
  final List<RegionAnnotation> regions;
  final PhotoCrop? displayCrop;
  PhotoCrop get visibleCrop =>
      displayCrop != null &&
          regions.every((region) => displayCrop!.containsBox(region.box))
      ? displayCrop!
      : PhotoCrop.full;
  ContributionPhoto annotated(
    Iterable<RegionAnnotation> value,
    PhotoDecision state,
  ) => ContributionPhoto(
    role: role,
    id: id,
    surface: surface,
    declaredRole: declaredRole,
    localName: localName,
    checksum: checksum,
    originalChecksum: originalChecksum,
    width: width,
    height: height,
    byteLength: byteLength,
    capturedAt: capturedAt,
    importedAt: importedAt,
    displayCrop: displayCrop,
    regions: value,
    decision: state,
  );
  Map<String, dynamic> toJson() => {
    'role': role?.name,
    if (id != null) ...{
      'id': id,
      'surface': surface.name,
      'declaredRole': declaredRole?.name,
    },
    if (id != null || role == null) 'origin': origin,
    if (importedAt != null) 'importedAtUtc': importedAt,
    'localName': localName,
    'checksum': checksum,
    'originalChecksum': originalChecksum,
    'width': width,
    'height': height,
    'byteLength': byteLength,
    'capturedAt': capturedAt,
    'derivative': 'orientation-baked-jpeg-2048-q90-v1',
    'decision': decision.name,
    'regions': regions.map((r) => r.toJson()).toList(),
    if (displayCrop != null) 'displayCrop': displayCrop!.toJson(),
  };
  factory ContributionPhoto.fromJson(Map<String, dynamic> j) =>
      ContributionPhoto(
        role: j['role'] == null
            ? null
            : CaptureRole.values.byName(j['role'] as String),
        id: j['id'] as String?,
        surface: PhotoSurface.values.byName(j['surface'] as String? ?? 'cup'),
        declaredRole: j['declaredRole'] == null
            ? null
            : CaptureRole.values.byName(j['declaredRole'] as String),
        localName: j['localName'] as String,
        checksum: j['checksum'] as String,
        originalChecksum: j['originalChecksum'] as String,
        width: j['width'] as int,
        height: j['height'] as int,
        byteLength: j['byteLength'] as int,
        capturedAt: j['capturedAt'] as String?,
        importedAt: j['origin'] == 'gallery'
            ? j['importedAtUtc'] as String
            : null,
        displayCrop: j['displayCrop'] == null
            ? null
            : PhotoCrop.fromJson(
                Map<String, dynamic>.from(j['displayCrop'] as Map),
              ),
        decision: PhotoDecision.values.byName(j['decision'] as String),
        regions: (j['regions'] as List).map(
          (r) => RegionAnnotation.fromJson(Map<String, dynamic>.from(r as Map)),
        ),
      );
}

final class ContributionDraft {
  ContributionDraft({
    required this.id,
    required this.rootId,
    required this.groupId,
    required this.createdAt,
    required this.consentedAt,
    this.kind = ContributionKind.threeAngle,
    this.revision = 1,
    this.supersedesId,
    Iterable<ContributionPhoto> photos = const [],
    this.queued = false,
    this.galleryStart = false,
    this.cupSelectionDone = false,
    this.saucerDecided = false,
  }) : photos = List.unmodifiable(photos) {
    if (kind == ContributionKind.photoSet) {
      final angles = cups
          .map((p) => p.angle == CaptureRole.top ? CaptureRole.free : p.angle)
          .whereType<CaptureRole>()
          .toList();
      if (cups.length > 3 ||
          saucers.length > 1 ||
          this.photos.any((p) => p.id == null) ||
          this.photos.map((p) => p.id).toSet().length != this.photos.length ||
          angles.toSet().length != angles.length) {
        throw ArgumentError('Invalid photo set');
      }
      return;
    }
    if (kind == ContributionKind.gallerySingle) {
      if (this.photos.length > 1 || this.photos.any((p) => p.role != null)) {
        throw ArgumentError('Gallery session requires one unposed photo');
      }
      return;
    }
    if (this.photos.length > captureRoles.length ||
        this.photos.map((p) => p.role).toSet().length != this.photos.length ||
        this.photos.any((p) => !captureRoles.contains(p.role))) {
      throw ArgumentError('Invalid photo roles');
    }
    for (var i = 0; i < this.photos.length; i++) {
      if (this.photos[i].role != captureRoles[i]) {
        throw ArgumentError('Photo roles must be contiguous and ordered');
      }
    }
  }
  final String id, rootId, groupId, createdAt, consentedAt;
  final ContributionKind kind;
  final bool galleryStart, cupSelectionDone, saucerDecided;
  bool get isSet => kind == ContributionKind.photoSet;
  bool get isGallery =>
      kind == ContributionKind.gallerySingle || (isSet && galleryStart);
  List<ContributionPhoto> get cups =>
      photos.where((p) => p.surface == PhotoSurface.cup).toList();
  List<ContributionPhoto> get saucers =>
      photos.where((p) => p.surface == PhotoSurface.saucer).toList();
  String get photoSummary =>
      '${cups.length} fincan${saucers.isEmpty ? '' : ' · ${saucers.length} tabak'}';
  bool get cupsComplete => isGallery ? cups.isNotEmpty : cups.length == 3;
  List<CaptureRole> get captureRoles => switch (kind) {
    ContributionKind.threeAngle => legacyCaptureRoles,
    ContributionKind.freeThreeAngle => freeCaptureRoles,
    ContributionKind.gallerySingle => const [],
    ContributionKind.photoSet => galleryStart ? const [] : freeCaptureRoles,
  };
  int get requiredPhotos => isGallery ? 1 : 3;
  final String? supersedesId;
  final int revision;
  final bool queued;
  final List<ContributionPhoto> photos;
  bool get complete => isSet
      ? cupsComplete && cupSelectionDone && saucerDecided
      : photos.length == requiredPhotos;
  bool get reviewed =>
      complete && photos.every((p) => p.decision != PhotoDecision.unreviewed);
  ContributionPhoto? photo(CaptureRole role) {
    for (final p in photos) {
      if (p.surface == PhotoSurface.cup && p.angle == role) return p;
    }
    return null;
  }

  ContributionDraft withPhoto(ContributionPhoto next) {
    if (isSet) {
      if (next.id == null) throw ArgumentError('Set photo requires identity');
      final exists = photos.any((p) => p.id == next.id);
      final updated = [
        for (final p in photos)
          if (p.id == next.id) next else p,
        if (!exists) next,
      ];
      return copy(
        photos: [
          ...updated.where((p) => p.surface == PhotoSurface.cup),
          ...updated.where((p) => p.surface == PhotoSurface.saucer),
        ],
        queued: false,
      );
    }
    if (!isGallery && !captureRoles.contains(next.role)) {
      throw ArgumentError('Photo role does not belong to this draft');
    }
    return copy(
      photos: isGallery
          ? [next]
          : [
              for (final role in captureRoles)
                if (role == next.role) next else ?photo(role),
            ],
      queued: false,
    );
  }

  ContributionDraft copy({
    Iterable<ContributionPhoto>? photos,
    bool? queued,
    bool? cupSelectionDone,
    bool? saucerDecided,
  }) => ContributionDraft(
    id: id,
    rootId: rootId,
    groupId: groupId,
    createdAt: createdAt,
    consentedAt: consentedAt,
    kind: kind,
    galleryStart: galleryStart,
    cupSelectionDone: cupSelectionDone ?? this.cupSelectionDone,
    saucerDecided: saucerDecided ?? this.saucerDecided,
    revision: revision,
    supersedesId: supersedesId,
    photos: photos ?? this.photos,
    queued: queued ?? this.queued,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    if (kind != ContributionKind.threeAngle) 'kind': kind.name,
    if (kind == ContributionKind.gallerySingle) 'recordVersion': 2,
    if (isSet) ...{
      'recordVersion': 4,
      'galleryStart': galleryStart,
      'cupSelectionDone': cupSelectionDone,
      'saucerDecided': saucerDecided,
    },
    if (kind == ContributionKind.freeThreeAngle) 'recordVersion': 3,
    if (isGallery) 'physicalIndependence': 'unverified',
    'rootId': rootId,
    'groupId': groupId,
    'revision': revision,
    'supersedesId': supersedesId,
    'createdAt': createdAt,
    'consentedAt': consentedAt,
    'consentVersion': consentVersion,
    'labelVersion': labelVersion,
    'photos': photos.map((p) => p.toJson()).toList(),
    'queued': queued,
  };
  factory ContributionDraft.fromJson(Map<String, dynamic> j) {
    final kind = j['kind'] == null
        ? ContributionKind.threeAngle
        : switch ((j['kind'], j['recordVersion'])) {
            ('gallerySingle', 2) => ContributionKind.gallerySingle,
            ('freeThreeAngle', 3) => ContributionKind.freeThreeAngle,
            ('photoSet', 4) => ContributionKind.photoSet,
            _ => throw const FormatException('Unsupported contribution kind'),
          };
    if (j['labelVersion'] != labelVersion ||
        j['consentVersion'] != consentVersion) {
      throw const FormatException('Unsupported draft version');
    }
    return ContributionDraft(
      id: j['id'] as String,
      kind: kind,
      galleryStart: j['galleryStart'] as bool? ?? false,
      cupSelectionDone: j['cupSelectionDone'] as bool? ?? false,
      saucerDecided: j['saucerDecided'] as bool? ?? false,
      rootId: j['rootId'] as String,
      groupId: j['groupId'] as String,
      revision: j['revision'] as int,
      supersedesId: j['supersedesId'] as String?,
      createdAt: j['createdAt'] as String,
      consentedAt: j['consentedAt'] as String,
      queued: j['queued'] as bool? ?? false,
      photos: (j['photos'] as List).map(
        (p) => ContributionPhoto.fromJson(Map<String, dynamic>.from(p as Map)),
      ),
    );
  }
}
