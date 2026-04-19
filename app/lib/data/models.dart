class StabilityReading {
  final DateTime date;
  final double score; // 0..1
  final int hrvMs;
  final int sleepMinutes; // raw minutes asleep
  final int sleepScore;   // 0..100 (derived from sleepMinutes)
  final int steps;

  const StabilityReading({
    required this.date,
    required this.score,
    required this.hrvMs,
    required this.sleepMinutes,
    required this.sleepScore,
    required this.steps,
  });

  /// Format sleep as "Xh Ym"
  String get sleepLabel {
    final h = sleepMinutes ~/ 60;
    final m = sleepMinutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  factory StabilityReading.fromJson(Map<String, dynamic> j) {
    final rawMin = (j['sleep_min'] as num?)?.toInt();
    final rawScore = (j['sleep_score'] as num?)?.toInt();
    // support both old format (sleep_score only) and new (sleep_min)
    final mins = rawMin ?? ((rawScore ?? 0) * 480 ~/ 100);
    final score = rawScore ?? ((mins / 480) * 100).clamp(0, 100).toInt();
    return StabilityReading(
      date: DateTime.parse(j['date'] as String),
      score: (j['score'] as num).toDouble(),
      hrvMs: (j['hrv_ms'] as num).toInt(),
      sleepMinutes: mins,
      sleepScore: score,
      steps: (j['steps'] as num).toInt(),
    );
  }
}

enum StabilityStatus { stable, monitoring, alert }

class StabilitySnapshot {
  final double score; // 0..1 (most recent)
  final StabilityStatus status;
  final int hrvMs;
  final double hrvDeltaPct;
  final int sleepScore;
  final int sleepMinutes; // today's raw sleep minutes
  final String sleepTrendLabel;
  final List<StabilityReading> last14Days;
  final List<StabilityReading> last30Days;
  final String deviceName;
  final Duration lastSync;

  const StabilitySnapshot({
    required this.score,
    required this.status,
    required this.hrvMs,
    required this.hrvDeltaPct,
    required this.sleepScore,
    required this.sleepMinutes,
    required this.sleepTrendLabel,
    required this.last14Days,
    required this.last30Days,
    required this.deviceName,
    required this.lastSync,
  });

  String get sleepLabel {
    final h = sleepMinutes ~/ 60;
    final m = sleepMinutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  static StabilitySnapshot fromReadings(
    List<StabilityReading> readings, {
    required String deviceName,
    Duration lastSync = Duration.zero,
  }) {
    if (readings.isEmpty) return _empty(deviceName);

    final sorted = [...readings]..sort((a, b) => a.date.compareTo(b.date));
    final last30 = sorted.length > 30 ? sorted.sublist(sorted.length - 30) : sorted;
    final last14 = last30.length > 14 ? last30.sublist(last30.length - 14) : last30;
    final latest = last30.last;

    // HRV delta vs 7-day prior window
    final priorWindow = last30.length >= 8
        ? last30.sublist(last30.length - 8, last30.length - 1)
        : last30.sublist(0, last30.length - 1);
    final priorAvgHrv = priorWindow.isEmpty
        ? latest.hrvMs.toDouble()
        : priorWindow.map((r) => r.hrvMs).reduce((a, b) => a + b) /
            priorWindow.length;
    final hrvDelta = priorAvgHrv == 0
        ? 0.0
        : (latest.hrvMs - priorAvgHrv) / priorAvgHrv * 100;

    // Sleep trend label
    final recentSleep = last30.length >= 3
        ? last30.sublist(last30.length - 3).map((r) => r.sleepScore).toList()
        : [latest.sleepScore];
    final sleepAvg = recentSleep.reduce((a, b) => a + b) / recentSleep.length;
    final sleepLabel = sleepAvg >= 70
        ? 'Improving'
        : sleepAvg >= 55
            ? 'Stable'
            : 'Declining';

    final status = latest.score >= 0.65
        ? StabilityStatus.stable
        : latest.score >= 0.45
            ? StabilityStatus.monitoring
            : StabilityStatus.alert;

    return StabilitySnapshot(
      score: latest.score,
      status: status,
      hrvMs: latest.hrvMs,
      hrvDeltaPct: hrvDelta,
      sleepScore: latest.sleepScore,
      sleepMinutes: latest.sleepMinutes,
      sleepTrendLabel: sleepLabel,
      last14Days: last14,
      last30Days: last30,
      deviceName: deviceName,
      lastSync: lastSync,
    );
  }

  static StabilitySnapshot _empty(String deviceName) => StabilitySnapshot(
        score: 0.0,
        status: StabilityStatus.monitoring,
        hrvMs: 0,
        hrvDeltaPct: 0,
        sleepScore: 0,
        sleepMinutes: 0,
        sleepTrendLabel: 'No data',
        last14Days: const [],
        last30Days: const [],
        deviceName: deviceName,
        lastSync: Duration.zero,
      );
}
