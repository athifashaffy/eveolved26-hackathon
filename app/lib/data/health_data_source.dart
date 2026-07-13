import '../domain/daily_signal.dart';

enum HealthFetchFailure {
  permissionDenied,
  unsupported,
  offline,
  rateLimited,
  unknown,
}

class HealthFetchResult {
  final List<DailySignal> signals;
  final SignalSource source;
  final DateTime? fetchedAt;
  final HealthFetchFailure? failure;

  const HealthFetchResult({
    required this.signals,
    required this.source,
    required this.fetchedAt,
    this.failure,
  });

  const HealthFetchResult.failure(this.source, this.failure)
      : signals = const <DailySignal>[],
        fetchedAt = null;

  bool get isSuccess => failure == null;
}

abstract interface class HealthDataSource {
  Future<HealthFetchResult> fetch(DateTime start, DateTime end);
}

class FitbitSignalNormalizer {
  const FitbitSignalNormalizer._();

  static List<DailySignal> combine({
    required Map<String, int> steps,
    required Map<String, int> sleepMinutes,
    required Map<String, double> hrvRmssd,
  }) {
    final dates = <String>{
      ...steps.keys,
      ...sleepMinutes.keys,
      ...hrvRmssd.keys,
    }.toList()
      ..sort();
    return dates
        .map(
          (date) => DailySignal(
            date: DateTime.parse(date),
            source: SignalSource.fitbit,
            hrvMs: _positiveDouble(hrvRmssd[date]),
            sleepMinutes: _positiveInt(sleepMinutes[date]),
            steps: _positiveInt(steps[date]),
          ),
        )
        .toList();
  }

  static double? _positiveDouble(double? value) =>
      value != null && value > 0 ? value : null;

  static int? _positiveInt(int? value) =>
      value != null && value > 0 ? value : null;
}
