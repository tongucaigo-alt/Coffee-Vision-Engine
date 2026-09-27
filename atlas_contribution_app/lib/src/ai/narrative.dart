import 'dart:convert';

const narrativeTopics = [
  'relationships',
  'work',
  'social',
  'decisions',
  'rest',
  'beginnings',
];
const narrativeArcs = [
  'notice-explore-choice',
  'contrast-perspective-small-step',
  'pause-connection-opening',
];
const narrativeClosings = [
  'gentle-question',
  'small-invitation',
  'open-possibility',
];

Map<String, dynamic> planNarrative(List<Map<String, dynamic>> recent) {
  final topics = recent
      .take(5)
      .map((r) => (r['context'] as Map?)?['narrative']?['topic'])
      .toList();
  final choices =
      narrativeTopics.where((t) => topics.isEmpty || t != topics.first).toList()
        ..sort((a, b) {
          final count = topics
              .where((t) => t == a)
              .length
              .compareTo(topics.where((t) => t == b).length);
          return count == 0
              ? narrativeTopics.indexOf(a).compareTo(narrativeTopics.indexOf(b))
              : count;
        });
  return {
    'version': 'atlas-narrative-v1',
    'topic': choices.first,
    'arc':
        narrativeArcs[(narrativeArcs.indexOf(
                  recent.isEmpty
                      ? ''
                      : ((recent.first['context'] as Map?)?['narrative']?['arc']
                                as String? ??
                            ''),
                ) +
                1) %
            narrativeArcs.length],
    'closing':
        narrativeClosings[(narrativeClosings.indexOf(
                  recent.isEmpty
                      ? ''
                      : ((recent.first['context']
                                    as Map?)?['narrative']?['closing']
                                as String? ??
                            ''),
                ) +
                1) %
            narrativeClosings.length],
    'maxPhysicalDetails': 3,
  };
}

void validateNarrative(Object? value) {
  if (value is! Map ||
      value.length != 5 ||
      !value.keys.every(
        ['version', 'topic', 'arc', 'closing', 'maxPhysicalDetails'].contains,
      ) ||
      value['version'] != 'atlas-narrative-v1' ||
      !narrativeTopics.contains(value['topic']) ||
      !narrativeArcs.contains(value['arc']) ||
      !narrativeClosings.contains(value['closing']) ||
      value['maxPhysicalDetails'] != 3) {
    throw const FormatException('Invalid narrative plan');
  }
}

String _normalize(String text) => text
    .toLowerCase()
    .replaceAll('ı', 'i')
    .replaceAll(RegExp(r'[^a-zçğöşü0-9\s]'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
List<String> _sentences(String text) => text
    .split(RegExp(r'[.!?\n]+'))
    .map(_normalize)
    .where((s) => s.split(' ').length >= 8)
    .toList();

/// Only a generic reason crosses the provider boundary, never previous stories.
String? narrativeRepetition(String text, Iterable<String> previous) {
  final sentences = _sentences(text);
  if (sentences.toSet().length < sentences.length) return 'repetition';
  final opening = _normalize(text).split(' ').take(10).join(' ');
  for (final old in previous) {
    if (opening.split(' ').length >= 10 &&
        opening == _normalize(old).split(' ').take(10).join(' ')) {
      return 'repetition';
    }
    final oldSentences = _sentences(old).toSet();
    if (sentences.any(oldSentences.contains)) {
      return 'repetition';
    }
  }
  return null;
}

Map<String, dynamic> freezeNarrativeContext(
  Map<String, dynamic> input,
  Map<String, dynamic> plan,
) => Map<String, dynamic>.from(
  jsonDecode(jsonEncode({...input, 'narrative': plan})) as Map,
);
