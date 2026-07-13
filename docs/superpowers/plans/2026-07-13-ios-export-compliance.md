# iOS Export Compliance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make future Signa iOS uploads declare that the app uses no non-exempt encryption and advance the upload to build 6.

**Architecture:** Store Apple’s Boolean export-compliance declaration in the Runner application plist so it is embedded in every iOS bundle. Protect the declaration and release number with the existing file-based release configuration test, then inspect the built application plist.

**Tech Stack:** Flutter, Dart tests, Apple property lists, Flutter iOS release build

## Global Constraints

- `ITSAppUsesNonExemptEncryption` must be a Boolean with value `false`.
- The next upload version must be `1.0.1+6`.
- Existing local/generated Xcode workspace changes must remain untouched.
- Build 3 cannot be changed retroactively and still requires its manual compliance response.

---

### Task 1: Export declaration and build number

**Files:**
- Modify: `app/test/release_config_test.dart`
- Modify: `app/ios/Runner/Info.plist`
- Modify: `app/pubspec.yaml`
- Modify: `app/lib/app_info.dart`
- Modify: `store/app-store/metadata.md`
- Modify: `store/google-play/metadata.md`
- Modify: `store/release-checklist.md`
- Modify: `store/screenshots/README.md`

**Interfaces:**
- Consumes: Apple’s `ITSAppUsesNonExemptEncryption` Info.plist Boolean.
- Produces: iOS bundles declaring no non-exempt encryption and release identifier `1.0.1+6`.

- [ ] **Step 1: Write the failing release test**

Parse `ios/Runner/Info.plist` with `Process.runSync('plutil', ['-extract', 'ITSAppUsesNonExemptEncryption', 'raw', '-o', '-', 'ios/Runner/Info.plist'])`, assert exit code zero and stdout `false`, and update the version assertions to `1.0.1+6`.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/release_config_test.dart`

Expected: FAIL because the plist key is absent and the project is still build 5.

- [ ] **Step 3: Add the minimal declaration and version bump**

Add this property to the Runner plist:

```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

Set `pubspec.yaml` and `app_info.dart` to `1.0.1+6`, label it `v1.0.1 (6)`, and update the store release metadata to build 6.

- [ ] **Step 4: Run focused and full verification**

Run:

```bash
flutter test test/release_config_test.dart
flutter analyze
flutter test
plutil -lint ios/Runner/Info.plist
```

Expected: focused test passes, analyzer reports no issues, all tests pass, and plist lint reports `OK`.

- [ ] **Step 5: Commit the implementation**

```bash
git add app/test/release_config_test.dart app/ios/Runner/Info.plist app/pubspec.yaml app/lib/app_info.dart store/app-store/metadata.md store/google-play/metadata.md store/release-checklist.md store/screenshots/README.md
git commit -m "fix(ios): declare exempt encryption for uploads"
```

### Task 2: Validate the built iOS application

**Files:**
- Verify: `app/build/ios/iphoneos/Runner.app/Info.plist`

**Interfaces:**
- Consumes: committed `1.0.1+6` iOS configuration.
- Produces: unsigned release application verified to contain the compliance Boolean.

- [ ] **Step 1: Build without code signing in the clean implementation worktree**

Run: `flutter build ios --release --no-codesign`

Expected: `build/ios/iphoneos/Runner.app` is produced successfully.

- [ ] **Step 2: Inspect the built plist**

Run:

```bash
plutil -extract ITSAppUsesNonExemptEncryption raw -o - build/ios/iphoneos/Runner.app/Info.plist
plutil -extract CFBundleVersion raw -o - build/ios/iphoneos/Runner.app/Info.plist
```

Expected output: `false` and `6`.
