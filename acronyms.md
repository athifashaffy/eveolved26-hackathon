# Acronyms Reference

Quick reference for all acronyms used in slides and codebase.

## Clinical / Medical
| Acronym | Meaning |
|---|---|
| **HRV** | Heart Rate Variability — variation in time between heartbeats |
| **RMSSD** | Root Mean Square of Successive Differences — primary HRV metric (ms) |
| **LF/HF** | Low-Frequency / High-Frequency ratio — sympathovagal balance indicator |
| **PHQ-9** | Patient Health Questionnaire-9 — standard depression screening (0-27 scale) |
| **MADRS** | Montgomery-Asberg Depression Rating Scale — clinician-rated depression severity |
| **CBT-I** | Cognitive Behavioral Therapy for Insomnia |
| **SaMD** | Software as Medical Device — Health Canada regulatory classification |
| **EEG** | Electroencephalogram — brain electrical activity recording |
| **PTSD** | Post-Traumatic Stress Disorder |

## Statistical / ML
| Acronym | Meaning |
|---|---|
| **AUC** | Area Under the (ROC) Curve — classification performance metric (0.5 = random, 1.0 = perfect) |
| **FDR** | False Discovery Rate — multiple testing correction (Benjamini-Hochberg) |
| **LOSO-CV** | Leave-One-Subject-Out Cross-Validation — each subject held out once |
| **CI** | Confidence Interval (we use 95% bootstrap CI) |
| **BH** | Benjamini-Hochberg — the specific FDR correction method we use |
| **CV** | Coefficient of Variation — std/mean, measures day-to-day instability |
| **LLM** | Large Language Model |
| **CSD** | Critical Slowing Down — physics theory we apply to wearable data |

## Regulatory / Business
| Acronym | Meaning |
|---|---|
| **PHIPA** | Personal Health Information Protection Act (Ontario) |
| **CGM** | Continuous Glucose Monitor — predicate device for SaMD pathway |
| **CRO** | Contract Research Organization — companies pharma hires to run trials |

## Infrastructure
| Acronym | Meaning |
|---|---|
| **GPU** | Graphics Processing Unit |
| **H100** | NVIDIA H100 GPU (used via Nebius) |

## Key Thresholds to Know
- **PHQ-9 >= 5** = mild+ depression (our outcome cutoff)
- **Cohen's d >= 0.3** = minimum effect size we consider
- **p_adj < 0.05** = significance after FDR correction
- **AUC 0.76** = our best interaction result
- **d = 1.06** = our best effect size (large by convention)
