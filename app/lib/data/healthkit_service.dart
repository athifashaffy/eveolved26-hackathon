import 'package:health/health.dart';
import 'models.dart';

/// Wraps the `health` package for Apple HealthKit (iOS) and
/// Google Health Connect (Android).
class HealthKitService {
  HealthKitService._();
  static final instance = HealthKitService._();

  final _health = Health();
  bool _configured = false;

  static const _types = [
    HealthDataType.HEART_RATE_VARIABILITY_SDNN,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.STEPS,
  ];

  Future<void> _configure() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  Future<bool> requestAuthorization() async {
    try {
      await _configure();
      return await _health.requestAuthorization(_types);
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasPermission() async {
    try {
      await _configure();
      return await _health.hasPermissions(_types) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Fetches the last [days] days of HRV, sleep and steps data.
  /// Returns null on failure.
  Future<List<StabilityReading>?> fetchReadings({int days = 30}) async {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: days));

    try {
      await _configure();
      final points = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: now,
        types: _types,
      );
      if (points.isEmpty) return null;

      // Group by date
      final Map<String, List<HealthDataPoint>> byDay = {};
      for (final p in points) {
        final key = _dateKey(p.dateFrom);
        (byDay[key] ??= []).add(p);
      }

      final readings = <StabilityReading>[];
      for (final entry in byDay.entries) {
        final date = DateTime.parse(entry.key);
        final pts = entry.value;

        final hrv = _avgOfType(pts, HealthDataType.HEART_RATE_VARIABILITY_SDNN);
        final sleepMin = _sumOfType(pts, HealthDataType.SLEEP_ASLEEP);
        final steps = _sumOfType(pts, HealthDataType.STEPS);

        final sleepMinInt = sleepMin.toInt();
        final sleepScore = (sleepMin / 480 * 100).clamp(0, 100).toInt();
        final hrvMs = hrv.toInt();

        final normHrv = (hrv / 60).clamp(0.0, 1.0);
        final normSleep = sleepScore / 100.0;
        final score = (normHrv * 0.6 + normSleep * 0.4).clamp(0.0, 1.0);

        readings.add(StabilityReading(
          date: date,
          score: score,
          hrvMs: hrvMs,
          sleepMinutes: sleepMinInt,
          sleepScore: sleepScore,
          steps: steps.toInt(),
        ));
      }

      readings.sort((a, b) => a.date.compareTo(b.date));
      return readings.isEmpty ? null : readings;
    } catch (_) {
      return null;
    }
  }

  static String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  static double _avgOfType(List<HealthDataPoint> pts, HealthDataType type) {
    final vals = pts
        .where((p) => p.type == type)
        .map((p) => (p.value as NumericHealthValue).numericValue.toDouble())
        .toList();
    if (vals.isEmpty) return 0;
    return vals.reduce((a, b) => a + b) / vals.length;
  }

  static double _sumOfType(List<HealthDataPoint> pts, HealthDataType type) {
    return pts
        .where((p) => p.type == type)
        .map((p) => (p.value as NumericHealthValue).numericValue.toDouble())
        .fold(0.0, (a, b) => a + b);
  }
}
