"""
AutoBiomarker — Full Overnight Pipeline

Runs sequentially:
  1. Round 1: 5,000 predefined + LLM-guided hypotheses (run_overnight.py)
  2. Round 2: LLM-guided refinement from Round 1 results (run_round2.py)
  3. Model training on all results (train_models.py)

Usage:
  python run_overnight_full.py
"""

import os
import sys
import time
import datetime
import traceback

sys.path.insert(0, os.path.dirname(__file__))

from config import RESULTS_DIR

LOG_FILE = os.path.join(RESULTS_DIR, "overnight_full_log.txt")


def log(msg: str):
    ts = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{ts}] {msg}"
    print(line)
    os.makedirs(RESULTS_DIR, exist_ok=True)
    with open(LOG_FILE, "a") as f:
        f.write(line + "\n")


def main():
    overall_start = time.time()

    log("=" * 70)
    log("AutoBiomarker — FULL OVERNIGHT PIPELINE")
    log(f"Started at {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    log("=" * 70)

    # ---- Round 1 ----
    log("\n" + "=" * 50)
    log("PHASE 1: Round 1 — Broad Autoresearch (5,000 hypotheses)")
    log("=" * 50)
    try:
        from run_overnight import run_overnight
        r1_start = time.time()
        round1_results = run_overnight()
        r1_time = time.time() - r1_start
        log(f"Round 1 complete: {len(round1_results)} hypotheses in {r1_time/60:.1f} min")
        kept1 = sum(1 for r in round1_results if r.status == "KEEP")
        log(f"Round 1 significant: {kept1}/{len(round1_results)}")
    except Exception as e:
        log(f"Round 1 FAILED: {e}")
        log(traceback.format_exc())
        log("Continuing to Round 2 anyway (using existing results if available)...")

    # ---- Round 2 ----
    log("\n" + "=" * 50)
    log("PHASE 2: Round 2 — LLM-Guided Refinement")
    log("=" * 50)
    try:
        from run_round2 import run_round2
        r2_start = time.time()
        round2_results = run_round2()
        r2_time = time.time() - r2_start
        log(f"Round 2 complete in {r2_time/60:.1f} min")
    except Exception as e:
        log(f"Round 2 FAILED: {e}")
        log(traceback.format_exc())

    # ---- Model Training ----
    log("\n" + "=" * 50)
    log("PHASE 3: Model Training (leakage-free LOSO-CV)")
    log("=" * 50)
    try:
        from train_models import run_training
        t_start = time.time()
        run_training()
        t_time = time.time() - t_start
        log(f"Model training complete in {t_time/60:.1f} min")
    except Exception as e:
        log(f"Model training FAILED: {e}")
        log(traceback.format_exc())

    # ---- Summary ----
    total_time = time.time() - overall_start
    log("\n" + "=" * 70)
    log("FULL PIPELINE COMPLETE")
    log(f"Total time: {total_time/60:.1f} min ({total_time/3600:.1f} hours)")
    log("=" * 70)

    # Check results files
    for fname in ["results.tsv", "results_round2.tsv", "models/model_comparison.tsv",
                   "models/best_model_meta.json"]:
        path = os.path.join(RESULTS_DIR, fname)
        if os.path.exists(path):
            size = os.path.getsize(path)
            log(f"  {fname}: {size:,} bytes")
        else:
            log(f"  {fname}: NOT FOUND")

    log(f"\nFull log: {os.path.abspath(LOG_FILE)}")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        log("\nInterrupted by user.")
    except Exception as e:
        log(f"\nFATAL ERROR: {e}")
        log(traceback.format_exc())
        raise
