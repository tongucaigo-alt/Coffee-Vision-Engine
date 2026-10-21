/// Local request identity; never part of the provider payload.
String readingRequestKey(
  String sessionId,
  String sourceFingerprint,
  String focus,
) => '$sessionId|$sourceFingerprint|focus=$focus';

String resultReadingFocus(Map result) {
  final focus = (result['context'] as Map?)?['readingFocus'];
  return const ['general', 'love', 'work', 'money'].contains(focus)
      ? focus as String
      : 'general';
}

String resultReadingRequestKey(Map result) => readingRequestKey(
  result['sessionId'] as String? ?? '',
  result['sourceFingerprint'] as String? ?? '',
  resultReadingFocus(result),
);

String legacyReadingKey(Map result) =>
    '${result['sessionId']}|${result['sourceFingerprint']}';

String physicalReadingKey(String key) =>
    key.replaceFirst(RegExp(r'\|focus=(general|love|work|money)$'), '');
