import 'package:coffee_camera/coffee_camera.dart';

enum AtlasCupCaptureRole { top, handleRight, handleLeft }

final class AtlasCupCaptureSlot {
  const AtlasCupCaptureSlot({required this.role, this.capture});

  final AtlasCupCaptureRole role;
  final CameraCaptureResult? capture;

  bool get isComplete => capture != null;
}

final class AtlasThreeAngleCaptureState {
  factory AtlasThreeAngleCaptureState({
    Iterable<AtlasCupCaptureSlot>? slots,
    AtlasCupCaptureRole? activeRole,
    String? errorMessage,
  }) {
    final canonical = slots == null
        ? [
            for (final role in AtlasCupCaptureRole.values)
              AtlasCupCaptureSlot(role: role),
          ]
        : slots.toList(growable: false);
    if (canonical.length != AtlasCupCaptureRole.values.length) {
      throw ArgumentError.value(slots, 'slots', 'must contain all three roles');
    }
    for (var index = 0; index < canonical.length; index++) {
      if (canonical[index].role != AtlasCupCaptureRole.values[index]) {
        throw ArgumentError.value(
          slots,
          'slots',
          'must use canonical role order without duplicates',
        );
      }
    }
    return AtlasThreeAngleCaptureState._(
      slots: List.unmodifiable(canonical),
      activeRole: activeRole,
      errorMessage: errorMessage,
    );
  }

  const AtlasThreeAngleCaptureState._({
    required this.slots,
    required this.activeRole,
    required this.errorMessage,
  });

  final List<AtlasCupCaptureSlot> slots;
  final AtlasCupCaptureRole? activeRole;
  final String? errorMessage;

  int get completedCount => slots.where((slot) => slot.isComplete).length;
  bool get isBusy => activeRole != null;
  bool get isComplete => completedCount == slots.length;

  AtlasCupCaptureRole? get nextIncompleteRole {
    for (final slot in slots) {
      if (!slot.isComplete) return slot.role;
    }
    return null;
  }

  CameraCaptureResult? captureFor(AtlasCupCaptureRole role) =>
      slots[role.index].capture;

  AtlasThreeAngleCaptureState startCapture(AtlasCupCaptureRole role) =>
      AtlasThreeAngleCaptureState(slots: slots, activeRole: role);

  AtlasThreeAngleCaptureState cancelCapture() =>
      AtlasThreeAngleCaptureState(slots: slots);

  AtlasThreeAngleCaptureState failCapture(String message) =>
      AtlasThreeAngleCaptureState(slots: slots, errorMessage: message);

  AtlasThreeAngleCaptureState store(
    AtlasCupCaptureRole role,
    CameraCaptureResult capture,
  ) => AtlasThreeAngleCaptureState(
    slots: [
      for (final slot in slots)
        if (slot.role == role)
          AtlasCupCaptureSlot(role: role, capture: capture)
        else
          slot,
    ],
  );
}

final class AtlasThreeAngleCupCaptureResult {
  factory AtlasThreeAngleCupCaptureResult(Iterable<AtlasCupCaptureSlot> slots) {
    final canonical = AtlasThreeAngleCaptureState(slots: slots);
    if (!canonical.isComplete) {
      throw ArgumentError.value(
        slots,
        'slots',
        'must contain one completed capture for every role',
      );
    }
    return AtlasThreeAngleCupCaptureResult._(canonical.slots);
  }

  const AtlasThreeAngleCupCaptureResult._(this.slots);

  final List<AtlasCupCaptureSlot> slots;

  List<CameraCaptureResult> get captures =>
      List.unmodifiable([for (final slot in slots) slot.capture!]);

  CameraCaptureResult captureFor(AtlasCupCaptureRole role) =>
      slots[role.index].capture!;
}
