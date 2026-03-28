# Evolved25 Winners Analysis

## Track Winners

### Track 1: Agentic Automation
- **Gold: M3TRIQ Sdn. Bhd.** — Agentic multi-objective paratope-preserving species adapter
- **Silver: Raycaster** — "Cursor for life sciences documents"

### Track 2: Integrative Intelligence
- **Gold: Bacformer** — Whole-genome bacterial genome modeling
- **Silver: Weekend Inc** — Mapping protein taste properties to sequence

### Track 3: Molecular/Genomic Modeling
- **Gold: Gardn Biosciences** — Simultaneous design of mRNA + protein sequence for biologics
- **Silver: Leash Biosciences** — Exploring and fighting memorization in protein-ligand binding prediction models

---

## Deep Dive: Leash Biosciences (2nd Place, Track 3)

### What they did
Asked a scientific question: "Are protein-ligand interaction models memorizing proteins instead of learning binding physics?"

### Method
1. Used H100 GPU time to **train multiple versions** of their Hermes model
2. Generated **attention maps** showing which amino acid residues the model focuses on
3. Discovered model looks at **unique protein regions** (memorization) instead of **conserved functional domains** (real learning)
4. Trained new models with **mutant protein data** (single amino acid substitutions)
5. Showed the new models shifted attention **toward functional domains**

### Why it won
- Clear scientific question → experiment → evidence → insight
- Used H100s for actual training, not just inference
- Publishable-quality figures and analysis
- Deep domain knowledge (biology + ML)
- Later published as a Substack article that got significant attention

---

## Patterns Across All Winners

### 1. Scientific thesis, not just a product
Nobody built "an app." They all investigated a question or pushed a boundary.

### 2. Used H100 compute for actual training
Not just API calls. They trained models, compared versions, showed differences.

### 3. Publishable-quality output
Figures, charts, before/after comparisons, statistical analysis.

### 4. Deep domain knowledge
Biology/chemistry/medicine expertise was essential, not just ML skills.

### 5. Mostly companies/labs, not students
M3TRIQ, Leash Biosciences, Gardn Biosciences — serious domain players.

---

## What Judges Value (Derived)

| High Value | Low Value |
|---|---|
| Scientific question with evidence | Pretty UI/app demo |
| Used H100s for training/experiments | Just called an API |
| Novel insight the field didn't have | Known technique applied to known data |
| Domain depth (biology matters) | Pure ML engineering |
| Figures, attention maps, charts | Business plans |
| Before/after comparison | Feature lists |
| Could become a paper | Could become a startup pitch |

---

## Key Takeaway

> "The winning formula is: Question → Experiment → Evidence → Insight"
>
> NOT: "We built X using Y technology"
