# Signa Android Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce and publish a verified, signed Signa Android App Bundle with safely stored GitHub signing secrets.

**Architecture:** Flutter supplies version metadata while Gradle owns the Android application identity and reads ignored local signing properties. The private upload key stays outside Git history; only encrypted GitHub secrets and the signed AAB release artifact leave the workstation.

**Tech Stack:** Flutter/Dart, Android Gradle Plugin, Java `keytool`, Android bundletool, Git, GitHub Releases and Actions secrets.

## Global Constraints

- Android application ID and namespace are `com.thealphanova.signa`.
- Release is `1.0.1+8` (`versionName` 1.0.1, `versionCode` 8).
- Upload alias is `alias_name` and the user-provided password protects both store and key.
- Never commit the JKS, `key.properties`, or plaintext passwords.
- Publish `Signa-1.0.1-build8.aab` plus its SHA-256 checksum.

---

### Task 1: Protect Android release identity with tests

**Files:**
- Modify: `app/test/release_config_test.dart`

**Interfaces:**
- Consumes: Gradle, Kotlin launcher, pubspec, signing template, and ignore configuration as text files.
- Produces: Regression assertions for package `com.thealphanova.signa`, build 8, alias `alias_name`, and excluded private signing files.

- [ ] **Step 1: Write failing assertions**

Change expected application ID to `com.thealphanova.signa`, expected release to `1.0.1+8`, require the matching Kotlin package declaration, and require `keyAlias=alias_name` in `android/key.properties.example`.

- [ ] **Step 2: Verify the assertions fail**

Run: `cd app && flutter test test/release_config_test.dart`

Expected: failures report the old Android ID, old build number, old Kotlin package, and old example alias.

- [ ] **Step 3: Leave the failing test uncommitted until Task 2**

Inspect with `git diff -- app/test/release_config_test.dart`; no production file changes belong in this step.

### Task 2: Apply the Android package and release metadata

**Files:**
- Modify: `app/android/app/build.gradle`
- Move/Modify: `app/android/app/src/main/kotlin/com/autobiomarker/signa/MainActivity.kt` to `app/android/app/src/main/kotlin/com/thealphanova/signa/MainActivity.kt`
- Modify: `app/android/key.properties.example`
- Modify: `app/pubspec.yaml`
- Modify: `app/lib/app_info.dart`
- Modify: `store/google-play/metadata.md`
- Modify: `store/release-checklist.md`
- Modify: `store/screenshots/README.md`
- Test: `app/test/release_config_test.dart`

**Interfaces:**
- Consumes: The failing assertions from Task 1.
- Produces: Package/version/signing-template metadata consumed by Gradle and Flutter.

- [ ] **Step 1: Update application identity**

Set both `namespace` and `applicationId` to `com.thealphanova.signa`. Move `MainActivity.kt` into the matching directory and set `package com.thealphanova.signa`.

- [ ] **Step 2: Update version and public release metadata**

Set Flutter/app metadata to `1.0.1+8`, update the Google Play package and build references, and update the release checklist and screenshot release number.

- [ ] **Step 3: Update the secret-free signing template**

Keep placeholder passwords and set only `keyAlias=alias_name`. Preserve ignore rules for `key.properties`, `*.jks`, and `*.keystore`.

- [ ] **Step 4: Run the focused test**

Run: `cd app && flutter test test/release_config_test.dart`

Expected: all release configuration tests pass.

- [ ] **Step 5: Commit source configuration**

Stage only the files listed in this task and commit with `feat(android): prepare signed build 8 release`.

### Task 3: Generate local signing material and signed AAB

**Files:**
- Create locally, ignored: `app/android/signa-upload.jks`
- Create locally, ignored: `app/android/key.properties`
- Generate: `app/build/app/outputs/bundle/release/app-release.aab`

**Interfaces:**
- Consumes: Alias/password constraints and Gradle signing configuration.
- Produces: The signed Play App Bundle and signing certificate.

- [ ] **Step 1: Generate the upload key**

Use `keytool -genkeypair -v -keystore app/android/signa-upload.jks -alias alias_name -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Signa, OU=Mobile, O=The Alpha Nova, L=Toronto, ST=Ontario, C=CA"` with the supplied password for store and key.

- [ ] **Step 2: Create ignored Gradle properties**

Create `app/android/key.properties` with the absolute JKS path, alias `alias_name`, and supplied store/key passwords. Confirm both files are ignored with `git check-ignore -v`.

- [ ] **Step 3: Run quality checks**

Run `cd app && flutter analyze && flutter test`.

Expected: analyzer exits with no issues and all tests pass.

- [ ] **Step 4: Build the release bundle**

Run: `cd app && flutter build appbundle --release`

Expected: command exits 0 and produces `build/app/outputs/bundle/release/app-release.aab`.

### Task 4: Verify and publish the release

**Files:**
- Create locally: `app/build/releases/Signa-1.0.1-build8.aab`
- Create locally: `app/build/releases/Signa-1.0.1-build8.aab.sha256`

**Interfaces:**
- Consumes: Signed bundle and upload certificate.
- Produces: Verified GitHub release assets and encrypted repository signing secrets.

- [ ] **Step 1: Verify identity and signing**

Inspect the AAB manifest for package `com.thealphanova.signa`, version code 8, and version name 1.0.1. Verify JAR signatures with `jarsigner -verify -verbose -certs` and compare the signing certificate with `keytool -list -v -alias alias_name`.

- [ ] **Step 2: Create named release assets**

Copy the verified AAB to `app/build/releases/Signa-1.0.1-build8.aab` and write its SHA-256 to the adjacent `.sha256` file.

- [ ] **Step 3: Confirm secrets remain untracked**

Run `git status --short`, `git ls-files app/android/key.properties app/android/signa-upload.jks`, and `git grep` for the supplied password.

Expected: secret files are absent from `git ls-files` and the password is absent from tracked content.

- [ ] **Step 4: Push branch and publish on GitHub**

Push the current branch, store the JKS and credentials as encrypted repository secrets, and create release/tag `signa-android-v1.0.1-build8` with the AAB and checksum. If the current GitHub authentication cannot publish releases or secrets, preserve the verified local assets and report the exact authentication step required.
