# Project Ideas — Ranked by Win Potential

Based on analysis of Evolved25 winners and hackathon judging patterns.

---

## Tier 1: Highest Win Potential

### Idea A: "Do PLI Models Understand Binding Physics?" (Track 2/3 — Molecular)
**Inspired by:** Leash Biosciences (2nd place, Evolved25)
**Question:** Can we expose memorization in [any foundation model] by analyzing attention patterns?
**Method:**
1. Take ESM-2 or Boltz-2 embeddings for a set of proteins
2. Generate attention maps on conserved vs non-conserved domains
3. Fine-tune on Nebius with augmented data (mutations, diverse proteins)
4. Show attention shifts toward functional regions
**Why it wins:** Direct follow-up to last year's silver winner. Scientific, visual, uses H100s for training.
**Needs:** Protein biology expertise on team.

### Idea B: "Predicting Depression Episodes from Wearable Biomarkers" (Track 1.1 + 1.2)
**Question:** Can continuous HRV + sleep data predict PHQ-9 depression scores before self-report?
**Dataset:** Baigutanova et al. 2025 (450MB, no login, has PHQ-9 + GAD-7 + HRV)
**Method:**
1. Download dataset, explore HRV-mood-depression correlations
2. Build time-series prediction model (HRV trends → PHQ-9 change)
3. Fine-tune Llama on clinical interpretation of wearable data
4. Show: "3 days of declining HRV + poor sleep → elevated depression risk"
**Why it wins:** Visual (charts, predictions), uses provided dataset, clinically meaningful.
**Needs:** Stats/data science expertise, clinical knowledge of depression.

### Idea C: "Autonomous Scientific Literature Agent" (Track 2.2)
**Question:** Can an AI agent autonomously synthesize clinical evidence from PubMed and build a knowledge graph?
**Method:**
1. Build multi-agent system: search agent → extraction agent → synthesis agent
2. Target a specific domain (e.g., MCT for depression, or a drug target)
3. Agent searches PubMed, extracts findings, builds knowledge graph
4. Query the graph: "What evidence supports X treatment for Y condition?"
5. Show citations, confidence scores, contradiction detection
**Why it wins:** Directly matches hackathon's suggested "Multi-Agent Scientific Reasoning & Knowledge Graphs" example. Uses Nebius for large model inference.
**Needs:** NLP expertise, familiarity with PubMed API.

---

## Tier 2: Strong Potential

### Idea D: "ECG Anomaly Detection + Clinical Interpretation" (Track 1.1)
**Dataset:** PTB-XL (21K ECGs, 71 labels, open access)
**Method:** Train classifier on H100s, generate clinical interpretation with fine-tuned LLM
**Risk:** Well-trodden territory, many existing solutions

### Idea E: "Clinical Trial Matcher" (Track 1.2)
**Dataset:** ClinicalTrials.gov API (577K studies)
**Method:** Patient description → LLM extracts criteria → matches to trials
**Risk:** Suggested example in handout = many teams will try this

### Idea F: "Fine-Tuned Protein Language Model" (Track 2.1)
**Dataset:** UniProt + ESM-2
**Method:** Fine-tune ESM-2 for specific binding prediction task
**Risk:** Needs deep protein ML expertise

---

## Tier 3: Moderate Potential

### Idea G: "Cursor for Life Sciences" (Track 1.2/2.2)
**Inspired by:** Raycaster (silver, Track 1, Evolved25)
**What:** IDE-like tool for querying/navigating clinical or scientific documents
**Risk:** Hard to differentiate from existing tools

### Idea H: "Sleep Disorder Classifier from Wearables" (Track 1.1)
**Dataset:** DREAMT
**Risk:** Requires DUA signing, standard classification problem

### Idea I: "Adaptive Cognitive Training via Brain Signals" (Track 3)
**Dataset:** EBRAINS + OpenNeuro
**Risk:** Loose scope, hard to show concrete results in 48h

---

## Decision Framework

Pick based on your team's PhD expertise:

| Team Expertise | Best Idea |
|---|---|
| Protein biology / drug discovery | A (attention maps on PLI models) |
| Clinical psychology / psychiatry / epidemiology | B (wearable depression prediction) |
| NLP / information extraction | C (PubMed literature agent) |
| Signal processing / cardiology | D (ECG anomaly detection) |
| Bioinformatics / genomics | F (protein language model) |
