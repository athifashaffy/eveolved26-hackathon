import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:signa/coach/coach_context_builder.dart';
import 'package:signa/data/real_data.dart';
import 'package:signa/domain/daily_signal.dart';
import 'package:signa/domain/wellness_score.dart';
import 'package:signa/scoring/insight_engine.dart';

void main() {
  test('context contains approved facts but excludes raw records and notes',
      () {
    final snapshot = WellnessViewSnapshot(
      wellness: WellnessScore(
        date: DateTime(2026, 6, 20),
        score: 72,
        scoreVersion: 'wellness-v1',
        state: BaselineState.ready,
        confidence: ScoreConfidence.high,
        eligibleDays: 14,
        contributions: const <ScoreComponent, ComponentContribution>{
          ScoreComponent.sleep: ComponentContribution(
            score: 60,
            weight: 0.35,
            explanation: 'Sleep differed from your usual range.',
          ),
        },
      ),
      signals: [
        DailySignal(
          date: DateTime(2026, 6, 20),
          source: SignalSource.fitbit,
          hrvMs: 47.25,
          sleepMinutes: 421,
          steps: 7654,
        ),
      ],
      insight: const WellnessInsight(
        title: 'A mixed pattern',
        body: 'Sleep differed most from your usual range.',
        actionId: 'protect_sleep_window',
      ),
      lastSyncAt: DateTime(2026, 6, 20),
    );

    final context = const CoachContextBuilder().build(
      snapshot,
      'Explain my score',
      markerCategories: const ['therapy'],
    );
    final encoded = jsonEncode(context.toJson());

    expect(context.facts.every((fact) => fact.id.startsWith('fact_')), isTrue);
    expect(encoded, contains('72'));
    expect(encoded, contains('high confidence'));
    expect(encoded, contains('therapy'));
    expect(encoded, isNot(contains('47.25')));
    expect(encoded, isNot(contains('421')));
    expect(encoded, isNot(contains('7654')));
    expect(encoded, isNot(contains('oauth')));
    expect(encoded, isNot(contains('private note')));
  });
}
