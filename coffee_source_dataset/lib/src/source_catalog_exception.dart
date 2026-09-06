import 'package:atlas_canonical_json/atlas_canonical_json.dart';

enum SourceCatalogFailure {
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
  releaseEligibilityViolation,
}

final class SourceCatalogException implements Exception {
  const SourceCatalogException(
    this.failure, {
    required this.document,
    this.field,
    this.canonicalFailure,
  });

  final SourceCatalogFailure failure;
  final String document;
  final String? field;
  final AtlasCanonicalJsonFailure? canonicalFailure;

  @override
  String toString() =>
      'SourceCatalogException(failure: $failure, document: $document, '
      'field: ${field ?? '<none>'}, '
      'canonicalFailure: ${canonicalFailure ?? '<none>'})';
}
