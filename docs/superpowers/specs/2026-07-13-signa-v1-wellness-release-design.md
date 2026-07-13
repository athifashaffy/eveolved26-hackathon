# Signa v1 Wellness Release Design

**Date:** 2026-07-13  
**Status:** Approved for implementation planning  
**Product:** Signa mobile app for iOS and Android

## 1. Summary

Signa v1 will be a patient-owned mental-wellness app for people who already use a smartwatch or health platform. It will help users understand how their HRV, sleep, activity, and optional mood check-ins change relative to their own baseline.

The public app will not diagnose depression, estimate clinical depression risk, claim that a clinician has been notified, or present itself as a cleared medical device. It will use an explainable, on-device personal baseline engine while the research model is repaired and validated separately.

The first clinic-facing capability will be a patient-controlled report rather than a live clinic portal. A consent-based portal may follow as a controlled pilot after the public app is stable.

The visual identity will use the approved **Signal S** direction: a calm continuous signal forming an S, with two points representing wearable data and self-reported context becoming one understandable story.

## 2. Why the Current Model Cannot Ship

The repository contains useful exploratory research, but neither saved model is suitable for a public depression-risk feature.

Key audit findings:

- The mobile app does not execute `best_model.pkl` or `cross_dataset_model.pkl`. Apple Health and Fitbit readings currently receive a hand-written score of 60% normalized HRV plus 40% normalized sleep.
- The best recorded subject-level result is AUC 0.6875 and F1 0.5882 on 49 subjects. The combined cross-dataset result is AUC 0.596.
- The Baigutanova model searches hundreds of derived features with only 49 subjects. Selecting the best result after comparing many model and feature-set combinations makes the reported maximum optimistic unless model selection is nested inside an outer validation loop.
- Interaction AUC uses the two main effects and their product, but the reported permutation p-value and Cohen's d use only the first feature. Therefore, the current statistical test does not establish that the interaction itself is significant.
- The bootstrap AUC interval samples daily predictions as though they were independent even though multiple rows belong to the same subject.
- Baseline PHQ-9 is copied across the 28-day window. This supports exploratory cross-sectional classification, not early warning, relapse prediction, or treatment-response monitoring.
- A 28-day rolling feature inside a 28-day study has too little independent history for robust temporal inference.
- Fitbit HRV is estimated from resting heart rate in the app rather than read as an actual HRV measurement.
- The saved `best_model` metadata and current training source are inconsistent: the metadata describes an artifact that the current script no longer writes.

These findings do not mean the research has no value. They mean it should be presented as hypothesis-generating and used to design a better longitudinal study, not as the engine of a consumer medical claim.

## 3. Product Goals

Signa v1 will:

1. Connect to Apple Health, Android Health Connect, and Fitbit using only the permissions required for visible user features.
2. Learn an individual's normal range from their own recent data.
3. Present an explainable daily Signa Score with a separate confidence indicator.
4. Let users add mood, sleep-quality, treatment, illness, travel, and stress context.
5. Show 7-, 30-, and 90-day trends without implying diagnosis.
6. Produce a clinician-ready PDF and detailed CSV/JSON export controlled by the user.
7. Work without a cloud account for the initial release.
8. Offer an optional, private on-device Gemma wellness coach on supported devices, with deterministic guidance as the fallback.
9. Pass real-device closed beta testing before public store submission.

## 4. Non-Goals for v1

Signa v1 will not:

- Diagnose, treat, cure, prevent, or predict depression.
- Display a clinical threshold or label such as "depressed," "at risk," or "transition detected."
- Automatically notify a clinician, emergency service, family member, or caregiver.
- Claim Health Canada, FDA, or other medical-device clearance.
- Replace professional medical advice or crisis support.
- Upload raw health history to a Signa server.
- Train a population model from production users without separate, explicit research consent and applicable ethics approval.
- Launch a production clinic portal.
- Let a generative model diagnose a condition, recommend medication or treatment changes, provide crisis counselling, or calculate the Signa Score.

## 5. User Experience

### 5.1 Onboarding and consent

The app first explains what Signa does, what it does not do, and that it needs approximately two weeks of data before showing a stable personal score. The user chooses a data source and sees a plain-language explanation for each requested data type before the operating-system permission sheet appears.

Health authorization must not run automatically at app startup. Permission denial leaves the user in a recoverable setup state with manual check-ins and instructions for reconnecting later.

### 5.2 Baseline learning

The baseline experience shows progress rather than a premature score. A baseline becomes ready when Signa has at least 10 eligible days within a rolling 14-day period. An eligible day must contain sleep and either HRV or activity. Mood is optional.

If the requirement is not met after 14 calendar days, learning continues and the app explains which data is missing. It never fills a missing physiological value with zero.

### 5.3 Today

The Today screen contains:

- Signa Score from 0 to 100.
- Status language limited to wellness terms such as "steady," "mixed signals," or "worth a check-in."
- Data confidence: high, medium, or low.
- A concise "why it changed" explanation naming the strongest positive and negative contributors.
- HRV, sleep, and activity cards showing values relative to the user's baseline.
- One gentle, non-medical suggestion when the data supports it.

The score must never be shown without its confidence and explanation.

### 5.4 Daily check-in and timeline context

The optional check-in records mood and perceived sleep on five-point scales. Users can add a short note and timeline markers for medication change, therapy change, illness, travel, unusual stress, alcohol, or a custom event.

Check-ins are skippable. The app must not use guilt, streak loss, or alarming notifications to force engagement.

### 5.5 Trends

Trends display the Signa Score and its components over 7, 30, and 90 days. Timeline markers appear on the same chart. Insights describe correlations or sustained deviations as observations, not causes.

Examples:

- Allowed: "Your sleep timing was less consistent than your recent baseline this week."
- Not allowed: "Your depression risk increased because your sleep worsened."

### 5.6 Clinician-ready sharing

The user can generate a 7-, 30-, or 90-day report containing:

- Date range and data completeness.
- Signa Score trend and component trends.
- Mood and perceived-sleep check-ins.
- User-entered treatment and lifestyle markers.
- Plain-language scoring explanation and wellness disclaimer.
- Data source and last synchronization time.

The default PDF is concise and readable during an appointment. CSV/JSON remains available for detailed analysis. Export is always user initiated.

## 6. Personal Baseline Engine

### 6.1 Purpose

The v1 engine is an explainable wellness index, not a trained depression classifier. It estimates how stable the user's recent signals are relative to that user's own history.

### 6.2 Inputs

The normalized daily input record contains:

- Date and local time zone.
- HRV value and measurement type/source.
- Sleep duration and sleep-window midpoint when available.
- Steps or equivalent daily activity.
- Optional mood and perceived-sleep ratings.
- Data-source provenance and completeness flags.
- Optional timeline markers.

Source-specific measurements must not be presented as interchangeable without provenance. The engine resets or enters a recalibration state after a material source change.

### 6.3 Baseline calculation

After the initial learning period, the engine maintains a trailing 28-valid-day baseline per component. It uses robust statistics - median and median absolute deviation - so isolated extreme readings do not dominate the baseline.

Each available component becomes a 0-100 subscore based on its deviation and recent consistency:

- **HRV:** deviation from the personal HRV range, with source-specific handling.
- **Sleep:** duration relative to the personal range plus sleep-timing consistency when available.
- **Activity:** deviation from the personal activity range, avoiding an assumption that more activity is always better.
- **Mood:** direct user rating smoothed over recent check-ins; it remains visibly self-reported.

For v1, the transformation is explicit and deterministic. For each objective component, the robust scale is the largest of `1.4826 * MAD`, 5% of the absolute baseline median, and a small domain-specific non-zero floor. The normalized deviation is `abs(current - median) / robust_scale`. The component stability score is `100 * exp(-0.5 * (deviation / 2)^2)`, rounded to the nearest integer. This treats unusual upward and downward changes as deviations; the UI must explain that Signa measures stability, not athletic performance.

The current observation is defined per component:

- HRV uses the median of the latest three valid days to reduce sensor noise.
- Sleep combines last-night duration stability (70%) and sleep-midpoint stability (30%); if midpoint is unavailable, duration receives the full sleep weight.
- Activity uses the trailing seven-valid-day mean so one rest day does not appear abnormal.
- Mood maps the five-point rating to 0, 25, 50, 75, or 100 and averages the latest three check-ins from the last seven days.

Initial provisional weights are HRV 35%, sleep 35%, activity 15%, and mood 15%. If an optional component is absent, available weights are renormalized and confidence decreases. These weights are versioned configuration, not hidden constants, and will be evaluated during beta for comprehension and stability. A version change requires release notes and regression tests.

Subscores and the final score are clamped to 0-100. The app stores the score version and component contributions with every computed day so historical explanations remain reproducible.

### 6.4 Confidence

Confidence is separate from wellness state:

- **High:** all objective components are present and the baseline contains at least 21 valid days.
- **Medium:** baseline is ready and at least two objective components are present.
- **Low:** the minimum baseline exists but only one objective component is usable, data is stale, or a source recalibration is active.

If the baseline minimum is not met, no numeric score is shown.

### 6.5 Insight rules

Automatic insights are deterministic templates selected from component contributions and data-quality state. They must be traceable to values shown in the UI. Gemma may explain these approved facts or offer an allowlisted wellness action only after the user explicitly opens Ask Signa; it never selects or calculates an automatic health insight.

## 7. Optional On-Device Gemma Coach

### 7.1 Purpose and positioning

The optional **Ask Signa** coach helps an adult user understand the facts already calculated by Signa and prepare low-risk next steps. It is an explanation layer, not the scoring engine, a therapist, a clinician, or an unrestricted health chatbot.

The first release is intended for users aged 18 and older. The coach is labeled as AI-generated, and every answer reminds the user that Signa is a wellness tool when the question approaches medical interpretation.

### 7.2 Deployment

The reference model is the instruction-tuned Gemma 3 1B checkpoint in a supported 4-bit mobile format, executed on-device through the native Google AI Edge mobile runtime on Android and iOS. The Flutter layer communicates with small, platform-specific adapters behind a shared `CoachEngine` interface.

The model is not part of the initial app download. A supported user may explicitly download it from the Coach screen, preferably over Wi-Fi. The artifact and signed version manifest are hosted as static files on a first-party Signa-controlled endpoint; the download request carries no health or coach data. The app shows the download size, license/notice, privacy behavior, and delete option before consent. The downloaded artifact is checksum-verified, versioned, and removable without deleting the user's Signa history.

Devices that fail compatibility, memory, or performance checks use the deterministic Insight Engine. The rest of Signa must never depend on Gemma availability.

### 7.3 Grounded input

Gemma never receives raw HealthKit/Health Connect records, OAuth tokens, exported reports, or the user's private free-form notes. `CoachContextBuilder` creates a minimal structured context containing only:

- Current Signa Score, score version, and confidence.
- Available component scores and their reviewed explanations.
- Approved 7-day trend statements from the deterministic Insight Engine.
- User-selected timeline-marker categories, without note text.
- The current user question.

The coach has no network tools, browser, clinical-record retrieval, or memory across sessions. Chat history is ephemeral in v1 and is cleared when the Coach screen closes.

### 7.4 Constrained output

The model must return a structured response with:

- A short explanation grounded in supplied fact identifiers.
- Zero or more evidence identifiers from the provided context.
- At most one action identifier from a reviewed, versioned wellness-action allowlist.
- A response category such as `explanation`, `reflection`, `professional_support`, or `decline`.

The app rejects and replaces a response if it cites an unknown fact, proposes an action outside the allowlist, contains prohibited diagnostic/treatment language, or does not parse. The replacement is a deterministic explanation or a clear statement that Signa cannot answer safely.

Allowed actions are limited to low-risk behaviors such as keeping a consistent sleep window, reflecting on a recent change, completing a check-in, reviewing a trend, preparing questions for a healthcare professional, or contacting an appropriate professional for medical advice.

### 7.5 Safety routing

Before inference, a deterministic safety router identifies questions about self-harm, suicide, immediate danger, medication dosage, stopping or starting treatment, diagnosis, or other high-risk medical decisions.

- Crisis or immediate-danger language bypasses Gemma entirely and displays localized crisis/emergency resources plus encouragement to contact a trusted person or qualified professional.
- Medication, diagnosis, and treatment questions receive a deterministic boundary message and an option to prepare questions for a clinician.
- Prompt-injection attempts cannot add data, tools, permissions, or actions to the coach context.

The coach must not claim certainty, causal relationships, clinician endorsement, or that a clinician has been contacted.

### 7.6 Performance acceptance criteria

On the reference Pixel 8 and iPhone 15 devices, a normal coach response should begin within 8 seconds, peak memory must remain below the platform-specific termination threshold with a target below 2.5 GB, and the app must remain responsive during inference. Devices that cannot meet the safety and stability thresholds do not expose the generative coach.

Model generation is cancellable. Backgrounding the app cancels inference and clears transient prompt buffers.

## 8. Technical Architecture

The Flutter application remains the shared iOS and Android codebase. The design introduces clear boundaries:

- `HealthDataSource`: interface implemented by HealthKit, Health Connect, Fitbit, and demo adapters.
- `DailySignalRepository`: stores normalized daily records and provenance locally.
- `BaselineEngine`: pure, deterministic scoring and confidence calculation.
- `InsightEngine`: converts score contributions into reviewed wellness-language templates.
- `CoachContextBuilder`: creates minimal fact-grounded context for the optional coach.
- `CoachSafetyRouter`: handles crisis, diagnosis, treatment, medication, and prohibited-request boundaries before inference.
- `CoachEngine`: interface implemented by on-device Gemma and deterministic fallback adapters.
- `CheckInRepository`: stores self-reports and timeline markers.
- `ReportService`: produces clinician PDF and CSV/JSON exports.
- `AppSettings`: permissions, active source, baseline state, score version, and privacy preferences.

The UI consumes immutable view models rather than calculating health scores inside source adapters. HealthKit and Fitbit adapters only retrieve and normalize data.

The research pipeline under `src/` remains independent from the release app. No pickle artifact is bundled into Flutter v1.

## 9. Data Protection and Privacy

- Raw and derived health data remain in the operating system's protected app sandbox for v1. Health database files are excluded from unencrypted backups.
- OAuth tokens remain in platform secure storage.
- The app requests the minimum health permissions required for HRV, sleep, and activity features.
- The user can export and permanently delete all Signa data.
- Logs and crash reports must not contain health values, notes, OAuth tokens, or personal identifiers.
- No advertising SDK may receive health data or health-derived audience information.
- Gemma inference and coach safety processing remain on-device. Coach prompts and responses are not logged, uploaded, used for analytics, or used for model training.
- Downloaded model artifacts contain no user data and can be deleted independently.
- The public privacy policy and in-app policy must describe the same behavior.
- Any future research contribution or clinic sharing requires a separate, explicit consent flow.

## 10. Failure and Edge-Case Behavior

- Missing data stays missing; it is never converted to zero.
- A failed sync preserves the last valid view and displays its timestamp.
- Revoked permissions produce reconnection instructions without repeated permission harassment.
- Unsupported Health Connect versions or unavailable HealthKit capabilities produce a compatible-device explanation.
- Time-zone changes preserve the original local date and prevent duplicate days.
- Source switching triggers provenance-aware recalibration.
- Implausible values are quarantined from scoring and recorded as data-quality issues.
- Report generation failure leaves data unchanged and offers a retry.
- A failed, cancelled, incompatible, or out-of-memory coach session returns to deterministic insights without affecting health synchronization or stored scores.
- Invalid, ungrounded, or unsafe model output is never partially displayed.
- No error state may display a fabricated alert, clinical conclusion, or clinician-notified status.

## 11. Brand and Visual Direction

The production logo will follow the approved **Signal S** concept:

- A continuous signal or ribbon forming an S.
- Two secondary points representing wearable and self-reported context.
- Calm, warm, and trustworthy rather than hospital-like.
- Recognizable at 32 px and compatible with iOS and Android icon masks.
- No medical cross, diagnostic symbolism, brain silhouette, or detailed watch illustration.

The existing primary navy remains the anchor color. Warm cream, green, and amber may be retained as supporting colors. Final deliverables include the 1024x1024 App Store source icon, Android adaptive foreground/background assets, launcher sizes, and an in-app mark. The master should be vector-friendly even if store assets are exported as PNG.

## 12. Testing and Verification

### 11.1 Automated tests

- Baseline readiness and rolling-window behavior.
- Robust statistics and every component subscore.
- Weight renormalization and confidence levels.
- Missing, stale, duplicate, extreme, and source-switch data.
- Deterministic insight selection and prohibited-language checks.
- Coach context minimization and proof that raw records, free-form notes, and secrets cannot enter the prompt.
- Structured-output parsing, evidence grounding, action allowlisting, and deterministic fallback behavior.
- Crisis, self-harm, medication, diagnosis, treatment, prompt-injection, and adversarial-language fixtures.
- Coach cancellation, backgrounding, model deletion, corrupt download, checksum failure, low storage, unsupported hardware, and out-of-memory recovery.
- Health source normalization with fixture data.
- Database creation, migration, export, and deletion.
- PDF, CSV, and JSON report content.
- Onboarding, permission-denial, reconnect, and empty-state widgets.
- Accessibility labels and text scaling.

### 11.2 Release verification

- `flutter analyze` returns no warnings or errors.
- All Flutter tests pass.
- Android App Bundle and iOS archive build successfully in release configuration.
- Health Connect permissions match the Play Console declaration.
- HealthKit entitlements and usage descriptions match actual use.
- Dark and light themes, small screens, and large text are manually reviewed.
- Real-device tests cover at least one supported iPhone, one recent Android device, and a representative Fitbit account.
- Gemma latency, memory, thermal behavior, and battery impact meet the acceptance criteria on the reference devices before the feature is enabled for production.
- Privacy policy, screenshots, store descriptions, and in-app claims are reviewed together.

## 13. Release Plan

1. Repair architecture and scoring under tests.
2. Replace clinical or fabricated claims throughout the app.
3. Implement the deterministic Insight Engine and the optional Gemma coach behind the shared safety boundary.
4. Generate and integrate the Signal S production assets.
5. Complete HealthKit and Health Connect permissions, entitlements, AI disclosures, model notices, and privacy declarations.
6. Produce internal iOS and Android release builds.
7. Run TestFlight and Google Play closed testing, with the coach initially feature-gated.
8. Conduct a 20-50 user baseline pilot and a focused coach-safety/usability evaluation.
9. Fix reliability, comprehension, safety, and retention issues.
10. Submit to the public App Store and Google Play.
11. Begin a separate clinician-report pilot after the consumer release is stable.

Actual store submission requires authorized access to the owner's Apple Developer and Google Play Console accounts, signing identities, agreements, tax/banking setup where applicable, and final approval of store metadata.

## 14. Adoption Design

The initial product promise is: **Learn your personal baseline in 14 days and understand how sleep, recovery, activity, and mood move together.**

Initial channels:

- Smartwatch and quantified-self communities.
- University and workplace wellness groups.
- Existing hackathon, research, and clinical-advisor networks.
- Small clinician partnerships where patients bring Signa reports to appointments.

The product loop is:

1. Connect a data source.
2. Complete baseline learning.
3. Receive an understandable weekly insight.
4. Optionally ask Signa to explain the insight in plain language.
5. Add context through lightweight check-ins.
6. Generate or share a report.
7. Continue monitoring to compare future weeks with the personal baseline.

Primary launch metrics:

- Health-source connection success.
- Baseline completion rate.
- Day-7, day-14, and week-4 retention.
- Weekly check-in completion without coercive reminders.
- Percentage of active users viewing an explanation.
- Coach opt-in, successful on-device model setup, safe-answer rate, deterministic-fallback rate, response feedback, and repeat coach use.
- Report generation and voluntary sharing.
- Crash-free sessions and sync reliability.

Download count is secondary because it does not measure whether Signa becomes useful.

## 15. Future Clinic Pilot

The first portal pilot will be specified separately. Its likely boundaries are clinic invitation codes, explicit patient consent and revocation, derived trend sharing, PHQ-9 alongside wearable patterns, treatment annotations, follow-up reminders, and clinic-level access controls.

It will not be added to v1 implicitly. Security, privacy, regulatory positioning, incident response, and clinical workflow require their own approved design and validation plan.

## 16. Research Evolution

The research program should:

1. Correct interaction statistics so inference tests the interaction term.
2. Use subject-clustered resampling and nested model selection.
3. Pre-register a small feature set and primary outcome before validation.
4. Collect repeated symptom measures during follow-up rather than copying baseline PHQ-9 across days.
5. Validate temporal predictions on future observations and an untouched external cohort.
6. Measure calibration, sensitivity, specificity, decision thresholds, and subgroup performance in addition to AUC.
7. Keep exploratory discovery results separate from confirmatory evidence.

Only a locked, prospectively validated model with appropriate regulatory review may later replace or augment the public wellness engine.
