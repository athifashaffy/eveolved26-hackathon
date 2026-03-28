"""
AutoBiomarker — Overnight Runner

Runs the full autoresearch pipeline continuously:
1. Predefined hypotheses (single features + all interactions)
2. Multiple rounds of LLM-guided hypothesis generation
3. Saves intermediate results every 100 hypotheses
4. Logs progress to overnight_log.txt

Usage:
  python run_overnight.py
"""

import time
import sys
import os
import datetime
import numpy as np
import pandas as pd

# Add src to path
sys.path.insert(0, os.path.dirname(__file__))

from config import MAX_HYPOTHESES, PHQ9_MILD_THRESHOLD, RESULTS_DIR
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
    HypothesisResult,
    save_results,
)


LOG_FILE = os.path.join(RESULTS_DIR, "overnight_log.txt")


def log(msg: str):
    """Print and log to file."""
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{timestamp}] {msg}"
    print(line)
    os.makedirs(RESULTS_DIR, exist_ok=True)
    with open(LOG_FILE, "a") as f:
        f.write(line + "\n")


def save_intermediate(results: list[HypothesisResult], tag: str = ""):
    """Save intermediate results without FDR correction."""
    os.makedirs(RESULTS_DIR, exist_ok=True)
    rows = []
    for r in results:
        rows.append({
            "id": r.hypothesis_id,
            "feature": r.feature,
            "auc": r.auc,
            "p_value": r.p_value,
            "p_adjusted": r.p_adjusted,
            "cohens_d": r.cohens_d,
            "n_pos": r.n_positive,
            "n_neg": r.n_negative,
            "ci_lower": r.ci_lower,
            "ci_upper": r.ci_upper,
            "status": r.status,
            "description": r.description,
        })
    df = pd.DataFrame(rows)
    path = os.path.join(RESULTS_DIR, f"results_intermediate{tag}.tsv")
    df.to_csv(path, sep="\t", index=False)
    return path


def run_overnight():
    """Full overnight autoresearch run."""
    start_time = time.time()

    log("=" * 70)
    log("AutoBiomarker — OVERNIGHT RUN")
    log(f"Started at {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    log(f"Max hypotheses: {MAX_HYPOTHESES}")
    log("=" * 70)

    # ---- Load data ----
    log("[1/6] Loading dataset...")
    hrv = load_hrv_metrics()
    daily_hrv = compute_daily_hrv(hrv)
    sleep = load_sleep_diary()
    clinical = load_clinical_metadata()
    merged = build_merged_dataset(daily_hrv, sleep, clinical)

    # ---- Extract features ----
    log("[2/6] Extracting temporal features (6 rolling windows)...")
    features_df = compute_early_warning_signals(merged)
    feature_names = get_feature_names(features_df)
    log(f"  {len(feature_names)} features extracted")

    # ---- Prepare outcome ----
    log("[3/6] Preparing outcome...")
    phq9_map = clinical.set_index("subject_id")["PHQ9"].to_dict()
    outcome = features_df["subject_id"].map(phq9_map)
    binary_outcome = (outcome >= PHQ9_MILD_THRESHOLD).astype(float)
    n_pos = int(binary_outcome.sum())
    n_neg = int(len(binary_outcome) - n_pos)
    log(f"  Outcome (PHQ-9 >= {PHQ9_MILD_THRESHOLD}): {n_pos} positive, {n_neg} negative")

    subject_ids = features_df["subject_id"]

    # ---- Phase 1: Predefined hypotheses ----
    log("[4/6] Generating predefined hypotheses...")
    generator = HypothesisGenerator(use_llm=True)
    evaluator = HypothesisEvaluator()

    hypotheses = generator.get_predefined_hypotheses(feature_names)
    hypotheses = hypotheses[:MAX_HYPOTHESES]
    log(f"  Will test {len(hypotheses)} predefined hypotheses")

    results = []
    phase1_start = time.time()

    for i, hypothesis in enumerate(hypotheses):
        result = evaluator.evaluate(
            hypothesis=hypothesis,
            features_df=features_df,
            outcome_series=binary_outcome,
            subject_ids=subject_ids,
        )
        results.append(result)

        # Progress every 100
        if (i + 1) % 100 == 0:
            elapsed = time.time() - phase1_start
            rate = (i + 1) / elapsed
            promising = sum(1 for r in results if r.auc > 0.6 and r.p_value < 0.05)
            log(f"  [{i+1}/{len(hypotheses)}] {rate:.1f} hyp/sec | Promising: {promising} | AUC: {result.auc:.3f}")

            # Save intermediate
            save_intermediate(results, f"_phase1_{i+1}")

    phase1_time = time.time() - phase1_start
    log(f"  Phase 1 complete: {len(results)} hypotheses in {phase1_time/60:.1f} min")
    save_intermediate(results, "_phase1_done")

    # ---- Phase 2: LLM-guided exploration (multiple rounds) ----
    if generator.use_llm:
        log("[5/6] LLM-guided hypothesis generation (multiple rounds)...")
        llm_round = 0
        max_llm_hypotheses = min(200, MAX_HYPOTHESES - len(results))

        # Do interim FDR to inform LLM
        interim_results = evaluator.apply_fdr_correction(list(results))

        while len(results) < MAX_HYPOTHESES and llm_round < 10:
            llm_round += 1
            round_start = time.time()
            round_count = 0
            batch_size = min(20, max_llm_hypotheses - (len(results) - len(hypotheses)))

            if batch_size <= 0:
                break

            log(f"  LLM Round {llm_round}: generating up to {batch_size} hypotheses...")

            for _ in range(batch_size):
                llm_hyp = generator.generate_llm_hypothesis(interim_results, feature_names)
                if llm_hyp is None:
                    break

                result = evaluator.evaluate(
                    hypothesis=llm_hyp,
                    features_df=features_df,
                    outcome_series=binary_outcome,
                    subject_ids=subject_ids,
                )
                results.append(result)
                round_count += 1

            round_time = time.time() - round_start
            if round_count > 0:
                log(f"    Round {llm_round}: {round_count} hypotheses in {round_time:.0f}s "
                    f"(API cost: ~${generator.estimated_cost:.3f})")
                save_intermediate(results, f"_llm_round{llm_round}")

                # Re-run FDR on all results to inform next round
                interim_results = evaluator.apply_fdr_correction(list(results))
            else:
                log(f"    Round {llm_round}: no valid hypotheses generated, stopping LLM")
                break
    else:
        log("[5/6] Skipping LLM (no API key)")

    # ---- Phase 3: Final FDR correction ----
    log(f"[6/6] Final FDR correction across {len(results)} hypotheses...")
    results = evaluator.apply_fdr_correction(results)

    total_time = time.time() - start_time
    log(f"\n{'='*70}")
    log(f"OVERNIGHT RUN COMPLETE")
    log(f"{'='*70}")
    log(f"Total time: {total_time/60:.1f} minutes ({total_time/3600:.1f} hours)")
    log(f"Hypotheses tested: {len(results)}")
    if total_time > 0:
        log(f"Rate: {len(results)/total_time:.1f} hypotheses/second")
    if generator.use_llm:
        log(f"LLM calls: {generator.llm_calls} (est. cost: ${generator.estimated_cost:.3f})")

    # Save final results
    save_results(results)

    # Summary of findings
    kept = [r for r in results if r.status == "KEEP"]
    log(f"\nSIGNIFICANT FINDINGS: {len(kept)} / {len(results)}")

    if kept:
        kept_sorted = sorted(kept, key=lambda r: r.cohens_d, reverse=True)
        log("\nTop 20 biomarkers:")
        for i, r in enumerate(kept_sorted[:20]):
            log(f"  {i+1}. {r.feature}: AUC={r.auc:.3f}, d={r.cohens_d:.3f}, p_adj={r.p_adjusted:.4f}")
            log(f"     {r.description}")

        # Category breakdown
        categories = {}
        for r in kept:
            parts = r.feature.split("_")
            cat = parts[0] if parts[0] not in ("×",) else "interaction"
            if "×" in r.feature:
                cat = "interaction"
            categories[cat] = categories.get(cat, 0) + 1

        log("\nFindings by category:")
        for cat, count in sorted(categories.items(), key=lambda x: -x[1]):
            log(f"  {cat}: {count}")

    log(f"\nResults saved to: {os.path.abspath(os.path.join(RESULTS_DIR, 'results.tsv'))}")
    log(f"Log saved to: {os.path.abspath(LOG_FILE)}")

    return results


if __name__ == "__main__":
    try:
        results = run_overnight()
    except KeyboardInterrupt:
        log("\nInterrupted by user. Partial results may be in results/ directory.")
    except Exception as e:
        log(f"\nERROR: {e}")
        import traceback
        log(traceback.format_exc())
        raise
