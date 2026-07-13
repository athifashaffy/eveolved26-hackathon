import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/daily_signal.dart';
import '../domain/timeline_marker.dart';
import '../domain/wellness_score.dart';

class ClinicianReportData {
  final String displayName;
  final DateTime from;
  final DateTime to;
  final List<DailySignal> signals;
  final List<WellnessScore> scores;
  final List<TimelineMarker> markers;

  const ClinicianReportData({
    required this.displayName,
    required this.from,
    required this.to,
    required this.signals,
    required this.scores,
    required this.markers,
  });
}

/// Builds a user-initiated clinical conversation aid. Signa does not upload or
/// automatically send the report. Free-text marker notes are intentionally
/// excluded; only the category the user selected is included.
class ClinicianReportService {
  ClinicianReportService._();

  static final DateFormat _date = DateFormat('MMM d, yyyy');

  static String buildPlainText(ClinicianReportData report) {
    final scored = report.scores.where((score) => score.score != null).toList();
    final latest = scored.isEmpty ? null : scored.last;
    final sources =
        report.signals.map((signal) => _source(signal.source)).toSet();
    final markerLines = report.markers
        .map((marker) =>
            '- ${_date.format(marker.date)}: ${_title(marker.category.name)}')
        .join('\n');

    return <String>[
      'Signa wellness summary',
      '${_date.format(report.from)} - ${_date.format(report.to)}',
      if (report.displayName.trim().isNotEmpty)
        'Prepared by: ${report.displayName.trim()}',
      '',
      'Overview',
      '${report.signals.length} days of wearable signals; '
          '${scored.length} days with a personal wellness score.',
      if (latest != null)
        'Latest score: ${latest.score}/100 | ${_title(latest.confidence.name)} confidence '
            '| ${latest.eligibleDays} eligible baseline days.',
      'Data source${sources.length == 1 ? '' : 's'}: '
          '${sources.isEmpty ? 'None' : sources.join(', ')}.',
      'Scoring provenance: '
          '${scored.map((score) => score.scoreVersion).toSet().join(', ')}.',
      '',
      'Context categories',
      if (markerLines.isEmpty)
        'No context categories recorded.'
      else
        markerLines,
      '',
      'Important: Signa is a personal wellness tool, not a diagnosis or medical '
          'device. This summary should support, not replace, clinical judgment.',
    ].join('\n');
  }

  static Future<Uint8List> buildPdf(ClinicianReportData report) async {
    final document = pw.Document(
      title: 'Signa wellness summary',
      author: report.displayName,
      creator: 'Signa',
    );
    final text = buildPlainText(report);

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(42),
        build: (_) => <pw.Widget>[
          pw.Text(
            'Signa',
            style: pw.TextStyle(
              fontSize: 28,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#285B52'),
            ),
          ),
          pw.SizedBox(height: 12),
          ...text.split('\n').map(
                (line) => line.isEmpty
                    ? pw.SizedBox(height: 9)
                    : pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Text(
                          line,
                          style: const pw.TextStyle(fontSize: 10.5),
                        ),
                      ),
              ),
        ],
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Generated on device | Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ),
      ),
    );
    return document.save();
  }

  static String _source(SignalSource source) => switch (source) {
        SignalSource.appleHealth => 'Apple Health',
        SignalSource.healthConnect => 'Health Connect',
        SignalSource.fitbit => 'Fitbit',
        SignalSource.demo => 'Demo data',
      };

  static String _title(String value) =>
      '${value[0].toUpperCase()}${value.substring(1)}';
}
