# Signa V1 Execution Roadmap

The approved release is split into three independently testable plans. Execute them in this order because each later plan consumes contracts and UI states from the earlier one.

1. `2026-07-13-signa-core-wellness-app.md`
   - Replaces fabricated/prototype scores with the deterministic personal-baseline engine.
   - Delivers consent-first health access, explainable Today/Trends, check-ins, clinician PDF/CSV, and deletion.
   - This core remains useful and releasable without Gemma.
2. `2026-07-13-signa-on-device-gemma-coach.md`
   - Adds the optional, feature-gated Gemma 3 1B coach.
   - Uses pinned `llama.cpp`, not MediaPipe Tasks, so inference produces no third-party runtime telemetry.
   - A signed static model download is the only coach network transfer; prompts, responses, health facts, notes, and metrics stay on the phone.
3. `2026-07-13-signa-brand-and-store-release.md`
   - Produces the approved Signal S assets, native permissions, signing configuration, policies, listings, screenshots, closed-test builds, and submission gates.

At the end of every task, run its focused tests and commit only the paths named in that task. At the end of each plan, run `superpowers:verification-before-completion` before advancing. Preserve the current unrelated iOS generated files and untracked workspace artifacts.

## Release Boundary

Repository implementation can reach verified Android/iOS closed-test candidates. Actual TestFlight or Google Play upload begins only after the user supplies owner-controlled developer accounts, signing credentials, public privacy/support URLs, and confirms the final legal/store copy. Production rollout remains blocked until the coach device report is `GO`; if it is `NO-GO`, ship the deterministic core with the coach disabled.
