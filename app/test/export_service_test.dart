import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:signa/data/export_service.dart';
import 'package:signa/data/database_service.dart';
import 'package:signa/data/models.dart';

void main() {
  const patient = PatientProfile(
      name: 'Jane Doe',
      dob: '1990-01-01',
      email: 'j@x.com',
      clinician: 'Dr. Smith');
  final readings = <Map<String, Object?>>[
    {
      'date': '2026-06-22',
      'hrv_ms': 50,
      'sleep_min': 400,
      'sleep_score': 80,
      'steps': 6000,
      'score': 0.7,
      'source': 'fitbit'
    },
    {
      'date': '2026-06-23',
      'hrv_ms': 40,
      'sleep_min': 360,
      'sleep_score': 70,
      'steps': 5000,
      'score': 0.5,
      'source': 'fitbit'
    },
  ];
  final reports = [
    SelfReport(
        date: DateTime(2026, 6, 23),
        sleepRating: 4,
        moodRating: 3,
        notes: 'ok',
        createdAt: DateTime(2026, 6, 23, 8)),
  ];

  test('buildJson produces valid JSON with all sections', () {
    final s = DataExportService.buildJson(
      patient: patient,
      readings: readings,
      selfReports: reports,
      versionLabel: '1.0.0+3',
      exportedAt: DateTime.utc(2026, 6, 23, 12),
    );
    final m = jsonDecode(s) as Map<String, dynamic>;
    expect(m['meta']['schema_version'], 2);
    expect(m['meta']['version'], '1.0.0+3');
    expect(m['patient']['name'], 'Jane Doe');
    expect((m['self_reports'] as List).length, 1);
    expect((m['readings'] as List).length, 2);
    expect(m['summary']['reading_count'], 2);
    expect(m['summary']['avg_score'], 0.6);
    expect(m['summary']['date_range'], ['2026-06-22', '2026-06-23']);
  });

  test('buildJson handles empty data', () {
    final s = DataExportService.buildJson(
      patient: null,
      readings: const [],
      selfReports: const [],
      versionLabel: '1.0.0+3',
      exportedAt: DateTime.utc(2026, 1, 1),
    );
    final m = jsonDecode(s) as Map<String, dynamic>;
    expect(m['summary']['reading_count'], 0);
    expect(m['summary']['date_range'], isEmpty);
    expect(m['patient']['name'], '');
  });

  test('schema v2 preserves unavailable wearable values as null', () {
    final s = DataExportService.buildJson(
      patient: null,
      readings: const [
        {
          'date': '2026-06-24',
          'hrv_ms': null,
          'sleep_min': null,
          'steps': null,
          'score': null,
          'source': 'appleHealth',
        },
      ],
      selfReports: const [],
      versionLabel: '1.0.0+3',
      exportedAt: DateTime.utc(2026, 6, 24),
    );
    final reading = (jsonDecode(s)['readings'] as List).single;

    expect(reading['hrv_ms'], isNull);
    expect(reading['sleep_min'], isNull);
    expect(reading['steps'], isNull);
    expect(reading['score'], isNull);
  });

  test('buildCsv keeps the comment header and CSV body', () {
    final csv = DataExportService.buildCsv(
        patient: patient,
        readings: readings,
        exportedAt: DateTime.utc(2026, 6, 23, 12));
    expect(csv, contains('# Signa export'));
    expect(
        csv, contains('date,hrv_ms,sleep_min,sleep_score,steps,score,source'));
    expect(csv, contains('2026-06-22'));
  });

  test('lastExportSubtitle formats date + format', () {
    expect(DataExportService.lastExportSubtitle(null, null),
        'CSV/JSON · Never exported');
    expect(DataExportService.lastExportSubtitle(DateTime(2026, 6, 23), 'json'),
        'Last exported Jun 23, 2026 · JSON');
  });
}
