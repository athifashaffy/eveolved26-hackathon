import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'models.dart';
import '../domain/timeline_marker.dart';

/// Single SQLite database for patient profile + synced readings.
class DatabaseService {
  DatabaseService._();
  static final instance = DatabaseService._();

  static Database? _db;

  Future<Database> get db async => _db ??= await _open();

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      join(dbPath, 'signa.db'),
      version: 3,
      onCreate: (db, _) => createSchema(db),
      onUpgrade: migrateSchema,
    );
  }

  static Future<void> createSchema(DatabaseExecutor db) async {
    await db.execute('''
          CREATE TABLE patient (
            id       INTEGER PRIMARY KEY AUTOINCREMENT,
            name     TEXT NOT NULL DEFAULT '',
            dob      TEXT,
            email    TEXT,
            clinician TEXT,
            created_at TEXT NOT NULL
          )
        ''');
    await db.execute('''
          CREATE TABLE readings (
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            date         TEXT NOT NULL UNIQUE,
            hrv_ms       INTEGER NOT NULL DEFAULT 0,
            sleep_min    INTEGER NOT NULL DEFAULT 0,
            sleep_score  INTEGER NOT NULL DEFAULT 0,
            steps        INTEGER NOT NULL DEFAULT 0,
            score        REAL NOT NULL DEFAULT 0,
            source       TEXT NOT NULL DEFAULT 'demo'
          )
        ''');
    await _createSelfReports(db);
    await _createWellnessTables(db);
  }

  static Future<void> migrateSchema(
    DatabaseExecutor db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) await _createSelfReports(db);
    if (oldVersion < 3) {
      await _createWellnessTables(db);
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='readings'",
      );
      if (tables.isNotEmpty) {
        await db.execute('''
          INSERT OR REPLACE INTO daily_signals (
            date, source, hrv_ms, sleep_minutes, sleep_midpoint_minutes, steps
          )
          SELECT
            date,
            CASE source
              WHEN 'healthkit' THEN 'appleHealth'
              WHEN 'apple_health' THEN 'appleHealth'
              WHEN 'health_connect' THEN 'healthConnect'
              ELSE source
            END,
            NULLIF(hrv_ms, 0),
            NULLIF(sleep_min, 0),
            NULL,
            NULLIF(steps, 0)
          FROM readings
        ''');
      }
    }
  }

  // ─── Patient ──────────────────────────────────────────────────────────────

  Future<PatientProfile?> getPatient() async {
    final d = await db;
    final rows = await d.query('patient', limit: 1);
    if (rows.isEmpty) return null;
    return PatientProfile.fromMap(rows.first);
  }

  Future<void> savePatient(PatientProfile p) async {
    final d = await db;
    final existing = await d.query('patient', limit: 1);
    if (existing.isEmpty) {
      await d.insert('patient', p.toMap());
    } else {
      await d.update('patient', p.toMap(),
          where: 'id = ?', whereArgs: [existing.first['id']]);
    }
  }

  // ─── Readings ─────────────────────────────────────────────────────────────

  Future<List<StabilityReading>> getReadings({
    int days = 90,
    List<String>? sources,
  }) async {
    final d = await db;
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final clauses = <String>['date >= ?'];
    final args = <Object?>[_dateStr(cutoff)];
    if (sources != null && sources.isNotEmpty) {
      final placeholders = List.filled(sources.length, '?').join(', ');
      clauses.add('source IN ($placeholders)');
      args.addAll(sources);
    }
    final rows = await d.query(
      'readings',
      where: clauses.join(' AND '),
      whereArgs: args,
      orderBy: 'date ASC',
    );
    return rows.map(_rowToReading).toList();
  }

  /// Raw rows for every reading in the DB (no day cap), ordered by date ASC.
  /// Used by the CSV exporter so it can include the `source` column too.
  Future<List<Map<String, Object?>>> getAllReadingsRaw() async {
    final d = await db;
    return d.query('readings', orderBy: 'date ASC');
  }

  Future<void> upsertReadings(
      List<StabilityReading> readings, String source) async {
    final d = await db;
    final batch = d.batch();
    for (final r in readings) {
      batch.insert(
        'readings',
        {
          'date': _dateStr(r.date),
          'hrv_ms': r.hrvMs,
          'sleep_min': r.sleepMinutes,
          'sleep_score': r.sleepScore,
          'steps': r.steps,
          'score': r.score,
          'source': source,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> clearReadings() async {
    final d = await db;
    await d.delete('readings');
  }

  Future<void> deleteAllUserData() async {
    final database = await db;
    await deleteAllUserDataFrom(database);
  }

  static Future<void> deleteAllUserDataFrom(Database db) async {
    await db.transaction((transaction) async {
      for (final table in <String>[
        'patient',
        'readings',
        'self_reports',
        'daily_signals',
        'wellness_scores',
        'timeline_markers',
      ]) {
        await transaction.delete(table);
      }
    });
  }

  // ─── Self-reports ─────────────────────────────────────────────────────────

  Future<void> upsertSelfReport(SelfReport r) async {
    final d = await db;
    await d.insert('self_reports', r.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<SelfReport>> getAllSelfReports() async {
    final d = await db;
    final rows = await d.query('self_reports', orderBy: 'date ASC');
    return rows.map(SelfReport.fromMap).toList();
  }

  Future<SelfReport?> getSelfReportForDate(DateTime date) async {
    final d = await db;
    final rows = await d.query('self_reports',
        where: 'date = ?', whereArgs: [SelfReport.dateKey(date)], limit: 1);
    if (rows.isEmpty) return null;
    return SelfReport.fromMap(rows.first);
  }

  Future<void> upsertTimelineMarker(TimelineMarker marker) async {
    await upsertTimelineMarkerIn(await db, marker);
  }

  Future<List<TimelineMarker>> getTimelineMarkers(
    DateTime start,
    DateTime end,
  ) =>
      getTimelineMarkersFromDatabase(db, start, end);

  static Future<void> upsertTimelineMarkerIn(
    Database db,
    TimelineMarker marker,
  ) async {
    await db.insert(
      'timeline_markers',
      marker.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<TimelineMarker>> getTimelineMarkersFrom(
    Database db,
    DateTime start,
    DateTime end,
  ) async {
    final rows = await db.query(
      'timeline_markers',
      where: 'date >= ? AND date <= ?',
      whereArgs: <Object?>[_dateStr(start), _dateStr(end)],
      orderBy: 'date ASC',
    );
    return rows.map(TimelineMarker.fromMap).toList();
  }

  static Future<List<TimelineMarker>> getTimelineMarkersFromDatabase(
    Future<Database> database,
    DateTime start,
    DateTime end,
  ) async =>
      getTimelineMarkersFrom(await database, start, end);

  // ─── Helpers ──────────────────────────────────────────────────────────────

  static Future<void> _createSelfReports(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS self_reports (
        date         TEXT PRIMARY KEY,
        sleep_rating INTEGER NOT NULL,
        mood_rating  INTEGER NOT NULL,
        notes        TEXT,
        created_at   TEXT NOT NULL
      )
    ''');
  }

  static Future<void> _createWellnessTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS daily_signals (
        date TEXT NOT NULL,
        source TEXT NOT NULL,
        hrv_ms REAL,
        sleep_minutes INTEGER,
        sleep_midpoint_minutes INTEGER,
        steps INTEGER,
        PRIMARY KEY (date, source)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS wellness_scores (
        date TEXT PRIMARY KEY,
        score INTEGER,
        score_version TEXT NOT NULL,
        state TEXT NOT NULL,
        confidence TEXT NOT NULL,
        eligible_days INTEGER NOT NULL,
        contributions_json TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS timeline_markers (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        category TEXT NOT NULL,
        note TEXT,
        created_at TEXT NOT NULL
      )
    ''');
  }

  static StabilityReading _rowToReading(Map<String, dynamic> row) =>
      StabilityReading(
        date: DateTime.parse(row['date'] as String),
        score: (row['score'] as num).toDouble(),
        hrvMs: row['hrv_ms'] as int,
        sleepMinutes: row['sleep_min'] as int,
        sleepScore: row['sleep_score'] as int,
        steps: row['steps'] as int,
      );

  static String _dateStr(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

// ─── Patient profile model ─────────────────────────────────────────────────

class PatientProfile {
  final String name;
  final String? dob;
  final String? email;
  final String? clinician;

  const PatientProfile({
    required this.name,
    this.dob,
    this.email,
    this.clinician,
  });

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  factory PatientProfile.fromMap(Map<String, dynamic> m) => PatientProfile(
        name: m['name'] as String? ?? '',
        dob: m['dob'] as String?,
        email: m['email'] as String?,
        clinician: m['clinician'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'dob': dob,
        'email': email,
        'clinician': clinician,
        'created_at': DateTime.now().toIso8601String(),
      };

  PatientProfile copyWith({
    String? name,
    String? dob,
    String? email,
    String? clinician,
  }) =>
      PatientProfile(
        name: name ?? this.name,
        dob: dob ?? this.dob,
        email: email ?? this.email,
        clinician: clinician ?? this.clinician,
      );
}
