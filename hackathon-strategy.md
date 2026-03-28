# Hackathon Strategy — How to Win Evolved26

## The Meta-Game

Hackathons are judged on: **storytelling + demo quality + team credibility**, in that order.
Actual technical depth is ~20% of the score.

---

## Time Budget (48 hours)

| Hours | Activity |
|---|---|
| 0-4 | Scope, divide work, get Nebius running, download data |
| 4-24 | Core experiment: train models, run analysis |
| 24-36 | Second iteration, refine results, build visualizations |
| 36-42 | Polish figures, prepare demo |
| 42-48 | Rehearse pitch 5+ times, prepare backup |

**Critical:** Allocate 8+ hours to demo/pitch prep. Most teams spend 45h building and 3h panicking.

---

## Pitch Structure (3-5 minutes)

```
1. THE PROBLEM (30 sec)
   "X people suffer from Y. Currently, Z is broken because..."
   → Make judges feel the pain

2. THE INSIGHT (15 sec)
   "We realized that [data/model/approach] makes this solvable"
   → "Why now" / "Why us"

3. THE DEMO (60-90 sec)
   Live. Working. On screen. Not slides.
   → One flow. Start to finish. No tab switching.

4. THE RESULTS (30 sec)
   "We tested on X dataset. Metric: Y. Baseline was Z."
   → Numbers. Charts. Comparisons.

5. THE FUTURE (15 sec)
   "Next: [validation/paper/clinical deployment]"
   → Show it could be real beyond the hackathon
```

---

## Do's and Don'ts

### DO
- Pick ONE scientific question and nail it
- Use H100s for actual training, not just inference
- Use the provided datasets (shows you read the brief)
- Produce figures: attention maps, loss curves, scatter plots, before/after
- Have PhD team members present the science
- Cite papers in your pitch
- Show statistical significance, not just "it works"
- Have a working demo (even ugly)

### DON'T
- Build a chatbot (everyone does, judges are bored)
- Fine-tune a model and call it a project
- Use fake data for the demo
- Have 6 people present (1-2 speakers max)
- Show your GitHub repo or terminal to judges
- Try to build 5 features and finish none
- Spend 2 minutes explaining the problem
- Wrap an LLM in a UI and call it innovation

---

## Team Role Division

| Role | Responsibility | Pre-Hackathon |
|---|---|---|
| **ML Engineer** | Nebius setup, training, model comparison | Test Nebius API, prep training scripts |
| **Domain PhD(s)** | Scientific question, evaluation criteria, figures | Identify question, prepare dataset, literature |
| **Data Engineer** | Dataset prep, pipeline, visualization | Download datasets, explore data, build plots |
| **Presenter** | Pitch, demo flow, storytelling | Draft pitch narrative, practice |

---

## Pre-Hackathon Checklist

- [ ] Everyone creates Nebius Token Factory account
- [ ] Test one API call to verify credits work
- [ ] Register for NCBI API key (PubMed, free)
- [ ] Download target datasets (see datasets.md)
- [ ] Identify scientific question based on team expertise
- [ ] Prepare training data in JSONL format
- [ ] Test fine-tuning script locally (see nebius-finetune-example.py)
- [ ] Draft pitch narrative arc
- [ ] Assign roles
