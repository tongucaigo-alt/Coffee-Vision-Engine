/// Read-only presentation metadata for one saved contribution.
class RecordSummary {
  const RecordSummary({required this.state, required this.starred});

  static const unreadable = 'Fal durumu okunamadı';
  final String state;
  final bool starred;
}

typedef RecordSummaryLoader =
    Future<Map<String, RecordSummary>> Function(
      List<Map<String, dynamic>> rows,
    );
