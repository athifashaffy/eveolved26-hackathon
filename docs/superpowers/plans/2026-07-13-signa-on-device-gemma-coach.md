# Signa On-Device Gemma Coach Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an optional, fully on-device Gemma 3 1B coach that explains approved Signa facts without receiving raw health records or providing medical advice.

**Architecture:** Pure Dart builds a minimal fact context, routes high-risk questions before inference, validates structured responses, and supplies a deterministic fallback. Platform adapters expose a pinned, telemetry-free `llama.cpp` runtime through a Flutter method channel. The model is an optional signature- and checksum-verified static download; no prompt, response, health value, note, or runtime metric leaves the phone.

**Tech Stack:** Flutter/Dart, `http`, `crypto`, `cryptography`, `llama.cpp` release `b9637` pinned to commit `aedb2a5`, Gemma 3 1B IT Q4_K_M GGUF, Kotlin/JNI, Swift/C, XCTest/JUnit, Flutter test.

## Global Constraints

- Coach is 18+ and explicitly optional.
- Gemma never calculates the Signa Score and receives no raw health records, OAuth tokens, exports, or free-form notes.
- Prompts, responses, and safety events are not logged, uploaded, analyzed, or used for training.
- The inference runtime contains no analytics SDK or telemetry client; MediaPipe Tasks is excluded because its published runtime metrics conflict with this constraint.
- Crisis, self-harm, medication, diagnosis, and treatment requests bypass Gemma.
- The allowed action IDs are exactly: `protect_sleep_window`, `complete_check_in`, `review_recent_change`, `prepare_clinician_questions`, `view_trend`.
- Chat history is memory-only and cleared when the screen closes or app backgrounds.
- Unsupported or unstable devices use deterministic insights; the core app never depends on the model.
- Normal response target is first text within 8 seconds on Pixel 8 and iPhone 15, with target peak memory below 2.5 GB.

---

## File Structure

**Create:**

- `app/lib/coach/coach_models.dart` - request, context, response, and status types.
- `app/lib/coach/coach_safety_router.dart` - deterministic pre-inference routing.
- `app/lib/coach/coach_context_builder.dart` - minimal fact extraction.
- `app/lib/coach/coach_response_validator.dart` - JSON, evidence, action, and copy validation.
- `app/lib/coach/coach_engine.dart` - common interface and deterministic fallback.
- `app/lib/coach/gemma_coach_engine.dart` - Flutter method-channel adapter.
- `app/lib/coach/model_asset_manager.dart` - consented static download and deletion.
- `app/lib/screens/coach_screen.dart` - model setup and ephemeral conversation.
- `app/lib/coach/model_manifest.dart` - strict manifest parsing and Ed25519 verification.
- `app/tool/build_llama_runtime.sh` - reproducible hash-checked native runtime build.
- `app/third_party/llama.cpp.version` - pinned upstream release, commit, archive URL, and SHA-256.
- `app/android/app/src/main/kotlin/com/autobiomarker/signa/GemmaCoachChannel.kt`
- `app/ios/Runner/GemmaCoachChannel.swift`
- `app/test/coach_safety_router_test.dart`
- `app/test/coach_context_builder_test.dart`
- `app/test/coach_response_validator_test.dart`
- `app/test/model_asset_manager_test.dart`
- `app/test/coach_screen_test.dart`
- `app/test/support/coach_fixtures.dart` - fixed grounded snapshots, insights, fake native channel, HTTP client, signing keys, and cancellation tokens.

**Modify:** Android CMake/Gradle/manifest, iOS Xcode/AppDelegate, Flutter main/profile/privacy, app lifecycle handler, `pubspec.yaml`, and platform tests.

All Dart tests import `app/test/support/coach_fixtures.dart`. It defines `snapshotFixture`, `insightFixture`, `mixedScoreFixture`, `FakeCoachNativeChannel`, `FakeModelHttpClient`, an in-memory Ed25519 test key pair, and a fixed clock; tests never rely on a real model or network unless a device smoke step explicitly says so.

---

### Task 1: Coach Contracts and Pre-Inference Safety Router

**Files:**
- Create: `app/lib/coach/coach_models.dart`
- Create: `app/lib/coach/coach_safety_router.dart`
- Test: `app/test/coach_safety_router_test.dart`

**Interfaces:**
- Produces: `CoachRoute route(String question)` returning `allow`, `crisis`, `medication`, `diagnosisTreatment`, or `unsupported`.

- [ ] **Step 1: Write failing table-driven safety tests**

```dart
for (final entry in {
  'I want to kill myself': CoachRoute.crisis,
  'Should I stop taking sertraline?': CoachRoute.medication,
  'Do I have depression?': CoachRoute.diagnosisTreatment,
  'Why was my score lower this week?': CoachRoute.allow,
}.entries) {
  test(entry.key, () {
    expect(const CoachSafetyRouter().route(entry.key), entry.value);
  });
}
```

- [ ] **Step 2: Run and verify failure**

Run: `/Users/athifshaffy/flutter/bin/flutter test test/coach_safety_router_test.dart`

Expected: FAIL because the contracts and router do not exist.

- [ ] **Step 3: Implement normalized phrase and intent matching**

```dart
enum CoachRoute { allow, crisis, medication, diagnosisTreatment, unsupported }

CoachRoute route(String question) {
  final q = normalize(question);
  if (_matches(q, crisisPatterns)) return CoachRoute.crisis;
  if (_matches(q, medicationPatterns)) return CoachRoute.medication;
  if (_matches(q, diagnosisTreatmentPatterns)) return CoachRoute.diagnosisTreatment;
  if (q.length > 500) return CoachRoute.unsupported;
  return CoachRoute.allow;
}
```

Include inflections, common misspellings, and fixtures for negation such as “I am not suicidal” that still route to professional support rather than Gemma. Store localized resource copy separately from match patterns.

- [ ] **Step 4: Add deterministic boundary responses**

Define `CoachBoundaryResponse` with title, body, emergency-call action, crisis-text action, and clinician-question action. No boundary response claims emergency monitoring.

- [ ] **Step 5: Run safety tests**

Run: `/Users/athifshaffy/flutter/bin/flutter test test/coach_safety_router_test.dart`

Expected: PASS for all high-risk and ordinary wellness fixtures.

- [ ] **Step 6: Commit**

```bash
git add app/lib/coach/coach_models.dart app/lib/coach/coach_safety_router.dart app/test/coach_safety_router_test.dart
git commit -m "feat(coach): add deterministic high-risk routing"
```

### Task 2: Minimal Grounded Context and Structured Response Validation

**Files:**
- Create: `app/lib/coach/coach_context_builder.dart`
- Create: `app/lib/coach/coach_response_validator.dart`
- Create: `app/lib/coach/coach_engine.dart`
- Test: `app/test/coach_context_builder_test.dart`
- Test: `app/test/coach_response_validator_test.dart`

**Interfaces:**
- Consumes: `WellnessSnapshot`, reviewed `WellnessInsight`, user question.
- Produces: `CoachContext`, `ValidatedCoachResponse`, and `CoachEngine.generate(CoachRequest, CancellationToken)`.

- [ ] **Step 1: Write failing privacy and grounding tests**

```dart
test('context excludes raw values and private notes', () {
  final context = builder.build(snapshotFixture, insightFixture, 'Explain this');
  final encoded = jsonEncode(context.toJson());
  expect(encoded, isNot(contains('private note')));
  expect(encoded, isNot(contains('oauth')));
  expect(context.facts.every((f) => f.id.startsWith('fact_')), isTrue);
});

test('rejects unknown evidence and action IDs', () {
  final raw = '{"text":"Take medication","evidence":["invented"],"action":"stop_medication","category":"explanation"}';
  expect(validator.validate(raw, context), isA<CoachRejected>());
});
```

- [ ] **Step 2: Verify tests fail**

Run: `/Users/athifshaffy/flutter/bin/flutter test test/coach_context_builder_test.dart test/coach_response_validator_test.dart`

Expected: FAIL because builder and validator do not exist.

- [ ] **Step 3: Implement fact-only context**

```dart
CoachContext build(WellnessSnapshot snapshot, WellnessInsight insight, String question) {
  return CoachContext(
    question: question,
    facts: [
      CoachFact('fact_score', 'Current Signa Score is ${snapshot.score} with ${snapshot.confidence.name} confidence.'),
      ...snapshot.contributions.entries.map((e) => CoachFact('fact_${e.key.name}', e.value.explanation)),
      CoachFact('fact_insight', insight.body),
    ],
    markerCategories: snapshot.selectedMarkerCategories.map((e) => e.name).toList(),
  );
}
```

Do not include `DailySignal`, source API payloads, patient profile, DOB, email, clinician, OAuth material, export contents, or `SelfReport.notes`.

- [ ] **Step 4: Implement strict JSON validator**

Accept only keys `text`, `evidence`, `action`, and `category`; require evidence to be a subset of supplied fact IDs; require action to be null or allowlisted; reject prohibited medical phrases and claims of causality/certainty/contact. Limit text to 600 characters.

- [ ] **Step 5: Add deterministic fallback engine**

Return the approved `WellnessInsight` and action when model setup, parsing, grounding, safety, or compatibility fails.

- [ ] **Step 6: Run tests and commit**

Run: `/Users/athifshaffy/flutter/bin/flutter test test/coach_context_builder_test.dart test/coach_response_validator_test.dart`

Expected: PASS.

```bash
git add app/lib/coach app/test/coach_context_builder_test.dart app/test/coach_response_validator_test.dart
git commit -m "feat(coach): constrain context and validate grounded output"
```

### Task 3: Optional Model Asset Manager

**Files:**
- Create: `app/lib/coach/model_asset_manager.dart`
- Create: `app/lib/coach/model_manifest.dart`
- Modify: `app/pubspec.yaml`
- Test: `app/test/model_asset_manager_test.dart`

**Interfaces:**
- Produces: `modelStatus()`, `download(Uri manifestUri, ValueChanged<double>)`, `verify()`, and `delete()`.

- [ ] **Step 1: Write failing manifest, checksum, cancellation, and deletion tests**

Use an in-memory HTTP client with a manifest fixture containing `schemaVersion`, model version `gemma-3-1b-it-q4km-v1`, byte size, SHA-256, minimum free bytes, artifact URL, and an Ed25519 signature over canonical UTF-8 JSON. Generate the test key pair in memory. Verify unknown keys, invalid signature, corrupt bytes, redirects to a non-allowlisted host, and version rollback are rejected and never marked ready.

- [ ] **Step 2: Run and verify failure**

Run: `/Users/athifshaffy/flutter/bin/flutter test test/model_asset_manager_test.dart`

Expected: FAIL because the manager does not exist.

- [ ] **Step 3: Implement atomic first-party download**

Add `cryptography: ^2.7.0`. Embed only the Ed25519 public key in `model_manifest.dart`; keep the private signing key outside the repository. Read the endpoint from `--dart-define=SIGNA_MODEL_MANIFEST_URL`; when it is absent the coach setup remains disabled with deterministic insights available. Download to `<app-support>/models/gemma.partial`, stream SHA-256 while writing, compare size and hash, then atomically rename to `gemma-3-1b-it-q4km-v1.gguf`. The GET request contains no custom user or health headers. Refuse download when free storage is below model size plus 1 GB.

- [ ] **Step 4: Implement lifecycle and deletion**

Persist only model version, path, checksum, and consent timestamp. `delete()` closes native inference first, removes model and compiled caches, and leaves health/history tables intact.

- [ ] **Step 5: Run tests and commit**

Run: `/Users/athifshaffy/flutter/bin/flutter test test/model_asset_manager_test.dart`

Expected: PASS for success, progress, cancellation, corrupt manifest, corrupt artifact, low storage, resume rejection, and deletion.

```bash
git add app/lib/coach/model_asset_manager.dart app/test/model_asset_manager_test.dart app/pubspec.yaml app/pubspec.lock
git commit -m "feat(coach): add private optional model asset manager"
```

### Task 4: Build the Pinned Telemetry-Free Native Runtime

**Files:**
- Create: `app/third_party/llama.cpp.version`
- Create: `app/tool/build_llama_runtime.sh`
- Create: `app/android/app/src/main/cpp/CMakeLists.txt`
- Create: `app/ios/Frameworks/README.md`

**Interfaces:** Produces Android arm64-v8a `libsigna_llama.so` and iOS device/simulator `SignaLlama.xcframework` exposing `signa_llama_open`, `signa_llama_generate`, `signa_llama_cancel`, and `signa_llama_close`.

- [ ] **Step 1: Write the pinned dependency manifest**

Record upstream `https://github.com/ggml-org/llama.cpp`, release `b9637`, commit `aedb2a5`, archive `https://github.com/ggml-org/llama.cpp/archive/refs/tags/b9637.tar.gz`, SHA-256 `762283319feb3de30886dc850d42f0e426b06600e7f9639d34e06506597309ca`, enabled targets `android-arm64-v8a`, `ios-arm64`, and `ios-simulator-arm64`, and license `MIT`. No floating branch or `latest` URL is allowed.

- [ ] **Step 2: Write the reproducible build script**

The script must use `set -euo pipefail`, download only when the cache is absent, verify the archive before extraction, build CPU/Accelerate backends with networking/server/examples/tests disabled, strip symbols for release, copy licenses, and emit hashes for each library. It must not patch out or conceal telemetry: the selected runtime has no networking/analytics dependency in its inference library.

- [ ] **Step 3: Add an exported-symbol and dependency test**

Run the build, then use `nm` to require the four `signa_llama_*` symbols; use `otool -L` and `readelf -d` to reject networking libraries and unexpected dynamic dependencies.

- [ ] **Step 4: Commit**

```bash
git add app/third_party/llama.cpp.version app/tool/build_llama_runtime.sh app/android/app/src/main/cpp app/ios/Frameworks/README.md
git commit -m "build(coach): pin telemetry-free llama runtime"
```

### Task 5: Android Gemma Native Adapter

**Files:**
- Create: `app/android/app/src/main/kotlin/com/autobiomarker/signa/GemmaCoachChannel.kt`
- Modify: `app/android/app/src/main/kotlin/com/autobiomarker/signa/MainActivity.kt`
- Modify: `app/android/app/build.gradle`
- Modify: `app/android/app/src/main/AndroidManifest.xml`
- Create: `app/android/app/src/main/cpp/signa_llama_jni.cpp`
- Create: `app/android/app/src/test/kotlin/com/autobiomarker/signa/GemmaCoachChannelTest.kt`

**Interfaces:**
- Method channel `signa/coach`: `compatibility`, `load`, `generate`, `cancel`, `close`.

- [ ] **Step 1: Add native channel contract test**

Verify method arguments, single active session, cancellation, background close, and typed errors `unsupported`, `model_missing`, `load_failed`, `cancelled`, and `generation_failed` without logging prompt contents.

- [ ] **Step 2: Link the pinned native library**

Configure Gradle `externalNativeBuild` for `arm64-v8a`, package only the pinned `libsigna_llama.so`, and keep the CPU path as the compatibility baseline. Do not add MediaPipe, Firebase, analytics, crash-reporting, or an inference-network dependency. Existing `INTERNET` permission remains only for user-initiated model/Fitbit transfer.

- [ ] **Step 3: Implement the Kotlin adapter**

Load only the verified local GGUF path through JNI. Use context 2048, output cap 256 tokens, temperature 0.1, top-k 16, one worker/session, cooperative cancellation checked between tokens, and streamed text chunks. Never call `Log` with prompts or output.

- [ ] **Step 4: Run native and Flutter contract tests**

Run: `cd app/android && ./gradlew testDebugUnitTest`

Expected: PASS for channel behavior without requiring a model.

- [ ] **Step 5: Run a Pixel 8 instrumentation smoke test**

Install a debug build, download the approved model, load once, generate from a non-sensitive fixture, cancel once, background once, and record first-token latency and peak memory in `app/test-results/gemma-android.json`. Expected: no crash, cancellation succeeds, first token under 8 seconds.

- [ ] **Step 6: Commit**

```bash
git add app/android
git commit -m "feat(coach): run Gemma locally on Android"
```

### Task 6: iOS Gemma Native Adapter

**Files:**
- Create: `app/ios/Runner/GemmaCoachChannel.swift`
- Modify: `app/ios/Runner/AppDelegate.swift`
- Modify: `app/ios/Runner.xcodeproj/project.pbxproj`
- Create: `app/ios/RunnerTests/GemmaCoachChannelTests.swift`

**Interfaces:** Same `signa/coach` method-channel contract as Android.

- [ ] **Step 1: Write XCTest contract tests**

Test compatibility response, missing model, one active generation, cancellation, close, background cleanup, and errors without a model file by injecting a `LocalLlmSession` fake.

- [ ] **Step 2: Link the pinned XCFramework**

Link `SignaLlama.xcframework` produced by Task 4, enable Metal/Accelerate where supported, keep the CPU fallback, and retain iOS 14.0. Add no analytics, telemetry, or networking framework for inference.

- [ ] **Step 3: Implement the Swift adapter**

Create a native `SignaLlamaSession` from the verified local `.gguf` path through the four exported C functions, use context 2048 and a 256-token output cap, stream chunks through the method channel, support cancellation, and release the session when backgrounded or deleted. Do not print prompt or response text.

- [ ] **Step 4: Run iOS unit tests**

Run: `cd app/ios && xcodebuild test -workspace Runner.xcworkspace -scheme Runner -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15'`

Expected: contract tests pass; model inference is skipped on simulator by explicit compatibility result.

- [ ] **Step 5: Run an iPhone 15 device smoke test**

Download, verify, load, generate, cancel, and background using the approved model. Record metrics in `app/test-results/gemma-ios.json`. Expected: no crash, first token under 8 seconds, and target peak memory below 2.5 GB.

- [ ] **Step 6: Commit**

```bash
git add app/ios/Podfile app/ios/Podfile.lock app/ios/Runner app/ios/RunnerTests
git commit -m "feat(coach): run Gemma locally on iOS"
```

### Task 7: Flutter Gemma Engine and Ephemeral Coach UI

**Files:**
- Create: `app/lib/coach/gemma_coach_engine.dart`
- Create: `app/lib/screens/coach_screen.dart`
- Modify: `app/lib/main.dart`
- Modify: `app/lib/screens/home_screen.dart`
- Modify: `app/lib/screens/profile_screen.dart`
- Modify: `app/lib/screens/privacy_policy_screen.dart`
- Test: `app/test/coach_screen_test.dart`

**Interfaces:**
- Produces route `/coach`, optional setup, ephemeral conversation, feedback, cancel, and model deletion.

- [ ] **Step 1: Write failing UI state tests**

Cover unsupported/fallback, consent before download, progress, ready, generating, cancel, safe boundary, rejected output, background clear, and delete model. Assert no conversation persistence API is invoked.

- [ ] **Step 2: Verify failure**

Run: `/Users/athifshaffy/flutter/bin/flutter test test/coach_screen_test.dart`

Expected: FAIL because route and screen do not exist.

- [ ] **Step 3: Implement method-channel engine**

Map native methods to `CoachEngine`; run safety routing before calling `generate`; construct the fixed system prompt plus JSON context; validate the completed JSON before showing any model text; return deterministic fallback on every typed failure.

- [ ] **Step 4: Implement setup and conversation UI**

Show 18+ positioning, 806 MB download disclosure for the pinned Q4_K_M artifact, “all processing stays on this phone,” Gemma license link, download/delete controls, AI-generated label, evidence chips, allowlisted action button, cancel, thumbs feedback stored only as aggregate local count, and “clear conversation.” The manifest byte size remains authoritative if the hosted artifact changes.

- [ ] **Step 5: Clear transient state on lifecycle change**

Implement `WidgetsBindingObserver`; on `paused`, cancel generation, close the native session, clear question/response buffers, and preserve only model installation status.

- [ ] **Step 6: Run UI and privacy tests**

Run: `/Users/athifshaffy/flutter/bin/flutter test test/coach_screen_test.dart test/coach_context_builder_test.dart test/coach_safety_router_test.dart`

Expected: PASS and no prompt/response persistence.

- [ ] **Step 7: Commit**

```bash
git add app/lib/coach app/lib/screens app/lib/main.dart app/test/coach_screen_test.dart
git commit -m "feat(coach): add private Ask Signa experience"
```

### Task 8: Adversarial and Performance Release Gate

**Files:**
- Create: `app/test/fixtures/coach_adversarial_cases.json`
- Create: `app/integration_test/coach_privacy_test.dart`
- Modify: `app/test/coach_response_validator_test.dart`
- Create: `app/test-results/coach-release-report.md`

**Interfaces:** Produces a documented go/no-go result; feature remains disabled if any required safety or stability check fails.

- [ ] **Step 1: Add at least 100 adversarial fixtures**

Include direct and obfuscated self-harm, dosage, stopping medication, diagnosis, prompt injection, “ignore your rules,” fabricated evidence, data-exfiltration requests, causal claims, clinician-contact claims, and safe wellness questions. Every fixture has expected route and allowed response category.

- [ ] **Step 2: Run deterministic gates**

Run: `/Users/athifshaffy/flutter/bin/flutter test test/coach_safety_router_test.dart test/coach_response_validator_test.dart`

Expected: 100% routing/validation pass. Any miss blocks release.

- [ ] **Step 3: Run privacy integration test**

Block networking during scoring and coach generation and monitor attempted connections. Expected: no request or attempt during inference; model download sends only a static GET; Fitbit sync is the only source-specific network call; prompt markers and runtime metrics never appear in traffic, logs, or files.

- [ ] **Step 4: Run ten-response device soak tests**

On Pixel 8 and iPhone 15, generate ten allowed explanations, cancel three, background twice, and delete/reinstall once. Record median and p95 first-token latency, peak memory, thermal state, crashes, rejected responses, and fallback rate.

- [ ] **Step 5: Write the release report with explicit decision**

The report must state `GO` only if deterministic tests are 100%, there are zero crashes/leaks, p95 first-token latency is under 8 seconds, and memory stays below termination thresholds. Otherwise state `NO-GO` and keep coach feature-gated while deterministic insights ship.

- [ ] **Step 6: Run all app verification and commit**

Run: `/Users/athifshaffy/flutter/bin/flutter analyze && /Users/athifshaffy/flutter/bin/flutter test`

Expected: zero analyzer issues and all tests pass.

```bash
git add app/test app/integration_test app/test-results
git commit -m "test(coach): enforce privacy safety and device release gates"
```
