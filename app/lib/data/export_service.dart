import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'database_service.dart'; // PatientProfile
import 'models.dart'; // SelfReport

/// Builds shareable CSV/JSON exports from patient data. Pure functions — data
/// is passed in, so this is unit-testable without a database.
class DataExportService {
  DataExportService._();

  static String buildCsv({
    required PatientProfile? patient,
    required List<Map<String, Object?>> readings,
    required DateTime exportedAt,
  }) {
    final buf = StringBuffer();
    buf.writeln('# Signa export');
    buf.writeln('# exported_at,${exportedAt.toIso8601String()}');
    buf.writeln('# patient_name,${_csvSafe(patient?.name)}');
    buf.writeln('# patient_dob,${_csvSafe(patient?.dob)}');
    buf.writeln('# patient_email,${_csvSafe(patient?.email)}');
    buf.writeln('# clinician,${_csvSafe(patient?.clinician)}');
    buf.writeln('# row_count,${readings.length}');
    const header = ['date', 'hrv_ms', 'sleep_min', 'sleep_score', 'steps', 'score', 'source'];
    final data = <List<dynamic>>[
      header,
      for (final r in readings)
        [
          r['date'] ?? '',
          r['hrv_ms'] ?? 0,
          r['sleep_min'] ?? 0,
          r['sleep_score'] ?? 0,
          r['steps'] ?? 0,
          (r['score'] as num?)?.toStringAsFixed(3) ?? '0.000',
          r['source'] ?? '',
        ],
    ];
    buf.write(const ListToCsvConverter().convert(data));
    return buf.toString();
  }

  static String buildJson({
    required PatientProfile? patient,
    required List<Map<String, Object?>> readings,
    required List<SelfReport> selfReports,
    required String versionLabel,
    required DateTime exportedAt,
  }) {
    final scores =
        readings.map((r) => (r['score'] as num?)?.toDouble() ?? 0.0).toList();
    final avg = scores.isEmpty ? 0.0 : scores.reduce((a, b) => a + b) / scores.length;
    final dates = readings
        .map((r) => r['date']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
    final map = {
      'meta': {
        'app': 'Signa',
        'version': versionLabel,
        'exported_at': exportedAt.toIso8601String(),
        'schema_version': 1,
      },
      'patient': {
        'name': patient?.name ?? '',
        'dob': patient?.dob ?? '',
        'email': patient?.email ?? '',
        'clinician': patient?.clinician ?? '',
      },
      'self_reports': [for (final s in selfReports) s.toJson()],
      'readings': [
        for (final r in readings)
          {
            'date': r['date'] ?? '',
            'hrv_ms': r['hrv_ms'] ?? 0,
            'sleep_min': r['sleep_min'] ?? 0,
            'sleep_score': r['sleep_score'] ?? 0,
            'steps': r['steps'] ?? 0,
            'score': (r['score'] as num?)?.toDouble() ?? 0.0,
            'source': r['source'] ?? '',
          },
      ],
      'summary': {
        'reading_count': readings.length,
        'date_range': dates.isEmpty ? <String>[] : [dates.first, dates.last],
        'avg_score': double.parse(avg.toStringAsFixed(3)),
      },
    };
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  /// Subtitle string for the "Share My Data" tile.
  static String lastExportSubtitle(DateTime? when, String? format) {
    if (when == null) return 'CSV/JSON · Never exported';
    final d = DateFormat('MMM d, yyyy').format(when);
    final f = (format ?? '').toUpperCase();
    return f.isEmpty ? 'Last exported $d' : 'Last exported $d · $f';
  }

  static String _csvSafe(String? v) {
    if (v == null || v.isEmpty) return '';
    return v.replaceAll(RegExp(r'[\r\n,]'), ' ').trim();
  }
}
