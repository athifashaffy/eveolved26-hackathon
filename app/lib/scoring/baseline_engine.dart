import 'dart:math' as math;

import '../data/models.dart';
import '../domain/daily_signal.dart';
import '../domain/wellness_score.dart';

class BaselineEngine {
  static const scoreVersion = 'wellness-v1';
  static const componentWeights = <ScoreComponent, double>{
    ScoreComponent.hrv: .35,
    ScoreComponent.sleep: .35,
    ScoreComponent.activity: .15,
    ScoreComponent.mood: .15,
  };

  WellnessScore evaluate(
    List<DailySignal> signals,
    List<SelfReport> reports,
    DateTime now,
  ) {
    final today = DateTime(now.year, now.month, now.day);
    final chronological = signals
        .where((signal) => !signal.date.isAfter(today))
        .toList()
      ..sort((left, right) => left.date.compareTo(right.date));
    final readinessStart = today.subtract(const Duration(days: 13));
    final recentEligible = chronological
        .where((signal) =>
            !signal.date.isBefore(readinessStart) && signal.isEligible)
        .toList();

    if (recentEligible.length < 10) {
      return _withoutScore(
        date: today,
        state: BaselineState.learning,
        confidence: ScoreConfidence.unavailable,
        eligibleDays: recentEligible.length,
      );
    }

    final latestSource = recentEligible.last.source;
    final sources = recentEligible.map((signal) => signal.source).toSet();
    final latestSourceDays =
        recentEligible.where((signal) => signal.source == latestSource).length;
    if (sources.length > 1 && latestSourceDays < 10) {
      return _withoutScore(
        date: today,
        state: BaselineState.recalibrating,
        confidence: ScoreConfidence.low,
        eligibleDays: recentEligible.length,
      );
    }

    final sourceSignals =
        chronological.where((signal) => signal.source == latestSource).toList();
    final baseline = _latestValidDays(sourceSignals, 28);
    final parts = <ScoreComponent, _UnweightedContribution>{};

    final hrvValues = _values(baseline, (signal) => signal.hrvMs);
    final recentHrv = _values(
      _latestWhere(sourceSignals, (signal) => signal.hrvMs != null, 3),
      (signal) => signal.hrvMs,
    );
    if (hrvValues.isNotEmpty && recentHrv.isNotEmpty) {
      parts[ScoreComponent.hrv] = _objective(
        current: _median(recentHrv),
        baseline: hrvValues,
        floor: .001,
        explanation: 'Recent HRV is compared with your personal range.',
      );
    }

    final durationValues =
        _values(baseline, (signal) => signal.sleepMinutes?.toDouble());
    final latestSleep = sourceSignals.lastWhere(
      (signal) => signal.sleepMinutes != null,
      orElse: () => sourceSignals.last,
    );
    if (durationValues.isNotEmpty && latestSleep.sleepMinutes != null) {
      final duration = _objective(
        current: latestSleep.sleepMinutes!.toDouble(),
        baseline: durationValues,
        floor: 1,
        explanation: 'Last night’s sleep is compared with your personal range.',
      );
      final midpointValues = _values(
        baseline,
        (signal) => signal.sleepMidpointMinutes?.toDouble(),
      );
      final midpoint = latestSleep.sleepMidpointMinutes;
      final sleepScore = midpoint != null && midpointValues.isNotEmpty
          ? (.7 * duration.score +
                  .3 *
                      _objective(
                        current: midpoint.toDouble(),
                        baseline: midpointValues,
                        floor: 1,
                        explanation: '',
                      ).score)
              .round()
          : duration.score;
      parts[ScoreComponent.sleep] = _UnweightedContribution(
        score: sleepScore,
        explanation: midpoint != null && midpointValues.isNotEmpty
            ? 'Sleep duration and timing are compared with your personal range.'
            : duration.explanation,
      );
    }

    final stepValues = _values(baseline, (signal) => signal.steps?.toDouble());
    final recentSteps = _values(
      _latestWhere(sourceSignals, (signal) => signal.steps != null, 7),
      (signal) => signal.steps?.toDouble(),
    );
    if (stepValues.isNotEmpty && recentSteps.isNotEmpty) {
      parts[ScoreComponent.activity] = _objective(
        current: _mean(recentSteps),
        baseline: stepValues,
        floor: 1,
        explanation:
            'Recent activity is compared with your usual activity range.',
      );
    }

    final moodStart = today.subtract(const Duration(days: 6));
    final recentReports = reports
        .where((report) =>
            !report.date.isBefore(moodStart) && !report.date.isAfter(today))
        .toList()
      ..sort((left, right) => right.date.compareTo(left.date));
    if (recentReports.isNotEmpty) {
      final moodValues = recentReports
          .take(3)
          .map((report) => (report.moodRating - 1) * 25.0)
          .toList();
      parts[ScoreComponent.mood] = _UnweightedContribution(
        score: _mean(moodValues).round().clamp(0, 100),
        explanation: 'Mood reflects your latest optional check-ins.',
      );
    }

    final totalWeight = parts.keys
        .map((component) => componentWeights[component]!)
        .fold<double>(0, (sum, weight) => sum + weight);
    final contributions = <ScoreComponent, ComponentContribution>{};
    var weightedScore = 0.0;
    for (final entry in parts.entries) {
      final weight = componentWeights[entry.key]! / totalWeight;
      weightedScore += entry.value.score * weight;
      contributions[entry.key] = ComponentContribution(
        score: entry.value.score,
        weight: weight,
        explanation: entry.value.explanation,
      );
    }

    final latestDate = chronological.last.date;
    final stale = today
            .difference(DateTime(
              latestDate.year,
              latestDate.month,
              latestDate.day,
            ))
            .inDays >=
        3;
    final objectiveCount = <ScoreComponent>{
      ScoreComponent.hrv,
      ScoreComponent.sleep,
      ScoreComponent.activity,
    }.where(parts.containsKey).length;
    final confidence = stale
        ? ScoreConfidence.low
        : objectiveCount == 3 && baseline.length >= 21
            ? ScoreConfidence.high
            : objectiveCount >= 2
                ? ScoreConfidence.medium
                : ScoreConfidence.low;

    return WellnessScore(
      date: today,
      score: weightedScore.round().clamp(0, 100),
      scoreVersion: scoreVersion,
      state: stale ? BaselineState.stale : BaselineState.ready,
      confidence: confidence,
      eligibleDays: recentEligible.length,
      contributions: contributions,
    );
  }

  WellnessScore _withoutScore({
    required DateTime date,
    required BaselineState state,
    required ScoreConfidence confidence,
    required int eligibleDays,
  }) =>
      WellnessScore(
        date: date,
        score: null,
        scoreVersion: scoreVersion,
        state: state,
        confidence: confidence,
        eligibleDays: eligibleDays,
      );

  List<DailySignal> _latestValidDays(
    List<DailySignal> signals,
    int count,
  ) {
    final eligible = signals.where((signal) => signal.isEligible).toList();
    return eligible.length <= count
        ? eligible
        : eligible.sublist(eligible.length - count);
  }

  List<DailySignal> _latestWhere(
    List<DailySignal> signals,
    bool Function(DailySignal signal) predicate,
    int count,
  ) {
    final valid = signals.where(predicate).toList();
    return valid.length <= count ? valid : valid.sublist(valid.length - count);
  }

  List<double> _values(
    List<DailySignal> signals,
    double? Function(DailySignal signal) select,
  ) =>
      signals.map(select).whereType<double>().toList();

  _UnweightedContribution _objective({
    required double current,
    required List<double> baseline,
    required double floor,
    required String explanation,
  }) {
    final center = _median(baseline);
    final deviations = baseline.map((value) => (value - center).abs()).toList();
    final mad = _median(deviations);
    final scale = math.max(
      math.max(1.4826 * mad, center.abs() * .05),
      floor,
    );
    final deviation = (current - center).abs() / scale;
    final score = (100 * math.exp(-.5 * math.pow(deviation / 2, 2))).round();
    return _UnweightedContribution(
      score: score.clamp(0, 100),
      explanation: explanation,
    );
  }

  double _median(List<double> values) {
    final sorted = [...values]..sort();
    final midpoint = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[midpoint]
        : (sorted[midpoint - 1] + sorted[midpoint]) / 2;
  }

  double _mean(List<double> values) =>
      values.fold<double>(0, (sum, value) => sum + value) / values.length;
}

class _UnweightedContribution {
  final int score;
  final String explanation;

  const _UnweightedContribution({
    required this.score,
    required this.explanation,
  });
}
