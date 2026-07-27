final class VisionConfig {
  const VisionConfig({this.workingResolution = defaultWorkingResolution})
    : assert(
        workingResolution > 0,
        'workingResolution must be greater than zero',
      );

  static const int defaultWorkingResolution = 512;

  final int workingResolution;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is VisionConfig && other.workingResolution == workingResolution;
  }

  @override
  int get hashCode => workingResolution.hashCode;

  @override
  String toString() {
    return 'VisionConfig(workingResolution: $workingResolution)';
  }
}
