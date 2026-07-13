import 'package:flutter_test/flutter_test.dart';
import 'package:signa/data/health_data_source.dart';
import 'package:signa/domain/daily_signal.dart';

void main() {
  test('Fitbit leaves HRV null when the HRV endpoint has no value', () {
    final signals = FitbitSignalNormalizer.combine(
      steps: const <String, int>{'2026-07-12': 6500},
      sleepMinutes: const <String, int>{'2026-07-12': 430},
      hrvRmssd: const <String, double>{},
    );

    expect(signals.single.hrvMs, isNull);
    expect(signals.single.steps, 6500);
    expect(signals.single.sleepMinutes, 430);
  });

  test('Fitbit preserves an actual RMSSD value', () {
    final signals = FitbitSignalNormalizer.combine(
      steps: const <String, int>{},
      sleepMinutes: const <String, int>{'2026-07-12': 430},
      hrvRmssd: const <String, double>{'2026-07-12': 42.5},
    );

    expect(signals.single.hrvMs, 42.5);
    expect(signals.single.steps, isNull);
    expect(signals.single.source, SignalSource.fitbit);
  });

  test('normalizer keeps absent measurements null instead of zero', () {
    final signals = FitbitSignalNormalizer.combine(
      steps: const <String, int>{'2026-07-12': 0},
      sleepMinutes: const <String, int>{'2026-07-12': 0},
      hrvRmssd: const <String, double>{'2026-07-12': 0},
    );

    expect(signals.single.steps, isNull);
    expect(signals.single.sleepMinutes, isNull);
    expect(signals.single.hrvMs, isNull);
  });

  test('fetch result exposes typed recoverable failure', () {
    const result = HealthFetchResult.failure(
      SignalSource.healthConnect,
      HealthFetchFailure.permissionDenied,
    );

    expect(result.signals, isEmpty);
    expect(result.failure, HealthFetchFailure.permissionDenied);
  });
}
