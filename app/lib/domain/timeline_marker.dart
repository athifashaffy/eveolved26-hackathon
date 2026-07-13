enum TimelineMarkerCategory {
  medication,
  therapy,
  illness,
  travel,
  stress,
  alcohol,
  custom,
}

class TimelineMarker {
  final String id;
  final DateTime date;
  final TimelineMarkerCategory category;
  final String? note;
  final DateTime createdAt;

  const TimelineMarker({
    required this.id,
    required this.date,
    required this.category,
    this.note,
    required this.createdAt,
  });
}
