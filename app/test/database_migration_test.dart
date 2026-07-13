import 'package:flutter_test/flutter_test.dart';
import 'package:signa/data/database_service.dart';
import 'package:signa/domain/daily_signal.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('daily signal preserves missing values', () {
    final signal = DailySignal(
      date: DateTime(2026, 7, 1),
      source: SignalSource.healthConnect,
      sleepMinutes: 421,
    );

    expect(signal.hrvMs, isNull);
    expect(signal.steps, isNull);
    expect(signal.toMap()['hrv_ms'], isNull);
  });

  test('v2 migration preserves rows and turns legacy zeroes into nulls',
      () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    await db.execute('''
      CREATE TABLE readings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL UNIQUE,
        hrv_ms INTEGER NOT NULL DEFAULT 0,
        sleep_min INTEGER NOT NULL DEFAULT 0,
        sleep_score INTEGER NOT NULL DEFAULT 0,
        steps INTEGER NOT NULL DEFAULT 0,
        score REAL NOT NULL DEFAULT 0,
        source TEXT NOT NULL DEFAULT 'demo'
      )
    ''');
    await db.insert('readings', {
      'date': '2026-07-01',
      'hrv_ms': 0,
      'sleep_min': 421,
      'sleep_score': 88,
      'steps': 0,
      'score': .72,
      'source': 'appleHealth',
    });

    await DatabaseService.migrateSchema(db, 2, 3);

    final columns = await db.rawQuery('PRAGMA table_info(daily_signals)');
    expect(
      columns.map((column) => column['name']),
      containsAll(<String>[
        'date',
        'source',
        'hrv_ms',
        'sleep_minutes',
        'sleep_midpoint_minutes',
        'steps',
      ]),
    );
    final migrated = await db.query('daily_signals');
    expect(migrated, hasLength(1));
    expect(migrated.single['hrv_ms'], isNull);
    expect(migrated.single['sleep_minutes'], 421);
    expect(migrated.single['steps'], isNull);
  });

  test('delete all user data clears every user table', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    await DatabaseService.createSchema(db);
    await db.insert('patient', {
      'name': 'Test',
      'created_at': '2026-07-01T00:00:00.000',
    });
    await db.insert('daily_signals', {
      'date': '2026-07-01',
      'source': 'demo',
      'sleep_minutes': 421,
    });
    await db.insert('timeline_markers', {
      'id': 'marker-1',
      'date': '2026-07-01',
      'category': 'travel',
      'created_at': '2026-07-01T00:00:00.000',
    });

    await DatabaseService.deleteAllUserDataFrom(db);

    for (final table in <String>[
      'patient',
      'readings',
      'self_reports',
      'daily_signals',
      'wellness_scores',
      'timeline_markers',
    ]) {
      final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $table'),
      );
      expect(count, 0, reason: table);
    }
  });
}
