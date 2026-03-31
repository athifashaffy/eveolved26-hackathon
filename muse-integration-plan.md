# Muse EEG Integration Plan — AutoBiomarker

## Goal
Add Muse headband EEG as a 3rd modality alongside HRV + sleep. Apply the same critical slowing down framework to neural data. Test whether triple-interaction (HRV x sleep x EEG) produces a stronger depression signal than the current dual-interaction (AUC 0.78).

---

## Phase 1: Data Collection Pipeline (Week 1-2)

### Hardware
- **Device:** Muse 2 or Muse S (both 256 Hz, 4 EEG channels)
- **Channels:** AF7 (left frontal), AF8 (right frontal), TP9 (left temporal), TP10 (right temporal)
- **Additional sensors:** Accelerometer (52 Hz), Gyroscope (52 Hz), PPG (Muse S only, 64 Hz)

### SDK Choice
| Option | Platform | Best For |
|---|---|---|
| **BrainFlow** (recommended) | Python, cross-platform | Research prototype, integrates with our numpy/scipy stack |
| **MuseLSL** | Python, desktop only | Quick prototyping, LSL streaming |
| **Muse Monitor app** | iOS/Android | Mobile data collection, CSV export |
| **muse-js** | Browser (Chrome) | Web-based demo |

**Recommendation:** Start with **BrainFlow** for the research pipeline (Python, same as our existing stack). Use **Muse Monitor** on mobile for data collection in the field.

### Recording Protocol
- **Duration:** 10 minutes per session (expect ~5 min clean data after artifact rejection)
- **Condition:** Eyes-closed resting state (cleaner signal, fewer blink artifacts)
- **Frequency:** Daily (same as HRV/sleep — enables temporal dynamics analysis)
- **Timing:** Morning, before caffeine/exercise (controls confounders)

### Data Format
```
timestamp, TP9, AF7, AF8, TP10  (raw EEG in microvolts, 256 Hz)
timestamp, acc_x, acc_y, acc_z   (accelerometer, 52 Hz)
```

---

## Phase 2: Feature Extraction (Week 2-3)

### Primary Feature: Frontal Alpha Asymmetry (FAA)

**What it is:** Log ratio of alpha power between right and left frontal electrodes. The most studied EEG depression biomarker.

**Computation:**
```python
from scipy.signal import welch
import numpy as np

def compute_faa(af7_data, af8_data, fs=256):
    """Compute Frontal Alpha Asymmetry from Muse AF7/AF8 channels."""
    # Power spectral density via Welch's method
    freqs_l, psd_l = welch(af7_data, fs=fs, nperseg=fs*2)
    freqs_r, psd_r = welch(af8_data, fs=fs, nperseg=fs*2)

    # Extract alpha band (8-13 Hz)
    alpha_mask = (freqs_l >= 8) & (freqs_l <= 13)
    alpha_left = np.mean(psd_l[alpha_mask])
    alpha_right = np.mean(psd_r[alpha_mask])

    # FAA = ln(right) - ln(left)
    # Positive = greater left frontal activity (healthy)
    # Negative = reduced left frontal activity (depression-associated)
    faa = np.log(alpha_right) - np.log(alpha_left)
    return faa
```

**Literature:**
- Davidson (1992, 1998) — approach-withdrawal model
- Thibodeau et al. (2006) meta-analysis — d = 0.35 for FAA-depression relationship
- van der Vinne et al. (2017) — updated meta-analysis, d ~ 0.1-0.3

### Secondary Features

| Feature | Channels | Formula | Depression Relevance |
|---|---|---|---|
| **Alpha power (absolute)** | AF7, AF8 | Mean PSD 8-13 Hz | Reduced alpha = hyperarousal |
| **Theta/Beta ratio** | AF7, AF8 | Mean theta PSD / Mean beta PSD | Elevated = emotional dysregulation |
| **Beta power** | AF7, AF8 | Mean PSD 12-30 Hz | Elevated = rumination, anxiety |
| **Alpha variability (CSD)** | AF7, AF8 | Rolling std of daily alpha power | Rising variability = destabilization |
| **FAA autocorrelation (CSD)** | AF7, AF8 | Rolling autocorr of daily FAA | Rising autocorr = critical slowing |
| **Blink rate** | AF7, AF8 | Detect blink artifacts, count/min | Low blink rate = low dopamine = anhedonia |

### Temporal Dynamics (same framework as HRV/sleep)
Apply `feature_extractor.py` logic to EEG features:
- Rolling mean, std, CV, slope, autocorrelation
- Windows: 3, 5, 7, 14, 21 days
- Per-subject z-scoring

This gives us ~50 additional temporal features from EEG alone.

---

## Phase 3: Preprocessing & Artifact Rejection (Week 2-3)

### Pipeline
```
Raw EEG (256 Hz)
    → Bandpass filter (1-40 Hz, 4th order Butterworth)
    → Notch filter (50/60 Hz for power line noise)
    → Epoch into 2-second windows
    → Reject epochs where amplitude > 100 uV (blinks, muscle)
    → Reject epochs where variance < 1 uV (flat line / lost contact)
    → Compute PSD on clean epochs (Welch's method)
    → Extract band powers and asymmetry
```

### Expected Data Loss
- **30-50% of epochs rejected** (blinks, movement, poor contact)
- 10 min recording → ~5 min clean data → sufficient for reliable FAA
- Minimum: 2 min clean data needed per session

### Quality Indicators
- Signal quality from electrode contact variance
- Percentage of clean epochs (reject session if < 50%)
- Flag sessions with high artifact rate in dashboard

---

## Phase 4: Triple-Interaction Hypothesis Testing (Week 3-4)

### The Core Hypothesis
```
Current best:  HRV_slope × sleep_dynamics = AUC 0.78, d = 1.11

New hypotheses to test:
1. FAA_trend × HRV_slope × sleep_dynamics        (triple interaction)
2. FAA_variability × HRV_variability              (dual CSD: neural + autonomic)
3. alpha_autocorr × sleep_autocorr                (dual CSD: neural + behavioral)
4. FAA × sleep_duration_autocorr                  (neural-behavioral interaction)
5. theta_beta_ratio_slope × HRV_slope             (emotional regulation x autonomic)
```

### Use the Existing Autoresearch Engine
- Feed new EEG features into `feature_extractor.py`
- Generate hypotheses via `run_until_significant.py` (same LLM-guided loop)
- Same evaluation: LOSO-CV, permutation tests, BH-FDR
- Same validation: hold-out, cross-dataset (if EEG depression datasets available)

### Expected Outcome
- FAA alone: d ~ 0.2-0.4 (literature consensus — weak)
- FAA × HRV interaction: potentially d > 0.5 (untested, our hypothesis)
- Triple interaction: potentially d > 1.0 (if CSD theory holds across 3 systems)

---

## Phase 5: Mobile App Architecture (Week 4-6)

### Data Flow
```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│  Wrist       │    │  Muse        │    │  App         │
│  Wearable    │    │  Headband    │    │  (Optional)  │
│  (24/7)      │    │  (10 min/day)│    │  PHQ-9/GAD-7 │
│              │    │              │    │              │
│  HRV data    │    │  EEG data    │    │  Mood log    │
│  Sleep data  │    │  Alpha/FAA   │    │  Symptoms    │
└──────┬───────┘    └──────┬───────┘    └──────┬───────┘
       │                   │                   │
       └───────────────────┼───────────────────┘
                           │
                    ┌──────▼───────┐
                    │  Mobile App  │
                    │  Data Hub    │
                    ├──────────────┤
                    │ ML Model:    │
                    │ HRV × Sleep  │ ◄── Model input (objective only)
                    │ (× EEG)     │
                    ├──────────────┤
                    │ Display:     │
                    │ • Stability  │
                    │   score      │
                    │ • Trends     │
                    │ • Mood log   │ ◄── Display only (not model input)
                    │ • Alerts     │
                    └──────┬───────┘
                           │
                    ┌──────▼───────┐
                    │  Clinician   │
                    │  Dashboard   │
                    │              │
                    │ • Patient    │
                    │   trajectory │
                    │ • Objective  │
                    │   + subjective│
                    │   side by    │
                    │   side       │
                    │ • Alerts     │
                    └──────────────┘
```

### Key Design Principle
- **Model input:** HRV + Sleep + EEG only (purely objective)
- **Questionnaire:** Display layer only, never feeds into model
- **Why:** Patients who drop out stop answering questionnaires. The wearable signal must work without them.

---

## Phase 6: Prospective Validation Study (Week 6-12)

### Study Design
- **Collaboration:** Prof. Dr. Steffen Moritz, University of Hamburg
- **N:** 200+ subjects (power analysis for d = 0.5, alpha = 0.05, power = 0.80)
- **Duration:** 8 weeks per subject (vs. 28 days in pilot)
- **Measures:**
  - Wearable HRV + sleep (24/7)
  - Muse EEG (10 min/day resting state)
  - PHQ-9 weekly (ground truth, not model input)
  - Treatment records (medication, therapy sessions)
- **Primary endpoint:** Can HRV × sleep × EEG interaction predict PHQ-9 change at week 4 and week 8?
- **Secondary endpoint:** Does adding EEG improve AUC over HRV × sleep alone?

### Regulatory Considerations
- Ethics approval (Uni of Hamburg IRB)
- GDPR compliance (EU data)
- PHIPA compliance (if Canadian subjects added)
- Data stored on-device, only computed scores transmitted

---

## Phase 7: Public EEG Depression Datasets (Parallel Track)

Before collecting new data, test the framework on existing datasets:

| Dataset | N | EEG | Depression Measure | Access |
|---|---|---|---|---|
| **MODMA** (Lanzhou Univ) | 53 | 128-ch, resting + task | PHQ-9, SDS | Open |
| **MDD Patients vs Controls** (various) | varies | 64-ch typically | Clinical diagnosis | By request |
| **LEMON** (MPI Leipzig) | 228 | 62-ch, resting | BDI-II, various | Open |

These won't have Muse-format data, but we can:
1. Extract AF7/AF8 equivalent channels
2. Compute same features (FAA, alpha variability, CSD indicators)
3. Test interaction hypotheses before collecting our own Muse data

---

## Timeline Summary

| Week | Milestone |
|---|---|
| 1-2 | BrainFlow/MuseLSL setup, recording protocol, first raw data |
| 2-3 | Feature extraction pipeline (FAA, alpha CSD, preprocessing) |
| 3-4 | Run autoresearch on public EEG datasets + interaction hypotheses |
| 4-6 | Mobile app prototype (data hub, basic dashboard) |
| 6-8 | Muse data collection with pilot subjects (n=10-20) |
| 8-12 | Prospective validation study design + ethics submission |

---

## Technical Requirements

### Python Packages (add to requirements.txt)
```
brainflow>=5.0
mne>=1.0
neurokit2>=0.2
pylsl>=1.16
```

### Hardware
- Muse 2 (~$250 USD) or Muse S (~$400 USD)
- Bluetooth 4.0+ capable computer/phone
- Existing wearable (Apple Watch, Oura, or Fitbit) for HRV/sleep

### New Files to Create
```
src/
├── data_loader_eeg.py        # Load and preprocess Muse EEG data
├── eeg_features.py           # FAA, band powers, CSD indicators
├── eeg_preprocessing.py      # Filtering, artifact rejection, epoching
└── run_triple_interaction.py  # Autoresearch with 3-modality interactions
```
