import 'package:atlas_canonical_json/atlas_canonical_json.dart';

/// Stable failure categories produced by the strict Symbol dataset adapter.
enum SymbolDatasetFailure {
  canonicalJsonRejected,
  schemaViolation,
  unsupportedSchemaVersion,
  unsupportedRecordType,
  unsupportedCanonicalProfile,
  duplicateIdentity,
  nonCanonicalOrder,
  checksumMismatch,
  missingRecord,
  unexpectedRecord,
  invalidReference,
}

/// Typed, content-safe failure raised while parsing a Symbol release bundle.
final class SymbolDatasetException implements Exception {
  const SymbolDatasetException(
    this.failure, {
    required this.document,
    this.field,
    this.canonicalFailure,
  });

  final SymbolDatasetFailure failure;
  final String document;
  final String? field;
  final AtlasCanonicalJsonFailure? canonicalFailure;

  @override
  String toString() {
    return 'SymbolDatasetException(failure: $failure, document: $document, '
        'field: ${field ?? '<none>'}, '
        'canonicalFailure: ${canonicalFailure ?? '<none>'})';
  }
}
