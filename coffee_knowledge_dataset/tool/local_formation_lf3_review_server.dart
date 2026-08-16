import 'local_formation_evidence_review_server.dart' as shared_review;

/// Starts the verified LF-2 geometric review surface for LF-3 observations.
///
/// The shared surface performs no automatic alignment decision. LF-3 uses a
/// separate default port so both research checkpoints can remain available.
Future<void> main(List<String> arguments) {
  final effectiveArguments = List<String>.of(arguments);
  if (!effectiveArguments.contains('--port')) {
    effectiveArguments.addAll(const ['--port', '8768']);
  }
  return shared_review.main(effectiveArguments);
}
