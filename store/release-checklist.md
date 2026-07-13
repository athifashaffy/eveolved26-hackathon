# Signa closed-test release checklist

## Repository gates

- [x] Bundle/package ID is `com.autobiomarker.signa`.
- [x] Version is `1.0.1+5`.
- [x] Health access is read-only and requested after consent.
- [x] Analyzer has zero issues and unit/widget tests pass.
- [x] Android release no longer uses debug signing.
- [x] Android debug APK built locally on July 13, 2026.
- [x] iOS simulator debug app built locally on July 13, 2026.
- [ ] Run physical iPhone and Android privacy/destructive-flow tests.

## Owner-controlled inputs

- [ ] Confirm legal owner/responsible entity.
- [ ] Supply and monitor a support email.
- [ ] Publish privacy and support pages at stable HTTPS URLs.
- [ ] Complete owner/legal/privacy review of wellness and coach copy.
- [ ] Supply Apple Developer team/provisioning through Xcode or CI.
- [ ] Supply `android/key.properties` and owner-held upload keystore.
- [ ] Configure Fitbit production OAuth credentials and redirect registration.
- [ ] Complete Apple privacy, HealthKit, age, and export-compliance forms.
- [ ] Complete Google Data safety, Health apps, Health Connect, and age forms.
- [ ] Include Gemma/llama.cpp notices before enabling native Gemma.

## Gemma release gate

- [x] Deterministic safety routing, fact minimization, output validation, signed
  model manifest, checksum, atomic install, and fallback are tested.
- [ ] Build pinned native llama.cpp runtime for iOS and Android.
- [ ] Pass 100+ adversarial cases with zero routing misses.
- [ ] Pixel 8 and iPhone 15: ten-answer soak, cancel, background, delete/reinstall.
- [ ] p95 first token below 8 seconds and memory below termination threshold.
- [ ] Verify zero prompt/response/health/log/network leakage during inference.
- [ ] Change decision from NO-GO to GO in the coach release report.

Until every unchecked Gemma gate passes, the native model stays disabled and
Ask Signa uses reviewed deterministic on-device explanations.

## Rollout

- [ ] TestFlight internal testing first.
- [ ] Google Play closed testing first.
- [ ] Recruit only consented 20–50 person pilot cohort.
- [ ] Name rollback owner and 24-hour contact.
- [ ] Record signed `.ipa`/`.aab` SHA-256 hashes without committing binaries.
