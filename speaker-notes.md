# Speaker Notes — AutoBiomarker Pitch (3-5 min)

---

## Slide 1: Title (10 sec)

"We're AutoBiomarker. We built an autonomous system that discovers depression early warning signals from wearable data — specifically from the interaction between heart rate variability and sleep."

> Don't linger. Move to slide 2 quickly.

---

## Slide 2: The Problem (30 sec)

"280 million people have depression. Half drop out of treatment. And here's the real problem — clinicians only check in every 4 to 6 weeks, using subjective questionnaires. By the time they realize a patient is getting worse, the patient has already stopped showing up."

*Point to the right box:*

"What clinicians need is an objective, continuous signal — something from a wearable that tells them daily whether treatment is working, between appointments."

---

## Slide 3: Insight & Core Finding (40 sec)

*Point to the bar chart:*

"This is the key finding. Standard HRV — just measuring how low someone's heart rate variability is — gives you AUC 0.61. Sleep alone, 0.63. Neither survives multiple testing correction."

*Point to the highlighted bar:*

"But when you look at HRV AND sleep destabilizing at the same time — the interaction — you get 0.78. That's a 28% improvement and a Cohen's d of 1.11, which is a large effect."

*Point to the CSD box:*

"This comes from a concept in physics called critical slowing down. When any complex system is under stress, it starts wobbling — more variability, slower recovery. We applied that to wearable physiology. The key insight is: it's not how LOW your HRV is, it's whether HRV and sleep are destabilizing together."

> This is your money slide. Pause after "the interaction is the biomarker." Let it land.

---

## Slide 4: Autoresearch Engine (40 sec)

"How did we find this? We built an autoresearch engine — adapted from Karpathy's autoresearch concept — using Nebius Token Factory for inference and 8090 Software Factory for development."

*Walk through the flow:*

"Llama 3.3 70B on Nebius AI Studio proposes hypotheses. We extract 187 temporal features. A statistical evaluator runs leave-one-subject-out cross-validation. Each hypothesis gets a KEEP or DISCARD. And the results feed back to the LLM to propose better hypotheses."

*Point to Round 1 vs Round 2:*

"Round 1: we tested 5,000 single-feature hypotheses. 636 looked promising but ZERO survived FDR correction across 5,000 tests. That's the honest result. Then the LLM adapted — proposed interaction features in small rounds of 8. Out of 271 targeted hypotheses, 2 unique features survived FDR."

---

## Slide 5: Methods & Results (40 sec)

*Point to the pipeline box:*

"Quick methods overview: 49 subjects — 17 with mild+ depression, 32 healthy — 28 days of data. 187 temporal features. We compute HRV-times-sleep interaction terms. Critically, feature selection happens INSIDE each cross-validation fold — no data leakage."

*Point to the results table:*

"The 2 significant interactions. Both are HRV times sleep. The best — RMSSD 3-day slope times sleep duration autocorrelation — gives AUC 0.78 with Cohen's d of 1.11. The AUC is inverted because the interaction is LOWER in depression — it reflects a loss of coordination between the two systems."

*Point to volcano plot:*

"The volcano plot shows all 271 hypotheses. Most cluster in the bottom left — small effect, not significant. The 2 blue dots in the upper right are our significant findings. They're clearly separated from the noise."

---

## Slide 6: Validation (30 sec)

"Now, you're probably thinking — is this overfitted? We thought the same thing, so we ran validation."

*Point to the bar chart:*

"Permutation test: we shuffled depression labels 100 times and re-ran the entire analysis. The real effects — the blue bars — are 3 to 4 times larger than the null. Zero out of 20 full shuffled simulations produced ANY significant finding. Real data produced 2."

*Point to hold-out table:*

"Hold-out validation: 33 discovery, 16 validation subjects. Both effect directions are consistent. Effects replicate in the held-out set."

*Point to cross-dataset:*

"And when we transfer to a completely different dataset — Depresjon, 55 subjects, actigraphy instead of HRV — we get AUC 0.66. The temporal instability pattern generalizes."

*Read limitations quickly:*

"Limitations: n=49 is pilot-scale, we're capturing mild symptoms, and we need prospective validation."

> Being upfront about limitations builds trust. Don't skip this.

---

## Slide 7: Regulatory Pathway (20 sec)

"We've mapped out a regulatory pathway. This is Health Canada SaMD Class II — clinical decision support, not diagnosis. The predicate is continuous glucose monitors, which established the pathway for wearable-derived clinical signals."

*Point to timeline:*

"We're here at the retrospective pilot. Next: prospective validation with the University of Hamburg, then multi-site, then filing."

*Key point:*

"The discovery engine evolves freely. The clinical product is a frozen snapshot — locked model, no autonomous changes. That's what makes it regulatable."

---

## Slide 8: Market & Products (20 sec)

"Two products, two customers. The discovery engine sells to pharma for digital endpoint discovery in clinical trials — that generates revenue before we need regulatory approval. The treatment response tracker is the clinical product — a daily score for hospitals and clinics, per-patient SaaS."

> Keep this brief. Don't get into pricing or TAM unless asked.

---

## Slide 9: Team & Roadmap (30 sec)

*Introduce each team member briefly — one sentence each.*

"Our clinical advisor is Professor Steffen Moritz at the University of Hamburg — that collaboration is confirmed."

*Point to next steps:*

"Next: we're integrating Muse EEG headbands as a third modality — real-time brainwave data alongside HRV and sleep, all through a mobile app. Plus consumer wearable support — Apple Watch, Oura. And prospective validation with 200+ subjects."

*Point to long-term vision:*

"Long term, critical slowing down is condition-agnostic. The same engine works for anxiety, bipolar, PTSD. One engine, many conditions."

---

## Slide 10: Closing (15 sec)

"AutoBiomarker. Objective, continuous tracking of depressive state from a wrist."

*Let the numbers speak:*

"AUC 0.78. 28% better than standard HRV."

*Pause. Then:*

"The interaction between HRV and sleep is the biomarker. We're ready to validate it prospectively."

*Stop talking. Don't ramble after the closing. Let the room sit with it.*

---

## Anticipate Q&A

**"n=49 is too small."**
"Agreed — that's why our next step is prospective validation with 200+ subjects at Hamburg. But the permutation test and hold-out validation give us confidence the signal is real, not noise."

**"Why not just use an Apple Watch app?"**
"An Apple Watch gives you HRV OR sleep. Our finding is that neither alone works — you need both destabilizing simultaneously. That requires multi-modal integration, which is what we build."

**"How is this different from Whoop / Oura?"**
"Those track single metrics — HRV recovery, sleep score. We track the interaction between systems over time. It's the temporal instability pattern that predicts, not the level."

**"What about confounders — caffeine, exercise, stress?"**
"We ran confounder residualization against age, BMI, and lifestyle factors. The interaction effect survives adjustment."

**"How do you handle data privacy?"**
"PHIPA-compliant design. On-device processing. No raw physiological data leaves the device — only the computed interaction score is transmitted."

**"Why SaMD Class II and not Class I?"**
"Class II because we provide clinical information that aids treatment decisions — that's beyond general wellness. CGMs established this pathway for wearable-derived signals."

**"What's the AUC inversion about?"**
"The raw AUC is below 0.5, which means the interaction feature is LOWER in depressed subjects — they lose the coordination between HRV and sleep. We report the inverted AUC (0.78) because the direction is clinically meaningful: loss of multi-system coordination."
