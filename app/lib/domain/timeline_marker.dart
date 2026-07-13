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

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'date': _dateKey(date),
        'category': category.name,
        'note': note,
        'created_at': createdAt.toIso8601String(),
      };

  factory TimelineMarker.fromMap(Map<String, Object?> map) => TimelineMarker(
        id: map['id']! as String,
        date: DateTime.parse(map['date']! as String),
        category:
            TimelineMarkerCategory.values.byName(map['category']! as String),
        note: map['note'] as String?,
        createdAt: DateTime.parse(map['created_at']! as String),
      );

  static String _dateKey(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
