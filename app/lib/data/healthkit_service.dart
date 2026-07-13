import 'dart:io';

import 'package:health/health.dart';
import 'app_settings.dart';
import 'health_data_source.dart';
import 'models.dart';
import '../domain/daily_signal.dart';

/// Wraps the `health` package for Apple HealthKit (iOS) and
/// Google Health Connect (Android).
///
/// iOS quirk: Apple deliberately hides read-permission grant state from
/// apps, so `hasPermissions()` returns `null` for read-only types. We
/// persist a "granted" flag in [AppSettings] after a successful auth
/// request and use that as the source of truth on cold start.
class HealthKitService implements HealthDataSource {
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
      final ok = await _health.requestAuthorization(_types);
      if (ok) await AppSettings.instance.setAppleHealthGranted(true);
      return ok;
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasPermission() async {
    if (AppSettings.instance.appleHealthGranted) return true;
    try {
      await _configure();
      return await _health.hasPermissions(_types) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Soft-disconnect from the app's perspective. iOS keeps the authorization
  /// in Settings → Privacy → Health, but the app stops treating Apple Health
  /// as a connected source until the user re-authorises.
  Future<void> forgetAuthorization() async {
    await AppSettings.instance.setAppleHealthGranted(false);
  }

  @override
  Future<HealthFetchResult> fetch(DateTime start, DateTime end) async {
    final source = Platform.isAndroid
        ? SignalSource.healthConnect
        : SignalSource.appleHealth;
    try {
      await _configure();
      final points = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: _types,
      );
      final byDay = <String, List<HealthDataPoint>>{};
      for (final point in points) {
        (byDay[_dateKey(point.dateFrom)] ??= <HealthDataPoint>[]).add(point);
      }
      final signals = <DailySignal>[];
      for (final entry in byDay.entries) {
        final sleepPoints = entry.value
            .where((point) => point.type == HealthDataType.SLEEP_ASLEEP)
            .toList();
        signals.add(
          DailySignal(
            date: DateTime.parse(entry.key),
            source: source,
            hrvMs: _nullableAverage(
              entry.value,
              HealthDataType.HEART_RATE_VARIABILITY_SDNN,
            ),
            sleepMinutes:
                _nullableSum(entry.value, HealthDataType.SLEEP_ASLEEP)?.round(),
            sleepMidpointMinutes: _sleepMidpoint(sleepPoints),
            steps: _nullableSum(entry.value, HealthDataType.STEPS)?.round(),
          ),
        );
      }
      signals.sort((left, right) => left.date.compareTo(right.date));
      return HealthFetchResult(
        signals: signals,
        source: source,
        fetchedAt: DateTime.now(),
      );
    } catch (_) {
      return HealthFetchResult.failure(source, HealthFetchFailure.unknown);
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

  static double? _nullableAverage(
    List<HealthDataPoint> points,
    HealthDataType type,
  ) {
    final values = points
        .where((point) => point.type == type)
        .map((point) =>
            (point.value as NumericHealthValue).numericValue.toDouble())
        .where((value) => value > 0)
        .toList();
    if (values.isEmpty) return null;
    return values.reduce((left, right) => left + right) / values.length;
  }

  static double? _nullableSum(
    List<HealthDataPoint> points,
    HealthDataType type,
  ) {
    final values = points
        .where((point) => point.type == type)
        .map((point) =>
            (point.value as NumericHealthValue).numericValue.toDouble())
        .where((value) => value > 0)
        .toList();
    if (values.isEmpty) return null;
    return values.reduce((left, right) => left + right);
  }

  static int? _sleepMidpoint(List<HealthDataPoint> points) {
    if (points.isEmpty) return null;
    final start = points
        .map((point) => point.dateFrom)
        .reduce((left, right) => left.isBefore(right) ? left : right);
    final end = points
        .map((point) => point.dateTo)
        .reduce((left, right) => left.isAfter(right) ? left : right);
    final midpoint = start
        .add(Duration(milliseconds: end.difference(start).inMilliseconds ~/ 2));
    return midpoint.hour * 60 + midpoint.minute;
  }
}
