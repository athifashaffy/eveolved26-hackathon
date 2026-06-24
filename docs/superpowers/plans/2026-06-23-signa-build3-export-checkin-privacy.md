# Signa Build 3 — Export, Daily Check-in, Privacy & Branding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship Signa build 3 with a branded launcher icon, a JSON export (alongside CSV) bundling a daily self-report, last-export tracking, and an in-app privacy policy.

**Architecture:** Flutter app in `app/`. New pure-Dart `DataExportService` builds CSV/JSON strings from data passed in (unit-testable, no DB coupling). A new `self_reports` SQLite table (migrated via `onUpgrade`) stores daily check-ins. `AppSettings` (SharedPreferences) tracks the last export. The Profile screen wires the new check-in dialog, format toggle, last-export subtitle, and privacy route.

**Tech Stack:** Flutter, Dart, sqflite, shared_preferences, share_plus, path_provider, csv, intl, flutter_launcher_icons.

## Global Constraints

- App version MUST be `1.0.0+3` in `app/pubspec.yaml` (TestFlight build 2 is live; next build is 3).
- In-app version label MUST read `v1.0.0 (3)` via the constant `kAppVersionLabel`.
- JSON export `schema_version` MUST be `1`.
- iOS launcher icons MUST be fully opaque (cream `#FBF7EC` fill, `remove_alpha_ios: true`) — App Store/TestFlight rejects transparency.
- All processing stays on-device; export is user-initiated only. No network calls added.
- SQLite changes MUST use `onUpgrade` so existing build-2 testers keep their patient/readings data.
- Logo source file: `/Users/athifshaffy/Downloads/Signa Logo.png`.
- Package import prefix is `package:signa/...`.
- Run all commands from `app/` unless noted.

---

### Task 1: App icon + version bump + app-info constants

**Files:**
- Create: `app/lib/app_info.dart`
- Create: `app/assets/icon/signa_icon.png` (copied logo)
- Modify: `app/pubspec.yaml` (version, dev dep, launcher-icons config)
- Modify: `app/lib/screens/profile_screen.dart` (About tile subtitle)

**Interfaces:**
- Produces: `const String kAppVersion = '1.0.0+3';` and `const String kAppVersionLabel = 'v1.0.0 (3)';` (consumed by Tasks 5 & 7 and the About tile).

- [ ] **Step 1: Create the app-info constants file**

`app/lib/app_info.dart`:
```dart
/// Single source of truth for the app's version strings.
/// Keep in sync with `version:` in pubspec.yaml.
const String kAppVersion = '1.0.0+3';
const String kAppVersionLabel = 'v1.0.0 (3)';
```

- [ ] **Step 2: Copy the logo into the asset folder**

Run:
```bash
mkdir -p app/assets/icon
cp "/Users/athifshaffy/Downloads/Signa Logo.png" app/assets/icon/signa_icon.png
ls -la app/assets/icon/signa_icon.png
```
Expected: the file exists and is non-zero size.

- [ ] **Step 3: Bump version and add the launcher-icons dev dependency + config**

In `app/pubspec.yaml`, change the version line:
```yaml
version: 1.0.0+3
```
Under `dev_dependencies:` add:
```yaml
  flutter_launcher_icons: ^0.13.1
```
At the end of the file (top-level, not nested under `flutter:`) add:
```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/icon/signa_icon.png"
  remove_alpha_ios: true
  background_color_ios: "#FBF7EC"
  adaptive_icon_background: "#FBF7EC"
  adaptive_icon_foreground: "assets/icon/signa_icon.png"
```

- [ ] **Step 4: Fetch deps and generate the icons**

Run:
```bash
cd app && flutter pub get && dart run flutter_launcher_icons
```
Expected: output ends with `✓ Successfully generated launcher icons` (or similar). iOS `ios/Runner/Assets.xcassets/AppIcon.appiconset/` and Android `android/app/src/main/res/mipmap-*/ic_launcher.png` are overwritten with the Signa logo.

- [ ] **Step 5: Update the Profile "About Signa" tile to use the constant**

In `app/lib/screens/profile_screen.dart`, add the import near the other imports:
```dart
import '../app_info.dart';
```
Replace the About tile subtitle:
```dart
                  _SettingTile(
                    icon: Icons.info_outline,
                    title: 'About Signa',
                    subtitle: 'v1.0.0 · Evolved26 Hackathon',
                    onTap: () {},
                  ),
```
with:
```dart
                  _SettingTile(
                    icon: Icons.info_outline,
                    title: 'About Signa',
                    subtitle: '$kAppVersionLabel · Evolved26 Hackathon',
                    onTap: () {},
                  ),
```

- [ ] **Step 6: Analyze**

Run: `cd app && flutter analyze`
Expected: `No issues found!` (warnings pre-existing in other files are acceptable; no new errors in touched files).

- [ ] **Step 7: Commit**

```bash
git add app/pubspec.yaml app/lib/app_info.dart app/lib/screens/profile_screen.dart app/assets/icon app/ios app/android
git commit -m "feat(app): Signa launcher icon + version 1.0.0+3"
```

---

### Task 2: SelfReport model

**Files:**
- Modify: `app/lib/data/models.dart`
- Test: `app/test/self_report_test.dart`

**Interfaces:**
- Produces: `SelfReport` with fields `DateTime date`, `int sleepRating`, `int moodRating`, `String? notes`, `DateTime createdAt`; static `SelfReport.dateKey(DateTime) -> String`; `toMap() -> Map<String,Object?>`; `factory SelfReport.fromMap(Map<String,Object?>)`; `toJson() -> Map<String,Object?>` (omits `created_at`, never-null `notes`). Consumed by Tasks 3, 5, 6.

- [ ] **Step 1: Write the failing test**

`app/test/self_report_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:signa/data/models.dart';

void main() {
  test('SelfReport round-trips through toMap/fromMap', () {
    final r = SelfReport(
      date: DateTime(2026, 6, 23),
      sleepRating: 4,
      moodRating: 3,
      notes: 'slept ok',
      createdAt: DateTime(2026, 6, 23, 8, 30),
    );
    final back = SelfReport.fromMap(r.toMap());
    expect(back.sleepRating, 4);
    expect(back.moodRating, 3);
    expect(back.notes, 'slept ok');
    expect(SelfReport.dateKey(back.date), '2026-06-23');
  });

  test('SelfReport.toJson omits created_at and never returns null notes', () {
    final r = SelfReport(
      date: DateTime(2026, 1, 5),
      sleepRating: 1,
      moodRating: 2,
      notes: null,
      createdAt: DateTime(2026, 1, 5),
    );
    final j = r.toJson();
    expect(j['date'], '2026-01-05');
    expect(j['notes'], '');
    expect(j.containsKey('created_at'), false);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/self_report_test.dart`
Expected: FAIL — `SelfReport` is undefined.

- [ ] **Step 3: Add the SelfReport model**

Append to `app/lib/data/models.dart`:
```dart
/// A patient-entered daily self-report (sleep + mood), bundled into exports.
class SelfReport {
  final DateTime date; // the day this report is for (date-only)
  final int sleepRating; // 1..5 (Very poor .. Very good)
  final int moodRating; // 1..5
  final String? notes;
  final DateTime createdAt;

  const SelfReport({
    required this.date,
    required this.sleepRating,
    required this.moodRating,
    this.notes,
    required this.createdAt,
  });

  static String dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, Object?> toMap() => {
        'date': dateKey(date),
        'sleep_rating': sleepRating,
        'mood_rating': moodRating,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
      };

  factory SelfReport.fromMap(Map<String, Object?> m) => SelfReport(
        date: DateTime.parse(m['date'] as String),
        sleepRating: (m['sleep_rating'] as num).toInt(),
        moodRating: (m['mood_rating'] as num).toInt(),
        notes: m['notes'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  /// Export-facing shape: stable keys, no internal timestamp, notes never null.
  Map<String, Object?> toJson() => {
        'date': dateKey(date),
        'sleep_rating': sleepRating,
        'mood_rating': moodRating,
        'notes': notes ?? '',
      };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/self_report_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add app/lib/data/models.dart app/test/self_report_test.dart
git commit -m "feat(app): SelfReport model for daily check-ins"
```

---

### Task 3: self_reports table + CRUD + migration

**Files:**
- Modify: `app/lib/data/database_service.dart`

**Interfaces:**
- Consumes: `SelfReport` (Task 2).
- Produces: `DatabaseService.instance.upsertSelfReport(SelfReport) -> Future<void>`, `getAllSelfReports() -> Future<List<SelfReport>>`, `getSelfReportForDate(DateTime) -> Future<SelfReport?>`. Consumed by Tasks 6 & 7.

> Note: this project has no sqflite test harness (only `flutter_test`), matching its single boot smoke test. CRUD here is verified by `flutter analyze` + the manual run in Task 9, not a unit test.

- [ ] **Step 1: Bump schema version and add migration**

In `app/lib/data/database_service.dart`, change `version: 1,` to `version: 2,` and update `_open()` so both `onCreate` and a new `onUpgrade` create the table. Replace the `onCreate` closing and add `onUpgrade`:
```dart
      version: 2,
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
        await _createSelfReports(db);
      },
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 2) {
          await _createSelfReports(db);
        }
      },
```

- [ ] **Step 2: Add the table-creation helper and CRUD methods**

In `app/lib/data/database_service.dart`, add the helper just above the `_rowToReading` helper (inside the `DatabaseService` class):
```dart
  static Future<void> _createSelfReports(Database db) async {
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
```
And add the CRUD methods after `clearReadings()`:
```dart
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
```

- [ ] **Step 3: Analyze**

Run: `cd app && flutter analyze lib/data/database_service.dart`
Expected: no new errors. (`SelfReport`, `ConflictAlgorithm`, `Database` are already importable — `models.dart` and `sqflite` are imported at the top.)

- [ ] **Step 4: Commit**

```bash
git add app/lib/data/database_service.dart
git commit -m "feat(app): self_reports table, CRUD, and v2 migration"
```

---

### Task 4: AppSettings last-export persistence

**Files:**
- Modify: `app/lib/data/app_settings.dart`

**Interfaces:**
- Produces: `AppSettings.instance.lastExportAt -> DateTime?`, `lastExportFormat -> String?`, `setLastExport(DateTime when, String format) -> Future<void>`. Consumed by Task 7.

- [ ] **Step 1: Add keys and backing fields**

In `app/lib/data/app_settings.dart`, after the `_kAppleHealthGranted` const add:
```dart
  static const _kLastExportAt = 'last_export_at';
  static const _kLastExportFormat = 'last_export_format';
```
After `bool _appleHealthGranted = false;` add:
```dart
  DateTime? _lastExportAt;
  String? _lastExportFormat;
```

- [ ] **Step 2: Add getters**

After the `appleHealthGranted` getter add:
```dart
  /// When the user last shared an export, and which format ('csv' / 'json').
  DateTime? get lastExportAt => _lastExportAt;
  String? get lastExportFormat => _lastExportFormat;
```

- [ ] **Step 3: Load them in `load()`**

Inside `load()`, after the `_appleHealthGranted = ...` line add:
```dart
    final ts = prefs.getString(_kLastExportAt);
    _lastExportAt = ts != null ? DateTime.tryParse(ts) : null;
    _lastExportFormat = prefs.getString(_kLastExportFormat);
```

- [ ] **Step 4: Add the setter**

After `setAppleHealthGranted(...)` add:
```dart
  Future<void> setLastExport(DateTime when, String format) async {
    _lastExportAt = when;
    _lastExportFormat = format;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastExportAt, when.toIso8601String());
    await prefs.setString(_kLastExportFormat, format);
  }
```

- [ ] **Step 5: Analyze**

Run: `cd app && flutter analyze lib/data/app_settings.dart`
Expected: no new errors.

- [ ] **Step 6: Commit**

```bash
git add app/lib/data/app_settings.dart
git commit -m "feat(app): persist last-export timestamp and format"
```

---

### Task 5: DataExportService (CSV + JSON builders)

**Files:**
- Create: `app/lib/data/export_service.dart`
- Test: `app/test/export_service_test.dart`

**Interfaces:**
- Consumes: `PatientProfile` (from `database_service.dart`), `SelfReport` (Task 2), `kAppVersion` (Task 1).
- Produces (all static on `DataExportService`):
  - `buildCsv({required PatientProfile? patient, required List<Map<String,Object?>> readings, required DateTime exportedAt}) -> String`
  - `buildJson({required PatientProfile? patient, required List<Map<String,Object?>> readings, required List<SelfReport> selfReports, required String versionLabel, required DateTime exportedAt}) -> String`
  - `lastExportSubtitle(DateTime? when, String? format) -> String`
  Consumed by Task 7.

- [ ] **Step 1: Write the failing test**

`app/test/export_service_test.dart`:
```dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:signa/data/export_service.dart';
import 'package:signa/data/database_service.dart';
import 'package:signa/data/models.dart';

void main() {
  final patient = const PatientProfile(
      name: 'Jane Doe', dob: '1990-01-01', email: 'j@x.com', clinician: 'Dr. Smith');
  final readings = <Map<String, Object?>>[
    {'date': '2026-06-22', 'hrv_ms': 50, 'sleep_min': 400, 'sleep_score': 80, 'steps': 6000, 'score': 0.7, 'source': 'fitbit'},
    {'date': '2026-06-23', 'hrv_ms': 40, 'sleep_min': 360, 'sleep_score': 70, 'steps': 5000, 'score': 0.5, 'source': 'fitbit'},
  ];
  final reports = [
    SelfReport(date: DateTime(2026, 6, 23), sleepRating: 4, moodRating: 3, notes: 'ok', createdAt: DateTime(2026, 6, 23, 8)),
  ];

  test('buildJson produces valid JSON with all sections', () {
    final s = DataExportService.buildJson(
      patient: patient, readings: readings, selfReports: reports,
      versionLabel: '1.0.0+3', exportedAt: DateTime.utc(2026, 6, 23, 12),
    );
    final m = jsonDecode(s) as Map<String, dynamic>;
    expect(m['meta']['schema_version'], 1);
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
      patient: null, readings: const [], selfReports: const [],
      versionLabel: '1.0.0+3', exportedAt: DateTime.utc(2026, 1, 1),
    );
    final m = jsonDecode(s) as Map<String, dynamic>;
    expect(m['summary']['reading_count'], 0);
    expect(m['summary']['date_range'], isEmpty);
    expect(m['patient']['name'], '');
  });

  test('buildCsv keeps the comment header and CSV body', () {
    final csv = DataExportService.buildCsv(
        patient: patient, readings: readings, exportedAt: DateTime.utc(2026, 6, 23, 12));
    expect(csv, contains('# Signa export'));
    expect(csv, contains('date,hrv_ms,sleep_min,sleep_score,steps,score,source'));
    expect(csv, contains('2026-06-22'));
  });

  test('lastExportSubtitle formats date + format', () {
    expect(DataExportService.lastExportSubtitle(null, null), 'CSV/JSON · Never exported');
    expect(DataExportService.lastExportSubtitle(DateTime(2026, 6, 23), 'json'),
        'Last exported Jun 23, 2026 · JSON');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/export_service_test.dart`
Expected: FAIL — `DataExportService` is undefined.

- [ ] **Step 3: Implement the service**

`app/lib/data/export_service.dart`:
```dart
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/export_service_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add app/lib/data/export_service.dart app/test/export_service_test.dart
git commit -m "feat(app): DataExportService with CSV + JSON builders"
```

---

### Task 6: Daily Check-in dialog + Profile tile

**Files:**
- Modify: `app/lib/screens/profile_screen.dart`

**Interfaces:**
- Consumes: `DatabaseService.upsertSelfReport`, `getSelfReportForDate` (Task 3); `SelfReport` (Task 2).
- Produces: a `Daily Check-in` tile and `_DailyCheckInDialog` returning a `SelfReport`. The `_todayChecked` state field is reused by the tile subtitle.

> Verified by `flutter analyze` + manual run (Task 9).

- [ ] **Step 1: Add imports and the `_todayChecked` state field**

In `app/lib/screens/profile_screen.dart`, add to the imports (if not already present from Task 1):
```dart
import '../data/models.dart';
```
In `_ProfileScreenState`, after `bool _loading = true;` add:
```dart
  bool _todayChecked = false;
```

- [ ] **Step 2: Load today's check-in state in `_load()`**

Replace the body of `_load()` with:
```dart
  Future<void> _load() async {
    final p = await DatabaseService.instance.getPatient();
    final todayReport =
        await DatabaseService.instance.getSelfReportForDate(DateTime.now());
    if (!mounted) return;
    setState(() {
      _patient = p;
      _todayChecked = todayReport != null;
      _loading = false;
    });
    // First launch — prompt to set up profile
    if (p == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _editProfile());
    }
  }
```

- [ ] **Step 3: Add the `_openCheckIn` method**

In `_ProfileScreenState`, after `_syncNow()` add:
```dart
  Future<void> _openCheckIn() async {
    final result = await showDialog<SelfReport>(
      context: context,
      builder: (_) => const _DailyCheckInDialog(),
    );
    if (result != null) {
      await DatabaseService.instance.upsertSelfReport(result);
      if (!mounted) return;
      setState(() => _todayChecked = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check-in saved')),
      );
    }
  }
```

- [ ] **Step 4: Replace the stub "PHQ-9 Log" tile with the Daily Check-in tile**

In the CLINICAL section, replace:
```dart
                  _SettingTile(
                    icon: Icons.assignment_outlined,
                    title: 'PHQ-9 Log',
                    subtitle: 'Optional weekly questionnaire',
                    onTap: () {},
                  ),
```
with:
```dart
                  _SettingTile(
                    icon: Icons.assignment_outlined,
                    title: 'Daily Check-in',
                    subtitle: _todayChecked ? 'Logged today' : 'Not logged yet',
                    onTap: _openCheckIn,
                  ),
```

- [ ] **Step 5: Add the `_DailyCheckInDialog` widget**

At the end of `app/lib/screens/profile_screen.dart` (after the existing widget classes), add:
```dart
// ─── Daily check-in dialog ──────────────────────────────────────────────────

class _DailyCheckInDialog extends StatefulWidget {
  const _DailyCheckInDialog();

  @override
  State<_DailyCheckInDialog> createState() => _DailyCheckInDialogState();
}

class _DailyCheckInDialogState extends State<_DailyCheckInDialog> {
  int _sleep = 3;
  int _mood = 3;
  final _notes = TextEditingController();

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Daily Check-in',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RatingRow(
              label: 'How did you sleep last night?',
              value: _sleep,
              onChanged: (v) => setState(() => _sleep = v),
            ),
            const SizedBox(height: 16),
            _RatingRow(
              label: 'Mood today?',
              value: _mood,
              onChanged: (v) => setState(() => _mood = v),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notes,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Notes (optional)',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final now = DateTime.now();
            Navigator.pop(
              context,
              SelfReport(
                date: DateTime(now.year, now.month, now.day),
                sleepRating: _sleep,
                moodRating: _mood,
                notes: _notes.text.trim().isNotEmpty ? _notes.text.trim() : null,
                createdAt: now,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _RatingRow extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  const _RatingRow(
      {required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 1; i <= 5; i++)
              GestureDetector(
                onTap: () => onChanged(i),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: i == value
                        ? AppColors.primaryContainer
                        : AppColors.primaryContainer.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text('$i',
                        style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: i == value
                                ? Colors.white
                                : AppColors.primaryContainer)),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Very poor',
                style: GoogleFonts.inter(fontSize: 10, color: AppColors.outline)),
            Text('Very good',
                style: GoogleFonts.inter(fontSize: 10, color: AppColors.outline)),
          ],
        ),
      ],
    );
  }
}
```

- [ ] **Step 6: Analyze**

Run: `cd app && flutter analyze lib/screens/profile_screen.dart`
Expected: no new errors.

- [ ] **Step 7: Commit**

```bash
git add app/lib/screens/profile_screen.dart
git commit -m "feat(app): daily check-in dialog and profile tile"
```

---

### Task 7: JSON/CSV export toggle + last-export wiring

**Files:**
- Modify: `app/lib/screens/profile_screen.dart`

**Interfaces:**
- Consumes: `DataExportService` (Task 5), `AppSettings.setLastExport` / `lastExportAt` / `lastExportFormat` (Task 4), `DatabaseService.getAllSelfReports` (Task 3), `kAppVersion` (Task 1).

> Verified by `flutter analyze` + manual run (Task 9).

- [ ] **Step 1: Fix imports**

In `app/lib/screens/profile_screen.dart`, add:
```dart
import '../data/export_service.dart';
```
Remove the now-unused direct CSV import (the converter lives in the service now):
```dart
import 'package:csv/csv.dart';
```
Keep `dart:io`, `path_provider`, and `share_plus` imports — still used for file writing/sharing.

- [ ] **Step 2: Update the "Share My Data" tile subtitle**

In the DEVICES & DATA section, replace:
```dart
                  _SettingTile(
                    icon: Icons.file_download_outlined,
                    title: 'Share My Data',
                    subtitle: 'CSV · Share to any app',
                    onTap: _exportData,
                  ),
```
with:
```dart
                  _SettingTile(
                    icon: Icons.file_download_outlined,
                    title: 'Share My Data',
                    subtitle: DataExportService.lastExportSubtitle(
                      AppSettings.instance.lastExportAt,
                      AppSettings.instance.lastExportFormat,
                    ),
                    onTap: _exportData,
                  ),
```

- [ ] **Step 3: Replace `_exportData` and delete the old `_csvSafe`**

Replace the entire `_exportData()` method and remove the `_csvSafe(...)` method below it with:
```dart
  Future<void> _exportData() async {
    try {
      final rows = await DatabaseService.instance.getAllReadingsRaw();
      final patient = await DatabaseService.instance.getPatient();
      final reports = await DatabaseService.instance.getAllSelfReports();
      final now = DateTime.now();

      String contentFor(String f) => f == 'json'
          ? DataExportService.buildJson(
              patient: patient,
              readings: rows,
              selfReports: reports,
              versionLabel: kAppVersion,
              exportedAt: now,
            )
          : DataExportService.buildCsv(
              patient: patient,
              readings: rows,
              exportedAt: now,
            );

      var fmt = 'json';

      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => StatefulBuilder(
          builder: (dialogCtx, setLocal) {
            final content = contentFor(fmt);
            return AlertDialog(
              title: Text('Share My Data',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'json', label: Text('JSON')),
                          ButtonSegment(value: 'csv', label: Text('CSV')),
                        ],
                        selected: {fmt},
                        onSelectionChanged: (s) => setLocal(() => fmt = s.first),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${rows.length} reading${rows.length == 1 ? '' : 's'} · '
                        '${reports.length} check-in${reports.length == 1 ? '' : 's'}',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppColors.onSurfaceVariant),
                      ),
                      const SizedBox(height: 12),
                      SelectableText(content,
                          style: GoogleFonts.robotoMono(fontSize: 11)),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Close'),
                ),
                Builder(builder: (btnContext) {
                  return FilledButton.icon(
                    icon: const Icon(Icons.ios_share, size: 18),
                    label: const Text('Share'),
                    onPressed: () async {
                      final ext = fmt == 'json' ? 'json' : 'csv';
                      final mime =
                          fmt == 'json' ? 'application/json' : 'text/csv';
                      final dir = await getTemporaryDirectory();
                      final stamp = now
                          .toIso8601String()
                          .replaceAll(':', '-')
                          .substring(0, 19);
                      final file =
                          File('${dir.path}/signa_export_$stamp.$ext');
                      await file.writeAsString(content);

                      final box =
                          btnContext.findRenderObject() as RenderBox?;
                      final origin = box != null && box.hasSize
                          ? box.localToGlobal(Offset.zero) & box.size
                          : const Rect.fromLTWH(0, 0, 1, 1);
                      await Share.shareXFiles(
                        [XFile(file.path, mimeType: mime)],
                        subject: 'Signa data export',
                        text:
                            'Signa stability data — ${rows.length} reading${rows.length == 1 ? '' : 's'}',
                        sharePositionOrigin: origin,
                      );

                      await AppSettings.instance.setLastExport(now, fmt);
                      if (mounted) setState(() {});
                    },
                  );
                }),
              ],
            );
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }
```

- [ ] **Step 4: Analyze**

Run: `cd app && flutter analyze lib/screens/profile_screen.dart`
Expected: no new errors and no "unused import" warning for `csv`.

- [ ] **Step 5: Commit**

```bash
git add app/lib/screens/profile_screen.dart
git commit -m "feat(app): JSON/CSV export toggle + last-export tracking"
```

---

### Task 8: Privacy Policy screen + route

**Files:**
- Create: `app/lib/screens/privacy_policy_screen.dart`
- Modify: `app/lib/main.dart`
- Modify: `app/lib/screens/profile_screen.dart` (wire the Privacy tile)

**Interfaces:**
- Produces: `PrivacyPolicyScreen` at route `/privacy`.

> Verified by `flutter analyze` + manual run (Task 9).

- [ ] **Step 1: Create the screen**

`app/lib/screens/privacy_policy_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../widgets/signa_scaffold.dart';
import '../widgets/top_app_bar.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SignaScaffold(
      currentRoute: '/profile',
      child: Column(
        children: [
          const SignaAppBar(title: 'Privacy Policy'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
              children: const [
                _Updated('Last updated: June 23, 2026'),
                _Para(
                  'Signa is designed privacy-first. Your health data is '
                  'processed and stored only on this device. We do not run a '
                  'server and we never upload your data anywhere automatically.',
                ),
                _Heading('On-device only'),
                _Para(
                  'All analysis — including your Stability Score — is computed '
                  'locally on your phone. Nothing leaves the device unless you '
                  'choose to export and share it.',
                ),
                _Heading('What we store'),
                _Para(
                  'Heart rate variability (HRV), sleep, steps, your computed '
                  'stability scores, your daily check-ins (sleep and mood '
                  'self-reports), and the profile details you enter (name, date '
                  'of birth, email, linked clinician).',
                ),
                _Heading('Where data comes from'),
                _Para(
                  'Data is read from Apple Health or Fitbit only after you '
                  'explicitly authorize access. You can revoke access at any '
                  'time in your device or Fitbit account settings.',
                ),
                _Heading('Sharing your data'),
                _Para(
                  'Exports (CSV or JSON) are created only when you tap "Share My '
                  'Data". You choose who receives the file — for example, you '
                  'can show or send it to your physician. Once shared, the '
                  'recipient controls that copy.',
                ),
                _Heading('Deleting your data'),
                _Para(
                  'Uninstalling Signa removes all locally stored data from this '
                  'device, including readings, check-ins, and your profile.',
                ),
                _Heading('Not a medical device'),
                _Para(
                  'Signa is for informational and self-monitoring purposes only. '
                  'It does not diagnose, treat, or prevent any condition. Always '
                  'consult a qualified clinician about your health.',
                ),
                _Heading('Your rights'),
                _Para(
                  'Signa is built to align with PIPEDA and PHIPA principles '
                  '(Canada) and privacy-by-design: data minimization, on-device '
                  'processing, and user-controlled sharing.',
                ),
                _Heading('Contact'),
                _Para(
                  'Questions about privacy? Reach the Signa team via the '
                  'Evolved26 Hackathon project channel.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  final String text;
  const _Heading(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
        child: Text(text,
            style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface)),
      );
}

class _Para extends StatelessWidget {
  final String text;
  const _Para(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: GoogleFonts.inter(
          fontSize: 14, height: 1.5, color: AppColors.onSurfaceVariant));
}

class _Updated extends StatelessWidget {
  final String text;
  const _Updated(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(text,
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.outline)),
      );
}
```

- [ ] **Step 2: Register the route in `main.dart`**

In `app/lib/main.dart`, add the import:
```dart
import 'screens/privacy_policy_screen.dart';
```
And add the route inside the `routes:` list (after the `/alert` route):
```dart
    GoRoute(path: '/privacy', builder: (_, __) => const PrivacyPolicyScreen()),
```

- [ ] **Step 3: Wire the Profile "Privacy" tile**

In `app/lib/screens/profile_screen.dart`, replace:
```dart
                  _SettingTile(
                    icon: Icons.lock_outline,
                    title: 'Privacy',
                    subtitle: 'On-device processing · PHIPA',
                    onTap: () {},
                  ),
```
with:
```dart
                  _SettingTile(
                    icon: Icons.lock_outline,
                    title: 'Privacy',
                    subtitle: 'On-device processing · PHIPA',
                    onTap: () => context.go('/privacy'),
                  ),
```

- [ ] **Step 4: Analyze**

Run: `cd app && flutter analyze lib/screens/privacy_policy_screen.dart lib/main.dart lib/screens/profile_screen.dart`
Expected: no new errors.

- [ ] **Step 5: Commit**

```bash
git add app/lib/screens/privacy_policy_screen.dart app/lib/main.dart app/lib/screens/profile_screen.dart
git commit -m "feat(app): in-app privacy policy screen + route"
```

---

### Task 9: Full verification pass

**Files:** none (verification only).

- [ ] **Step 1: Analyze the whole app**

Run: `cd app && flutter analyze`
Expected: no new errors introduced by this work.

- [ ] **Step 2: Run the full test suite**

Run: `cd app && flutter test`
Expected: all tests pass (boot smoke test + `self_report_test.dart` + `export_service_test.dart`).

- [ ] **Step 3: Manual smoke (simulator or device)**

Run: `cd app && flutter run` (pick a simulator). Then verify:
  1. Launcher icon shows the Signa watch logo (check the home screen / app switcher).
  2. Profile → "Daily Check-in" → set sleep + mood + notes → Save → tile shows "Logged today".
  3. Profile → "Share My Data" → toggle JSON/CSV → preview updates → Share → after sharing, tile subtitle shows "Last exported <today> · JSON".
  4. Inspect the shared JSON: it contains `meta` (version `1.0.0+3`, schema_version 1), `patient`, `self_reports` (your check-in), `readings`, and `summary`.
  5. Profile → "Privacy" opens the policy screen; back returns to Profile.
  6. Profile → "About Signa" subtitle reads `v1.0.0 (3) · Evolved26 Hackathon`.

- [ ] **Step 4: Confirm version**

Run: `grep '^version:' app/pubspec.yaml`
Expected: `version: 1.0.0+3`

---

## Self-Review

**Spec coverage:**
- Workstream 1 (icon + version) → Task 1. ✓
- Workstream 2 (daily check-in) → Tasks 2, 3, 6. ✓
- Workstream 3 (JSON export alongside CSV) → Tasks 5, 7. ✓
- Workstream 4 (last-export tracking) → Tasks 4, 7. ✓
- Workstream 5 (privacy policy) → Task 8. ✓
- SQLite `onUpgrade` migration constraint → Task 3 Step 1. ✓
- iOS opaque-icon constraint → Task 1 Step 3. ✓

**Type consistency:** `SelfReport` (Task 2) used identically in Tasks 3/5/6. `DataExportService.buildJson/buildCsv/lastExportSubtitle` signatures match between Task 5 definition and Task 7 use. `AppSettings.setLastExport(DateTime, String)` and getters match between Task 4 and Task 7. `kAppVersion`/`kAppVersionLabel` defined in Task 1, used in Tasks 5/7 and the About tile. ✓

**Placeholder scan:** No TBD/TODO/"handle edge cases" — all steps contain concrete code or exact commands. ✓
