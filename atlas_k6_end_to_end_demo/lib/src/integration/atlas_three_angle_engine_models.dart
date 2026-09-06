import 'package:coffee_camera/coffee_camera.dart';
import 'package:coffee_pattern/coffee_pattern.dart';
import 'package:coffee_symbol/coffee_symbol.dart';
import 'package:coffee_vision/coffee_vision.dart';

import '../capture/atlas_three_angle_capture_models.dart';
import 'atlas_k6_result.dart';
import 'atlas_k6_surface_processor.dart';

final class AtlasThreeAngleAngleResult {
  factory AtlasThreeAngleAngleResult.success({
    required AtlasCupCaptureRole role,
    required CameraCaptureResult capture,
    required AtlasK6SurfaceResult surfaceResult,
  }) {
    if (surfaceResult.featureSet.surfaceType != VisionSurfaceType.cup ||
        surfaceResult.patternResult.surfaceType != PatternSurfaceType.cup) {
      throw ArgumentError.value(
        surfaceResult,
        'surfaceResult',
        'must contain a cup surface result',
      );
    }
    return AtlasThreeAngleAngleResult._(
      role: role,
      capture: capture,
      surfaceResult: surfaceResult,
    );
  }

  factory AtlasThreeAngleAngleResult.technicalError({
    required AtlasCupCaptureRole role,
    required CameraCaptureResult capture,
    required AtlasSurfaceProcessingStage failureStage,
    required String errorMessage,
  }) {
    if (errorMessage.isEmpty || errorMessage.trim() != errorMessage) {
      throw ArgumentError.value(errorMessage, 'errorMessage');
    }
    return AtlasThreeAngleAngleResult._(
      role: role,
      capture: capture,
      failureStage: failureStage,
      errorMessage: errorMessage,
    );
  }

  const AtlasThreeAngleAngleResult._({
    required this.role,
    required this.capture,
    this.surfaceResult,
    this.failureStage,
    this.errorMessage,
  });

  final AtlasCupCaptureRole role;
  final CameraCaptureResult capture;
  final AtlasK6SurfaceResult? surfaceResult;
  final AtlasSurfaceProcessingStage? failureStage;
  final String? errorMessage;

  bool get isTechnicalError => surfaceResult == null;

  AtlasK6AggregateOutcome get outcome => isTechnicalError
      ? AtlasK6AggregateOutcome.technicalError
      : surfaceResult!.outcome;

  int get matchedRecordCount => surfaceResult?.matchedRecordCount ?? 0;
  int get symbolCandidateCount => surfaceResult?.symbolCandidateCount ?? 0;
}

final class AtlasThreeAngleSymbolOccurrence {
  const AtlasThreeAngleSymbolOccurrence({
    required this.role,
    required this.candidate,
  });

  final AtlasCupCaptureRole role;
  final SymbolCandidate candidate;

  int get patternCandidateId => candidate.patternCandidateId;
  String get symbolId => candidate.symbolId;
  int get symbolRevision => candidate.symbolRevision;
}

final class AtlasThreeAngleSymbolGroup {
  factory AtlasThreeAngleSymbolGroup({
    required SymbolDefinition definition,
    required Iterable<AtlasThreeAngleSymbolOccurrence> occurrences,
  }) {
    final canonical = occurrences.toList(growable: false)
      ..sort(_compareOccurrences);
    if (canonical.isEmpty) {
      throw ArgumentError.value(
        occurrences,
        'occurrences',
        'must not be empty',
      );
    }
    for (final occurrence in canonical) {
      if (!identical(occurrence.candidate.definition, definition)) {
        throw ArgumentError.value(
          occurrence.candidate.definition,
          'occurrences',
          'must preserve one exact SymbolDefinition revision',
        );
      }
    }
    for (var index = 1; index < canonical.length; index++) {
      final previous = canonical[index - 1];
      final current = canonical[index];
      if (previous.role == current.role &&
          previous.patternCandidateId == current.patternCandidateId) {
        throw ArgumentError.value(
          occurrences,
          'occurrences',
          'must not contain duplicate occurrence identities',
        );
      }
    }
    final roles = <AtlasCupCaptureRole>[];
    for (final occurrence in canonical) {
      if (roles.isEmpty || roles.last != occurrence.role) {
        roles.add(occurrence.role);
      }
    }
    return AtlasThreeAngleSymbolGroup._(
      definition: definition,
      occurrences: List<AtlasThreeAngleSymbolOccurrence>.unmodifiable(
        canonical,
      ),
      roles: List<AtlasCupCaptureRole>.unmodifiable(roles),
    );
  }

  const AtlasThreeAngleSymbolGroup._({
    required this.definition,
    required this.occurrences,
    required this.roles,
  });

  final SymbolDefinition definition;
  final List<AtlasThreeAngleSymbolOccurrence> occurrences;
  final List<AtlasCupCaptureRole> roles;

  SymbolRevisionRef get symbolRef => definition.symbolRef;
  int get occurrenceCount => occurrences.length;
  int get angleCount => roles.length;
  bool get isMultiAngle => angleCount > 1;

  static int _compareOccurrences(
    AtlasThreeAngleSymbolOccurrence first,
    AtlasThreeAngleSymbolOccurrence second,
  ) {
    final role = first.role.index.compareTo(second.role.index);
    if (role != 0) return role;
    return first.patternCandidateId.compareTo(second.patternCandidateId);
  }
}

final class AtlasThreeAngleEngineResult {
  factory AtlasThreeAngleEngineResult({
    required AtlasThreeAngleCupCaptureResult captureResult,
    required Iterable<AtlasThreeAngleAngleResult> angleResults,
  }) {
    final angles = angleResults.toList(growable: false);
    if (angles.length != AtlasCupCaptureRole.values.length) {
      throw ArgumentError.value(
        angleResults,
        'angleResults',
        'must contain one terminal result for every capture role',
      );
    }
    for (var index = 0; index < angles.length; index++) {
      final role = AtlasCupCaptureRole.values[index];
      final angle = angles[index];
      if (angle.role != role ||
          !identical(angle.capture, captureResult.captureFor(role))) {
        throw ArgumentError.value(
          angleResults,
          'angleResults',
          'must preserve canonical roles and exact capture instances',
        );
      }
    }
    final occurrences = <AtlasThreeAngleSymbolOccurrence>[
      for (final angle in angles)
        if (angle.surfaceResult case final surface?)
          for (final candidate in surface.symbolCandidates)
            AtlasThreeAngleSymbolOccurrence(
              role: angle.role,
              candidate: candidate,
            ),
    ];
    final occurrencesBySymbol =
        <SymbolRevisionRef, List<AtlasThreeAngleSymbolOccurrence>>{};
    for (final occurrence in occurrences) {
      occurrencesBySymbol
          .putIfAbsent(
            occurrence.candidate.definition.symbolRef,
            () => <AtlasThreeAngleSymbolOccurrence>[],
          )
          .add(occurrence);
    }
    final groups = [
      for (final entry in occurrencesBySymbol.entries)
        AtlasThreeAngleSymbolGroup(
          definition: entry.value.first.candidate.definition,
          occurrences: entry.value,
        ),
    ]..sort(_compareSymbolGroups);
    return AtlasThreeAngleEngineResult._(
      captureResult: captureResult,
      angleResults: List<AtlasThreeAngleAngleResult>.unmodifiable(angles),
      symbolOccurrences: List<AtlasThreeAngleSymbolOccurrence>.unmodifiable(
        occurrences,
      ),
      symbolGroups: List<AtlasThreeAngleSymbolGroup>.unmodifiable(groups),
    );
  }

  const AtlasThreeAngleEngineResult._({
    required this.captureResult,
    required this.angleResults,
    required this.symbolOccurrences,
    required this.symbolGroups,
  });

  final AtlasThreeAngleCupCaptureResult captureResult;
  final List<AtlasThreeAngleAngleResult> angleResults;
  final List<AtlasThreeAngleSymbolOccurrence> symbolOccurrences;
  final List<AtlasThreeAngleSymbolGroup> symbolGroups;

  int get matchedRecordCount =>
      angleResults.fold(0, (total, angle) => total + angle.matchedRecordCount);

  int get symbolCandidateCount => symbolOccurrences.length;

  int get technicalErrorCount =>
      angleResults.where((angle) => angle.isTechnicalError).length;

  AtlasThreeAngleAngleResult resultFor(AtlasCupCaptureRole role) =>
      angleResults[role.index];

  static int _compareSymbolGroups(
    AtlasThreeAngleSymbolGroup first,
    AtlasThreeAngleSymbolGroup second,
  ) {
    final symbolId = first.symbolRef.symbolId.compareTo(
      second.symbolRef.symbolId,
    );
    if (symbolId != 0) return symbolId;
    final revision = first.symbolRef.revision.compareTo(
      second.symbolRef.revision,
    );
    if (revision != 0) return revision;
    return first.symbolRef.checksum.compareTo(second.symbolRef.checksum);
  }
}

enum AtlasThreeAngleEnginePhase { idle, processing, complete }

final class AtlasThreeAngleEngineState {
  factory AtlasThreeAngleEngineState.idle({String? setupError}) {
    if (setupError != null &&
        (setupError.isEmpty || setupError.trim() != setupError)) {
      throw ArgumentError.value(setupError, 'setupError');
    }
    return AtlasThreeAngleEngineState._(
      phase: AtlasThreeAngleEnginePhase.idle,
      angleResults: const <AtlasThreeAngleAngleResult>[],
      setupError: setupError,
    );
  }

  factory AtlasThreeAngleEngineState.processing({
    required AtlasThreeAngleCupCaptureResult captureResult,
    required AtlasCupCaptureRole activeRole,
    required Iterable<AtlasThreeAngleAngleResult> angleResults,
  }) => AtlasThreeAngleEngineState._(
    phase: AtlasThreeAngleEnginePhase.processing,
    captureResult: captureResult,
    activeRole: activeRole,
    angleResults: _validatedPartialResults(angleResults),
  );

  factory AtlasThreeAngleEngineState.complete(
    AtlasThreeAngleEngineResult result,
  ) => AtlasThreeAngleEngineState._(
    phase: AtlasThreeAngleEnginePhase.complete,
    captureResult: result.captureResult,
    angleResults: result.angleResults,
    result: result,
  );

  const AtlasThreeAngleEngineState._({
    required this.phase,
    required this.angleResults,
    this.captureResult,
    this.activeRole,
    this.result,
    this.setupError,
  });

  final AtlasThreeAngleEnginePhase phase;
  final AtlasThreeAngleCupCaptureResult? captureResult;
  final AtlasCupCaptureRole? activeRole;
  final List<AtlasThreeAngleAngleResult> angleResults;
  final AtlasThreeAngleEngineResult? result;
  final String? setupError;

  bool get isBusy => phase == AtlasThreeAngleEnginePhase.processing;
  bool get isComplete => phase == AtlasThreeAngleEnginePhase.complete;

  static List<AtlasThreeAngleAngleResult> _validatedPartialResults(
    Iterable<AtlasThreeAngleAngleResult> values,
  ) {
    final results = values.toList(growable: false);
    final seen = <AtlasCupCaptureRole>{};
    var previousIndex = -1;
    for (final result in results) {
      if (!seen.add(result.role) || result.role.index <= previousIndex) {
        throw ArgumentError.value(
          values,
          'angleResults',
          'must use unique canonical role order',
        );
      }
      previousIndex = result.role.index;
    }
    return List<AtlasThreeAngleAngleResult>.unmodifiable(results);
  }
}
