import '../models.dart';
import 'review_models.dart';
import 'regional_summary.dart';

const initialObservationVersion = 'atlas-initial-observation-v2';
const reviewPreparationVersion = 'atlas-review-preparation-v1';
const reviewPayloadVersion = 'atlas-fortune-context-v2';

/// Seals the first observation of this exact photo set before any named
/// suggestion is shown. Subsequent edits remain in the ordinary review history.
ReviewSession captureInitialObservations(
  ReviewSession session, {
  required String capturedAtUtc,
  Iterable<Map<String, dynamic>> priorExposures = const [],
}) {
  if (!session.ready) throw StateError('Review not ready for observations');
  if (DateTime.tryParse(capturedAtUtc) == null) {
    throw const FormatException('Invalid observation time');
  }
  final normalized = [
    for (final p in session.photos)
      if (p.photo.decision == PhotoDecision.unreviewed)
        p.update(photo: p.photo.annotated(const [], PhotoDecision.skipped))
      else
        p,
  ];
  if (session.currentInitialObservation != null) {
    return session.photos.any(
          (p) => p.photo.decision == PhotoDecision.unreviewed,
        )
        ? session.next(photos: normalized)
        : session;
  }
  final exposures = [
    ...priorExposures,
    for (final p in session.photos) ...[
      if (p.observationExposureRunId != null)
        {
          'kind': 'namedCandidate',
          'sessionId': session.id,
          'photoId': p.id,
          'runId': p.observationExposureRunId,
          'exposedAtUtc': null,
        },
      for (final feedback in p.feedback)
        {
          'kind': 'namedCandidate',
          'sessionId': session.id,
          'photoId': p.id,
          'runId': feedback.runId,
          'candidateKey': feedback.candidateKey,
          'exposedAtUtc': feedback.exposedAtUtc,
        },
    ],
  ];
  final history =
      session.observationHistory == 'unknown' ||
          exposures.any(
            (e) =>
                e['history'] == 'unknown' || e['exposureHistory'] == 'unknown',
          )
      ? 'unknown'
      : 'known';
  final snapshot = immutableDocument({
    'version': initialObservationVersion,
    'sessionId': session.id,
    'groupId': session.groupId,
    'sourceRevision': session.revision + 1,
    'photoSetFingerprint': reviewPhotoSetFingerprint(session),
    'capturedAtUtc': capturedAtUtc,
    'sameSampleDeclared': session.sameSampleDeclared,
    'physicalIndependence': 'unverified',
    'labelVersion': labelVersion,
    'exposureHistory': history,
    'priorExposures': exposures,
    'photos': [
      for (final p in normalized)
        {
          'photoId': p.id,
          'photoChecksum': p.photo.checksum,
          'surface': p.surface.name,
          'declaredRole': p.declaredRole?.name,
          'origin': p.photo.origin,
          'photoDecision': p.photo.decision.name,
          'observationCoordinateSpace': 'orientedFullPhotoNormalized',
          'displayCrop': p.visibleCrop.toJson(),
          'regions': p.photo.regions.map((r) => r.toJson()).toList(),
        },
    ],
  });
  return session.next(
    photos: normalized,
    initialObservations: [...session.initialObservations, snapshot],
  );
}

/// A local envelope contains provenance and status. Only its `payload` is an
/// AI input. Building that payload from an allowlist prevents research/private
/// fields in an analysis document from crossing this boundary.
Map<String, dynamic> prepareReviewInput(
  ReviewSession session, {
  required String preparedAtUtc,
}) {
  if (!session.ready || session.currentInitialObservation == null) {
    throw StateError('Initial observations must be saved before preparation');
  }
  if (DateTime.tryParse(preparedAtUtc) == null) {
    throw const FormatException('Invalid preparation time');
  }
  var pending = 0;
  var errors = 0;
  var invalid = 0;
  var observationCount = 0;
  var physicalPhotoCount = 0;
  final photos = <Map<String, dynamic>>[];
  for (final (index, p) in session.orderedPhotos.indexed) {
    final analysis = p.analysis;
    final analysisState = analysis == null
        ? 'pending'
        : analysis['errorStage'] != null ||
              !const {
                'noMatch',
                'insufficientSymbolEvidence',
                'symbolCandidatesAvailable',
              }.contains(analysis['outcome'])
        ? 'technicalError'
        : 'complete';
    if (analysisState == 'pending') pending++;
    if (analysisState == 'technicalError') errors++;
    final raw = analysisState == 'complete'
        ? (analysis?['globalPhysicalMeasurements'])
        : null;
    final measurements = _physicalMeasurements(raw);
    final measurementsStatus = raw == null
        ? 'notAvailable'
        : measurements == null
        ? 'invalid'
        : 'available';
    if (measurementsStatus == 'invalid') invalid++;
    if (measurements != null &&
        ((measurements['residuePixelCount'] as int) > 0 ||
            (measurements['contentResidueRatio'] as num) > 0)) {
      physicalPhotoCount++;
    }
    final observations = [
      for (final r in p.photo.regions)
        if (r.label != null)
          {
            'origin': 'userObservation',
            'symbolName': contributionLabels[r.label]!,
            'box': r.box.toJson(),
          },
    ];
    observationCount += observations.length;
    validateRegionalSummary(
      analysisState == 'complete' ? (analysis?['regionalSummary']) : null,
    );
    photos.add({
      'photoNumber': index + 1,
      'surface': p.surface.name,
      'declaredRole': p.declaredRole?.name,
      'analysisState': analysisState,
      'userObservations': observations,
      'physicalMeasurementsStatus': measurementsStatus,
      'physicalMeasurementScope': 'wholeImageContentNotUserRegion',
      'globalPhysicalMeasurements': measurements,
      'regionalSummary': analysisState == 'complete'
          ? (analysis?['regionalSummary'])
          : null,
    });
  }
  final hasInput = observationCount > 0 || physicalPhotoCount > 0;
  final status = pending > 0
      ? 'analysisPending'
      : !hasInput
      ? 'empty'
      : errors > 0 || invalid > 0
      ? 'partial'
      : 'ready';
  return immutableDocument({
    'version': reviewPreparationVersion,
    'preparedAtUtc': preparedAtUtc,
    'sourceFingerprint': preparationSourceFingerprint(session),
    'sourceRevision': session.revision,
    'status': status,
    'observationCount': observationCount,
    'physicalPhotoCount': physicalPhotoCount,
    'pendingPhotoCount': pending,
    'technicalErrorCount': errors,
    'invalidMeasurementPhotoCount': invalid,
    'payload': {
      'version': reviewPayloadVersion,
      'language': 'tr',
      'status': status,
      'photos': photos,
    },
  });
}

Map<String, num>? _physicalMeasurements(Object? raw) {
  if (raw is! Map) return null;
  final ratio = raw['contentResidueRatio'];
  if (ratio is! num || !ratio.isFinite || ratio < 0 || ratio > 1) return null;
  final result = <String, num>{};
  for (final key in preparationMeasurementFields) {
    final value = raw[key];
    if (key == 'contentResidueRatio') {
      result[key] = ratio;
    } else {
      if (value is! int || value < 0) return null;
      result[key] = value;
    }
  }
  if (result['selectedRelationCount']! > result['candidateRelationCount']!) {
    return null;
  }
  return result;
}
