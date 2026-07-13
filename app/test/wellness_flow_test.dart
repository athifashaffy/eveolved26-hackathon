import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signa/data/real_data.dart';
import 'package:signa/domain/wellness_score.dart';
import 'package:signa/scoring/insight_engine.dart';
import 'package:signa/screens/connect_screen.dart';
import 'package:signa/screens/home_screen.dart';

void main() {
  test('main does not request health authorization at startup', () async {
    final source = await File('lib/main.dart').readAsString();
    expect(source, isNot(contains('requestAuthorization()')));
  });

  testWidgets('health permission is requested only after the consent action',
      (tester) async {
    var requests = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ConnectScreen(
          initialHealthConnected: false,
          initialFitbitConnected: false,
          requestHealthAuthorization: () async {
            requests++;
            return false;
          },
        ),
      ),
    );
    await tester.pump();

    expect(requests, 0);
    expect(find.text('Your data stays on this phone'), findsOneWidget);
    await tester.tap(find.text('Connect health data'));
    await tester.pump();

    expect(requests, 1);
  });

  testWidgets('learning state hides a numeric score', (tester) async {
    final wellness = WellnessScore(
      date: DateTime(2026, 7, 13),
      score: null,
      scoreVersion: 'wellness-v1',
      state: BaselineState.learning,
      confidence: ScoreConfidence.unavailable,
      eligibleDays: 6,
    );
    final snapshot = WellnessViewSnapshot(
      wellness: wellness,
      signals: const [],
      insight: const InsightEngine().build(wellness),
      lastSyncAt: null,
    );
    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(snapshotOverride: snapshot)),
    );

    expect(find.text('6 of 10 eligible days'), findsOneWidget);
    expect(find.textContaining('/ 100'), findsNothing);
    expect(find.text('Keep wearing your device'), findsOneWidget);
  });

  testWidgets('ready state shows score, confidence, and explanation',
      (tester) async {
    final wellness = WellnessScore(
      date: DateTime(2026, 7, 13),
      score: 74,
      scoreVersion: 'wellness-v1',
      state: BaselineState.ready,
      confidence: ScoreConfidence.medium,
      eligibleDays: 14,
      contributions: const <ScoreComponent, ComponentContribution>{
        ScoreComponent.sleep: ComponentContribution(
          score: 74,
          weight: 1,
          explanation: 'Sleep stayed near your usual range.',
        ),
      },
    );
    final snapshot = WellnessViewSnapshot(
      wellness: wellness,
      signals: const [],
      insight: const InsightEngine().build(wellness),
      lastSyncAt: DateTime(2026, 7, 13, 9),
    );
    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(snapshotOverride: snapshot)),
    );

    expect(find.text('74 / 100'), findsOneWidget);
    expect(find.text('Medium confidence'), findsOneWidget);
    expect(find.textContaining('usual range'), findsWidgets);
  });
}
