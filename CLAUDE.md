# AutoBiomarker — Evolved26 Hackathon

## Project Overview
Autonomous biomarker discovery system for depression early warning signals from wearable data (HRV + sleep). Built for Evolved26 Toronto hackathon (March 28-30, 2026).

## Key Finding
**HRV x sleep interactions** are the biomarker — neither modality alone survives FDR correction at n=49, but their interaction does (AUC 0.76, d=1.06, p_adj=0.02).

## Project Structure
```
evolved26-hackathon/
├── src/
│   ├── config.py                 # Nebius API keys, thresholds, rolling windows
│   ├── data_loader.py            # Load Baigutanova HRV/sleep/clinical data
│   ├── data_loader_depresjon.py  # Load Depresjon actigraphy dataset
│   ├── feature_extractor.py      # Temporal features (autocorr, CV, slope, std)
│   ├── hypothesis.py             # Hypothesis generation + evaluation (subject-level stats)
│   ├── run_overnight.py          # Round 1: 5,000 predefined hypotheses
│   ├── run_round2.py             # Round 2: LLM-guided refinement via Nebius
│   ├── run_overnight_full.py     # Combined pipeline: Round 1 + 2 + model training
│   ├── run_until_significant.py  # Iterative small-round search (mild FDR per round)
│   ├── train_models.py           # Leakage-free LOSO-CV model training
│   ├── train_cross_dataset.py    # Cross-dataset transfer learning
│   └── dashboard.py              # Streamlit interactive dashboard
├── data/                         # CSV datasets (not committed)
├── results/                      # TSV results, model artifacts, logs
├── slides.html                   # Reveal.js presentation (16 slides)
├── generate_pptx.py              # PowerPoint generator
└── test_slides.py                # Playwright screenshot QA
```

## Running

```bash
# Activate venv
source venv/bin/activate

# Full overnight pipeline (Round 1 + 2 + training)
python src/run_overnight_full.py

# Iterative search for significant findings
python src/run_until_significant.py

# Model training only
python src/train_models.py

# Streamlit dashboard
streamlit run src/dashboard.py

# Slides (serve locally)
python -m http.server 8000
# Then open http://localhost:8000/slides.html

# Generate PowerPoint
python generate_pptx.py
```

## Key Design Decisions
- **Feature selection inside CV folds** — prevents data leakage
- **Subject-level permutation tests** — avoids pseudoreplication from daily rows
- **Per-subject z-scoring** — composites standardized within subjects
- **Small-round FDR** — 8 hypotheses per round keeps BH correction mild
- **Nebius Token Factory** — Llama 3.3 70B for hypothesis generation ($0.22 total)

## Data
- **Baigutanova et al. 2025**: 49 subjects, 28 days, HRV + sleep + PHQ-9 (Figshare)
- **Depresjon (Garcia-Ceja 2018)**: 55 subjects, actigraphy + MADRS (Simula)

## Collaborator
Prof. Dr. Steffen Moritz, Uni of Hamburg — clinical validation pathway
