"""
AutoBiomarker — Round 2: LLM-Guided Refinement

Loads Round 1 results, feeds top findings + null results to Llama 3.3 70B
on Nebius, asks it to propose NEW hypotheses exploring:
  a) Interactions between top-performing features
  b) Under-explored temporal windows (2-day, 4-day, 10-day)
  c) Novel composite indices combining the best features

Budget-conscious: max 5-10 LLM calls.

Usage:
  python run_round2.py
"""

import os
import sys
import time
import json
import datetime
import numpy as np
import pandas as pd

sys.path.insert(0, os.path.dirname(__file__))

from config import (
    NEBIUS_API_KEY, NEBIUS_BASE_URL, NEBIUS_MODEL,
    NEBIUS_COST_PER_1K_TOKENS, RESULTS_DIR, RESULTS_TSV,
    PHQ9_MILD_THRESHOLD, SIGNIFICANCE_THRESHOLD, EFFECT_SIZE_THRESHOLD,
    FDR_METHOD, ROLLING_WINDOWS,
)
from data_loader import (
    load_hrv_metrics, load_sleep_diary, load_clinical_metadata,
    compute_daily_hrv, build_merged_dataset,
)
from feature_extractor import compute_early_warning_signals, get_feature_names, compute_rolling_stats
from hypothesis import (
    BiomarkerHypothesis, HypothesisEvaluator, HypothesisResult, save_results,
)

ROUND2_TSV = os.path.join(RESULTS_DIR, "results_round2.tsv")
ROUND2_LOG = os.path.join(RESULTS_DIR, "round2_log.txt")
MAX_LLM_CALLS = 7  # budget-conscious


def log(msg: str):
    ts = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{ts}] {msg}"
    print(line)
    os.makedirs(RESULTS_DIR, exist_ok=True)
    with open(ROUND2_LOG, "a") as f:
        f.write(line + "\n")


def load_round1_results() -> pd.DataFrame:
    """Load Round 1 results from results.tsv."""
    if not os.path.exists(RESULTS_TSV):
        raise FileNotFoundError(f"Round 1 results not found at {RESULTS_TSV}")
    df = pd.read_csv(RESULTS_TSV, sep="\t")
    log(f"Loaded Round 1: {len(df)} hypotheses, {len(df[df.status=='KEEP'])} KEEP, {len(df[df.status=='DISCARD'])} DISCARD")
    return df


def summarize_round1(df: pd.DataFrame) -> str:
    """Build a compact summary of Round 1 for the LLM prompt."""
    keep = df[df["status"] == "KEEP"].sort_values("cohens_d", ascending=False)
    discard = df[df["status"] == "DISCARD"].sort_values("cohens_d", ascending=False)

    # Top 30 findings (deduplicate by feature name)
    seen = set()
    top_lines = []
    for _, r in keep.iterrows():
        if r["feature"] not in seen and len(top_lines) < 30:
            seen.add(r["feature"])
            top_lines.append(
                f"  KEEP: {r['feature']} | AUC={r['auc']:.3f} | d={r['cohens_d']:.3f} | p_adj={r['p_adjusted']:.4f}"
            )
    top_section = "\n".join(top_lines)

    # Top 10 null results (high d but discarded)
    null_high = discard[discard["cohens_d"] > 0.2].head(20)
    null_seen = set()
    null_lines = []
    for _, r in null_high.iterrows():
        if r["feature"] not in null_seen and len(null_lines) < 10:
            null_seen.add(r["feature"])
            null_lines.append(
                f"  DISCARD: {r['feature']} | AUC={r['auc']:.3f} | d={r['cohens_d']:.3f} | p_adj={r['p_adjusted']:.4f}"
            )
    null_section = "\n".join(null_lines)

    hit_rate = len(keep) / len(df) * 100

    return f"""ROUND 1 SUMMARY ({len(df)} hypotheses tested, {len(keep)} significant, hit rate {hit_rate:.1f}%)

TOP 30 SIGNIFICANT FINDINGS (sorted by effect size):
{top_section}

TOP 10 NULL RESULTS (high effect size but failed FDR):
{null_section}

WINDOWS ALREADY TESTED: 3, 5, 7, 14, 21, 28 days
KEY OBSERVATIONS:
- LF/HF ratio slope (21d, 28d) has the strongest effect sizes (d~0.9)
- rmssd_7d_std interactions with sleep features dominate (d~0.76)
- 28-day window features often have high d but fail FDR (small N)
- Autocorrelation features at 14d+ show critical slowing down signal
- Sleep variability (std, cv) features are consistently significant"""


def build_llm_prompt(summary: str, available_features: list[str], call_num: int, prior_proposals: list[str]) -> str:
    """Build the LLM prompt for hypothesis generation."""

    prior_text = ""
    if prior_proposals:
        prior_text = f"\n\nALREADY PROPOSED THIS ROUND (do NOT repeat):\n" + "\n".join(f"  - {p}" for p in prior_proposals)

    if call_num <= 2:
        # First calls: explore interactions between top features
        focus = """FOCUS: Propose 3-5 interaction hypotheses combining the TOP-PERFORMING features.
The best single features are: lfhf slope, rmssd_7d_std, rmssd_14d_autocorr, sleep variability.
Think about which PAIRS of these would create the strongest composite biomarker.
For each, specify both features and explain the clinical logic."""
    elif call_num <= 4:
        # Middle calls: explore new windows
        focus = """FOCUS: Propose 3-5 hypotheses using UNEXPLORED temporal windows.
Round 1 tested: 3, 5, 7, 14, 21, 28 days.
Propose features computed at 2-day, 4-day, or 10-day windows.
These would require computing NEW features. Specify the base signal (rmssd, hr, lfhf, sleep_dur, sleep_qual, sleep_lat) and the statistic (mean, std, cv, slope, autocorr)."""
    else:
        # Later calls: novel composites
        focus = """FOCUS: Propose 3-5 NOVEL COMPOSITE indices that combine multiple signals.
Examples:
  - "autonomic_rigidity_index" = rmssd_autocorr + hr_autocorr (both measure sluggishness)
  - "sleep_disruption_composite" = sleep_dur_cv + sleep_lat_std + sleep_onset_sd
  - "critical_slowing_composite" = mean(autocorr features) + mean(variance features)
Be creative. Name the composite, specify the formula, explain the theory."""

    return f"""You are a computational psychiatry researcher. You have completed Round 1 of an autoresearch loop testing 5000 biomarker hypotheses for depression prediction from wearable data (HRV + sleep).

{summary}

{focus}{prior_text}

DATASET: 49 participants, 28 days daily HRV (RMSSD, HR, LF/HF) + sleep diary + PHQ-9.

AVAILABLE BASE FEATURES for interactions (from Round 1):
{', '.join(available_features[:60])}

Respond in JSON format:
{{
  "hypotheses": [
    {{
      "type": "interaction" | "new_window" | "composite",
      "feature1": "existing_feature_name",
      "feature2": "existing_feature_name_or_null",
      "new_window": null | 2 | 4 | 10,
      "base_signal": "rmssd | hr | lfhf | sleep_dur | sleep_qual | sleep_lat",
      "statistic": "mean | std | cv | slope | autocorr",
      "composite_formula": "description of how to compute if composite",
      "description": "Clinical reasoning for why this should predict depression",
      "expected_effect": "small | medium | large"
    }}
  ]
}}"""


def compute_new_window_features(merged_df: pd.DataFrame, window: int, base_signal: str, statistic: str) -> tuple:
    """Compute a feature at a new window size not in Round 1."""
    signal_map = {
        "rmssd": "RMSSD_mean",
        "hr": "heart_rate_mean",
        "lfhf": "LF_HF_ratio_mean",
        "sleep_dur": "sleep_duration",
        "sleep_qual": "sleep_quality_score",
        "sleep_lat": "sleep_latency",
    }

    col = signal_map.get(base_signal)
    if col is None:
        return None, None

    feature_name = f"{base_signal}_{window}d_{statistic}"
    all_features = []

    for subject_id, subj_df in merged_df.groupby("subject_id"):
        subj_df = subj_df.sort_values("date").copy()
        if col not in subj_df.columns:
            continue

        series = subj_df[col]
        feat_df = compute_rolling_stats(series, windows=[window], prefix=base_signal)

        result = pd.DataFrame(index=subj_df.index)
        result["subject_id"] = subject_id
        if feature_name in feat_df.columns:
            result[feature_name] = feat_df[feature_name].values
        all_features.append(result)

    if not all_features:
        return None, None

    combined = pd.concat(all_features, ignore_index=True)
    return feature_name, combined


def compute_composite_feature(features_df: pd.DataFrame, component_features: list[str], name: str) -> tuple:
    """Compute a composite index by averaging per-subject z-scored component features.

    Z-scoring is done per-subject to avoid leaking population statistics.
    The evaluator's LOSO-CV will handle train/test separation.
    """
    available = [f for f in component_features if f in features_df.columns]
    if len(available) < 2:
        return None, None

    # Z-score within each subject (no cross-subject leakage)
    z_scored = pd.DataFrame(index=features_df.index)
    for f in available:
        col = features_df[f].copy()
        # Per-subject z-scoring
        subj_groups = features_df.groupby("subject_id")[f]
        z_scored[f] = subj_groups.transform(
            lambda x: (x - x.mean()) / x.std() if x.std() > 0 else 0.0
        )

    composite = z_scored.mean(axis=1)
    result_df = features_df[["subject_id"]].copy()
    result_df[name] = composite.values
    return name, result_df


def parse_and_test_hypotheses(
    llm_response: dict,
    features_df: pd.DataFrame,
    merged_df: pd.DataFrame,
    binary_outcome: pd.Series,
    subject_ids: pd.Series,
    evaluator: HypothesisEvaluator,
    hypothesis_id_start: int,
) -> list[HypothesisResult]:
    """Parse LLM-proposed hypotheses and test each one."""
    results = []
    hypotheses_raw = llm_response.get("hypotheses", [])

    for i, h in enumerate(hypotheses_raw):
        h_type = h.get("type", "interaction")
        h_id = hypothesis_id_start + i
        desc = h.get("description", "LLM Round 2 hypothesis")

        try:
            if h_type == "interaction":
                feat1 = h.get("feature1", "")
                feat2 = h.get("feature2", "")
                if feat1 in features_df.columns and feat2 and feat2 in features_df.columns:
                    hyp = BiomarkerHypothesis(
                        id=h_id, feature=feat1, threshold=None, direction="above",
                        outcome="phq9_mild", temporal_lag=7,
                        description=f"R2 Interaction: {feat1} x {feat2} | {desc}",
                        combination=feat2,
                    )
                    result = evaluator.evaluate(hyp, features_df, binary_outcome, subject_ids)
                    results.append(result)
                    log(f"    Tested interaction {feat1} x {feat2}: AUC={result.auc:.3f}, d={result.cohens_d:.3f}")
                elif feat1 in features_df.columns:
                    # Test as single feature
                    hyp = BiomarkerHypothesis(
                        id=h_id, feature=feat1, threshold=None, direction="above",
                        outcome="phq9_mild", temporal_lag=7,
                        description=f"R2 Single: {feat1} | {desc}",
                    )
                    result = evaluator.evaluate(hyp, features_df, binary_outcome, subject_ids)
                    results.append(result)
                    log(f"    Tested single {feat1}: AUC={result.auc:.3f}, d={result.cohens_d:.3f}")
                else:
                    log(f"    Skipped interaction: {feat1} or {feat2} not in features")

            elif h_type == "new_window":
                window = h.get("new_window", 10)
                base_signal = h.get("base_signal", "rmssd")
                statistic = h.get("statistic", "std")

                if window in ROLLING_WINDOWS:
                    # Already computed, use existing
                    feat_name = f"{base_signal}_{window}d_{statistic}"
                    if feat_name in features_df.columns:
                        hyp = BiomarkerHypothesis(
                            id=h_id, feature=feat_name, threshold=None, direction="above",
                            outcome="phq9_mild", temporal_lag=7,
                            description=f"R2 Window: {feat_name} | {desc}",
                        )
                        result = evaluator.evaluate(hyp, features_df, binary_outcome, subject_ids)
                        results.append(result)
                        log(f"    Tested existing window {feat_name}: AUC={result.auc:.3f}, d={result.cohens_d:.3f}")
                else:
                    # Compute new window feature
                    feat_name, new_feat_df = compute_new_window_features(merged_df, window, base_signal, statistic)
                    if feat_name and new_feat_df is not None:
                        # Merge into features_df
                        temp_df = features_df.merge(
                            new_feat_df[["subject_id", feat_name]],
                            on="subject_id", how="left", suffixes=("", "_new")
                        )
                        if feat_name in temp_df.columns:
                            hyp = BiomarkerHypothesis(
                                id=h_id, feature=feat_name, threshold=None, direction="above",
                                outcome="phq9_mild", temporal_lag=7,
                                description=f"R2 NewWindow({window}d): {feat_name} | {desc}",
                            )
                            result = evaluator.evaluate(hyp, temp_df, binary_outcome, subject_ids)
                            results.append(result)
                            log(f"    Tested new window {feat_name}: AUC={result.auc:.3f}, d={result.cohens_d:.3f}")
                    else:
                        log(f"    Failed to compute new window feature: {base_signal}_{window}d_{statistic}")

            elif h_type == "composite":
                formula = h.get("composite_formula", "")
                feat1 = h.get("feature1", "")
                feat2 = h.get("feature2", "")

                # Try to build composite from available features
                component_feats = []
                if feat1 and feat1 in features_df.columns:
                    component_feats.append(feat1)
                if feat2 and feat2 in features_df.columns:
                    component_feats.append(feat2)

                # Also try to parse component names from formula
                for col in features_df.columns:
                    if col in ("subject_id", "date"):
                        continue
                    if col in formula and col not in component_feats:
                        component_feats.append(col)

                if len(component_feats) >= 2:
                    composite_name = f"composite_r2_{h_id}"
                    comp_name, comp_df = compute_composite_feature(features_df, component_feats[:5], composite_name)
                    if comp_name:
                        temp_df = features_df.copy()
                        temp_df[comp_name] = comp_df[comp_name].values
                        hyp = BiomarkerHypothesis(
                            id=h_id, feature=comp_name, threshold=None, direction="above",
                            outcome="phq9_mild", temporal_lag=7,
                            description=f"R2 Composite ({'+'.join(component_feats[:5])}): {desc}",
                        )
                        result = evaluator.evaluate(hyp, temp_df, binary_outcome, subject_ids)
                        results.append(result)
                        log(f"    Tested composite {comp_name}: AUC={result.auc:.3f}, d={result.cohens_d:.3f}")
                else:
                    log(f"    Skipped composite: not enough valid components ({component_feats})")

        except Exception as e:
            log(f"    Error testing hypothesis {h_id}: {e}")

    return results


def run_round2():
    """Main Round 2 pipeline."""
    start_time = time.time()

    log("=" * 70)
    log("AutoBiomarker — ROUND 2 (LLM-Guided Refinement)")
    log(f"Max LLM calls: {MAX_LLM_CALLS}")
    log("=" * 70)

    # ---- Load Round 1 results ----
    r1_df = load_round1_results()
    r1_keep = len(r1_df[r1_df.status == "KEEP"])
    r1_total = len(r1_df)
    r1_hit_rate = r1_keep / r1_total * 100

    summary = summarize_round1(r1_df)
    log(f"Round 1 hit rate: {r1_hit_rate:.1f}% ({r1_keep}/{r1_total})")

    # ---- Load dataset ----
    log("Loading dataset...")
    hrv = load_hrv_metrics()
    daily_hrv = compute_daily_hrv(hrv)
    sleep = load_sleep_diary()
    clinical = load_clinical_metadata()
    merged = build_merged_dataset(daily_hrv, sleep, clinical)

    log("Extracting features...")
    features_df = compute_early_warning_signals(merged)
    feature_names = get_feature_names(features_df)
    log(f"  {len(feature_names)} features available")

    # Prepare outcome
    phq9_map = clinical.set_index("subject_id")["PHQ9"].to_dict()
    outcome = features_df["subject_id"].map(phq9_map)
    binary_outcome = (outcome >= PHQ9_MILD_THRESHOLD).astype(float)
    subject_ids = features_df["subject_id"]

    # ---- Initialize LLM client ----
    if not NEBIUS_API_KEY:
        log("ERROR: No NEBIUS_API_KEY set. Cannot run Round 2.")
        return

    from openai import OpenAI
    client = OpenAI(base_url=NEBIUS_BASE_URL, api_key=NEBIUS_API_KEY)

    evaluator = HypothesisEvaluator()
    all_results = []
    total_cost = 0.0
    prior_proposals = []
    hypothesis_id = 10000

    # ---- LLM-guided hypothesis generation (5-7 calls) ----
    for call_num in range(1, MAX_LLM_CALLS + 1):
        log(f"\n--- LLM Call {call_num}/{MAX_LLM_CALLS} ---")

        prompt = build_llm_prompt(summary, feature_names, call_num, prior_proposals)

        try:
            response = client.chat.completions.create(
                model=NEBIUS_MODEL,
                messages=[{"role": "user", "content": prompt}],
                response_format={"type": "json_object"},
                temperature=0.8,
                max_tokens=2000,
            )

            tokens = getattr(response.usage, "total_tokens", 1000) if response.usage else 1000
            cost = (tokens / 1000) * NEBIUS_COST_PER_1K_TOKENS
            total_cost += cost
            log(f"  Tokens: {tokens}, Cost: ${cost:.4f} (total: ${total_cost:.4f})")

            raw = response.choices[0].message.content
            parsed = json.loads(raw)

            hypotheses_list = parsed.get("hypotheses", [])
            log(f"  LLM proposed {len(hypotheses_list)} hypotheses")

            # Track proposals
            for h in hypotheses_list:
                desc_short = h.get("description", "")[:60]
                prior_proposals.append(f"{h.get('type','?')}: {h.get('feature1','')} {h.get('feature2','')} - {desc_short}")

            # Test them
            results = parse_and_test_hypotheses(
                parsed, features_df, merged, binary_outcome, subject_ids,
                evaluator, hypothesis_id,
            )
            all_results.extend(results)
            hypothesis_id += len(hypotheses_list) + 1

            log(f"  Tested {len(results)} hypotheses this call")

        except json.JSONDecodeError as e:
            log(f"  JSON parse error: {e}")
            log(f"  Raw response: {raw[:200]}")
        except Exception as e:
            log(f"  LLM call failed: {e}")

        # Budget check
        if total_cost > 1.0:
            log("  Budget warning: exceeded $1.00, stopping LLM calls")
            break

    # ---- Apply FDR correction ----
    log(f"\nApplying FDR correction across {len(all_results)} Round 2 hypotheses...")
    if all_results:
        all_results = evaluator.apply_fdr_correction(all_results)

    # ---- Save Round 2 results ----
    os.makedirs(RESULTS_DIR, exist_ok=True)
    rows = []
    for r in all_results:
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
    r2_df = pd.DataFrame(rows)
    r2_df.to_csv(ROUND2_TSV, sep="\t", index=False)
    log(f"Round 2 results saved to {ROUND2_TSV}")

    # ---- Comparison ----
    r2_total = len(all_results)
    r2_keep = sum(1 for r in all_results if r.status == "KEEP")
    r2_hit_rate = (r2_keep / r2_total * 100) if r2_total > 0 else 0

    elapsed = time.time() - start_time

    log("\n" + "=" * 70)
    log("ROUND 2 COMPLETE")
    log("=" * 70)
    log(f"Time: {elapsed:.0f}s")
    log(f"LLM cost: ${total_cost:.4f}")
    log(f"")
    log(f"{'Metric':<30} {'Round 1':>12} {'Round 2':>12}")
    log(f"{'-'*54}")
    log(f"{'Hypotheses tested':<30} {r1_total:>12} {r2_total:>12}")
    log(f"{'Significant (KEEP)':<30} {r1_keep:>12} {r2_keep:>12}")
    log(f"{'Hit rate':<30} {r1_hit_rate:>11.1f}% {r2_hit_rate:>11.1f}%")

    if r2_keep > 0:
        log(f"\nRound 2 SIGNIFICANT FINDINGS:")
        kept = sorted([r for r in all_results if r.status == "KEEP"], key=lambda r: r.cohens_d, reverse=True)
        for i, r in enumerate(kept[:20]):
            log(f"  {i+1}. {r.feature}: AUC={r.auc:.3f}, d={r.cohens_d:.3f}, p_adj={r.p_adjusted:.4f}")
            log(f"     {r.description}")
    else:
        log("\nNo significant findings in Round 2 after FDR correction.")
        # Still show the best results
        if all_results:
            best = sorted(all_results, key=lambda r: r.cohens_d, reverse=True)
            log("\nTop 10 Round 2 results (not significant after FDR):")
            for i, r in enumerate(best[:10]):
                log(f"  {i+1}. {r.feature}: AUC={r.auc:.3f}, d={r.cohens_d:.3f}, p={r.p_value:.4f}, p_adj={r.p_adjusted:.4f}")

    return all_results


if __name__ == "__main__":
    try:
        results = run_round2()
    except KeyboardInterrupt:
        log("\nInterrupted by user.")
    except Exception as e:
        log(f"\nERROR: {e}")
        import traceback
        log(traceback.format_exc())
        raise
