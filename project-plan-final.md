# AutoBiomarker — Final Project Plan

## One-Liner
"Autonomous discovery of depression early warning signals from wearable data using Karpathy's autoresearch loop"

## The Scientific Question
> "Do early warning signals — rising autocorrelation and variance in daily HRV and mood — precede depression worsening, and can an autonomous discovery system find the optimal biomarker signatures?"

## Why This Is Novel (Literature Gaps)

### Gap 1: HRV-CV (day-to-day variability) never tested against depression
- HRV-CV was shown as a behavioral biomarker (2025 study) but never tested against PHQ-9
- Everyone measures how LOW HRV is. Nobody measures how RIGID or CHAOTIC it is over weeks.

### Gap 2: Critical slowing down never applied to wearable HRV in depression
- Theory proven in ecology (Scheffer 2009), finance, climate
- Applied to mood self-reports (van de Leemput 2014, PNAS) but NEVER to physiological wearable data
- Rising autocorrelation + rising variance in daily HRV = early warning signal before PHQ-9 worsens

### Gap 3: Three-way temporal ordering (HRV × sleep × mood) never modeled daily
- All existing studies are cross-sectional or examine only 2 of 3 variables
- Nobody has run day-level cross-lagged panel models on HRV + sleep + mood simultaneously
- Does poor sleep → low HRV → low mood? Or another order?

### Gap 4: Wearable-derived "digital allostatic load" never tested in depression
- Traditional allostatic load uses blood biomarkers (cortisol, CRP)
- A composite wearable score (low HRV + poor sleep + high resting HR) has never been validated against PHQ-9

### Gap 5: Autonomous biomarker discovery loop doesn't exist
- Karpathy's autoresearch optimizes ML training. Nobody has adapted it for biomarker hypothesis testing.
- DSPy, tsfresh, AutoML exist separately but nobody has combined them into an autoresearch-style loop for clinical discovery.

## Key References
- Koch et al. 2019 — HRV-depression meta-analysis, moderate effect sizes with single timepoints
- 2026 meta-analysis (56 studies) — HRV predicts future depression but "conditional" on unknown moderators
- 2025 study — HRV-CV as behavioral biomarker (never tested for depression)
- Drysdale et al. 2017 (Nature Medicine) — 4 fMRI depression biotypes (nobody has done this from wearables)
- Scheffer 2009 — Critical slowing down theory
- van de Leemput 2014 (PNAS) — Critical slowing down in mood data (not physiological)
- Karpathy autoresearch (2026) — autonomous experiment loop pattern

## Dataset
**Baigutanova et al. 2025** (provided by hackathon)
- 49 participants, 28 continuous days
- Per-minute: RMSSD, SDNN, pNN50, LF, HF, LF/HF_ratio, heart_rate
- Daily: sleep_quality, sleep_bedtime, sleep_wake_time, mood_score, stress_level, steps, exercise, caffeine, alcohol
- Clinical: PHQ-9, GAD-7, PSS, age, gender, BMI
- Access: https://springernature.figshare.com/articles/dataset/28509740
- Free, no login, ~450MB

## System Architecture

```
┌──────────────────────────────────────────────────────┐
│  Hypothesis Generator (Llama 3.3 70B on Nebius)      │
│  "Given prior results, propose next biomarker        │
│   hypothesis in structured form"                     │
└──────────────┬───────────────────────────────────────┘
               │ JSON hypothesis
               ▼
┌──────────────────────────────────────────────────────┐
│  Feature Extractor (tsfresh + custom temporal)       │
│  200+ features: rolling means, slopes, variance,     │
│  autocorrelation, HRV-CV, circadian amplitude,       │
│  sleep regularity, cross-variable coupling           │
└──────────────┬───────────────────────────────────────┘
               │ feature matrix
               ▼
┌──────────────────────────────────────────────────────┐
│  Statistical Evaluator                                │
│  Leave-one-subject-out CV, AUC, Cohen's d,           │
│  bootstrap 95% CI, Benjamini-Hochberg FDR            │
└──────────────┬───────────────────────────────────────┘
               │ score
          ┌────┴────┐
      [KEEP]    [DISCARD]
          │
          ▼
┌──────────────────────────────────────────────────────┐
│  Results Log (TSV)                                    │
│  id | feature | AUC | p_adj | d | status | desc      │
│  Feeds back into Hypothesis Generator                 │
└──────────────────────────────────────────────────────┘
```

## 3-Day Build Plan

### Day 1 (Friday)
| Hours | Who | Task |
|---|---|---|
| 0-2 | Everyone | Setup: Nebius account, download dataset, verify API |
| 2-4 | Data PhD | Data cleaning, compute daily aggregates, EDA |
| 2-4 | ML PhD | Scaffold autoresearch loop (hypothesis → test → log) |
| 2-4 | Engineer | Build Streamlit dashboard skeleton |
| 4-8 | Data PhD | Compute temporal features: HRV-CV, rolling autocorrelation, rolling variance, slopes |
| 4-8 | ML PhD | Wire Nebius Llama 70B as hypothesis generator, build evaluator |
| 4-8 | Engineer | Connect dashboard to results log |
| Night | Machine | Run first batch: 100-200 hypothesis tests |

### Day 2 (Saturday)
| Hours | Who | Task |
|---|---|---|
| 0-4 | Data PhD | Analyze overnight results. Run cross-lagged panel models (HRV × sleep × mood) |
| 0-4 | ML PhD | Refine hypothesis generator with prior results. Run second batch |
| 0-4 | Engineer | Build visualization: temporal plots, biomarker heatmaps, patient trajectories |
| 4-8 | Data PhD | Clustering analysis: identify autonomic subtypes from temporal features |
| 4-8 | ML PhD | Run comparison: autoresearch features vs standard (mean HRV) features |
| 4-8 | Engineer | Polish dashboard, build demo flow |
| Night | Machine | Run final batch: 300 more hypotheses |

### Day 3 (Sunday)
| Hours | Who | Task |
|---|---|---|
| 0-3 | Data PhD | Finalize figures, write up top findings |
| 0-3 | ML PhD | Prepare results summary, comparison charts |
| 0-3 | Engineer | Final demo polish, backup recording |
| 3-5 | Everyone | Write regulatory pathway (SaMD Class II, Health Canada) |
| 5-8 | Everyone | Rehearse pitch 5+ times. Assign speakers (2 max) |

## Pitch Structure (3 min)

### Problem (30s)
"280 million people have depression globally. 5.4 million in Canada. We still can't predict who's getting worse until they tell us — by which point they've often dropped out of treatment. What if their body already knows?"

### Insight (15s)
"In physics, systems approaching a tipping point show measurable warning signs — they get sluggish and start wobbling. We asked: does the human body do the same before depression worsens?"

### Demo (90s)
- Show the autoresearch loop running live
- Show top findings table (500 tested, 14 significant)
- Show patient trajectory with early warning signal highlighted
- Show comparison: our temporal features vs standard HRV (AUC improvement)

### Results (30s)
"We ran 500 autonomous experiments in 12 hours. We found that [top finding]. A human researcher would need months. This is the first application of critical slowing down theory to wearable depression monitoring."

### Future (15s)
"Next: validation study with Professor Steffen's D-MCT group therapy patients at UKE Hamburg. Regulatory pathway: Health Canada SaMD Class II. Market: precision psychiatry SaaS for clinical trials and digital therapeutics."

## Regulatory Pathway
- **Classification:** Software as a Medical Device (SaMD), Class II
- **Health Canada:** Pre-market notification pathway
- **Clinical Decision Support exemption:** Possible if tool "supports but does not replace" clinician judgment
- **GDPR/PIPEDA:** On-device processing for patient data (privacy by design)
- **Bias detection:** Test across age, gender, ethnicity subgroups in Baigutanova data

## Venture Model
- **Customer 1:** Pharma companies running depression clinical trials (digital endpoint)
- **Customer 2:** Digital therapeutics companies (precision intervention trigger)
- **Customer 3:** Hospital psychiatric departments (remote monitoring)
- **Revenue:** SaaS per-patient or per-trial licensing
- **Moat:** Proprietary biomarker signatures + autonomous discovery engine

## Tech Stack
| Component | Tool |
|---|---|
| Feature extraction | tsfresh, custom Python |
| Statistical testing | scipy, statsmodels (FDR correction) |
| ML evaluation | scikit-learn (LOSO cross-validation) |
| Hypothesis generation | Nebius Llama 3.3 70B via OpenAI API |
| Experiment orchestration | Custom autoresearch loop (Python) |
| Dashboard | Streamlit |
| Data | pandas, numpy |
| Visualization | matplotlib, plotly |
| Causal modeling | DoWhy (optional) |
