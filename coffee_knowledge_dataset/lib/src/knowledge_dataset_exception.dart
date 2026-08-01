/// Safe validation failure produced while parsing a Knowledge dataset.
final class KnowledgeDatasetException implements FormatException {
  const KnowledgeDatasetException(this.message);

  @override
  final String message;

  @override
  int? get offset => null;

  @override
  Object? get source => null;

  @override
  String toString() => 'KnowledgeDatasetException: $message';
}
