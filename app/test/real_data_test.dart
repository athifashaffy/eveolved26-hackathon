import 'package:flutter_test/flutter_test.dart';
import 'package:signa/data/daily_signal_repository.dart';
import 'package:signa/data/database_service.dart';
import 'package:signa/data/health_data_source.dart';
import 'package:signa/data/real_data.dart';
import 'package:signa/domain/daily_signal.dart';
import 'package:signa/domain/wellness_score.dart';
import 'package:signa/scoring/baseline_engine.dart';
import 'package:signa/scoring/insight_engine.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  final now = DateTime(2026, 7, 13, 12);

  Future<DailySignalRepository> repository() async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    await DatabaseService.createSchema(db);
    return DailySignalRepository(db);
  }

  List<DailySignal> signals(int count) => List<DailySignal>.generate(
        count,
        (index) => DailySignal(
          date: now.subtract(Duration(days: count - index - 1)),
          source: SignalSource.healthConnect,
          hrvMs: 50 + (index % 3 - 1),
          sleepMinutes: 450 + (index % 3 - 1) * 3,
          steps: 7000 + (index % 3 - 1) * 100,
        ),
      );

  test('repository round-trips nullable signals and score provenance',
      () async {
    final repo = await repository();
    await repo.upsertSignals(<DailySignal>[
      DailySignal(
        date: now,
        source: SignalSource.healthConnect,
        sleepMinutes: 420,
      ),
    ]);
    final score = WellnessScore(
      date: now,
      score: 81,
      scoreVersion: 'wellness-v1',
      state: BaselineState.ready,
      confidence: ScoreConfidence.medium,
      eligibleDays: 14,
      contributions: const <ScoreComponent, ComponentContribution>{
        ScoreComponent.sleep: ComponentContribution(
          score: 81,
          weight: 1,
          explanation: 'Sleep stayed near your usual range.',
        ),
      },
    );
    await repo.saveScore(score);

    final storedSignals = await repo.getSignals();
    final storedScore = await repo.getLatestScore();

    expect(storedSignals.single.hrvMs, isNull);
    expect(storedSignals.single.sleepMinutes, 420);
    expect(storedScore!.scoreVersion, 'wellness-v1');
    expect(storedScore.contributions[ScoreComponent.sleep]!.score, 81);
  });

  test('controller computes and persists a baseline snapshot after sync',
      () async {
    final repo = await repository();
    final source = _FakeSource(
      HealthFetchResult(
        signals: signals(14),
        source: SignalSource.healthConnect,
        fetchedAt: now,
      ),
    );
    final controller = WellnessDataController(
      repository: repo,
      source: source,
      baselineEngine: BaselineEngine(),
      insightEngine: const InsightEngine(),
      clock: () => now,
    );

    final snapshot = await controller.forceSync();

    expect(snapshot.wellness.state, BaselineState.ready);
    expect(snapshot.wellness.score, isNotNull);
    expect(snapshot.signals, hasLength(14));
    expect((await repo.getLatestScore())!.score, snapshot.wellness.score);
  });

  test('failed sync preserves the last valid snapshot', () async {
    final repo = await repository();
    await repo.upsertSignals(signals(14));
    final source = _FakeSource(const HealthFetchResult.failure(
      SignalSource.healthConnect,
      HealthFetchFailure.offline,
    ));
    final controller = WellnessDataController(
      repository: repo,
      source: source,
      baselineEngine: BaselineEngine(),
      insightEngine: const InsightEngine(),
      clock: () => now,
    );
    final before = await controller.load(refreshIfStale: false);

    final after = await controller.forceSync();

    expect(after.wellness.score, before.wellness.score);
    expect(after.signals, hasLength(14));
    expect(after.syncIssue, HealthFetchFailure.offline.name);
  });
}

class _FakeSource implements HealthDataSource {
  final HealthFetchResult result;

  _FakeSource(this.result);

  @override
  Future<HealthFetchResult> fetch(DateTime start, DateTime end) async => result;
}
