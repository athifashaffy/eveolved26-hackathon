# Signa v1.0.0 (build 3) — Export, Daily Check-in, Privacy & Branding

**Date:** 2026-06-23
**App:** `app/` (Flutter — "Signa")
**Status:** Approved design

## Goal

Ship build 3 of the Signa app with: a branded launcher icon, a JSON data export
patients can show a physician, a daily self-report ("form filled") bundled into
that export, last-export tracking, and an in-app privacy policy.

## Context

- The app already has a CSV "Share My Data" export in
  `app/lib/screens/profile_screen.dart` (`_exportData`), using `share_plus` +
  `path_provider`.
- Data layer: `DatabaseService` (SQLite `signa.db`, tables for patient + readings),
  `RealData` singleton, `AppSettings` (SharedPreferences), models in `models.dart`
  (`StabilityReading`, `PatientProfile`).
- `pubspec.yaml` version is currently `1.0.0+2`. TestFlight build 2 is live, so the
  next build is 3.
- The Profile screen has two stub tiles: "PHQ-9 Log" and "Privacy", both no-ops.
- Logo source: `Signa Logo.png` (watch illustration on cream background), provided
  by the user, to be copied into the repo.

## Out of Scope

- No PHQ-9 clinical questionnaire (replaced by a lighter self-report).
- No server/cloud upload — all processing stays on-device.
- No hosted privacy page; in-app screen only.
- No Home-screen entry point for the check-in (Profile tile only for build 3).

---

## Workstream 1 — App icon + version

- Add `flutter_launcher_icons` as a dev dependency.
- Copy the provided logo to `app/assets/icon/signa_icon.png`.
- Configure `flutter_launcher_icons` in `pubspec.yaml`:
  - `image_path: assets/icon/signa_icon.png`
  - iOS: `remove_alpha_ios: true`, background `#FBF7EC` (cream) so the icon is
    opaque (iOS rejects transparency).
  - Android: standard mipmap generation (legacy + adaptive with the cream
    background).
- Run the generator to replace the default Flutter icons on both platforms.
- Bump `pubspec.yaml`: `version: 1.0.0+3`.
- Update the Profile "About Signa" tile subtitle from hardcoded `v1.0.0 · …` to
  reflect `v1.0.0 (3)` (read from `package_info_plus` if already available;
  otherwise a single hardcoded constant `kAppVersionLabel` in one place).

**Acceptance:** `flutter pub run flutter_launcher_icons` succeeds; iOS
`AppIcon.appiconset` and Android `mipmap-*/ic_launcher.png` show the Signa watch
logo; `version: 1.0.0+3` in `pubspec.yaml`.

## Workstream 2 — Daily Check-in (self-report form)

- New SQLite table:
  `self_reports(date TEXT PRIMARY KEY, sleep_rating INTEGER, mood_rating INTEGER, notes TEXT, created_at TEXT)`.
  - Bump `DatabaseService` schema version and add `onUpgrade` to create the table
    on existing installs (preserve existing patient/readings data).
- New model `SelfReport { DateTime date; int sleepRating; int moodRating; String? notes; DateTime createdAt; }`
  with `toJson()` / `fromMap()`.
- `DatabaseService` methods: `upsertSelfReport(SelfReport)`,
  `getAllSelfReports()`, `getSelfReportForDate(DateTime)`.
- New `DailyCheckInDialog` (or small screen) with:
  - "How did you sleep last night?" — 1–5 (Very poor → Very good)
  - "Mood today?" — 1–5
  - Optional notes (`TextField`)
  - Saves an upsert for today's date.
- Profile: replace the stub "PHQ-9 Log" tile with a **Daily Check-in** tile
  (`Icons.assignment_outlined`) that opens the dialog; subtitle shows whether
  today's check-in is done (e.g. "Logged today" / "Not logged yet").

**Acceptance:** Saving a check-in writes one row per day (re-saving same day
updates, not duplicates); the row appears in the JSON export.

## Workstream 3 — JSON export (alongside CSV)

- Add a format choice to the existing share flow. Implementation: a
  `DataExportService` (new file `app/lib/data/export_service.dart`) with:
  - `Future<String> buildCsv()` — refactor of current inline CSV logic.
  - `Future<String> buildJson()` — structured export below.
  - `Future<File> writeToTemp(String content, {required String ext})`.
- JSON structure (`schema_version: 1`):
  ```json
  {
    "meta": { "app": "Signa", "version": "1.0.0+3", "exported_at": "<ISO8601>", "schema_version": 1 },
    "patient": { "name": "...", "dob": "...", "email": "...", "clinician": "..." },
    "self_reports": [ { "date": "...", "sleep_rating": 4, "mood_rating": 3, "notes": "..." } ],
    "readings": [ { "date": "...", "hrv_ms": 0, "sleep_min": 0, "sleep_score": 0, "steps": 0, "score": 0.0, "source": "..." } ],
    "summary": { "reading_count": 0, "date_range": ["<first>", "<last>"], "avg_score": 0.0 }
  }
  ```
- Share dialog (`_exportData` in `profile_screen.dart`) gains a CSV / JSON
  segmented toggle. JSON files: `signa_export_<timestamp>.json`,
  `mimeType: application/json`. CSV path stays `text/csv`.
- Both formats shared via the existing `share_plus` `shareXFiles` flow with the
  iPad `sharePositionOrigin` anchor preserved.

**Acceptance:** Choosing JSON produces a valid, parseable `.json` file containing
`patient`, `self_reports`, `readings`, and `summary`; CSV still works unchanged.

## Workstream 4 — Last-export tracking

- `AppSettings`: add `DateTime? get lastExportAt` and
  `Future<void> setLastExportAt(DateTime)` backed by SharedPreferences
  (ISO string key `last_export_at`).
- Stamp `lastExportAt` = now() at the moment an export is actually shared (after
  `Share.shareXFiles` returns), recording the chosen format too (key
  `last_export_format`).
- "Share My Data" tile subtitle reflects state:
  - never: "CSV/JSON · Never exported"
  - after: "Last exported <Mon D, YYYY> · <FORMAT>" (formatted with `intl`).

**Acceptance:** After a successful share, the Profile tile shows the date and
format; persists across app restarts.

## Workstream 5 — Privacy Policy (in-app)

- New `app/lib/screens/privacy_policy_screen.dart` — a scrollable screen styled
  with the Signa theme (`SignaScaffold` / `SignaAppBar`).
- Add route `/privacy` in `main.dart` (GoRouter).
- Wire the Profile "Privacy" tile to `context.go('/privacy')` (currently no-op).
- Content sections:
  - On-device only — data never leaves the phone except when the user exports.
  - What is stored — HRV, sleep, steps, stability score, self-reports, profile.
  - Data sources — Apple HealthKit / Fitbit (user-authorized).
  - Sharing — exports are user-initiated; the user controls who receives them.
  - Deletion — uninstalling the app removes all local data.
  - Not a medical device — informational, not diagnostic; consult a clinician.
  - Regulatory framing — PHIPA / PIPEDA (Canada), privacy-by-design.
  - Contact line / last-updated date.

**Acceptance:** Profile "Privacy" tile opens the policy screen; back navigation
returns to Profile.

---

## Data Flow Summary

```
Daily Check-in dialog ──► DatabaseService.self_reports (SQLite)
                                   │
Device (HealthKit/Fitbit) ──► readings (SQLite)
                                   │
Profile "Share My Data" ──► DataExportService.buildJson()/buildCsv()
                                   │
                                   ├─► temp file (path_provider)
                                   ├─► share_plus share sheet ──► physician
                                   └─► AppSettings.setLastExportAt(now)
```

## Files Touched / Added

- `app/pubspec.yaml` — version bump, `flutter_launcher_icons` dev dep + config,
  `assets/icon/` asset.
- `app/assets/icon/signa_icon.png` — new (copied logo).
- `app/lib/data/models.dart` — add `SelfReport`.
- `app/lib/data/database_service.dart` — schema upgrade + self-report CRUD.
- `app/lib/data/app_settings.dart` — `lastExportAt` / format persistence.
- `app/lib/data/export_service.dart` — new (CSV + JSON builders).
- `app/lib/screens/profile_screen.dart` — Daily Check-in tile + dialog, format
  toggle in export, last-export subtitle, Privacy tile wiring, version label.
- `app/lib/screens/privacy_policy_screen.dart` — new.
- `app/lib/main.dart` — `/privacy` route.
- iOS/Android icon assets — regenerated by the launcher-icons tool.

## Testing / Verification

- `flutter analyze` clean on `app/`.
- Manual: run app, open Profile → save a Daily Check-in → export JSON → confirm
  the file parses and includes the check-in + readings + patient + summary.
- Confirm CSV export still works.
- Confirm "Last exported" updates and survives restart.
- Confirm Privacy tile opens the screen.
- Confirm launcher icon shows the Signa logo after a rebuild; `version: 1.0.0+3`.

## Risks / Notes

- SQLite migration must use `onUpgrade` so existing build-2 testers keep their
  data when the `self_reports` table is added.
- iOS launcher icons must be fully opaque (cream fill) or App Store/TestFlight
  upload validation fails.
- JSON export contains identifying patient fields by design (physician needs
  identification); this is user-initiated and covered by the privacy policy.
