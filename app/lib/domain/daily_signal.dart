enum SignalSource { appleHealth, healthConnect, fitbit, demo }

class DailySignal {
  final DateTime date;
  final SignalSource source;
  final double? hrvMs;
  final int? sleepMinutes;
  final int? sleepMidpointMinutes;
  final int? steps;

  const DailySignal({
    required this.date,
    required this.source,
    this.hrvMs,
    this.sleepMinutes,
    this.sleepMidpointMinutes,
    this.steps,
  });

  bool get isEligible =>
      sleepMinutes != null && (hrvMs != null || steps != null);

  static String dateKey(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  Map<String, Object?> toMap() => <String, Object?>{
        'date': dateKey(date),
        'source': source.name,
        'hrv_ms': hrvMs,
        'sleep_minutes': sleepMinutes,
        'sleep_midpoint_minutes': sleepMidpointMinutes,
        'steps': steps,
      };

  factory DailySignal.fromMap(Map<String, Object?> map) => DailySignal(
        date: DateTime.parse(map['date']! as String),
        source: SignalSource.values.byName(map['source']! as String),
        hrvMs: (map['hrv_ms'] as num?)?.toDouble(),
        sleepMinutes: (map['sleep_minutes'] as num?)?.toInt(),
        sleepMidpointMinutes: (map['sleep_midpoint_minutes'] as num?)?.toInt(),
        steps: (map['steps'] as num?)?.toInt(),
      );
}
