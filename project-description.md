# AutoBiomarker: Autonomous Discovery of Depression Early Warning Signals from Wearable Data

## Problem

Depression affects 280 million people globally, yet treatment response is assessed only every 4-6 weeks through subjective self-report questionnaires. By the time clinicians detect worsening, 50% of patients have already dropped out of treatment. There is no objective, continuous signal that tracks depressive state between appointments.

## Approach

We built an autonomous biomarker discovery system that applies critical slowing down theory — a concept from physics where systems under stress show rising variability and sluggish recovery — to wearable physiological data. Our autoresearch engine, adapted from Karpathy's autoresearch paradigm, uses Llama 3.3 70B on Nebius Token Factory to iteratively generate, test, and refine biomarker hypotheses, with 8090 Software Factory supporting the development pipeline. The system extracts 187 temporal dynamics features (autocorrelation, coefficient of variation, slope, standard deviation) from heart rate variability (HRV) and sleep data across multiple rolling windows, then evaluates cross-domain interaction terms using leave-one-subject-out cross-validation with feature selection inside each fold to prevent data leakage.

## Key Results

From 5,271 hypotheses tested across 50 rounds, 2 unique HRV x sleep interaction features survived Benjamini-Hochberg FDR correction. The best interaction (RMSSD 3-day slope x sleep duration 3-day autocorrelation) achieved AUC 0.78 (inverted) with Cohen's d = 1.11 (p_adj = 0.006) — a 28% improvement over standard HRV approaches (AUC 0.61). The AUC inversion indicates that the interaction is lower in depressed subjects, reflecting a loss of coordination between autonomic and behavioral regulation. Critically, no single-modality feature survived FDR correction at n=49; the interaction between modalities is the biomarker. Permutation testing (100 label shuffles) confirmed real effects are 3-4x larger than null (0/100 shuffles beat the top interaction), and hold-out validation (33/16 split) showed consistent effect directions for both findings. Cross-dataset transfer to the Depresjon actigraphy dataset (n=55) yielded AUC 0.66, suggesting temporal instability patterns generalize across sensor types.

## Significance

This work demonstrates that multi-system physiological destabilization — specifically the simultaneous instability of autonomic (HRV) and behavioral (sleep) regulation — provides a stronger depression signal than either modality alone. The clinical implication is a daily, objective treatment response signal from a wristband, enabling clinicians to detect deterioration between appointments. Our regulatory pathway targets Health Canada SaMD Class II certification, with prospective validation planned through a confirmed collaboration with Prof. Dr. Steffen Moritz at the University of Hamburg. Future work includes Muse EEG integration as a third modality and expansion to anxiety, bipolar disorder, and PTSD using the same condition-agnostic critical slowing down framework.

## Technical Details

- **Data:** Baigutanova et al. 2025 (49 subjects, 28 days, HRV + sleep + PHQ-9); Depresjon dataset (55 subjects, actigraphy + MADRS)
- **Compute:** Nebius Token Factory, Llama 3.3 70B inference; 8090 Software Factory for development
- **Stack:** Python, scikit-learn, scipy, Streamlit dashboard, reveal.js slides
- **Repo:** Open source with full results, validation scripts, and reproducible pipeline
