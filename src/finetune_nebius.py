"""
AutoBiomarker — Nebius Fine-Tuning Pipeline

Fine-tunes Llama 3.1 8B on Nebius Token Factory to create a specialized
biomarker hypothesis generator trained on our discovery results.

This uses your Nebius credits for actual GPU training on H100s.

Usage:
  python finetune_nebius.py --prepare   # Create training data from results
  python finetune_nebius.py --train     # Upload data and start fine-tuning
  python finetune_nebius.py --status    # Check training status
  python finetune_nebius.py --compare   # Compare base vs fine-tuned model
"""

import os
import sys
import json
import time
import argparse
import datetime
import pandas as pd

sys.path.insert(0, os.path.dirname(__file__))
from config import (
    NEBIUS_API_KEY, NEBIUS_BASE_URL, NEBIUS_MODEL,
    RESULTS_DIR, NEBIUS_BUDGET_LIMIT,
)

FINETUNE_DIR = os.path.join(RESULTS_DIR, "finetune")
TRAINING_DATA_PATH = os.path.join(FINETUNE_DIR, "training_data.jsonl")
VALIDATION_DATA_PATH = os.path.join(FINETUNE_DIR, "validation_data.jsonl")
FINETUNE_MODEL = "meta-llama/Llama-3.1-8B-Instruct"  # 8B for fine-tuning (cheaper)


def log(msg):
    ts = datetime.datetime.now().strftime("%H:%M:%S")
    print(f"[{ts}] {msg}")


def prepare_training_data():
    """Generate fine-tuning dataset from autoresearch results.

    Creates conversations where the model learns to:
    1. Analyze prior biomarker results
    2. Propose novel, scientifically-grounded hypotheses
    3. Explain reasoning connecting features to depression
    """
    os.makedirs(FINETUNE_DIR, exist_ok=True)

    # Load results
    results_path = os.path.join(RESULTS_DIR, "results.tsv")
    if not os.path.exists(results_path):
        log("ERROR: No results.tsv found. Run the autoresearch loop first.")
        return

    df = pd.read_csv(results_path, sep="\t")
    kept = df[df["status"] == "KEEP"].sort_values("cohens_d", ascending=False)
    discarded = df[df["status"] == "DISCARD"]

    log(f"Building training data from {len(kept)} KEEP + {len(discarded)} DISCARD results")

    training_examples = []

    # ---- Type 1: Given prior results, propose next hypothesis ----
    # Simulate the iterative discovery process
    kept_list = kept.to_dict("records")
    for i in range(5, len(kept_list), 3):
        prior = kept_list[:i]
        next_finding = kept_list[i]

        prior_text = "\n".join(
            f"  - {r['feature']}: AUC={r['auc']:.3f}, d={r['cohens_d']:.3f} (SIGNIFICANT)"
            for r in prior[-10:]  # Last 10
        )

        example = {
            "messages": [
                {
                    "role": "system",
                    "content": "You are a computational psychiatry researcher specializing in wearable biomarker discovery for depression. You analyze prior experimental results and propose novel hypotheses based on patterns in the data."
                },
                {
                    "role": "user",
                    "content": f"""Based on these prior biomarker testing results, propose the next hypothesis to test.

PRIOR RESULTS (top findings so far):
{prior_text}

CONTEXT: 49 participants, 28 days of daily HRV + sleep data, PHQ-9 depression scores.
Features available include rolling statistics (mean, std, cv, autocorrelation, slope) for RMSSD, heart rate, LF/HF ratio, sleep duration, sleep quality, sleep latency, and a digital allostatic load composite.

Propose ONE novel biomarker hypothesis. Explain your reasoning."""
                },
                {
                    "role": "assistant",
                    "content": f"""Based on the accumulating evidence, I propose testing: **{next_finding['feature']}**

{next_finding['description']}

**Reasoning:** Looking at the prior results, I notice that {'variability features (std, cv) are among the strongest predictors' if '_std' in next_finding['feature'] or '_cv' in next_finding['feature'] else 'temporal dynamics features show consistent signal'}. This aligns with critical slowing down theory — {'the system is becoming more rigid (rising autocorrelation)' if 'autocorr' in next_finding['feature'] else 'the system is wobbling more (rising variance)' if '_std' in next_finding['feature'] or '_cv' in next_finding['feature'] else 'changes in the mean level of this marker'} before depression worsens.

**Expected result:** Based on the pattern of prior findings, I predict this feature will show AUC > {next_finding['auc']:.2f} and Cohen's d > {next_finding['cohens_d']:.2f}, contributing to the emerging picture that depression is preceded by measurable changes in physiological temporal dynamics.

**Clinical implication:** If significant, this biomarker could be monitored passively via smartwatch to provide early warning of depression worsening."""
                }
            ]
        }
        training_examples.append(example)

    # ---- Type 2: Interpret a result ----
    for _, row in kept.head(30).iterrows():
        example = {
            "messages": [
                {
                    "role": "system",
                    "content": "You are a computational psychiatry researcher. Interpret biomarker findings in the context of depression neurobiology and critical slowing down theory."
                },
                {
                    "role": "user",
                    "content": f"We found that {row['feature']} predicts depression (PHQ-9 >= 5) with AUC={row['auc']:.3f} and Cohen's d={row['cohens_d']:.3f} (p_adj={row['p_adjusted']:.4f}). What does this mean clinically?"
                },
                {
                    "role": "assistant",
                    "content": _generate_interpretation(row)
                }
            ]
        }
        training_examples.append(example)

    # ---- Type 3: Explain why a hypothesis was discarded ----
    for _, row in discarded.sample(min(20, len(discarded)), random_state=42).iterrows():
        example = {
            "messages": [
                {
                    "role": "system",
                    "content": "You are a computational psychiatry researcher. Explain why a biomarker hypothesis failed and what this teaches us."
                },
                {
                    "role": "user",
                    "content": f"We tested whether {row['feature']} predicts depression. Result: AUC={row['auc']:.3f}, d={row['cohens_d']:.3f}, p_adj={row['p_adjusted']:.4f}. Status: DISCARDED. Why might this have failed?"
                },
                {
                    "role": "assistant",
                    "content": f"This feature did not reach significance after FDR correction (p_adj={row['p_adjusted']:.4f} > 0.01) and/or the effect size was too small (d={row['cohens_d']:.3f}). "
                    f"{'The AUC near 0.5 suggests this feature has essentially no discriminative power for depression status. ' if abs(row['auc'] - 0.5) < 0.05 else ''}"
                    f"This null result is informative: it tells us that {'mean levels of this marker' if '_mean' in row['feature'] else 'this particular temporal window'} alone is insufficient. "
                    f"The evidence increasingly points toward temporal dynamics (variability, autocorrelation) being more predictive than static levels, consistent with critical slowing down theory."
                }
            ]
        }
        training_examples.append(example)

    # ---- Type 4: Literature-grounded reasoning ----
    lit_examples = [
        {
            "messages": [
                {"role": "system", "content": "You are a computational psychiatry researcher."},
                {"role": "user", "content": "What is critical slowing down and how does it apply to depression prediction from wearables?"},
                {"role": "assistant", "content": "Critical slowing down is a phenomenon from dynamical systems theory (Scheffer 2009). Before a system transitions to a new state (a 'tipping point'), two warning signs appear: (1) rising autocorrelation — the system becomes 'sluggish', recovering more slowly from perturbations, and (2) rising variance — the system starts 'wobbling' more. This has been demonstrated in ecology, climate, and financial systems.\n\nvan de Leemput et al. (2014, PNAS) showed these warning signs in mood self-reports before depressive episodes. However, nobody has applied this to continuous physiological wearable data (HRV, sleep patterns) — which is our key innovation.\n\nIn practice, we compute rolling autocorrelation and coefficient of variation of daily RMSSD, heart rate, and sleep metrics. If these indicators rise in the days before PHQ-9 worsens, it would be the first evidence that the autonomic nervous system shows critical slowing down before depression onset — detectable from a smartwatch."}
            ]
        },
        {
            "messages": [
                {"role": "system", "content": "You are a computational psychiatry researcher."},
                {"role": "user", "content": "Why test HRV coefficient of variation (CV) specifically? Hasn't HRV-depression been studied extensively?"},
                {"role": "assistant", "content": "Yes — 56 meta-analyses confirm depressed people have lower mean HRV. But the effect sizes are small (d ≈ 0.3) and inconsistent. Everyone measures HOW LOW HRV is. Nobody measures HOW RIGID OR CHAOTIC it is over time.\n\nHRV-CV captures day-to-day variability — is your HRV staying rigidly the same every day, or does it fluctuate naturally? A 2025 study showed HRV-CV is a behavioral biomarker, but it was NEVER tested against PHQ-9 depression scores. This is our Gap 1.\n\nWhy it matters: a healthy autonomic system should show natural variability. If HRV becomes rigid (low CV, high autocorrelation), it suggests the system has lost flexibility — a hallmark of allostatic overload. This is fundamentally different from testing whether mean RMSSD is lower in depressed people."}
            ]
        },
        {
            "messages": [
                {"role": "system", "content": "You are a computational psychiatry researcher."},
                {"role": "user", "content": "What is digital allostatic load and why is it novel?"},
                {"role": "assistant", "content": "Allostatic load is the cumulative physiological 'wear and tear' from chronic stress. Traditionally measured with blood biomarkers: cortisol, C-reactive protein, IL-6, etc. Requires lab visits.\n\nOur digital allostatic load composite creates the same concept from wearable data: (-RMSSD_z + HR_z - sleep_quality_z) / 3. Higher scores mean: lower HRV (autonomic exhaustion) + higher resting heart rate (sympathetic overdrive) + worse sleep quality (recovery failure).\n\nThis has NEVER been validated against PHQ-9 depression scores. If it works, it would mean we can continuously monitor cumulative stress burden from a wrist — replacing expensive, infrequent blood draws with continuous, passive sensing. The clinical implication is enormous: daily allostatic load tracking could identify patients accumulating stress before they cross the depression threshold."}
            ]
        },
    ]
    training_examples.extend(lit_examples)

    # ---- Split train/val (90/10) ----
    import random
    random.seed(42)
    random.shuffle(training_examples)
    split = int(0.9 * len(training_examples))
    train_data = training_examples[:split]
    val_data = training_examples[split:]

    # Write JSONL
    with open(TRAINING_DATA_PATH, "w") as f:
        for ex in train_data:
            f.write(json.dumps(ex) + "\n")

    with open(VALIDATION_DATA_PATH, "w") as f:
        for ex in val_data:
            f.write(json.dumps(ex) + "\n")

    log(f"Training data: {len(train_data)} examples → {TRAINING_DATA_PATH}")
    log(f"Validation data: {len(val_data)} examples → {VALIDATION_DATA_PATH}")
    log(f"Total: {len(training_examples)} conversation examples")

    return train_data, val_data


def _generate_interpretation(row):
    """Generate a clinical interpretation for a significant finding."""
    feat = row["feature"]
    auc = row["auc"]
    d = row["cohens_d"]

    # Determine feature type
    if "autocorr" in feat:
        mechanism = "rising autocorrelation (sluggishness) — consistent with critical slowing down theory. The autonomic nervous system is recovering more slowly from daily perturbations."
        clinical = "This could serve as an early warning signal: when this metric starts rising, the patient may be approaching a depressive tipping point."
    elif "_cv" in feat:
        mechanism = "altered coefficient of variation (day-to-day variability). This suggests the physiological system has either become rigid (low CV) or chaotic (high CV)."
        clinical = "Monitoring this variability pattern could detect loss of autonomic flexibility days before mood symptoms appear."
    elif "_std" in feat:
        mechanism = "increased variance (wobbling) — the second key indicator of critical slowing down. The system is becoming less stable."
        clinical = "Combined with autocorrelation changes, this provides converging evidence for approaching a tipping point."
    elif "_slope" in feat:
        mechanism = "a directional trend over time, indicating progressive change rather than fluctuation."
        clinical = "A sustained negative slope in this marker could trigger clinical attention."
    elif "allostatic" in feat:
        mechanism = "cumulative physiological strain across multiple systems (HRV, heart rate, sleep). This composite captures what blood-based allostatic load measures, but continuously from a wearable."
        clinical = "The first evidence that wearable-derived allostatic load predicts depression severity."
    else:
        mechanism = f"differences in the level of this marker between depression groups."
        clinical = "This finding adds to the growing evidence for wearable-based depression monitoring."

    effect_size = "large" if d > 0.8 else "medium" if d > 0.5 else "small-to-medium"

    return (
        f"This is a significant finding with a {effect_size} effect size (d={d:.3f}). "
        f"The AUC of {auc:.3f} indicates {'good' if auc > 0.7 else 'moderate' if auc > 0.6 else 'modest'} "
        f"discriminative ability.\n\n"
        f"**Mechanism:** The result suggests {mechanism}\n\n"
        f"**Clinical relevance:** {clinical}\n\n"
        f"**Novel contribution:** This specific feature has not been tested against depression "
        f"in the published literature, making this a genuine discovery from the autoresearch loop."
    )


def start_finetune():
    """Upload data and start fine-tuning on Nebius."""
    if not NEBIUS_API_KEY:
        log("ERROR: No NEBIUS_API_KEY set")
        return

    from openai import OpenAI
    client = OpenAI(base_url=NEBIUS_BASE_URL, api_key=NEBIUS_API_KEY)

    if not os.path.exists(TRAINING_DATA_PATH):
        log("Training data not found. Run with --prepare first.")
        return

    # Count examples
    with open(TRAINING_DATA_PATH) as f:
        n_train = sum(1 for _ in f)
    log(f"Training data: {n_train} examples")

    # Upload training file
    log("Uploading training data to Nebius...")
    with open(TRAINING_DATA_PATH, "rb") as f:
        train_file = client.files.create(file=f, purpose="fine-tune")
    log(f"  Training file ID: {train_file.id}")

    # Upload validation file
    val_file = None
    if os.path.exists(VALIDATION_DATA_PATH):
        log("Uploading validation data...")
        with open(VALIDATION_DATA_PATH, "rb") as f:
            val_file = client.files.create(file=f, purpose="fine-tune")
        log(f"  Validation file ID: {val_file.id}")

    # Start fine-tuning job
    log(f"Starting fine-tuning: {FINETUNE_MODEL}...")
    log(f"  Budget limit: ${NEBIUS_BUDGET_LIMIT}")

    ft_params = {
        "training_file": train_file.id,
        "model": FINETUNE_MODEL,
        "hyperparameters": {
            "n_epochs": 3,
            "learning_rate_multiplier": 1.5,
        },
        "suffix": "autobiomarker",
    }
    if val_file:
        ft_params["validation_file"] = val_file.id

    job = client.fine_tuning.jobs.create(**ft_params)

    log(f"  Fine-tuning job ID: {job.id}")
    log(f"  Status: {job.status}")

    # Save job info
    job_info = {
        "job_id": job.id,
        "model": FINETUNE_MODEL,
        "training_file": train_file.id,
        "validation_file": val_file.id if val_file else None,
        "status": job.status,
        "started_at": datetime.datetime.now().isoformat(),
    }
    with open(os.path.join(FINETUNE_DIR, "job_info.json"), "w") as f:
        json.dump(job_info, f, indent=2)

    log(f"\nFine-tuning started! Monitor with: python finetune_nebius.py --status")
    log(f"This typically takes 15-30 minutes on Nebius H100s.")

    # Monitor progress
    log("\nMonitoring progress...")
    while job.status in ("validating_files", "queued", "running"):
        time.sleep(30)
        job = client.fine_tuning.jobs.retrieve(job.id)
        log(f"  Status: {job.status}")

        if hasattr(job, "trained_tokens") and job.trained_tokens:
            log(f"  Trained tokens: {job.trained_tokens}")

    if job.status == "succeeded":
        log(f"\nFine-tuning SUCCEEDED!")
        log(f"  Fine-tuned model: {job.fine_tuned_model}")

        job_info["status"] = "succeeded"
        job_info["fine_tuned_model"] = job.fine_tuned_model
        with open(os.path.join(FINETUNE_DIR, "job_info.json"), "w") as f:
            json.dump(job_info, f, indent=2)
    else:
        log(f"\nFine-tuning ended with status: {job.status}")
        if hasattr(job, "error"):
            log(f"  Error: {job.error}")

    return job


def check_status():
    """Check fine-tuning job status."""
    job_path = os.path.join(FINETUNE_DIR, "job_info.json")
    if not os.path.exists(job_path):
        log("No fine-tuning job found. Run with --train first.")
        return

    with open(job_path) as f:
        job_info = json.load(f)

    from openai import OpenAI
    client = OpenAI(base_url=NEBIUS_BASE_URL, api_key=NEBIUS_API_KEY)

    job = client.fine_tuning.jobs.retrieve(job_info["job_id"])
    log(f"Job ID: {job.id}")
    log(f"Status: {job.status}")
    log(f"Model: {job_info['model']}")

    if hasattr(job, "fine_tuned_model") and job.fine_tuned_model:
        log(f"Fine-tuned model: {job.fine_tuned_model}")

    # List events
    events = client.fine_tuning.jobs.list_events(job.id, limit=10)
    log("\nRecent events:")
    for event in events.data:
        log(f"  {event.message}")


def compare_models():
    """Compare base vs fine-tuned model for hypothesis generation."""
    job_path = os.path.join(FINETUNE_DIR, "job_info.json")
    if not os.path.exists(job_path):
        log("No fine-tuned model found.")
        return

    with open(job_path) as f:
        job_info = json.load(f)

    ft_model = job_info.get("fine_tuned_model")
    if not ft_model:
        log("Fine-tuning not yet complete.")
        return

    from openai import OpenAI
    client = OpenAI(base_url=NEBIUS_BASE_URL, api_key=NEBIUS_API_KEY)

    test_prompt = """Based on these prior biomarker testing results, propose the next hypothesis to test.

PRIOR RESULTS (top findings so far):
  - sleep_dur_14d_std: AUC=0.661, d=0.619 (SIGNIFICANT)
  - lfhf_14d_mean: AUC=0.627, d=0.683 (SIGNIFICANT)
  - rmssd_7d_autocorr: AUC=0.580, d=0.420 (SIGNIFICANT)

CONTEXT: 49 participants, 28 days of daily HRV + sleep data, PHQ-9 depression scores.

Propose ONE novel biomarker hypothesis. Explain your reasoning."""

    log("=" * 60)
    log("BASE MODEL vs FINE-TUNED MODEL COMPARISON")
    log("=" * 60)

    for model_name, model_id in [("Base (Llama 3.3 70B)", NEBIUS_MODEL),
                                   ("Fine-tuned (Llama 3.1 8B)", ft_model)]:
        log(f"\n--- {model_name} ---")
        try:
            response = client.chat.completions.create(
                model=model_id,
                messages=[
                    {"role": "system", "content": "You are a computational psychiatry researcher specializing in wearable biomarker discovery for depression."},
                    {"role": "user", "content": test_prompt},
                ],
                temperature=0.7,
                max_tokens=500,
            )
            log(response.choices[0].message.content)

            if response.usage:
                log(f"\n  Tokens: {response.usage.total_tokens}")
        except Exception as e:
            log(f"  Error: {e}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="AutoBiomarker Nebius Fine-Tuning")
    parser.add_argument("--prepare", action="store_true", help="Prepare training data")
    parser.add_argument("--train", action="store_true", help="Start fine-tuning on Nebius")
    parser.add_argument("--status", action="store_true", help="Check job status")
    parser.add_argument("--compare", action="store_true", help="Compare base vs fine-tuned")
    parser.add_argument("--all", action="store_true", help="Run full pipeline")
    args = parser.parse_args()

    if args.all or args.prepare:
        prepare_training_data()

    if args.all or args.train:
        start_finetune()

    if args.status:
        check_status()

    if args.compare:
        compare_models()

    if not any([args.prepare, args.train, args.status, args.compare, args.all]):
        parser.print_help()
