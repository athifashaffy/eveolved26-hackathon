# Signa Brand and Mobile Store Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the approved Signal S identity and produce privacy-complete, signed-candidate Android and iOS builds ready for closed testing and store submission.

**Architecture:** One canonical 1024 px Signal S source asset generates platform icon sets and in-app branding. Native health permissions are least-privilege and requested only after consent. Release configuration reads signing secrets from ignored local files or CI secrets. Store copy, legal pages, and screenshots describe a private wellness product whose optional coach runs locally.

**Tech Stack:** Flutter, `flutter_launcher_icons`, Android Gradle, Health Connect, Xcode/HealthKit, App Store Connect, Google Play Console, Flutter integration tests.

## Global Constraints

- No health values, prompts, responses, notes, or analytics are uploaded by Signa.
- The only coach network transfer is the optional static model package and signed manifest; after installation the coach works offline.
- Do not claim depression detection, diagnosis, treatment, clinician monitoring, medical-device status, or emergency monitoring.
- Do not commit signing keys, passwords, Apple certificates, provisioning profiles, OAuth secrets, generated Pods, `.dart_tool`, or build outputs.
- Preserve the existing light-first visual direction and verify every release screen in light mode, large text, and high contrast.
- A store upload requires the user's Apple Developer and Google Play Console credentials; the repository work stops at verified signed candidates when those credentials are unavailable.

---

## File Structure

**Create:**

- `app/assets/brand/signa-s-1024.png` - canonical approved mark on warm ivory.
- `app/assets/brand/signa-s-foreground.png` - transparent Android adaptive foreground.
- `app/test/brand_asset_test.dart` - dimensions, alpha, contrast, and registration checks.
- `app/test/permission_copy_test.dart` - least-privilege and consent-copy checks.
- `app/test/release_config_test.dart` - package, version, signing, and prohibited-copy checks.
- `app/android/key.properties.example` - secret-free signing template.
- `store/privacy-policy.md` - public policy source.
- `store/support.md` - support and deletion instructions.
- `store/app-store/metadata.md` - iOS listing and privacy answers.
- `store/google-play/metadata.md` - Play listing, Data safety, and Health apps declarations.
- `store/release-checklist.md` - owner, credential, review, and rollout gates.
- `store/screenshots/README.md` - required devices, routes, and captions.
- `pilot/consumer-pilot-protocol.md` - 20-50 person recruitment, consent, milestones, and success criteria.
- `pilot/clinic-report-pilot.md` - patient-controlled report workflow with clinic staff; no portal or automatic sharing.
- `app/lib/data/pilot_metrics.dart` - local-only aggregate counters and voluntary diagnostics export.

**Modify:** `app/pubspec.yaml`, Flutter theme/onboarding/profile/privacy screens, Android manifest/build resources, iOS plist/entitlements/project assets, platform launch screens, and release documentation.

---

### Task 1: Produce and Validate the Signal S Asset Set

**Files:**
- Create: `app/assets/brand/signa-s-1024.png`
- Create: `app/assets/brand/signa-s-foreground.png`
- Modify: `app/pubspec.yaml`
- Test: `app/test/brand_asset_test.dart`

- [ ] **Step 1: Write the failing asset contract**

The test must decode both PNGs, require 1024x1024 dimensions, require an opaque canonical icon, require alpha in the adaptive foreground, sample the four corners as `#FBF7EC`, and assert both paths are registered in `pubspec.yaml`.

Run: `/Users/athifshaffy/flutter/bin/flutter test test/brand_asset_test.dart`

Expected: FAIL because the approved files do not exist.

- [ ] **Step 2: Generate the canonical raster with the imagegen skill**

Use the approved direction: “Minimal premium wellness app icon, abstract continuous S-shaped signal path formed by two balanced flowing strokes, deep forest green `#173F35` with one muted amber pulse `#D99A3D`, centered with generous optical whitespace on warm ivory `#FBF7EC`, flat vector-like geometry, no text, no heart, no cross, no watch, no gradients, readable at 32 px, 1024x1024.” Save the selected result as `app/assets/brand/signa-s-1024.png` and derive the transparent foreground without changing its geometry.

- [ ] **Step 3: Inspect at native and small sizes**

Render a contact sheet at 1024, 180, 60, and 32 px. Confirm the S remains distinct, the pulse does not look like a medical cross, and the safe zone occupies no more than 66% of the canvas. If it fails, edit using the same imagegen skill and rerun the contract.

- [ ] **Step 4: Register assets and run tests**

Run: `/Users/athifshaffy/flutter/bin/flutter test test/brand_asset_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/assets/brand app/pubspec.yaml app/test/brand_asset_test.dart
git commit -m "feat(brand): add approved Signal S identity"
```

### Task 2: Apply Branding and Generate Platform Icons

**Files:**
- Modify: `app/pubspec.yaml`
- Modify: `app/lib/theme/app_theme.dart`
- Modify: `app/lib/screens/onboarding_screen.dart`
- Modify: Android launcher resources
- Modify: `app/ios/Runner/Assets.xcassets/AppIcon.appiconset`
- Test: `app/test/widget_test.dart`

- [ ] **Step 1: Add failing widget checks**

Pump onboarding at 320x568 and 430x932, assert the branded image is visible, no overflow exception occurs, semantics include `Signa`, and `ThemeMode.light` is used for the release build.

- [ ] **Step 2: Point launcher generation at the approved assets**

Set `image_path_ios` to `assets/brand/signa-s-1024.png`, `adaptive_icon_foreground` to `assets/brand/signa-s-foreground.png`, and `adaptive_icon_background` to `#FBF7EC`. Keep alpha removal enabled for iOS.

- [ ] **Step 3: Generate and inspect icons**

Run: `cd app && /Users/athifshaffy/flutter/bin/dart run flutter_launcher_icons`

Verify iOS 1024 px has no transparency, Android adaptive masking works for circle/squircle/rounded square, and launch backgrounds use warm ivory.

- [ ] **Step 4: Run widget and brand tests**

Run: `/Users/athifshaffy/flutter/bin/flutter test test/brand_asset_test.dart test/widget_test.dart`

Expected: PASS at both phone sizes and text scale 1.3.

- [ ] **Step 5: Commit**

```bash
git add app/pubspec.yaml app/lib/theme app/lib/screens/onboarding_screen.dart app/android/app/src/main/res app/ios/Runner/Assets.xcassets app/test/widget_test.dart
git commit -m "feat(brand): apply Signal S to the mobile experience"
```

### Task 3: Configure Consent-First HealthKit and Health Connect Access

**Files:**
- Modify: `app/android/app/src/main/AndroidManifest.xml`
- Modify: `app/ios/Runner/Info.plist`
- Verify: `app/ios/Runner/Runner.entitlements`
- Modify: `app/lib/screens/connect_screen.dart`
- Modify: `app/lib/main.dart`
- Test: `app/test/permission_copy_test.dart`

- [ ] **Step 1: Write failing permission and startup tests**

Assert the Android manifest contains only read permissions required by the `health` package for HRV, sleep, and steps; assert HealthKit is enabled; assert `main()` does not call authorization; and assert the connect screen explains each category before its button invokes the injected authorization service.

- [ ] **Step 2: Add least-privilege native declarations**

Declare Android Health Connect read access for heart-rate variability, sleep, and steps using the exact manifest constants supported by the pinned `health` package/compile SDK. Keep HealthKit read-only in app behavior and retain `com.apple.developer.healthkit = true`. Rewrite usage descriptions as wellness explanations without “stability score” or medical claims.

- [ ] **Step 3: Move authorization behind explicit consent**

Remove `HealthKitService.instance.requestAuthorization()` from startup. The connect route must show data types, purpose, on-phone storage, optionality, and a `Connect health data` button before the native prompt.

- [ ] **Step 4: Validate both native configurations**

Run:

```bash
cd app
/Users/athifshaffy/flutter/bin/flutter test test/permission_copy_test.dart test/widget_test.dart
/Users/athifshaffy/flutter/bin/flutter build apk --debug
/Users/athifshaffy/flutter/bin/flutter build ios --simulator --debug
```

Expected: tests and both builds PASS; denying health access leaves manual check-ins usable.

- [ ] **Step 5: Commit**

```bash
git add app/android/app/src/main/AndroidManifest.xml app/ios/Runner/Info.plist app/ios/Runner/Runner.entitlements app/lib/main.dart app/lib/screens/connect_screen.dart app/test/permission_copy_test.dart
git commit -m "feat(privacy): request health access after consent"
```

### Task 4: Add Production Signing and Release Configuration

**Files:**
- Modify: `app/android/app/build.gradle`
- Create: `app/android/key.properties.example`
- Modify: `.gitignore`
- Modify: `app/pubspec.yaml`
- Verify: iOS Runner bundle identifier and Release signing settings
- Test: `app/test/release_config_test.dart`

- [ ] **Step 1: Write failing release configuration tests**

Require display name `Signa`, Android application ID and iOS product bundle ID `com.autobiomarker.signa`, version `1.0.0+4` or higher, no debug signing in the Android release block, and ignored signing material.

- [ ] **Step 2: Configure Android signing without secrets**

Load `android/key.properties` when present with keys `storeFile`, `storePassword`, `keyAlias`, and `keyPassword`; configure a `release` signing config; fail a release build with a clear message when it is absent. Commit only `key.properties.example` and ignore the real file plus `*.jks`/`*.keystore`.

- [ ] **Step 3: Verify iOS identity without modifying user credentials**

Set display/bundle names in source configuration and document the required Apple Team and provisioning profile in `store/release-checklist.md`. Do not commit a personal team ID or profile.

- [ ] **Step 4: Run configuration tests**

Run: `/Users/athifshaffy/flutter/bin/flutter test test/release_config_test.dart`

Expected: PASS. A release build without local secrets must stop before producing an unsigned artifact and identify the missing file.

- [ ] **Step 5: Commit**

```bash
git add .gitignore app/android/app/build.gradle app/android/key.properties.example app/pubspec.yaml app/test/release_config_test.dart
git commit -m "build(release): configure store-safe mobile signing"
```

### Task 5: Write Public Privacy, Support, and Store Declarations

**Files:**
- Create: `store/privacy-policy.md`
- Create: `store/support.md`
- Create: `store/app-store/metadata.md`
- Create: `store/google-play/metadata.md`
- Modify: `app/lib/screens/privacy_policy_screen.dart`
- Modify: `app/lib/screens/profile_screen.dart`
- Test: `app/test/wellness_copy_test.dart`

- [ ] **Step 1: Extend failing copy parity tests**

Require the in-app policy and store sources to state: data categories, purposes, on-device storage, user-initiated PDF/CSV sharing, optional model download, offline inference, no Signa cloud account, no advertising/tracking, retention/deletion controls, age 18+, wellness limitation, crisis limitation, and support contact. Prohibit clinical claims throughout.

- [ ] **Step 2: Write canonical legal and support sources**

Use a visible effective date and responsible entity. Distinguish Apple/Google system services and Fitbit OAuth from Signa collection. Explain that users control any file they share and that deleting app data/model is immediate on-device deletion. Include a route for privacy questions and account-free deletion instructions.

- [ ] **Step 3: Complete store questionnaires in source control**

For Apple, document App Privacy answers and HealthKit use. For Google, document Data safety, Health apps declaration, Health Connect data types/purposes, and AI-generated-content behavior. State that static model delivery is not health-data collection.

- [ ] **Step 4: Run copy tests and legal review gate**

Run: `/Users/athifshaffy/flutter/bin/flutter test test/wellness_copy_test.dart`

Expected: PASS. Mark counsel/owner approval as an unchecked release gate; do not imply legal review occurred.

- [ ] **Step 5: Commit**

```bash
git add store app/lib/screens/privacy_policy_screen.dart app/lib/screens/profile_screen.dart app/test/wellness_copy_test.dart
git commit -m "docs(release): add privacy and store declarations"
```

### Task 6: Capture Store Screenshots and Accessibility Evidence

**Files:**
- Create: `store/screenshots/README.md`
- Create: `app/integration_test/store_screenshot_test.dart`
- Create: approved PNGs under `store/screenshots/ios` and `store/screenshots/android`

- [ ] **Step 1: Build deterministic demo fixtures**

Use synthetic, visibly labelled demo wellness data. Capture onboarding, baseline learning, Today, Trends, private coach setup, coach explanation, and clinician report preview. Do not capture real user data or a crisis conversation.

- [ ] **Step 2: Add golden accessibility checks**

Verify no overflow at text scales 1.0 and 1.3, minimum 44 pt/48 dp touch targets, semantic labels for score confidence and charts, WCAG AA text contrast, and no required dark-mode screenshots for this release.

- [ ] **Step 3: Capture required device sizes**

Record the exact iPhone and Android emulator/device profiles, locale `en-CA`, build number, route, and caption in the README. Save lossless PNGs only.

- [ ] **Step 4: Run the integration test**

Run: `cd app && /Users/athifshaffy/flutter/bin/flutter test integration_test/store_screenshot_test.dart`

Expected: PASS and all documented screenshots exist with no debug banner.

- [ ] **Step 5: Commit**

```bash
git add app/integration_test store/screenshots
git commit -m "test(release): capture accessible store screenshots"
```

### Task 7: Build Closed-Test Candidates and Complete Submission Gates

**Files:**
- Create: `store/release-checklist.md`
- Modify: `app/README.md`

- [ ] **Step 1: Run the full local quality gate**

```bash
cd app
/Users/athifshaffy/flutter/bin/dart format lib test integration_test
/Users/athifshaffy/flutter/bin/flutter analyze
/Users/athifshaffy/flutter/bin/flutter test
```

Expected: formatter leaves no diff, analyzer has zero errors/warnings, and all tests PASS.

- [ ] **Step 2: Test offline and destructive privacy flows on physical phones**

On one supported iPhone and one supported Android phone: deny health access, revoke it later, download and delete Gemma, restart offline, generate offline, cancel generation, export a report, delete all app data, and verify no health/model/chat residue remains in app-visible storage.

- [ ] **Step 3: Produce signed candidates after credentials are supplied**

```bash
cd app
/Users/athifshaffy/flutter/bin/flutter build appbundle --release
/Users/athifshaffy/flutter/bin/flutter build ipa --release
```

Expected: signed `.aab` and `.ipa` use `com.autobiomarker.signa`, release `1.0.0+4` or later, and the verified icon. Record SHA-256 hashes in the checklist; do not commit binaries.

- [ ] **Step 4: Upload only after owner-controlled gates pass**

The checklist must require: privacy/support URLs are publicly reachable; Gemma terms/notices are included; counsel/owner copy approval; Health Connect/HealthKit declarations; age rating; export compliance; closed-test participant list; signing ownership; and rollback contact. Upload first to TestFlight internal testing and Google Play closed testing, not production.

- [ ] **Step 5: Run verification-before-completion and commit**

Re-run the full quality gate and inspect `git status` to ensure credentials and generated artifacts are absent.

```bash
git add app/README.md store/release-checklist.md
git commit -m "docs(release): complete Signa closed-test runbook"
```

### Task 8: Run the Privacy-Preserving Adoption and Clinic Pilots

**Files:**
- Create: `app/lib/data/pilot_metrics.dart`
- Modify: `app/lib/data/export_service.dart`
- Create: `app/test/pilot_metrics_test.dart`
- Create: `pilot/consumer-pilot-protocol.md`
- Create: `pilot/clinic-report-pilot.md`
- Create: `pilot/feedback-form.md`

**Interfaces:** `PilotMetrics.record(PilotEvent event)`, `PilotMetrics.snapshot()`, and `PilotMetrics.buildVoluntaryExport()` store aggregate counters locally and produce a user-reviewed JSON file only after an explicit export action.

- [ ] **Step 1: Write failing local-only metrics tests**

Test the exact events `healthConnectionAttempted`, `healthConnectionSucceeded`, `baselineCompleted`, `weeklyInsightViewed`, `checkInCompleted`, `coachOptedIn`, `coachSetupSucceeded`, `coachFallbackUsed`, `reportGenerated`, and `reportShared`. Assert no timestamp finer than local calendar day, no health value, prompt, response, note, identifier, HTTP client, or background uploader appears in the stored/exported JSON.

- [ ] **Step 2: Implement local aggregate counters**

Persist first-use day, last-use day, active-day set, and integer event counts in SQLite. Compute day-7/day-14/week-4 return flags on-device. Display the export content before the system share sheet and require `Share anonymous pilot diagnostics`; never send automatically.

- [ ] **Step 3: Write the 20-50 person consumer protocol**

Recruit adults who already use Apple Health, Health Connect, or Fitbit through smartwatch communities, university/workplace wellness groups, and the existing research network. Use onboarding, baseline-day-7, baseline-day-14, and week-4 check-ins. Predefine success thresholds: at least 80% health connection among consenters, 60% baseline completion, 40% week-4 return, 80% comprehension of “wellness/not diagnosis,” zero high-severity coach safety misses, and fewer than 5% crash-blocked sessions.

- [ ] **Step 4: Write the clinic-report pilot protocol**

Use 3-5 clinicians and 10-20 consenting patients. Patients generate and choose whether to share a 30-day PDF before an ordinary appointment; clinics receive no portal login, background feed, alert, or Signa account. Measure report usefulness, interpretation time, misunderstood claims, whether the report changed the appointment discussion, and revocation/deletion comprehension. Include Prof. Dr. Steffen Moritz as a proposed clinical advisor, not as a confirmed study sponsor or data controller.

- [ ] **Step 5: Run tests and owner review**

Run: `/Users/athifshaffy/flutter/bin/flutter test test/pilot_metrics_test.dart test/export_service_test.dart`

Expected: PASS and network mocking records zero automatic calls. The protocols remain marked draft until ethics/privacy/owner review appropriate to the actual recruitment setting is recorded.

- [ ] **Step 6: Commit**

```bash
git add app/lib/data/pilot_metrics.dart app/lib/data/export_service.dart app/test/pilot_metrics_test.dart pilot
git commit -m "feat(pilot): add private adoption and clinic evaluation"
```
