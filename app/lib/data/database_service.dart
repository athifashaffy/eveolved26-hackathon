import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'models.dart';

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
      version: 1,
      onCreate: (db, _) async {
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
      },
    );
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

  Future<List<StabilityReading>> getReadings({int days = 90}) async {
    final d = await db;
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final rows = await d.query(
      'readings',
      where: 'date >= ?',
      whereArgs: [_dateStr(cutoff)],
      orderBy: 'date ASC',
    );
    return rows.map(_rowToReading).toList();
  }

  Future<void> upsertReadings(List<StabilityReading> readings, String source) async {
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

  // ─── Helpers ──────────────────────────────────────────────────────────────

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
