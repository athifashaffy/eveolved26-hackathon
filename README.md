# Evolved26 Toronto Hackathon Prep

**Event:** 48-hour biotech/health AI hackathon by Evolved Technology, Toronto
**Resources:** Nebius Token Factory (H100 GPUs, $200 credits, 60+ models)
**Key:** FAIR data principles, open-ended tracks

## Tracks (examples only — open-ended)
1. **Healthcare** — Wearables + Clinical Operations
2. **Biological & Molecular Systems** — Bench to Discovery + Scaling Workflows
3. **Neuro-Tech** — Brain signals, cognitive training

## Key Files
- `nebius-guide.md` — How to use Nebius Token Factory (inference, fine-tuning, models)
- `hackathon-strategy.md` — How to win, pitch structure, time allocation
- `datasets.md` — All provided datasets with access instructions
- `project-ideas.md` — Brainstormed project options ranked by win potential
- `nebius-finetune-example.py` — Ready-to-run fine-tuning script
- `nebius-inference-example.py` — Ready-to-run inference script

## Limitations
- Small sample sizes (n=49 Baigutanova, n=55 Depresjon) — pilot-scale, hypothesis-generating
- PHQ-9 ≥ 5 threshold captures mild symptoms, not clinical depression diagnosis
- Baseline-only confounder control (coffee, alcohol, smoking, exercise); daily variation unaddressed
- Features correlated across rolling windows — we report 22 independent feature families, not raw test counts
- Cross-dataset transfer (AUC 0.66) is preliminary, not conclusive
- Prospective validation needed before any clinical deployment
