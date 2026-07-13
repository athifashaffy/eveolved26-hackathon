import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../domain/daily_signal.dart';
import '../domain/wellness_score.dart';
import 'models.dart';

class DailySignalRepository {
  final Database database;

  const DailySignalRepository(this.database);

  Future<void> upsertSignals(List<DailySignal> signals) async {
    final batch = database.batch();
    for (final signal in signals) {
      batch.insert(
        'daily_signals',
        signal.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<DailySignal>> getSignals({int days = 90}) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final rows = await database.query(
      'daily_signals',
      where: 'date >= ?',
      whereArgs: <Object?>[DailySignal.dateKey(cutoff)],
      orderBy: 'date ASC',
    );
    return rows.map(DailySignal.fromMap).toList();
  }

  Future<List<SelfReport>> getSelfReports() async {
    final rows = await database.query('self_reports', orderBy: 'date ASC');
    return rows.map(SelfReport.fromMap).toList();
  }

  Future<void> saveScore(WellnessScore score) async {
    final contributions = score.contributions.map(
      (component, value) => MapEntry(component.name, <String, Object?>{
        'score': value.score,
        'weight': value.weight,
        'explanation': value.explanation,
      }),
    );
    await database.insert(
      'wellness_scores',
      <String, Object?>{
        'date': DailySignal.dateKey(score.date),
        'score': score.score,
        'score_version': score.scoreVersion,
        'state': score.state.name,
        'confidence': score.confidence.name,
        'eligible_days': score.eligibleDays,
        'contributions_json': jsonEncode(contributions),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<WellnessScore?> getLatestScore() async {
    final rows = await database.query(
      'wellness_scores',
      orderBy: 'date DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _scoreFromRow(rows.single);
  }

  Future<List<WellnessScore>> getScores({int days = 90}) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final rows = await database.query(
      'wellness_scores',
      where: 'date >= ?',
      whereArgs: <Object?>[DailySignal.dateKey(cutoff)],
      orderBy: 'date ASC',
    );
    return rows.map(_scoreFromRow).toList();
  }

  WellnessScore _scoreFromRow(Map<String, Object?> row) {
    final rawContributions = jsonDecode(row['contributions_json']! as String)
        as Map<String, dynamic>;
    final contributions = rawContributions.map((name, rawValue) {
      final value = rawValue as Map<String, dynamic>;
      return MapEntry(
        ScoreComponent.values.byName(name),
        ComponentContribution(
          score: (value['score'] as num).toInt(),
          weight: (value['weight'] as num).toDouble(),
          explanation: value['explanation'] as String,
        ),
      );
    });
    return WellnessScore(
      date: DateTime.parse(row['date']! as String),
      score: (row['score'] as num?)?.toInt(),
      scoreVersion: row['score_version']! as String,
      state: BaselineState.values.byName(row['state']! as String),
      confidence: ScoreConfidence.values.byName(row['confidence']! as String),
      eligibleDays: (row['eligible_days'] as num).toInt(),
      contributions: contributions,
    );
  }
}
