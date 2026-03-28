"""
AutoBiomarker — Main Autoresearch Loop

Adapted from Karpathy's autoresearch pattern:
  Original: modify train.py → train → evaluate val_bpb → keep/revert → repeat
  Ours:     propose hypothesis → extract feature → test statistically → keep/discard → repeat

Usage:
  python autoresearch_loop.py           # with LLM
  python autoresearch_loop.py --no-llm  # without LLM
"""

import time
import numpy as np
import pandas as pd

from config import MAX_HYPOTHESES, PHQ9_MILD_THRESHOLD
from data_loader import (
    load_hrv_metrics,
    load_sleep_diary,
    load_clinical_metadata,
    compute_daily_hrv,
    build_merged_dataset,
)
from feature_extractor import compute_early_warning_signals, get_feature_names
from hypothesis import (
    BiomarkerHypothesis,
    HypothesisGenerator,
    HypothesisEvaluator,
    save_results,
)


def prepare_outcome(merged_df: pd.DataFrame, clinical_df: pd.DataFrame) -> pd.Series:
    """Create binary outcome variables from PHQ-9 scores.

    Primary outcome: PHQ-9 >= 5 (mild+ depression)
    Using 5 instead of 10 because only 4/49 participants score >= 10.
    """
    phq9_map = clinical_df.set_index("subject_id")["PHQ9"].to_dict()
    outcome = merged_df["subject_id"].map(phq9_map)
    binary_outcome = (outcome >= PHQ9_MILD_THRESHOLD).astype(float)

    n_pos = int(binary_outcome.sum())
    n_neg = int(len(binary_outcome) - n_pos)
    print(f"Outcome (PHQ-9 >= {PHQ9_MILD_THRESHOLD}): {n_pos} positive, {n_neg} negative")

    return binary_outcome


def run_autoresearch_loop(use_llm: bool = True):
    """Main autonomous biomarker discovery loop."""
    print("=" * 60)
    print("AutoBiomarker — Autonomous Biomarker Discovery")
    print("Adapted from Karpathy's autoresearch pattern")
    print("=" * 60)

    # ---- Step 1: Load data ----
    print("\n[1/5] Loading Baigutanova et al. 2025 dataset...")
    try:
        hrv = load_hrv_metrics()
        daily_hrv = compute_daily_hrv(hrv)
        sleep = load_sleep_diary()
        clinical = load_clinical_metadata()
        merged = build_merged_dataset(daily_hrv, sleep, clinical)
    except FileNotFoundError as e:
        print(f"\nERROR: {e}")
        print("\nTo get started:")
        print("1. Download from: https://springernature.figshare.com/articles/dataset/28509740")
        print("2. Place CSV files in: ../data/")
        return

    # ---- Step 2: Extract temporal features ----
    print("\n[2/5] Extracting temporal features (critical slowing down indicators)...")
    features_df = compute_early_warning_signals(merged)
    feature_names = get_feature_names(features_df)
    print(f"  {len(feature_names)} features extracted")

    # ---- Step 3: Prepare outcome ----
    print("\n[3/5] Preparing outcome variable...")
    outcome = prepare_outcome(features_df, clinical)
    subject_ids = features_df["subject_id"]

    # ---- Step 4: Generate and test hypotheses ----
    print(f"\n[4/5] Running autoresearch loop (up to {MAX_HYPOTHESES} hypotheses)...")
    print("  This runs autonomously. Go sleep. Wake up to results.\n")

    generator = HypothesisGenerator(use_llm=use_llm)
    evaluator = HypothesisEvaluator()

    # Start with predefined hypotheses
    hypotheses = generator.get_predefined_hypotheses(feature_names)

    # Cap at MAX_HYPOTHESES
    hypotheses = hypotheses[:MAX_HYPOTHESES]

    results = []
    start_time = time.time()

    for i, hypothesis in enumerate(hypotheses):
        elapsed = time.time() - start_time
        rate = (i + 1) / elapsed if elapsed > 0 else 0

        result = evaluator.evaluate(
            hypothesis=hypothesis,
            features_df=features_df,
            outcome_series=outcome,
            subject_ids=subject_ids,
        )
        results.append(result)

        # Progress update every 50 hypotheses
        if (i + 1) % 50 == 0:
            pending_keep = sum(1 for r in results if r.auc > 0.6 and r.p_value < 0.05)
            print(
                f"  [{i+1}/{len(hypotheses)}] "
                f"{rate:.1f} hyp/sec | "
                f"Promising: {pending_keep} | "
                f"Latest AUC: {result.auc:.3f}"
            )

    # Add LLM-generated hypotheses if enabled
    if use_llm and generator.use_llm:
        print("\n  Generating LLM-proposed hypotheses...")
        for _ in range(min(50, MAX_HYPOTHESES - len(results))):
            llm_hyp = generator.generate_llm_hypothesis(results, feature_names)
            if llm_hyp:
                result = evaluator.evaluate(
                    hypothesis=llm_hyp,
                    features_df=features_df,
                    outcome_series=outcome,
                    subject_ids=subject_ids,
                )
                results.append(result)

    # ---- Step 5: FDR correction and report ----
    print(f"\n[5/5] Applying FDR correction across {len(results)} hypotheses...")
    results = evaluator.apply_fdr_correction(results)

    total_time = time.time() - start_time
    print(f"\nCompleted in {total_time:.1f} seconds ({total_time/60:.1f} minutes)")
    print(f"Hypotheses tested: {len(results)}")
    if total_time > 0:
        print(f"Rate: {len(results)/total_time:.1f} hypotheses/second")

    # Save results
    save_results(results)

    return results


if __name__ == "__main__":
    import sys

    use_llm = "--no-llm" not in sys.argv
    if not use_llm:
        print("Running without LLM hypothesis generation (--no-llm flag)")

    results = run_autoresearch_loop(use_llm=use_llm)
