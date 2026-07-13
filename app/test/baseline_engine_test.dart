import 'package:flutter_test/flutter_test.dart';
import 'package:signa/data/models.dart';
import 'package:signa/domain/daily_signal.dart';
import 'package:signa/domain/wellness_score.dart';
import 'package:signa/scoring/baseline_engine.dart';

void main() {
  final now = DateTime(2026, 7, 13, 12);
  final engine = BaselineEngine();

  List<DailySignal> stableSignals(int count, {bool includeActivity = true}) {
    return List<DailySignal>.generate(count, (index) {
      final offset = count - index - 1;
      return DailySignal(
        date: DateTime(2026, 7, 13).subtract(Duration(days: offset)),
        source: SignalSource.appleHealth,
        hrvMs: 50 + (index % 3 - 1),
        sleepMinutes: 450 + (index % 3 - 1) * 3,
        sleepMidpointMinutes: 210 + (index % 3 - 1) * 2,
        steps: includeActivity ? 8000 + (index % 3 - 1) * 100 : null,
      );
    });
  }

  List<SelfReport> stableReports() => List<SelfReport>.generate(
        3,
        (index) => SelfReport(
          date: now.subtract(Duration(days: index)),
          sleepRating: 4,
          moodRating: 5,
          createdAt: now.subtract(Duration(days: index)),
        ),
      );

  test('requires ten eligible days inside fourteen days', () {
    final result = engine.evaluate(stableSignals(9), const [], now);

    expect(result.state, BaselineState.learning);
    expect(result.score, isNull);
    expect(result.eligibleDays, 9);
    expect(result.confidence, ScoreConfidence.unavailable);
  });

  test('stable personal signals score near one hundred', () {
    final result = engine.evaluate(
      stableSignals(28),
      stableReports(),
      now,
    );

    expect(result.state, BaselineState.ready);
    expect(result.score, inInclusiveRange(95, 100));
    expect(result.confidence, ScoreConfidence.high);
    expect(result.scoreVersion, 'wellness-v1');
  });

  test('an unusual change lowers its component without directional claims', () {
    final signals = stableSignals(28);
    final latest = signals.last;
    signals[signals.length - 1] = DailySignal(
      date: latest.date,
      source: latest.source,
      hrvMs: 25,
      sleepMinutes: 260,
      sleepMidpointMinutes: 430,
      steps: 2200,
    );

    final result = engine.evaluate(signals, stableReports(), now);

    expect(result.score, lessThan(90));
    expect(
      result.contributions[ScoreComponent.sleep]!.score,
      lessThan(70),
    );
  });

  test('missing mood renormalizes weights and keeps medium confidence', () {
    final result = engine.evaluate(stableSignals(14), const [], now);

    expect(result.contributions, isNot(contains(ScoreComponent.mood)));
    expect(
      result.appliedWeights.values.reduce((a, b) => a + b),
      closeTo(1, .0001),
    );
    expect(result.confidence, ScoreConfidence.medium);
  });

  test('zero MAD uses the five percent robust scale floor', () {
    final identical = List<DailySignal>.generate(
      14,
      (index) => DailySignal(
        date: now.subtract(Duration(days: 13 - index)),
        source: SignalSource.healthConnect,
        hrvMs: 50,
        sleepMinutes: 480,
        steps: 6000,
      ),
    );

    final result = engine.evaluate(identical, const [], now);

    expect(result.score, 100);
    expect(
        result.contributions.values.every((part) => part.score == 100), isTrue);
  });

  test('stale latest data lowers confidence', () {
    final result = engine.evaluate(
      stableSignals(14),
      const [],
      now.add(const Duration(days: 4)),
    );

    expect(result.state, BaselineState.stale);
    expect(result.confidence, ScoreConfidence.low);
  });

  test('material source switch recalibrates without showing a score', () {
    final signals = stableSignals(14);
    for (var index = 11; index < signals.length; index++) {
      final signal = signals[index];
      signals[index] = DailySignal(
        date: signal.date,
        source: SignalSource.fitbit,
        hrvMs: signal.hrvMs,
        sleepMinutes: signal.sleepMinutes,
        sleepMidpointMinutes: signal.sleepMidpointMinutes,
        steps: signal.steps,
      );
    }

    final result = engine.evaluate(signals, const [], now);

    expect(result.state, BaselineState.recalibrating);
    expect(result.score, isNull);
    expect(result.confidence, ScoreConfidence.low);
  });
}
