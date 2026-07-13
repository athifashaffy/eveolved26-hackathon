import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signa/coach/coach_engine.dart';
import 'package:signa/coach/coach_response_validator.dart';
import 'package:signa/data/real_data.dart';
import 'package:signa/domain/wellness_score.dart';
import 'package:signa/scoring/insight_engine.dart';
import 'package:signa/screens/coach_screen.dart';

void main() {
  testWidgets('ordinary question receives a grounded ephemeral explanation',
      (tester) async {
    final engine = _FakeEngine();
    await tester.pumpWidget(MaterialApp(
      home: CoachScreen(snapshot: _snapshot, engine: engine),
    ));

    expect(find.textContaining('stays on this phone'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('coach_question')),
      'Why was my score lower?',
    );
    await tester.tap(find.byKey(const Key('coach_submit')));
    await tester.pumpAndSettle();

    expect(find.text('Sleep differed from your usual range.'), findsOneWidget);
    expect(find.textContaining('Evidence: fact_sleep'), findsOneWidget);
    expect(engine.calls, 1);
  });

  testWidgets('high-risk question bypasses the engine', (tester) async {
    final engine = _FakeEngine();
    await tester.pumpWidget(MaterialApp(
      home: CoachScreen(snapshot: _snapshot, engine: engine),
    ));

    await tester.enterText(
      find.byKey(const Key('coach_question')),
      'Should I stop taking sertraline?',
    );
    await tester.tap(find.byKey(const Key('coach_submit')));
    await tester.pumpAndSettle();

    expect(find.text('Check with a qualified professional'), findsOneWidget);
    expect(engine.calls, 0);
  });

  testWidgets('clear conversation removes question and response',
      (tester) async {
    final engine = _FakeEngine();
    await tester.pumpWidget(MaterialApp(
      home: CoachScreen(snapshot: _snapshot, engine: engine),
    ));
    await tester.enterText(
      find.byKey(const Key('coach_question')),
      'Explain this',
    );
    await tester.tap(find.byKey(const Key('coach_submit')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clear conversation'));
    await tester.pump();

    expect(find.text('Sleep differed from your usual range.'), findsNothing);
    expect(find.text('Explain this'), findsNothing);
  });
}

final _snapshot = WellnessViewSnapshot(
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
  signals: const [],
  insight: const WellnessInsight(
    title: 'A mixed pattern',
    body: 'Sleep differed from your usual range.',
    actionId: 'protect_sleep_window',
  ),
  lastSyncAt: DateTime(2026, 6, 20),
);

class _FakeEngine implements CoachEngine {
  int calls = 0;

  @override
  Future<CoachValidationResult> generate(
    CoachRequest request,
    CancellationToken cancellation,
  ) async {
    calls++;
    return const CoachValidated(
      text: 'Sleep differed from your usual range.',
      evidenceIds: <String>['fact_sleep'],
      actionId: 'protect_sleep_window',
      category: 'explanation',
    );
  }

  @override
  Future<void> close() async {}
}
