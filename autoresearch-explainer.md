# AutoBiomarker: How It Works

---

## The Problem with Biomarker Research Today

- A researcher reads papers, forms **1 hypothesis**
- Spends 2 weeks cleaning data and testing it
- Writes it up, submits to journal
- **Months per hypothesis. Everyone tests the same obvious things.**

> "Mean HRV is lower in depressed people" has been published **56 times**.

---

## What If a Machine Could Run Experiments While You Sleep?

Karpathy's autoresearch (2026):

```
change code → train model → check score → keep/revert → repeat
```

**Our adaptation for biomarker discovery:**

```
propose hypothesis → extract feature → test statistically → keep/discard → repeat
```

---

## One Loop Iteration (Example)

**Step 1 — Propose:**
> "Does rising autocorrelation in daily HRV over 7 days predict depression?"

**Step 2 — Extract:**
Compute lag-1 autocorrelation of RMSSD for each of 49 participants over rolling 7-day windows

**Step 3 — Test:**
Leave-one-subject-out cross-validation → AUC, Cohen's d, permutation p-value

**Step 4 — Decide:**
AUC > 0.6 AND p < 0.05 after FDR correction → **KEEP** ✓

---

## Scale: Human vs AutoBiomarker

| | Human Researcher | AutoBiomarker |
|---|---|---|
| Hypotheses per night | 0 (sleeping) | **500** |
| Time per hypothesis | 2-5 days | **~90 seconds** |
| Feature space | 3-5 obvious ones | **200+ novel temporal features** |
| Statistical rigor | Same | Same (LOSO-CV, FDR, bootstrap CI) |
| Bias | Picks what they've read about | **Searches systematically + LLM adapts** |

---

## The Three Components

### 1. Feature Extractor (the science)
Computes **temporal dynamics** from wearable data — borrowed from physics:

- **Rolling autocorrelation** → is HRV getting "sluggish"? (critical slowing down)
- **Rolling variance** → is HRV starting to "wobble"?
- **HRV-CV** → how rigid or chaotic is HRV day-to-day?
- **Sleep onset SD** → how irregular is bedtime?
- **Digital allostatic load** → composite body strain score

> **None of these have been tested against depression before.**

---

### 2. Hypothesis Engine (the brain)

**Round 1 — Systematic sweep (~160 hypotheses):**
Every temporal feature × every outcome (PHQ-9 ≥ 10, PHQ-9 increase)

**Round 2 — Interaction effects (~6 hypotheses):**
- HRV rigidity × sleep instability
- Autonomic sluggishness × mood sluggishness
- High allostatic load × declining HRV

**Round 3 — LLM-guided (~50 hypotheses):**
Llama 70B reads prior results and proposes what to test next

---

### 3. Statistical Evaluator (the rigor)

For **every single hypothesis:**

| Test | What it does |
|---|---|
| Leave-one-subject-out CV | No data leakage between subjects |
| AUC-ROC | How well does it discriminate? |
| Cohen's d | How big is the effect? |
| Permutation p-value | Is this real or noise? (non-parametric) |
| Bootstrap 95% CI | How certain are we? |
| **Benjamini-Hochberg FDR** | **Corrects for testing 500 things at once** |

> Without FDR correction, 25 out of 500 would look significant **by pure chance**. FDR eliminates those.

---

## The LLM Makes It Smart, Not Just Fast

After 200 hypotheses, Llama 70B sees:

```
rmssd_7d_autocorr:     AUC = 0.67  ← promising
sleep_onset_sd_7d:     AUC = 0.61  ← interesting
rmssd_7d_mean:         AUC = 0.52  ← boring (already known)
```

**LLM proposes:**
> "Test rmssd_7d_autocorr × sleep_onset_sd_7d — if autonomic sluggishness AND circadian disruption are both present, the combined signal may be stronger"

→ Tests it → AUC = 0.72 → **Novel finding no human thought to test**

---

## The Sleep × HRV × Depression Connection

```
SLEEP DISRUPTION          HRV RIGIDITY           MOOD DECLINE
(irregular bedtime,    (rising autocorrelation,   (falling scores)
 poor quality)          falling variability)
       │                       │                       │
       └───────────┬───────────┘                       │
                   │                                   │
          These couple tighter                         │
          before depression worsens  ◄─────────────────┘
                   │
                   ▼
        EARLY WARNING SIGNAL
     (detectable from a smartwatch)
```

The autoresearch loop searches for **which specific patterns** in this coupling predict depression — across 500 tests.

---

## Architecture

```
┌─────────────────────────────────────┐
│  Hypothesis Generator               │
│  (Predefined + Llama 70B on Nebius) │
└──────────────┬──────────────────────┘
               │ JSON hypothesis
               ▼
┌─────────────────────────────────────┐
│  Feature Extractor                   │
│  200+ temporal features from         │
│  HRV, sleep, mood time series        │
└──────────────┬──────────────────────┘
               │ feature matrix
               ▼
┌─────────────────────────────────────┐
│  Statistical Evaluator               │
│  LOSO-CV → AUC → Cohen's d →        │
│  permutation p → bootstrap CI        │
└──────────────┬──────────────────────┘
          ┌────┴────┐
       KEEP      DISCARD
          │
          ▼
┌─────────────────────────────────────┐
│  Results Log (TSV)                   │
│  Feeds back into LLM for next round │
└─────────────────────────────────────┘
```

---

## The Code (5 files)

| File | What | Lines |
|---|---|---|
| `autoresearch_loop.py` | Runs the whole pipeline | Orchestrator |
| `hypothesis.py` | Generates & evaluates hypotheses | Core engine |
| `feature_extractor.py` | Computes 200+ temporal features | The science |
| `data_loader.py` | Loads HRV + sleep + clinical data | Data pipeline |
| `config.py` | API keys, thresholds, settings | Configuration |

---

## How to Run

```bash
cd evolved26-hackathon/src
pip install -r requirements.txt
python autoresearch_loop.py          # with LLM
python autoresearch_loop.py --no-llm # without LLM
```

Results appear in `results/results.tsv`

Budget safeguard: capped at $70 Nebius spend (200 LLM calls max)

---

## Why This Wins

| Layer | What's New |
|---|---|
| **Features** | Physics-derived temporal dynamics never tested on depression |
| **Engine** | Autonomous biomarker discovery loop (doesn't exist anywhere) |
| **Intelligence** | LLM-guided scientific hypothesis search |
| **Rigor** | 500 hypotheses, all FDR-corrected, all cross-validated |
| **Platform** | Reusable: plug in anxiety, PTSD, bipolar data tomorrow |

---

## The Pitch Line

> "A human researcher tests 5 biomarker hypotheses per month. Our system tests 500 overnight — with the same statistical rigor — and discovers signals nobody has looked for, because they come from physics, not psychiatry textbooks."

---

## Team Roles

| Role | Focus |
|---|---|
| **Data PhD** | Feature engineering, EDA, analyze results |
| **ML PhD** | Autoresearch loop, LLM integration, evaluation |
| **Engineer** | Streamlit dashboard, visualizations, demo |
| **Everyone** | Pitch rehearsal on Day 3 |

---

## Questions?

Dataset: Baigutanova et al. 2025 — 49 participants, 28 days, HRV + sleep + mood + PHQ-9

Compute: Nebius Token Factory — Llama 3.3 70B on H100 GPUs

Theory: Critical slowing down (Scheffer 2009, van de Leemput 2014 PNAS)
