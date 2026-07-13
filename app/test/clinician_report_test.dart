import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:signa/data/clinician_report_service.dart';
import 'package:signa/domain/daily_signal.dart';
import 'package:signa/domain/timeline_marker.dart';
import 'package:signa/domain/wellness_score.dart';

void main() {
  final report = ClinicianReportData(
    displayName: 'Alex',
    from: DateTime(2026, 6, 1),
    to: DateTime(2026, 6, 30),
    signals: [
      DailySignal(
        date: DateTime(2026, 6, 20),
        source: SignalSource.appleHealth,
        hrvMs: 48,
        sleepMinutes: 430,
        steps: 7200,
      ),
    ],
    scores: [
      WellnessScore(
        date: DateTime(2026, 6, 20),
        score: 72,
        scoreVersion: 'wellness-v1',
        state: BaselineState.ready,
        confidence: ScoreConfidence.high,
        eligibleDays: 14,
      ),
    ],
    markers: [
      TimelineMarker(
        id: 'marker-1',
        date: DateTime(2026, 6, 19),
        category: TimelineMarkerCategory.therapy,
        note: 'Private session detail must stay on device',
        createdAt: DateTime(2026, 6, 19, 9),
      ),
    ],
  );

  test('clinician summary includes confidence, provenance, and safe disclaimer',
      () {
    final text = ClinicianReportService.buildPlainText(report);

    expect(text, contains('High confidence'));
    expect(text, contains('Apple Health'));
    expect(text, contains('wellness-v1'));
    expect(text, contains('Therapy'));
    expect(text, contains('not a diagnosis'));
  });

  test('clinician summary never includes private marker notes', () {
    final text = ClinicianReportService.buildPlainText(report);

    expect(text, isNot(contains('Private session detail')));
  });

  test('clinician report builds a real PDF document', () async {
    final bytes = await ClinicianReportService.buildPdf(report);

    expect(utf8.decode(bytes.take(4).toList()), '%PDF');
    expect(bytes.length, greaterThan(500));
  });
}
