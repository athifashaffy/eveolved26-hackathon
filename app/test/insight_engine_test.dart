import 'package:flutter_test/flutter_test.dart';
import 'package:signa/domain/wellness_score.dart';
import 'package:signa/scoring/insight_engine.dart';

void main() {
  test('names strongest positive and negative contributors', () {
    final score = WellnessScore(
      date: _date,
      score: 71,
      scoreVersion: 'wellness-v1',
      state: BaselineState.ready,
      confidence: ScoreConfidence.high,
      eligibleDays: 28,
      contributions: <ScoreComponent, ComponentContribution>{
        ScoreComponent.sleep: ComponentContribution(
          score: 42,
          weight: .35,
          explanation: 'Sleep timing differed from your usual range.',
        ),
        ScoreComponent.hrv: ComponentContribution(
          score: 96,
          weight: .35,
          explanation: 'Recent HRV stayed close to your usual range.',
        ),
        ScoreComponent.activity: ComponentContribution(
          score: 78,
          weight: .15,
          explanation: 'Activity stayed near your usual range.',
        ),
      },
    );

    final insight = const InsightEngine().build(score);

    expect(
      insight.evidence,
      containsAll(<ScoreComponent>[ScoreComponent.sleep, ScoreComponent.hrv]),
    );
    expect(insight.body.toLowerCase(), contains('sleep'));
    expect(insight.body.toLowerCase(), contains('hrv'));
    expect(insight.actionId, 'protect_sleep_window');
  });

  test('learning state asks for more data without inventing a score', () {
    final score = WellnessScore(
      date: _date,
      score: null,
      scoreVersion: 'wellness-v1',
      state: BaselineState.learning,
      confidence: ScoreConfidence.unavailable,
      eligibleDays: 6,
    );

    final insight = const InsightEngine().build(score);

    expect(insight.title, 'Learning your baseline');
    expect(insight.body, contains('6 of 10'));
    expect(insight.actionId, 'complete_check_in');
    expect(insight.evidence, isEmpty);
  });

  test('every insight action is allowlisted', () {
    for (final state in BaselineState.values) {
      final insight = const InsightEngine().build(
        WellnessScore(
          date: _date,
          score: null,
          scoreVersion: 'wellness-v1',
          state: state,
          confidence: ScoreConfidence.low,
          eligibleDays: 10,
        ),
      );
      expect(InsightEngine.allowedActions, contains(insight.actionId));
    }
  });
}

final _date = DateTime(2026, 7, 13);
