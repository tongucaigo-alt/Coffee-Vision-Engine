import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models.dart';
import '../photo_crop.dart';

const legacyReviewVersion = 'atlas-local-review-v1';
const observationReviewVersion = 'atlas-local-review-v2';
const reviewVersion = 'atlas-local-review-v3';
const supportedReviewVersions = [
  legacyReviewVersion,
  observationReviewVersion,
  reviewVersion,
];
const reviewConsentVersion = 'atlas-local-review-consent-v1';

enum ReviewSurface { cup, saucer }

enum CandidateAnswer { unanswered, yes, maybe, no }

Map<String, dynamic> immutableDocument(Map<String, dynamic> value) {
  Object? freeze(Object? v) => switch (v) {
    Map<String, dynamic>() => Map<String, dynamic>.unmodifiable(
      v.map((k, value) => MapEntry(k, freeze(value))),
    ),
    List() => List<Object?>.unmodifiable(v.map(freeze)),
    _ => v,
  };
  return freeze(jsonDecode(jsonEncode(value))) as Map<String, dynamic>;
}

void safeReviewId(String value) {
  if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,100}$').hasMatch(value)) {
    throw const FormatException('Invalid local review identity');
  }
}

final class CandidateFeedback {
  CandidateFeedback({
    required this.candidateKey,
    required this.runId,
    required this.answer,
    required this.exposedAtUtc,
    this.editedBox,
  });
  final String candidateKey, runId, exposedAtUtc;
  final CandidateAnswer answer;
  final RegionBox? editedBox;

  Map<String, dynamic> toJson() => {
    'candidateKey': candidateKey,
    'runId': runId,
    'answer': answer.name,
    'exposedAtUtc': exposedAtUtc,
    'editedBox': editedBox?.toJson(),
  };
  factory CandidateFeedback.fromJson(Map<String, dynamic> j) =>
      CandidateFeedback(
        candidateKey: j['candidateKey'] as String,
        runId: j['runId'] as String,
        answer: CandidateAnswer.values.byName(j['answer'] as String),
        exposedAtUtc: j['exposedAtUtc'] as String,
        editedBox: j['editedBox'] == null
            ? null
            : RegionBox.fromJson(
                Map<String, dynamic>.from(j['editedBox'] as Map),
              ),
      );
}

final class ReviewPhoto {
  ReviewPhoto({
    required this.id,
    required this.photo,
    required this.surface,
    this.declaredRole,
    this.displayCrop,
    this.usableConfirmedAtUtc,
    Map<String, dynamic> quality = const {},
    Map<String, dynamic>? analysis,
    Iterable<CandidateFeedback> feedback = const [],
    this.observationExposureRunId,
  }) : quality = immutableDocument(quality),
       analysis = analysis == null ? null : immutableDocument(analysis),
       feedback = List.unmodifiable(feedback) {
    safeReviewId(id);
    if (!RegExp(r'^[a-zA-Z0-9_-]+\.jpg$').hasMatch(photo.localName) ||
        !RegExp(r'^sha256:[0-9a-f]{64}$').hasMatch(photo.checksum) ||
        photo.width <= 0 ||
        photo.height <= 0 ||
        photo.byteLength <= 0) {
      throw const FormatException('Invalid review photo');
    }
    if (surface == ReviewSurface.saucer &&
        (declaredRole != null || photo.role != null)) {
      throw const FormatException('Saucer must be unposed gallery input');
    }
    if (photo.role != null && declaredRole != photo.role) {
      throw const FormatException('Camera role mismatch');
    }
    if (analysis != null &&
        (analysis['photoId'] != id ||
            analysis['photoChecksum'] != photo.checksum ||
            analysis['surface'] != surface.name)) {
      throw const FormatException('Stale analysis');
    }
    if (this.feedback.map((f) => f.candidateKey).toSet().length !=
        this.feedback.length) {
      throw const FormatException('Duplicate feedback');
    }
    final candidates = (analysis?['symbols'] as List? ?? const []);
    for (final f in this.feedback) {
      if (f.runId != analysis?['runId'] ||
          !candidates.any((c) => (c as Map)['key'] == f.candidateKey)) {
        throw const FormatException(
          'Feedback must target an exact analysis candidate',
        );
      }
    }
    if (observationExposureRunId != null &&
        observationExposureRunId != analysis?['runId']) {
      throw const FormatException('Stale exposure');
    }
  }
  final String id;
  final ContributionPhoto photo;
  final ReviewSurface surface;
  final CaptureRole? declaredRole;
  final PhotoCrop? displayCrop;
  PhotoCrop get visibleCrop =>
      displayCrop != null &&
          photo.regions.every((r) => displayCrop!.containsBox(r.box))
      ? displayCrop!
      : PhotoCrop.full;
  final String? usableConfirmedAtUtc, observationExposureRunId;
  final Map<String, dynamic> quality;
  final Map<String, dynamic>? analysis;
  final List<CandidateFeedback> feedback;
  String get title => surface == ReviewSurface.saucer
      ? 'Tabak'
      : declaredRole?.title ?? 'Fincan · Açı belirtilmedi';
  bool get analyzed => analysis != null;
  bool get failed => analysis?['outcome'] == 'technicalError';

  ReviewPhoto update({
    ContributionPhoto? photo,
    String? confirmedAt,
    Map<String, dynamic>? analysis,
    Iterable<CandidateFeedback>? feedback,
    bool exposed = false,
  }) => ReviewPhoto(
    id: id,
    photo: photo ?? this.photo,
    surface: surface,
    declaredRole: declaredRole,
    displayCrop: displayCrop,
    usableConfirmedAtUtc: confirmedAt ?? usableConfirmedAtUtc,
    quality: quality,
    analysis: analysis ?? this.analysis,
    feedback: feedback ?? (analysis == null ? this.feedback : const []),
    observationExposureRunId: exposed
        ? ((analysis ?? this.analysis)?['runId'] as String?)
        : (analysis == null ? observationExposureRunId : null),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'photo': photo.toJson(),
    'surface': surface.name,
    'declaredRole': declaredRole?.name,
    if (displayCrop != null) 'displayCrop': displayCrop!.toJson(),
    'usableConfirmedAtUtc': usableConfirmedAtUtc,
    'quality': quality,
    'analysis': analysis,
    'feedback': feedback.map((f) => f.toJson()).toList(),
    'observationExposureRunId': observationExposureRunId,
  };
  factory ReviewPhoto.fromJson(Map<String, dynamic> j) => ReviewPhoto(
    id: j['id'] as String,
    photo: ContributionPhoto.fromJson(
      Map<String, dynamic>.from(j['photo'] as Map),
    ),
    surface: ReviewSurface.values.byName(j['surface'] as String),
    declaredRole: j['declaredRole'] == null
        ? null
        : CaptureRole.values.byName(j['declaredRole'] as String),
    displayCrop: j['displayCrop'] == null
        ? null
        : PhotoCrop.fromJson(
            Map<String, dynamic>.from(j['displayCrop'] as Map),
          ),
    usableConfirmedAtUtc: j['usableConfirmedAtUtc'] as String?,
    quality: Map<String, dynamic>.from(j['quality'] as Map),
    analysis: j['analysis'] == null
        ? null
        : Map<String, dynamic>.from(j['analysis'] as Map),
    feedback: (j['feedback'] as List).map(
      (f) => CandidateFeedback.fromJson(Map<String, dynamic>.from(f as Map)),
    ),
    observationExposureRunId: j['observationExposureRunId'] as String?,
  );
}

final class ReviewSession {
  ReviewSession({
    required this.id,
    required this.groupId,
    required this.createdAtUtc,
    required this.localConsentAtUtc,
    this.revision = 1,
    this.sameSampleDeclared = false,
    this.researchConsentAtUtc,
    this.deleted = false,
    Iterable<ReviewPhoto> photos = const [],
    this.recordVersion = reviewVersion,
    this.observationHistory = 'known',
    Iterable<Map<String, dynamic>> initialObservations = const [],
    Map<String, dynamic>? preparedInput,
  }) : photos = List.unmodifiable(photos),
       initialObservations = List.unmodifiable(
         initialObservations.map(immutableDocument),
       ) {
    safeReviewId(id);
    safeReviewId(groupId);
    if (revision < 1 ||
        this.photos.where((p) => p.surface == ReviewSurface.cup).length > 3 ||
        this.photos.where((p) => p.surface == ReviewSurface.saucer).length >
            1 ||
        this.photos.map((p) => p.id).toSet().length != this.photos.length) {
      throw const FormatException('Invalid review session');
    }
    final roles = this.photos
        .map((p) => p.declaredRole)
        .whereType<CaptureRole>()
        .map((r) => r == CaptureRole.top ? CaptureRole.free : r)
        .toList();
    if (roles.toSet().length != roles.length) {
      throw const FormatException('Duplicate declared role');
    }
    if (!supportedReviewVersions.contains(recordVersion) ||
        !['known', 'unknown'].contains(observationHistory) ||
        (recordVersion == legacyReviewVersion &&
            (observationHistory != 'unknown' ||
                this.initialObservations.isNotEmpty ||
                preparedInput != null))) {
      throw const FormatException('Invalid review observation version');
    }
    final setKeys = <String>{};
    for (final snapshot in this.initialObservations) {
      if (![
            'atlas-initial-observation-v1',
            'atlas-initial-observation-v2',
          ].contains(snapshot['version']) ||
          snapshot['sessionId'] != id ||
          snapshot['groupId'] != groupId ||
          snapshot['photoSetFingerprint'] is! String ||
          !setKeys.add(snapshot['photoSetFingerprint'] as String) ||
          snapshot['photos'] is! List ||
          snapshot['capturedAtUtc'] is! String ||
          snapshot['sourceRevision'] is! int ||
          (snapshot['sourceRevision'] as int) > revision ||
          !['known', 'unknown'].contains(snapshot['exposureHistory'])) {
        throw const FormatException('Invalid initial observation');
      }
    }
    // An old preparation may remain in an earlier immutable revision, but it
    // must never be presented as current after a source change.
    this.preparedInput =
        !deleted &&
            preparedInput?['sourceFingerprint'] ==
                preparationSourceFingerprint(this)
        ? immutableDocument(preparedInput!)
        : null;
  }
  final String id, groupId, createdAtUtc, localConsentAtUtc;
  final String? researchConsentAtUtc;
  final int revision;
  final bool sameSampleDeclared, deleted;
  final List<ReviewPhoto> photos;
  final String recordVersion, observationHistory;
  final List<Map<String, dynamic>> initialObservations;
  late final Map<String, dynamic>? preparedInput;
  Map<String, dynamic>? get currentInitialObservation => initialObservations
      .where((s) => s['photoSetFingerprint'] == reviewPhotoSetFingerprint(this))
      .firstOrNull;
  bool get ready =>
      !deleted &&
      sameSampleDeclared &&
      photos.any((p) => p.surface == ReviewSurface.cup) &&
      photos.every((p) => p.usableConfirmedAtUtc != null);
  List<ReviewPhoto> get orderedPhotos {
    final result = photos.toList();
    int order(ReviewPhoto p) => p.surface == ReviewSurface.saucer
        ? 10
        : switch (p.declaredRole) {
            CaptureRole.top || CaptureRole.free => 0,
            CaptureRole.handleRight => 1,
            CaptureRole.handleLeft => 2,
            null => 3,
          };
    result.sort((a, b) {
      final c = order(a).compareTo(order(b));
      return c == 0 ? photos.indexOf(a).compareTo(photos.indexOf(b)) : c;
    });
    return List.unmodifiable(result);
  }

  ReviewSession next({
    Iterable<ReviewPhoto>? photos,
    bool? sameSample,
    bool? researchAllowed,
    bool? deleted,
    Iterable<Map<String, dynamic>>? initialObservations,
    Map<String, dynamic>? preparedInput,
  }) => ReviewSession(
    id: id,
    groupId: groupId,
    createdAtUtc: createdAtUtc,
    localConsentAtUtc: localConsentAtUtc,
    revision: revision + 1,
    sameSampleDeclared: sameSample ?? sameSampleDeclared,
    researchConsentAtUtc: researchAllowed == null
        ? researchConsentAtUtc
        : researchAllowed
        ? DateTime.now().toUtc().toIso8601String()
        : null,
    deleted: deleted ?? this.deleted,
    photos: photos ?? this.photos,
    observationHistory: observationHistory,
    initialObservations: initialObservations ?? this.initialObservations,
    preparedInput: preparedInput ?? this.preparedInput,
  );
  ReviewSession withPhoto(ReviewPhoto p) => next(
    photos: [
      for (final existing in photos)
        if (existing.id == p.id) p else existing,
      if (!photos.any((e) => e.id == p.id)) p,
    ],
  );
  Map<String, dynamic> toJson() => {
    'version': recordVersion,
    'labelVersion': labelVersion,
    'consentVersion': reviewConsentVersion,
    'id': id,
    'groupId': groupId,
    'revision': revision,
    'createdAtUtc': createdAtUtc,
    'localConsentAtUtc': localConsentAtUtc,
    'researchConsentAtUtc': researchConsentAtUtc,
    'sameSampleDeclared': sameSampleDeclared,
    'physicalIndependence': 'unverified',
    'deleted': deleted,
    'photos': photos.map((p) => p.toJson()).toList(),
    if (recordVersion != legacyReviewVersion) ...{
      'observationHistory': observationHistory,
      'initialObservations': initialObservations,
      'preparedInput': preparedInput,
    },
  };
  factory ReviewSession.fromJson(Map<String, dynamic> j) {
    if (!supportedReviewVersions.contains(j['version']) ||
        j['labelVersion'] != labelVersion ||
        j['consentVersion'] != reviewConsentVersion) {
      throw const FormatException('Unsupported review version');
    }
    return ReviewSession(
      id: j['id'] as String,
      groupId: j['groupId'] as String,
      revision: j['revision'] as int,
      createdAtUtc: j['createdAtUtc'] as String,
      localConsentAtUtc: j['localConsentAtUtc'] as String,
      researchConsentAtUtc: j['researchConsentAtUtc'] as String?,
      sameSampleDeclared: j['sameSampleDeclared'] as bool,
      deleted: j['deleted'] as bool,
      photos: (j['photos'] as List).map(
        (p) => ReviewPhoto.fromJson(Map<String, dynamic>.from(p as Map)),
      ),
      recordVersion: j['version'] as String,
      observationHistory: j['version'] == legacyReviewVersion
          ? 'unknown'
          : j['observationHistory'] as String,
      initialObservations: j['version'] == legacyReviewVersion
          ? const []
          : (j['initialObservations'] as List).map(
              (s) => Map<String, dynamic>.from(s as Map),
            ),
      preparedInput:
          j['version'] == legacyReviewVersion || j['preparedInput'] == null
          ? null
          : Map<String, dynamic>.from(j['preparedInput'] as Map),
    );
  }
}

String _documentFingerprint(Object value) =>
    'sha256:${sha256.convert(utf8.encode(jsonEncode(value)))}';

/// Research-only identity for an exact set of photo bytes. Photo order and
/// later annotation edits do not create a new first-observation record.
String reviewPhotoSetFingerprint(ReviewSession session) {
  final photos = session.photos.toList()..sort((a, b) => a.id.compareTo(b.id));
  return _documentFingerprint([
    for (final p in photos)
      {'photoId': p.id, 'photoChecksum': p.photo.checksum},
  ]);
}

const preparationMeasurementFields = [
  'residuePixelCount',
  'contentResidueRatio',
  'componentCount',
  'candidateRelationCount',
  'selectedRelationCount',
];

/// Local invalidation token only. It never belongs in the AI payload.
String preparationSourceFingerprint(
  ReviewSession session,
) => _documentFingerprint({
  'sameSampleDeclared': session.sameSampleDeclared,
  'photos': [
    for (final p in session.orderedPhotos)
      {
        'photoId': p.id,
        'photoChecksum': p.photo.checksum,
        'surface': p.surface.name,
        'declaredRole': p.declaredRole?.name,
        'usableConfirmedAtUtc': p.usableConfirmedAtUtc,
        'photoDecision': p.photo.decision.name,
        'regions': p.photo.regions.map((r) => r.toJson()).toList(),
        'analysisRunId': p.analysis?['runId'],
        'analysisOutcome': p.analysis?['outcome'],
        'analysisErrorStage': p.analysis?['errorStage'],
        'globalPhysicalMeasurements':
            p.analysis?['globalPhysicalMeasurements'] is Map
            ? {
                for (final key in preparationMeasurementFields)
                  key: (p.analysis!['globalPhysicalMeasurements'] as Map)[key],
              }
            : null,
      },
  ],
});

Map<String, dynamic> interpretationInput(ReviewSession session) {
  final accepted = <Map<String, dynamic>>[];
  final additions = <Map<String, dynamic>>[];
  final audit = <Map<String, dynamic>>[];
  for (final p in session.orderedPhotos) {
    final identity = {
      'photoId': p.id,
      'surface': p.surface.name,
      'declaredRole': p.declaredRole?.name,
    };
    for (final candidate in (p.analysis?['symbols'] as List? ?? const [])) {
      final c = Map<String, dynamic>.from(candidate as Map);
      final feedback = p.feedback
          .where((f) => f.candidateKey == c['key'])
          .firstOrNull;
      final entry = {
        ...identity,
        'origin': 'engineCandidate',
        'runId': p.analysis!['runId'],
        'candidate': c,
        'answer': (feedback?.answer ?? CandidateAnswer.unanswered).name,
        'originalBox': c['box'],
        'editedBox': feedback?.editedBox?.toJson(),
        'exposedAtUtc': feedback?.exposedAtUtc,
      };
      if (feedback?.answer == CandidateAnswer.yes) {
        accepted.add(entry);
      } else {
        audit.add(entry);
      }
    }
    for (final r in p.photo.regions) {
      final entry = {
        ...identity,
        'origin': 'userObservation',
        'labelVersion': labelVersion,
        'label': r.label,
        'name': r.title,
        'box': r.box.toJson(),
        'exposureRunId': p.observationExposureRunId,
        'regionDensity': null,
      };
      if (r.label == null) {
        audit.add(entry);
      } else {
        additions.add(entry);
      }
    }
  }
  if (session.deleted) throw StateError('Deleted review is unavailable');
  return immutableDocument({
    'version': 'atlas-interpretation-input-v1',
    'category': 'general',
    'status': accepted.isEmpty && additions.isEmpty
        ? 'noSelectedSymbols'
        : session.photos.any((p) => !p.analyzed)
        ? 'analysisPending'
        : 'ready',
    'analysisComplete':
        session.photos.isNotEmpty && session.photos.every((p) => p.analyzed),
    'successfulPhotoCount': session.photos
        .where((p) => p.analyzed && !p.failed)
        .length,
    'technicalErrorCount': session.photos.where((p) => p.failed).length,
    'acceptedEngineCandidates': accepted,
    'userObservations': additions,
    'audit': audit,
    'photos': [
      for (final p in session.orderedPhotos)
        {
          'photoId': p.id,
          'photoChecksum': p.photo.checksum,
          'surface': p.surface.name,
          'declaredRole': p.declaredRole?.name,
          'photoDecision': p.photo.decision.name,
          'outcome': p.analysis?['outcome'] ?? 'notAnalyzed',
          'analysisRunId': p.analysis?['runId'],
          'visionFeatureSetRef': p.analysis?['visionFeatureSetRef'],
          'knowledgeRelease': p.analysis?['knowledgeRelease'],
          'symbolAvailability':
              p.analysis?['symbolAvailability'] ?? 'notConfigured',
          'globalPhysicalMeasurements':
              p.analysis?['globalPhysicalMeasurements'],
          'physicalMeasurementScope': 'wholeImageContentNotUserRegion',
        },
    ],
  });
}
