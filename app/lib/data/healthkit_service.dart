import 'dart:io';

import 'package:health/health.dart';
import 'app_settings.dart';
import 'health_data_source.dart';
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

  static String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

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
