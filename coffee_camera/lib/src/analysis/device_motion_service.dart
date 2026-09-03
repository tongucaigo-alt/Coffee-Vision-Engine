import 'dart:async';
import 'dart:math' as math;

import 'package:sensors_plus/sensors_plus.dart';

class MotionSnapshot {
  const MotionSnapshot({
    required this.isAvailable,
    required this.angleDegrees,
    required this.isStable,
  });

  const MotionSnapshot.unavailable()
    : isAvailable = false,
      angleDegrees = 0,
      isStable = false;

  final bool isAvailable;
  final double angleDegrees;
  final bool isStable;
}

class DeviceMotionService {
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<UserAccelerometerEvent>? _userAccelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  double _angleDegrees = 0;
  double _motionMagnitude = double.infinity;
  double _rotationMagnitude = double.infinity;
  bool _hasGravitySample = false;
  bool _hasMotionSample = false;
  bool _hasGyroscopeSample = false;

  MotionSnapshot get snapshot => MotionSnapshot(
    isAvailable: _hasGravitySample && _hasMotionSample && _hasGyroscopeSample,
    angleDegrees: _angleDegrees,
    isStable: _motionMagnitude < 0.25 && _rotationMagnitude < 0.12,
  );

  void start() {
    if (_accelerometerSubscription != null) return;
    _accelerometerSubscription = accelerometerEventStream(
      samplingPeriod: SensorInterval.uiInterval,
    ).listen(_onAccelerometer, onError: _onSensorError);
    _userAccelerometerSubscription = userAccelerometerEventStream(
      samplingPeriod: SensorInterval.uiInterval,
    ).listen(_onUserAccelerometer, onError: _onSensorError);
    _gyroscopeSubscription = gyroscopeEventStream(
      samplingPeriod: SensorInterval.uiInterval,
    ).listen(_onGyroscope, onError: _onSensorError);
  }

  void _onAccelerometer(AccelerometerEvent event) {
    final magnitude = math.sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );
    if (magnitude <= 0.01) return;
    final cosine = (event.z.abs() / magnitude).clamp(0.0, 1.0);
    _angleDegrees = math.acos(cosine) * 180 / math.pi;
    _hasGravitySample = true;
  }

  void _onUserAccelerometer(UserAccelerometerEvent event) {
    final current = math.sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );
    _motionMagnitude = _smoothed(_motionMagnitude, current);
    _hasMotionSample = true;
  }

  void _onGyroscope(GyroscopeEvent event) {
    final current = math.sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );
    _rotationMagnitude = _smoothed(_rotationMagnitude, current);
    _hasGyroscopeSample = true;
  }

  double _smoothed(double previous, double current) {
    if (!previous.isFinite) return current;
    return previous * 0.75 + current * 0.25;
  }

  void _onSensorError(Object _) {
    _hasGravitySample = false;
    _hasMotionSample = false;
    _hasGyroscopeSample = false;
  }

  Future<void> stop() async {
    await _accelerometerSubscription?.cancel();
    await _userAccelerometerSubscription?.cancel();
    await _gyroscopeSubscription?.cancel();
    _accelerometerSubscription = null;
    _userAccelerometerSubscription = null;
    _gyroscopeSubscription = null;
  }
}
