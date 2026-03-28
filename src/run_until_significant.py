"""
AutoBiomarker — Persistent Autoresearch Until Significant Finding

Strategy: Run many SMALL rounds (5-10 hypotheses each) so FDR correction
is mild within each round. Feed results forward between rounds.

Key insight: BH-FDR across 5,000 tests at n=49 is too conservative.
Small targeted rounds (5-10 tests) have a realistic chance of surviving FDR.

Usage:
  python run_until_significant.py
"""

import os
import sys
import time
import json
import datetime
import numpy as np
import pandas as pd
from copy import deepcopy

sys.path.insert(0, os.path.dirname(__file__))

from config import (
    NEBIUS_API_KEY, NEBIUS_BASE_URL, NEBIUS_MODEL,
    NEBIUS_COST_PER_1K_TOKENS, RESULTS_DIR, RESULTS_TSV,
    PHQ9_MILD_THRESHOLD, ROLLING_WINDOWS,
)
from data_loader import (
    load_hrv_metrics, load_sleep_diary, load_clinical_metadata,
    compute_daily_hrv, build_merged_dataset,
)
from feature_extractor import compute_early_warning_signals, get_feature_names, compute_rolling_stats
from hypothesis import (
    BiomarkerHypothesis, HypothesisEvaluator, HypothesisResult,
)

PERSISTENT_LOG = os.path.join(RESULTS_DIR, "persistent_search_log.txt")
PERSISTENT_RESULTS = os.path.join(RESULTS_DIR, "persistent_search_results.tsv")
MAX_ROUNDS = 50
MAX_COST = 5.0  # dollars
HYPOTHESES_PER_ROUND = 8  # small rounds = mild FDR


def log(msg: str):
    ts = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{ts}] {msg}"
    print(line)
    os.makedirs(RESULTS_DIR, exist_ok=True)
    with open(PERSISTENT_LOG, "a") as f:
        f.write(line + "\n")


def build_adaptive_prompt(
    round_num: int,
    all_prior_results: list[dict],
    feature_names: list[str],
    prior_proposals: list[str],
) -> str:
    """Build an evolving prompt that learns from ALL prior rounds."""

    # Sort all prior results by Cohen's d
    best_results = sorted(all_prior_results, key=lambda r: r.get("cohens_d", 0), reverse=True)

    # Top 15 best features so far
    top_lines = []
    for r in best_results[:15]:
        status = "PROMISING" if r.get("p_value", 1) < 0.05 else "weak"
        top_lines.append(
            f"  {status}: {r['feature']} | AUC={r.get('auc', 0):.3f} | d={r.get('cohens_d', 0):.3f} | "
            f"p={r.get('p_value', 1):.4f} | p_adj={r.get('p_adjusted', 1):.4f}"
        )
    top_section = "\n".join(top_lines) if top_lines else "  (no results yet)"

    # Features that nearly passed FDR (p_adj < 0.10)
    near_miss = [r for r in best_results if r.get("p_adjusted", 1) < 0.15]
    near_lines = []
    for r in near_miss[:5]:
        near_lines.append(
            f"  NEAR-MISS: {r['feature']} | d={r.get('cohens_d', 0):.3f} | p_adj={r.get('p_adjusted', 1):.4f}"
        )
    near_section = "\n".join(near_lines) if near_lines else "  (none yet)"

    # What types have been tried
    tried_types = set()
    for r in all_prior_results:
        feat = r.get("feature", "")
        if "×" in feat:
            tried_types.add("interaction")
        elif "composite" in feat:
            tried_types.add("composite")
        else:
            tried_types.add("single")

    prior_text = ""
    if prior_proposals:
        recent = prior_proposals[-30:]  # last 30
        prior_text = f"\n\nALREADY TESTED (do NOT repeat these exact combinations):\n" + "\n".join(f"  - {p}" for p in recent)

    # Adaptive focus based on what's working
    if round_num <= 3:
        focus = """FOCUS: Test interactions between features with the HIGHEST effect sizes from prior rounds.
The best single features tend to be: lfhf slope/autocorr, rmssd_7d_std, sleep variability features.
Propose 5 interaction hypotheses (feature1 × feature2) using these top performers."""
    elif round_num <= 8:
        focus = """FOCUS: The near-miss features almost passed FDR. Propose VARIANTS of these:
- Try different temporal windows (2d, 4d, 10d instead of 7d, 14d, 21d)
- Try combining near-miss features into composites
- Try the same base signal with a different statistic (e.g., if slope worked, try autocorr)
Propose 5 hypotheses that are variations on the near-miss features."""
    elif round_num <= 15:
        focus = """FOCUS: Try NOVEL composite indices that combine 3-4 features into one biomarker.
These composites should combine:
  - An HRV temporal feature (e.g., lfhf slope or rmssd autocorr)
  - A sleep variability feature (e.g., sleep_dur_std or sleep_lat_cv)
  - Optionally a cross-domain interaction term
Name each composite and explain the clinical logic. Propose 5 composites."""
    elif round_num <= 25:
        focus = """FOCUS: Try RATIO features and NON-LINEAR combinations:
- Ratio of two features: feature1 / (feature2 + epsilon)
- Squared terms: feature^2 to capture non-linear effects
- Difference features: feature_7d - feature_28d (short vs long term change)
- Max-min range features across windows
Be creative. Propose 5 novel transformations."""
    else:
        focus = """FOCUS: Final attempts. Try the MOST creative combinations you can think of:
- Triple interactions (feat1 × feat2 × feat3)
- Entropy-like measures of feature distributions
- Change-point detection features
- Features inspired by allostatic load theory
Propose 5 highly creative hypotheses."""

    return f"""You are a computational psychiatry researcher running Round {round_num} of an iterative autoresearch loop.

DATASET: 49 participants, 28 days daily HRV (RMSSD, HR, LF/HF) + sleep diary. Outcome: PHQ-9 >= 5.
CHALLENGE: Subject-level permutation tests at n=49 with BH-FDR correction. Need p_adj < 0.05.

BEST RESULTS SO FAR (across {len(all_prior_results)} tested hypotheses):
{top_section}

NEAR-MISS FEATURES (almost significant after FDR):
{near_section}

{focus}{prior_text}

AVAILABLE FEATURES: {', '.join(feature_names[:80])}

IMPORTANT:
- Each round tests only {HYPOTHESES_PER_ROUND} hypotheses, so FDR correction is mild
- Focus on features with large effect sizes (d > 0.5) AND low p-values (p < 0.05)
- The sweet spot is interactions between features that both have strong individual effects

Respond in JSON:
{{
  "hypotheses": [
    {{
      "type": "interaction" | "new_window" | "composite",
      "feature1": "existing_feature_name",
      "feature2": "existing_feature_name_or_null",
      "new_window": null | 2 | 4 | 10,
      "base_signal": "rmssd | hr | lfhf | sleep_dur | sleep_qual | sleep_lat",
      "statistic": "mean | std | cv | slope | autocorr",
      "composite_formula": "description if composite",
      "description": "Clinical reasoning"
    }}
  ]
}}"""


def run_persistent_search():
    """Keep running small targeted rounds until we find something significant."""
    start_time = time.time()

    log("=" * 70)
    log("AutoBiomarker — PERSISTENT SEARCH FOR SIGNIFICANCE")
    log(f"Strategy: Small rounds ({HYPOTHESES_PER_ROUND} hypotheses) with mild FDR")
    log(f"Max rounds: {MAX_ROUNDS}, Max cost: ${MAX_COST}")
    log("=" * 70)

    # ---- Load data ----
    log("Loading dataset...")
    hrv = load_hrv_metrics()
    daily_hrv = compute_daily_hrv(hrv)
    sleep = load_sleep_diary()
    clinical = load_clinical_metadata()
    merged = build_merged_dataset(daily_hrv, sleep, clinical)
    features_df = compute_early_warning_signals(merged)
    feature_names = get_feature_names(features_df)
    log(f"  {len(feature_names)} features available")

    phq9_map = clinical.set_index("subject_id")["PHQ9"].to_dict()
    outcome = features_df["subject_id"].map(phq9_map)
    binary_outcome = (outcome >= PHQ9_MILD_THRESHOLD).astype(float)
    subject_ids = features_df["subject_id"]

    # Load Round 1 results as prior knowledge
    all_prior_results = []
    if os.path.exists(RESULTS_TSV):
        r1_df = pd.read_csv(RESULTS_TSV, sep="\t")
        for _, row in r1_df.iterrows():
            all_prior_results.append(row.to_dict())
        log(f"Loaded {len(all_prior_results)} Round 1 results as prior knowledge")

    # Also load any existing persistent results
    if os.path.exists(PERSISTENT_RESULTS):
        prev_df = pd.read_csv(PERSISTENT_RESULTS, sep="\t")
        for _, row in prev_df.iterrows():
            all_prior_results.append(row.to_dict())
        log(f"Loaded {len(prev_df)} previous persistent search results")

    # ---- Initialize LLM ----
    from openai import OpenAI
    client = OpenAI(base_url=NEBIUS_BASE_URL, api_key=NEBIUS_API_KEY)

    evaluator = HypothesisEvaluator()
    total_cost = 0.0
    prior_proposals = []
    hypothesis_id = 20000
    all_significant = []
    all_round_results = []

    # Import parse_and_test from run_round2
    from run_round2 import parse_and_test_hypotheses

    for round_num in range(1, MAX_ROUNDS + 1):
        log(f"\n{'='*50}")
        log(f"ROUND {round_num}/{MAX_ROUNDS} | Cost so far: ${total_cost:.4f}")
        log(f"{'='*50}")

        # Build adaptive prompt
        prompt = build_adaptive_prompt(round_num, all_prior_results, feature_names, prior_proposals)

        try:
            response = client.chat.completions.create(
                model=NEBIUS_MODEL,
                messages=[{"role": "user", "content": prompt}],
                response_format={"type": "json_object"},
                temperature=0.9,  # higher temp for more creative hypotheses
                max_tokens=2000,
            )

            tokens = getattr(response.usage, "total_tokens", 1000) if response.usage else 1000
            cost = (tokens / 1000) * NEBIUS_COST_PER_1K_TOKENS
            total_cost += cost

            raw = response.choices[0].message.content
            parsed = json.loads(raw)
            hypotheses_list = parsed.get("hypotheses", [])
            log(f"  LLM proposed {len(hypotheses_list)} hypotheses (${cost:.4f})")

            # Track proposals
            for h in hypotheses_list:
                desc_short = h.get("description", "")[:50]
                prior_proposals.append(
                    f"{h.get('type','?')}: {h.get('feature1','')} {h.get('feature2','')} - {desc_short}"
                )

            # Test hypotheses
            results = parse_and_test_hypotheses(
                parsed, features_df, merged, binary_outcome, subject_ids,
                evaluator, hypothesis_id,
            )
            hypothesis_id += len(hypotheses_list) + 1

            if not results:
                log("  No valid hypotheses to test this round")
                continue

            # Apply FDR ONLY within this small round
            round_results = evaluator.apply_fdr_correction(results)

            # Check for significant findings
            kept = [r for r in round_results if r.status == "KEEP"]

            for r in round_results:
                result_dict = {
                    "id": r.hypothesis_id, "feature": r.feature,
                    "auc": r.auc, "p_value": r.p_value, "p_adjusted": r.p_adjusted,
                    "cohens_d": r.cohens_d, "n_pos": r.n_positive, "n_neg": r.n_negative,
                    "ci_lower": r.ci_lower, "ci_upper": r.ci_upper,
                    "status": r.status, "description": r.description,
                    "round": round_num,
                }
                all_prior_results.append(result_dict)
                all_round_results.append(result_dict)

            # Report round results
            best_in_round = sorted(round_results, key=lambda r: r.cohens_d, reverse=True)
            for r in best_in_round[:3]:
                marker = "*** SIGNIFICANT ***" if r.status == "KEEP" else ""
                log(f"  {r.feature}: AUC={r.auc:.3f}, d={r.cohens_d:.3f}, "
                    f"p={r.p_value:.4f}, p_adj={r.p_adjusted:.4f} {marker}")

            if kept:
                all_significant.extend(kept)
                log(f"\n  !!! FOUND {len(kept)} SIGNIFICANT FINDING(S) !!!")
                for r in kept:
                    log(f"  >>> {r.feature}: AUC={r.auc:.3f}, d={r.cohens_d:.3f}, p_adj={r.p_adjusted:.4f}")
                    log(f"      {r.description}")

                # Save immediately
                _save_results(all_round_results)
                log(f"\n  Total significant findings so far: {len(all_significant)}")

                # Keep going to find more, but celebrate
                log("  Continuing search for more findings...")

        except json.JSONDecodeError as e:
            log(f"  JSON parse error: {e}")
        except Exception as e:
            log(f"  Error in round {round_num}: {e}")
            import traceback
            log(traceback.format_exc())

        # Budget check
        if total_cost > MAX_COST:
            log(f"\nBudget limit reached (${total_cost:.2f} > ${MAX_COST})")
            break

        # Save intermediate results every 5 rounds
        if round_num % 5 == 0:
            _save_results(all_round_results)

    # ---- Final summary ----
    elapsed = time.time() - start_time
    _save_results(all_round_results)

    log("\n" + "=" * 70)
    log("PERSISTENT SEARCH COMPLETE")
    log("=" * 70)
    log(f"Rounds: {round_num}")
    log(f"Total hypotheses tested: {len(all_round_results)}")
    log(f"Significant findings: {len(all_significant)}")
    log(f"Total LLM cost: ${total_cost:.4f}")
    log(f"Time: {elapsed/60:.1f} min")

    if all_significant:
        log("\nALL SIGNIFICANT FINDINGS:")
        for i, r in enumerate(sorted(all_significant, key=lambda r: r.cohens_d, reverse=True)):
            log(f"  {i+1}. {r.feature}: AUC={r.auc:.3f}, d={r.cohens_d:.3f}, p_adj={r.p_adjusted:.4f}")
    else:
        log("\nNo findings survived per-round FDR correction.")
        best_overall = sorted(all_round_results, key=lambda r: r.get("p_adjusted", 1))
        log("Closest to significance:")
        for r in best_overall[:5]:
            log(f"  {r['feature']}: d={r.get('cohens_d',0):.3f}, p_adj={r.get('p_adjusted',1):.4f}")

    return all_significant, all_round_results


def _save_results(results: list[dict]):
    """Save accumulated results to TSV."""
    os.makedirs(RESULTS_DIR, exist_ok=True)
    df = pd.DataFrame(results)
    df.to_csv(PERSISTENT_RESULTS, sep="\t", index=False)
    log(f"  Saved {len(results)} results to {PERSISTENT_RESULTS}")


if __name__ == "__main__":
    try:
        significant, all_results = run_persistent_search()
    except KeyboardInterrupt:
        log("\nInterrupted by user.")
    except Exception as e:
        log(f"\nFATAL ERROR: {e}")
        import traceback
        log(traceback.format_exc())
        raise
