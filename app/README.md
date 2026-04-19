# Signa — Patient Mobile App

Flutter app for the AutoBiomarker / Signa platform. Reads HRV + sleep from Apple HealthKit (and Fitbit, post-auth milestone) and surfaces a daily **Stability Score** derived from the HRV × sleep interaction biomarker.

Design follows the Signa Stitch project ("Clinical Curator" system — `#1d3789` primary, Manrope + Inter, tonal layering, no hard borders).

## Screens

| Route       | Purpose                                                            |
|-------------|--------------------------------------------------------------------|
| `/`         | Onboarding / Welcome (Patient vs Clinician)                        |
| `/home`     | Stability Score gauge, HRV + Sleep cards, 14-day history, device   |
| `/trends`   | HRV × Sleep interaction chart (7/30/90d), summary + insight        |
| `/connect`  | HealthKit authorization, device grid (Apple Watch, Fitbit, Manual) |
| `/profile`  | Clinician link, alerts, privacy, export                            |
| `/alert`    | Transition-warning detail (alert sent to clinician)                |

## Run

```bash
flutter pub get
flutter run -d <ios-simulator-id>     # HealthKit requires iOS
flutter test                          # widget smoke test
```

## HealthKit

Configured in `ios/Runner/Info.plist` with `NSHealthShareUsageDescription`. The HealthKit capability still needs to be enabled in Xcode (Signing & Capabilities → +Capability → HealthKit). iOS deployment target is `12.0` (see `ios/Podfile`).

## Layout

```
lib/
├── main.dart                 # GoRouter + theme bootstrap
├── theme/
│   ├── app_colors.dart       # Signa design tokens
│   └── app_theme.dart        # Material 3 theme + typography
├── data/
│   ├── models.dart           # StabilitySnapshot, StabilityReading
│   ├── mock_data.dart        # 14/30-day synthetic scores
│   └── healthkit_service.dart # HRV / sleep reads via `health` pkg
├── widgets/
│   ├── signa_scaffold.dart   # Shared bottom nav
│   ├── top_app_bar.dart      # Welcome / titled variants
│   └── status_badge.dart     # Stable / Monitoring / Alert pill
└── screens/
    ├── onboarding_screen.dart
    ├── home_screen.dart
    ├── connect_screen.dart
    ├── trends_screen.dart
    ├── alert_screen.dart
    └── profile_screen.dart
```

Stitch source references are stashed in `design_refs/` (downloaded HTML exports).
