# Signa: Tracking Depressive State & Treatment Response from Wearable Data

## Problem

Depression is gradual — patients drift. By the time they report worsening, they've often dropped out. Treatment response is assessed only every 1-3 months through subjective self-report questionnaires, and 50% of patients drop out of treatment before clinicians detect deterioration. There is no objective, continuous signal that tracks depressive state or detects early warning signs of clinical transitions — relapse, non-response, or deterioration — between appointments. What's needed is objective, continuous tracking of depressive state from wearables, a daily signal that tells clinicians whether treatment is working between appointments.

## Approach

We built an autonomous biomarker discovery system (the Autoresearch Engine) that applies critical slowing down theory — a concept from physics where systems under stress show rising variability and sluggish recovery — to wearable physiological data. Adapted from Karpathy's autoresearch paradigm, the engine uses Llama 3.3 70B on Nebius Token Factory to iteratively generate, test, and refine biomarker hypotheses, with 8090 Software Factory supporting the development pipeline. The system extracts 187 temporal dynamics features (autocorrelation, coefficient of variation, slope, standard deviation) from heart rate variability (HRV) and sleep data across multiple rolling windows, then evaluates cross-domain interaction terms using leave-one-subject-out cross-validation with feature selection inside each fold to prevent data leakage.

## Key Results

From 5,271 hypotheses tested across 50 rounds, 2 unique HRV x sleep interaction features survived Benjamini-Hochberg FDR correction. The best interaction (RMSSD 3-day slope x sleep duration 3-day autocorrelation) achieved AUC 0.78 (inverted) with Cohen's d = 1.11 (p_adj = 0.006) — a 28% improvement over standard HRV approaches (AUC 0.61). The AUC inversion indicates that the interaction is lower in depressed subjects, reflecting a loss of coordination between autonomic and behavioral regulation. Critically, no single-modality feature survived FDR correction at n=49; the interaction between modalities is the biomarker. Permutation testing (100 label shuffles) confirmed real effects are 3-4x larger than null (0/100 shuffles beat the top interaction), and hold-out validation (33/16 split) showed consistent effect directions for both findings. Cross-dataset transfer to the Depresjon actigraphy dataset (n=55) yielded AUC 0.66, suggesting temporal instability patterns generalize across sensor types.

## Significance

We detect the early warning signals of clinical transitions — the moment a patient starts tipping toward relapse or responding to treatment — from a wristband. Clinicians see it days before their next appointment or assessment. Multi-system physiological destabilization — specifically the simultaneous instability of autonomic (HRV) and behavioral (sleep) regulation — provides a stronger depression signal than either modality alone. Our regulatory pathway targets Health Canada SaMD Class II certification (clinical decision support, not diagnosis), with PHIPA-compliant on-device processing where no raw physiological data leaves the device. Prospective validation (n=200+) is planned through a confirmed collaboration with Prof. Dr. Steffen Moritz at the University of Hamburg for Q3 2026, followed by a multi-site trial with Ontario Health in 2027, targeting SaMD Class II filing in 2028. The clinical product uses a locked model approach — the discovery engine evolves freely, but the clinical product is a frozen snapshot with no autonomous model changes post-validation. Future work includes Muse EEG integration as a third modality and expansion to anxiety, bipolar disorder, and PTSD using the same condition-agnostic critical slowing down framework.

## Two Products, Two Customers

1. **Discovery Engine (R&D Tool):** Autoresearch loop as a service for digital endpoint discovery in clinical trials. Not a medical device — no regulatory burden. Revenue: per-trial licensing to pharma CROs. Pursue Qualified Drug Development Tool status.

2. **Signa Monitoring Dashboard (SaMD):** Static, validated model for clinical monitoring. Health Canada SaMD Class II. Locked model — no autonomous changes. Clinical decision support, not diagnosis. Revenue: per-patient SaaS to hospitals. Continuous depression monitoring from wrist or through manual entry.

## Technical Details

- **Data:** Baigutanova et al. 2025 (49 subjects, 28 days, HRV + sleep + PHQ-9); Depresjon dataset (55 subjects, actigraphy + MADRS)
- **Compute:** Nebius Token Factory, Llama 3.3 70B inference; 8090 Software Factory for development
- **Stack:** Python, scikit-learn, scipy, Streamlit dashboard, reveal.js slides
- **Data Governance:** PHIPA-compliant, on-device processing, no raw physiological data leaves the device
- **Repo:** Open source with full results, validation scripts, and reproducible pipeline

## Team — The Alphanova (TAN)

- **Sarah Iskin** — MASc, Biomedical Engineering
- **Athif Shaffy** — Software Engineer
- **Baljinder Maan** — Software Engineer
- **Darien Lee** — Business Subject Expert
- **Clinical Advisor:** Prof. Dr. Steffen Moritz, Uni of Hamburg
