# Evolved26 — Provided Datasets

## Track 1.1: Wearable Technologies

### PTB-XL ECG v1.0.3
- **What:** 21,837 clinical 12-lead ECG waveforms from 18,885 patients, 71 diagnostic labels
- **Columns:** age, sex, scp_codes (labels), heart_axis, signal quality
- **Access:** https://physionet.org/content/ptb-xl/1.0.3/ (Open Access, no DUA)
- **Also on Kaggle:** https://www.kaggle.com/datasets/khyeh0719/ptb-xl-dataset
- **Python:** `pip install wfdb` → `signals, fields = wfdb.rdsamp('filename')`

### DREAMT v2.1.0
- **What:** 100 participants, synchronized smartwatch (BVP 64Hz, ACC 32Hz, EDA/TEMP 4Hz) + full PSG
- **Columns:** Age, Gender, BMI, Arousal Index, Mean Oxygen, Snoring, RLS, Headaches
- **Access:** https://physionet.org/content/dreamt/2.1.0/ (requires DUA signing)
- **Python:** `pip install wfdb`

### Baigutanova et al. (2025)
- **What:** 49 participants, 28 days continuous HRV + sleep via smartwatches
- **Columns:** subject_id, timestamp, heart_rate, RMSSD, SDNN, pNN50, LF, HF, LF/HF_ratio, steps, calories, distance, sleep_bedtime, sleep_wake_time, sleep_quality_score, caffeine_intake, alcohol_intake, exercise_binary, mood_score, stress_level, age, gender, ethnicity, BMI, **PHQ-9** (Depression), **GAD-7** (Anxiety), **PSS** (Perceived Stress)
- **Access:** https://springernature.figshare.com/articles/dataset/In-situ_wearable-based_dataset_of_continuous_heart_rate_variability_monitoring_accompanied_by_sleep_diaries/28509740
- **No login required**, ~450MB zip
- **Subfolders:** `/hrv_metrics/` (per-minute physiology), `/daily_logs/` (sleep/lifestyle), `/clinical_metadata/` (psychological assessments)
- **Paper:** Nature Scientific Data (2025)

---

## Track 1.2: Clinical Operations

### TGCA / GDC (Genomic Data Commons)
- **What:** 84,000+ cancer cases, 2.5M files — clinical, genomic, imaging
- **Columns:** demographics, diagnosis (stage, grade), treatments, genomic profiles (RNA-Seq, WXS, Methylation)
- **Access:** https://portal.gdc.cancer.gov/
- **Tip:** Pick one cancer type + one data type (e.g., RNA-seq)

### NIH Chest X-ray
- **What:** 112,120 frontal chest X-rays from 30,805 patients, 14 disease labels
- **Labels:** Atelectasis, Cardiomegaly, Effusion, Infiltration, Mass, Nodule, Pneumonia, Pneumothorax, Consolidation, Edema, Emphysema, Fibrosis, Pleural_Thickening, Hernia
- **Access:** Kaggle (recommended): https://www.kaggle.com/datasets/nih-chest-xrays/data

### ClinicalTrials.gov API
- **What:** 577,168 registered studies (as of March 2026)
- **Fields:** NCTId, BriefTitle, Condition, InterventionName, Phase, EligibilityCriteria, EnrollmentCount, OverallStatus
- **API:** https://clinicaltrials.gov/data-api/api
- **Endpoint:** `/studies` for search, `/studies/{NCTId}` for details

---

## Track 2.1: Bench to Discovery

### CellXGene (Single-Cell Atlas)
- **What:** 122M+ cells, 60K+ genes, massive transcriptomic datasets
- **Access:** `pip install cellxgene-census` (cloud querying, no download needed)
- **URL:** https://cellxgene.cziscience.com/

### ZINC20 (Drug Compounds)
- **What:** 1.4 billion molecules, ready-to-dock 2D/3D formats
- **Access:** https://zinc.docking.org/

### UniProt / ESM-2 / PoET-2 / BioReason Pro
- **UniProt:** 200M+ protein sequences — https://www.uniprot.org/
- **ESM-2:** Protein language model — `pip install fair-esm`
- **PoET-2:** https://app.openprotein.ai/
- **BioReason Pro:** https://app.bioreason.net/

### PDBbind / GROMACS Benchmarks (Molecular Dynamics / Docking)
- **PDBbind:** 29,001 protein-ligand complexes — https://www.pdbbind-plus.org.cn/download
- **GROMACS:** Systems from 82K to 204M atoms

---

## Track 2.2: Scaling Experimental Workflows

### Integrated Lab Digital Twin
- **Data:** FlowRepository, PRIDE Archive, Opentrons protocols
- **Mendeley API:** https://data.mendeley.com/api/docs/

### PubMed
- **What:** 36M+ biomedical articles
- **API:** NCBI E-Utilities — https://www.ncbi.nlm.nih.gov/books/NBK25501/
- **Knowledge Graphs:** BioCypher or LangChain's GraphIndex

---

## Track 3: Neuro-Tech

### OpenNeuro (iEEG/EEG)
- **What:** 700+ public neuroimaging datasets (BIDS format)
- **Access:** https://openneuro.org/ or `openneuro-cli download ds00XXXX`

### Julich-Brain Atlas
- **What:** 270+ brain regions, 3D probabilistic maps
- **Access:** `pip install siibra`

### EBRAINS Knowledge Graph
- **What:** Neuroscience datasets, computational models, software tools
- **Access:** https://search.kg.ebrains.eu/

### webKNOSSOS Connectomics
- **What:** Terabyte-scale electron microscopy brain data
- **Access:** `pip install webknossos`
