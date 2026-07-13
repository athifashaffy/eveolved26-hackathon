# Signa Core Wellness App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the prototype's hard-coded depression score with a private, explainable personal-baseline wellness experience and patient-controlled clinician reports.

**Architecture:** Health source adapters emit nullable, provenance-aware `DailySignal` records. A pure `BaselineEngine` computes versioned component scores and confidence, an `InsightEngine` produces reviewed copy, and repositories persist the immutable result. Screens consume `WellnessSnapshot` view models and never calculate scores.

**Tech Stack:** Flutter 3.35.7, Dart 3.9, `health`, `sqflite`, `shared_preferences`, `fl_chart`, `pdf`, `printing`, Flutter test.

## Global Constraints

- All health data and scoring stay on-device; no account or health-data backend.
- Do not display depression risk, diagnosis, clinical thresholds, automatic clinician alerts, or medical-device clearance.
- A baseline requires at least 10 eligible days in a rolling 14-day period; an eligible day has sleep and either HRV or activity.
- Missing physiological values remain null and never become zero.
- Score range is 0-100 and is never displayed without confidence and an explanation.
- Health authorization occurs only after in-app explanation and user action.
- Existing user changes and generated iOS files must not be overwritten or committed.

---

## File Structure

**Create:**

- `app/lib/domain/daily_signal.dart` - nullable normalized source record and provenance.
- `app/lib/domain/wellness_score.dart` - component scores, readiness, confidence, and snapshot types.
- `app/lib/domain/timeline_marker.dart` - user-entered context categories.
- `app/lib/scoring/baseline_engine.dart` - deterministic robust scoring.
- `app/lib/scoring/insight_engine.dart` - reviewed explanations and action identifiers.
- `app/lib/data/health_data_source.dart` - adapter interface and fetch result.
- `app/lib/data/daily_signal_repository.dart` - database-backed signal/score access.
- `app/lib/screens/baseline_screen.dart` - learning progress and missing-data guidance.
- `app/lib/screens/check_in_screen.dart` - mood, sleep, and marker entry.
- `app/lib/reports/clinician_report_service.dart` - PDF report generation.
- `app/test/baseline_engine_test.dart`
- `app/test/insight_engine_test.dart`
- `app/test/database_migration_test.dart`
- `app/test/health_data_source_test.dart`
- `app/test/clinician_report_test.dart`
- `app/test/wellness_copy_test.dart`
- `app/test/support/wellness_fixtures.dart` - fixed dates, signal/report builders, test app, database opener, and PDF text extractor used by the named tests.

**Modify:** `app/lib/data/models.dart`, `database_service.dart`, `healthkit_service.dart`, `fitbit_service.dart`, `real_data.dart`, `app_settings.dart`, `main.dart`, onboarding/home/trends/profile/privacy screens, `app/pubspec.yaml`, and existing tests.

---

### Task 1: Nullable Domain Model and Database v3

**Files:**
- Create: `app/lib/domain/daily_signal.dart`
- Create: `app/lib/domain/wellness_score.dart`
- Create: `app/lib/domain/timeline_marker.dart`
- Modify: `app/lib/data/database_service.dart:14-176`
- Test: `app/test/database_migration_test.dart`
- Create: `app/test/support/wellness_fixtures.dart`

**Interfaces:**
- Produces: `DailySignal`, `SignalSource`, `WellnessScore`, `ScoreConfidence`, `BaselineState`, `TimelineMarker`, `DailySignalRepository` storage schema.
- Test support produces `openFixtureDatabase({required int version})`, `signals({required int count})`, `stableSignals(int count)`, `stableReports()`, `testApp({required PermissionGateway permissionGateway})`, `todayFixture(BaselineState state)`, `allDartAndStoreCopy()`, and `extractPdfText(Uint8List bytes)`. All fixtures use the fixed clock `2026-07-13T12:00:00-04:00`; no test reads current time or production health data.

- [ ] **Step 1: Write failing model and migration tests**

```dart
test('daily signal preserves missing values', () {
  final signal = DailySignal(
    date: DateTime(2026, 7, 1),
    source: SignalSource.healthConnect,
    hrvMs: null,
    sleepMinutes: 421,
    sleepMidpointMinutes: null,
    steps: null,
  );
  expect(signal.hrvMs, isNull);
  expect(signal.toMap()['hrv_ms'], isNull);
});

test('v2 migration keeps readings and adds nullable signal columns', () async {
  final db = await openFixtureDatabase(version: 2);
  await DatabaseService.openForTest(db);
  final columns = await db.rawQuery('PRAGMA table_info(daily_signals)');
  expect(columns.map((c) => c['name']), containsAll([
    'date', 'source', 'hrv_ms', 'sleep_minutes', 'sleep_midpoint_minutes',
    'steps', 'score', 'score_version', 'confidence', 'contributions_json'
  ]));
});
```

- [ ] **Step 2: Run the focused tests and verify failure**

Run: `/Users/athifshaffy/flutter/bin/flutter test test/database_migration_test.dart`

Expected: FAIL because the domain files and v3 schema do not exist.

- [ ] **Step 3: Add the domain types**

```dart
enum SignalSource { appleHealth, healthConnect, fitbit, demo }
enum ScoreConfidence { unavailable, low, medium, high }

class DailySignal {
  final DateTime date;
  final SignalSource source;
  final double? hrvMs;
  final int? sleepMinutes;
  final int? sleepMidpointMinutes;
  final int? steps;
  const DailySignal({
    required this.date,
    required this.source,
    this.hrvMs,
    this.sleepMinutes,
    this.sleepMidpointMinutes,
    this.steps,
  });
  bool get isEligible => sleepMinutes != null && (hrvMs != null || steps != null);
  Map<String, Object?> toMap() => {
    'date': dateKey(date), 'source': source.name, 'hrv_ms': hrvMs,
    'sleep_minutes': sleepMinutes, 'sleep_midpoint_minutes': sleepMidpointMinutes,
    'steps': steps,
  };
}
```

- [ ] **Step 4: Upgrade SQLite to v3 in a transaction**

Create `daily_signals`, `wellness_scores`, and `timeline_markers`. Copy legacy readings with `NULLIF(hrv_ms, 0)`, `NULLIF(sleep_min, 0)`, and `NULLIF(steps, 0)`. Preserve `self_reports` and `patient`. Add `deleteAllUserData()` that clears every user table in one transaction.

- [ ] **Step 5: Run migration and existing tests**

Run: `/Users/athifshaffy/flutter/bin/flutter test test/database_migration_test.dart test/self_report_test.dart test/export_service_test.dart`

Expected: PASS with no data converted from missing to zero.

- [ ] **Step 6: Commit**

```bash
git add app/lib/domain app/lib/data/database_service.dart app/test/database_migration_test.dart
git commit -m "feat(app): add nullable wellness domain and v3 storage"
```

### Task 2: Deterministic Personal Baseline Engine

**Files:**
- Create: `app/lib/scoring/baseline_engine.dart`
- Test: `app/test/baseline_engine_test.dart`

**Interfaces:**
- Consumes: `DailySignal`, `SelfReport`.
- Produces: `BaselineEngine.evaluate(List<DailySignal>, List<SelfReport>, DateTime) -> WellnessScore`.

- [ ] **Step 1: Write failing readiness, math, and missing-data tests**

```dart
test('requires ten eligible days inside fourteen days', () {
  final result = engine.evaluate(signals(count: 9), const [], now);
  expect(result.state, BaselineState.learning);
  expect(result.score, isNull);
});

test('stable personal signals score near one hundred', () {
  final result = engine.evaluate(stableSignals(28), stableReports(), now);
  expect(result.score, inInclusiveRange(95, 100));
  expect(result.confidence, ScoreConfidence.high);
});

test('missing mood renormalizes weights and lowers confidence', () {
  final result = engine.evaluate(stableSignals(14), const [], now);
  expect(result.contributions.containsKey(ScoreComponent.mood), isFalse);
  expect(result.appliedWeights.values.reduce((a, b) => a + b), closeTo(1, .0001));
  expect(result.confidence, ScoreConfidence.medium);
});
```

- [ ] **Step 2: Run the test and verify failure**

Run: `/Users/athifshaffy/flutter/bin/flutter test test/baseline_engine_test.dart`

Expected: FAIL because `BaselineEngine` is undefined.

- [ ] **Step 3: Implement robust scale and component transform**

```dart
double robustScale(List<double> values) {
  final median = medianOf(values);
  final mad = medianOf(values.map((v) => (v - median).abs()).toList());
  return [1.4826 * mad, median.abs() * .05, .001].reduce(max);
}

int stabilityScore(double current, List<double> baseline) {
  final deviation = (current - medianOf(baseline)).abs() / robustScale(baseline);
  return (100 * exp(-.5 * pow(deviation / 2, 2))).round().clamp(0, 100);
}
```

Implement HRV as the latest 3-day median, sleep as 70% duration plus 30% midpoint when present, activity as the latest 7-valid-day mean, and mood as the latest three ratings within seven days mapped to 0/25/50/75/100.

- [ ] **Step 4: Implement weights, confidence, and versioning**

Use `scoreVersion = 'wellness-v1'`, weights HRV .35, sleep .35, activity .15, mood .15, renormalized across available components. High confidence requires all objective components and 21 baseline days; medium requires two objective components; low covers one objective component, stale data, or recalibration.

- [ ] **Step 5: Run the complete scoring suite**

Run: `/Users/athifshaffy/flutter/bin/flutter test test/baseline_engine_test.dart`

Expected: PASS for readiness, stable, divergent, zero-MAD, missing, stale, and source-switch fixtures.

- [ ] **Step 6: Commit**

```bash
git add app/lib/scoring/baseline_engine.dart app/test/baseline_engine_test.dart
git commit -m "feat(app): add explainable personal baseline engine"
```

### Task 3: Deterministic Insights and Wellness Copy Guard

**Files:**
- Create: `app/lib/scoring/insight_engine.dart`
- Test: `app/test/insight_engine_test.dart`
- Test: `app/test/wellness_copy_test.dart`

**Interfaces:**
- Consumes: `WellnessScore`.
- Produces: `WellnessInsight { String title; String body; String? actionId; List<ScoreComponent> evidence; }`.

- [ ] **Step 1: Write failing grounding and prohibited-copy tests**

```dart
test('names strongest positive and negative contributors', () {
  final insight = InsightEngine().build(mixedScoreFixture);
  expect(insight.evidence, containsAll([ScoreComponent.sleep, ScoreComponent.hrv]));
  expect(insight.body, contains('sleep'));
});

test('release copy contains no clinical claims', () async {
  final text = await allDartAndStoreCopy();
  for (final phrase in ['depression risk', 'clinical threshold', 'clinician notified', 'Health Canada SaMD']) {
    expect(text.toLowerCase(), isNot(contains(phrase.toLowerCase())));
  }
});
```

- [ ] **Step 2: Verify the tests fail against current clinical copy**

Run: `/Users/athifshaffy/flutter/bin/flutter test test/insight_engine_test.dart test/wellness_copy_test.dart`

Expected: FAIL on undefined engine and existing prohibited phrases.

- [ ] **Step 3: Implement reviewed insight templates**

Support only `protect_sleep_window`, `complete_check_in`, `review_recent_change`, `prepare_clinician_questions`, and `view_trend`. Every selected template must reference an available component and include no causal or diagnostic statement.

- [ ] **Step 4: Remove fabricated and clinical copy from app routes**

Delete `/alert` and `AlertScreen`; replace “continuous depression monitoring” with “Understand how sleep, recovery, activity, and mood move together”; replace status labels with `Steady`, `Mixed signals`, and `Worth a check-in`; remove clinician-notified dates and clearance badges.

- [ ] **Step 5: Run copy and widget tests**

Run: `/Users/athifshaffy/flutter/bin/flutter test test/insight_engine_test.dart test/wellness_copy_test.dart test/widget_test.dart`

Expected: PASS and no prohibited release phrase in `app/lib`, Android/iOS descriptions, or store copy.

- [ ] **Step 6: Commit**

```bash
git add app/lib/scoring app/lib/screens app/lib/main.dart app/test
git commit -m "feat(app): add grounded wellness insights and safe copy"
```

### Task 4: Source Adapters Without Fabricated Measurements

**Files:**
- Create: `app/lib/data/health_data_source.dart`
- Modify: `app/lib/data/healthkit_service.dart`
- Modify: `app/lib/data/fitbit_service.dart`
- Test: `app/test/health_data_source_test.dart`

**Interfaces:**
- Produces: `Future<HealthFetchResult> fetch(DateTime start, DateTime end)` where result includes signals, source, fetchedAt, and typed failure.

- [ ] **Step 1: Write adapter tests with fixtures**

```dart
test('Fitbit leaves HRV null when HRV endpoint has no value', () async {
  final result = await source.fetch(start, end);
  expect(result.signals.single.hrvMs, isNull);
});

test('sleep segments aggregate without converting missing steps', () async {
  final signal = (await healthSource.fetch(start, end)).signals.single;
  expect(signal.sleepMinutes, 430);
  expect(signal.steps, isNull);
});
```

- [ ] **Step 2: Run and verify failure**

Run: `/Users/athifshaffy/flutter/bin/flutter test test/health_data_source_test.dart`

Expected: FAIL because current adapters return non-null integers and Fitbit estimates HRV.

- [ ] **Step 3: Implement Apple Health and Health Connect normalization**

Use the `health` package types `HEART_RATE_VARIABILITY_SDNN`, `SLEEP_ASLEEP`, and `STEPS`. Group by original local date, return null for absent types, preserve source, and compute sleep midpoint from the first sleep start and final sleep end when available.

- [ ] **Step 4: Replace Fitbit HRV estimation with actual-or-missing data**

Call Fitbit's HRV endpoint for supported accounts and parse daily RMSSD. If unavailable or unauthorized, keep `hrvMs` null; do not derive it from resting heart rate. Preserve sleep and activity independently.

- [ ] **Step 5: Run adapter tests**

Run: `/Users/athifshaffy/flutter/bin/flutter test test/health_data_source_test.dart`

Expected: PASS with actual values or nulls and no physiological estimation.

- [ ] **Step 6: Commit**

```bash
git add app/lib/data/health_data_source.dart app/lib/data/healthkit_service.dart app/lib/data/fitbit_service.dart app/test/health_data_source_test.dart
git commit -m "fix(app): normalize wearable data without fabricated HRV"
```

### Task 5: Repository and App Orchestration

**Files:**
- Create: `app/lib/data/daily_signal_repository.dart`
- Modify: `app/lib/data/real_data.dart`
- Modify: `app/lib/data/app_settings.dart`
- Test: `app/test/real_data_test.dart`

**Interfaces:**
- Produces: `RealData.load()`, `RealData.forceSync()`, and `RealData.snapshot()` returning `WellnessSnapshot` with loading, learning, ready, stale, and source-recalibration states.

- [ ] **Step 1: Write failing orchestration tests**

Test cold DB load before refresh, 15-minute staleness, failed-sync preservation, score persistence with version/contributions, and source-switch recalibration.

- [ ] **Step 2: Verify failure**

Run: `/Users/athifshaffy/flutter/bin/flutter test test/real_data_test.dart`

Expected: FAIL because `RealData` still relies on `StabilitySnapshot` and adapter-calculated scores.

- [ ] **Step 3: Move calculation out of source adapters**

Inject `HealthDataSource`, `DailySignalRepository`, `BaselineEngine`, and `InsightEngine` into `RealData` for tests. Persist fetched signals first, compute from repository history, then persist the score and snapshot.

- [ ] **Step 4: Preserve good state on failure**

Map `permissionDenied`, `unsupported`, `offline`, `rateLimited`, and `unknown` to recoverable UI states while keeping the last valid snapshot and timestamp.

- [ ] **Step 5: Run orchestration tests**

Run: `/Users/athifshaffy/flutter/bin/flutter test test/real_data_test.dart`

Expected: PASS for all state transitions without hidden zero substitution.

- [ ] **Step 6: Commit**

```bash
git add app/lib/data app/test/real_data_test.dart
git commit -m "refactor(app): orchestrate normalized signals and wellness scores"
```

### Task 6: Consent-First Onboarding, Baseline, and Today Screens

**Files:**
- Create: `app/lib/screens/baseline_screen.dart`
- Modify: `app/lib/main.dart`
- Modify: `app/lib/screens/onboarding_screen.dart`
- Modify: `app/lib/screens/connect_screen.dart`
- Modify: `app/lib/screens/home_screen.dart`
- Modify: `app/lib/widgets/status_badge.dart`
- Test: `app/test/wellness_flow_test.dart`

**Interfaces:**
- Consumes: `WellnessSnapshot`.
- Produces routes `/welcome`, `/connect`, `/baseline`, `/today` and persisted onboarding completion.

- [ ] **Step 1: Write failing flow tests**

```dart
testWidgets('health permission is not requested before connect action', (tester) async {
  await tester.pumpWidget(testApp(permissionGateway: gateway));
  expect(gateway.requestCount, 0);
  await tester.tap(find.text('Connect Apple Health'));
  await tester.pump();
  expect(gateway.requestCount, 1);
});

testWidgets('learning state hides numeric score', (tester) async {
  await tester.pumpWidget(todayFixture(BaselineState.learning));
  expect(find.textContaining('Day 6 of 14'), findsOneWidget);
  expect(find.text('74'), findsNothing);
});
```

- [ ] **Step 2: Verify current startup fails consent test**

Run: `/Users/athifshaffy/flutter/bin/flutter test test/wellness_flow_test.dart`

Expected: FAIL because `main()` requests health authorization at startup.

- [ ] **Step 3: Implement persisted routing and consent-first connection**

Remove authorization from `main()`. Route based on onboarding, source connection, and baseline state. Explain each data type before invoking the platform permission sheet.

- [ ] **Step 4: Implement learning and ready Today states**

Render progress, missing-data guidance, 0-100 score, confidence, contributor explanation, nullable metric cards, stale timestamp, and one grounded suggestion. Keep text scalable at 200%.

- [ ] **Step 5: Run widget tests at phone sizes and text scales**

Run: `/Users/athifshaffy/flutter/bin/flutter test test/wellness_flow_test.dart test/widget_test.dart`

Expected: PASS at 320x568, 390x844, and 200% text scale without overflow.

- [ ] **Step 6: Commit**

```bash
git add app/lib/main.dart app/lib/screens app/lib/widgets app/test/wellness_flow_test.dart app/test/widget_test.dart
git commit -m "feat(app): add consent-first baseline and today experience"
```

### Task 7: Context Markers and Explainable Trends

**Files:**
- Create: `app/lib/screens/check_in_screen.dart`
- Modify: `app/lib/screens/trends_screen.dart`
- Modify: `app/lib/data/database_service.dart`
- Test: `app/test/check_in_marker_test.dart`
- Test: `app/test/trends_screen_test.dart`

**Interfaces:**
- Produces: `upsertTimelineMarker`, `getTimelineMarkers(range)`, and a skippable daily check-in with optional marker.

- [ ] **Step 1: Write failing marker persistence and chart tests**

Verify medication, therapy, illness, travel, stress, alcohol, and custom categories round-trip; note text remains local and is excluded from coach context; markers align to local date on the 7/30/90-day chart.

- [ ] **Step 2: Run and verify failure**

Run: `/Users/athifshaffy/flutter/bin/flutter test test/check_in_marker_test.dart test/trends_screen_test.dart`

Expected: FAIL because markers and working range filtering do not exist.

- [ ] **Step 3: Implement skippable check-in and marker persistence**

Use five-point mood/sleep controls, optional note, optional category, and `Save`/`Skip today`. Do not add streak-loss or alarming reminder copy.

- [ ] **Step 4: Rebuild trends from snapshot data**

Make 7/30/90 filters change actual data; show score and component series, confidence gaps, marker pins, and observational language.

- [ ] **Step 5: Run focused and full tests**

Run: `/Users/athifshaffy/flutter/bin/flutter test test/check_in_marker_test.dart test/trends_screen_test.dart`

Expected: PASS for persistence, date filtering, null gaps, and marker rendering.

- [ ] **Step 6: Commit**

```bash
git add app/lib/screens/check_in_screen.dart app/lib/screens/trends_screen.dart app/lib/data/database_service.dart app/test/check_in_marker_test.dart app/test/trends_screen_test.dart
git commit -m "feat(app): add context markers and explainable trends"
```

### Task 8: Clinician PDF, Detailed Export, and Permanent Deletion

**Files:**
- Create: `app/lib/reports/clinician_report_service.dart`
- Modify: `app/lib/data/export_service.dart`
- Modify: `app/lib/screens/profile_screen.dart`
- Modify: `app/lib/screens/privacy_policy_screen.dart`
- Modify: `app/pubspec.yaml`
- Test: `app/test/clinician_report_test.dart`
- Test: `app/test/delete_data_test.dart`

**Interfaces:**
- Produces: `buildPdf(ReportData, ReportRange) -> Future<Uint8List>` and user-confirmed `deleteAllUserData()`.

- [ ] **Step 1: Add `pdf` and `printing` dependencies and write failing tests**

```dart
test('report includes confidence, provenance, markers, and disclaimer', () async {
  final bytes = await service.buildPdf(reportFixture, ReportRange.days30);
  final text = await extractPdfText(bytes);
  expect(text, contains('Data confidence'));
  expect(text, contains('Apple Health'));
  expect(text, contains('not a medical device'));
  expect(text, isNot(contains('clinician notified')));
});
```

- [ ] **Step 2: Verify tests fail**

Run: `/Users/athifshaffy/flutter/bin/flutter test test/clinician_report_test.dart test/delete_data_test.dart`

Expected: FAIL because the PDF service and complete deletion do not exist.

- [ ] **Step 3: Implement concise 7/30/90-day PDF**

Include score/component chart, confidence, completeness, check-ins, marker categories, data source, last sync, score version, explanation, and wellness disclaimer. Exclude private notes by default.

- [ ] **Step 4: Update CSV/JSON schema to version 2**

Export nullable signals, score version, confidence, contributions, and user-selected marker data. Keep a migration reader for schema version 1 tests.

- [ ] **Step 5: Implement destructive deletion confirmation**

Require the exact confirmation action, delete every user table and secure Fitbit tokens, reset preferences, and route to welcome. Do not delete the optional Gemma model in this task; its independent deletion is in the coach plan.

- [ ] **Step 6: Run report, deletion, and regression tests**

Run: `/Users/athifshaffy/flutter/bin/flutter test test/clinician_report_test.dart test/delete_data_test.dart test/export_service_test.dart`

Expected: PASS and extracted PDF contains no fabricated clinical language.

- [ ] **Step 7: Commit**

```bash
git add app/pubspec.yaml app/pubspec.lock app/lib/reports app/lib/data app/lib/screens/profile_screen.dart app/lib/screens/privacy_policy_screen.dart app/test
git commit -m "feat(app): add clinician report and complete data controls"
```

### Task 9: Core App Quality Gate

**Files:**
- Modify: only files named by analyzer/test output.
- Test: all `app/test/*.dart`.

**Interfaces:** Produces a release-candidate core app for the coach and store plans.

- [ ] **Step 1: Run formatter and static analysis**

Run: `/Users/athifshaffy/flutter/bin/dart format lib test`

Run: `git diff --check`

Run: `/Users/athifshaffy/flutter/bin/flutter analyze`

Expected: zero warnings and errors. Replace deprecated `withOpacity` calls, remove the unused Fitbit import, and guard `BuildContext` after async gaps only where analyzer identifies them.

- [ ] **Step 2: Run all Flutter tests**

Run: `/Users/athifshaffy/flutter/bin/flutter test`

Expected: all tests pass.

- [ ] **Step 3: Build unsigned platform artifacts**

Run: `/Users/athifshaffy/flutter/bin/flutter build appbundle --release`

Run: `/Users/athifshaffy/flutter/bin/flutter build ios --release --no-codesign`

Expected: Android AAB and unsigned iOS release build complete successfully.

- [ ] **Step 4: Commit quality fixes**

```bash
git add app/lib app/test app/android app/ios app/pubspec.yaml app/pubspec.lock
git commit -m "chore(app): pass core wellness quality gate"
```
