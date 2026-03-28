"""
AutoBiomarker — Cross-Dataset Validation

Runs autoresearch on the Depresjon actigraphy dataset and cross-validates
temporal dynamics findings against the Baigutanova HRV dataset.

Key question: Do critical slowing down indicators (rising autocorrelation,
rising variance) generalize from HRV to motor activity?
"""

import os
import sys
import time
import numpy as np
import pandas as pd
from scipy import stats
from sklearn.metrics import roc_auc_score
from statsmodels.stats.multitest import multipletests

sys.path.insert(0, os.path.dirname(__file__))
from config import (
    RESULTS_DIR, SIGNIFICANCE_THRESHOLD, EFFECT_SIZE_THRESHOLD, FDR_METHOD,
)
from data_loader_depresjon import build_depresjon_dataset
from feature_extractor import get_feature_names

RESULTS_DEPRESJON = os.path.join(RESULTS_DIR, "results_depresjon.tsv")
RESULTS_CROSS = os.path.join(RESULTS_DIR, "results_cross_validation.tsv")


def log(msg):
    ts = time.strftime("[%H:%M:%S]")
    print(f"{ts} {msg}")


def test_feature(feature_vals, labels, n_permutations=500):
    """Test a single feature: AUC, Cohen's d, permutation p-value, bootstrap CI."""
    valid = ~(np.isnan(feature_vals) | np.isnan(labels))
    x = feature_vals[valid]
    y = labels[valid]

    if len(x) < 10 or y.sum() < 3 or (1 - y).sum() < 3:
        return None

    dep = x[y == 1]
    healthy = x[y == 0]

    # Cohen's d
    pooled_std = np.sqrt(((len(dep) - 1) * dep.std()**2 + (len(healthy) - 1) * healthy.std()**2)
                         / (len(dep) + len(healthy) - 2))
    if pooled_std == 0:
        return None
    cohens_d = abs(dep.mean() - healthy.mean()) / pooled_std

    # AUC
    try:
        auc = roc_auc_score(y, x)
        auc = max(auc, 1 - auc)  # direction-agnostic
    except ValueError:
        return None

    # Permutation test
    observed_d = cohens_d
    perm_count = 0
    for _ in range(n_permutations):
        perm_y = np.random.permutation(y)
        perm_dep = x[perm_y == 1]
        perm_healthy = x[perm_y == 0]
        perm_pooled = np.sqrt(((len(perm_dep) - 1) * perm_dep.std()**2 +
                               (len(perm_healthy) - 1) * perm_healthy.std()**2)
                              / (len(perm_dep) + len(perm_healthy) - 2))
        if perm_pooled > 0:
            perm_d = abs(perm_dep.mean() - perm_healthy.mean()) / perm_pooled
            if perm_d >= observed_d:
                perm_count += 1
    p_value = (perm_count + 1) / (n_permutations + 1)

    # Bootstrap CI for AUC
    bootstrap_aucs = []
    for _ in range(200):
        idx = np.random.choice(len(x), len(x), replace=True)
        bx, by = x[idx], y[idx]
        if by.sum() > 0 and (1 - by).sum() > 0:
            try:
                bauc = roc_auc_score(by, bx)
                bauc = max(bauc, 1 - bauc)
                bootstrap_aucs.append(bauc)
            except ValueError:
                pass

    ci_lower = np.percentile(bootstrap_aucs, 2.5) if bootstrap_aucs else auc
    ci_upper = np.percentile(bootstrap_aucs, 97.5) if bootstrap_aucs else auc

    return {
        "auc": auc,
        "cohens_d": cohens_d,
        "p_value": p_value,
        "ci_lower": ci_lower,
        "ci_upper": ci_upper,
        "n_dep": int(y.sum()),
        "n_healthy": int((1 - y).sum()),
    }


def run_depresjon_autoresearch():
    """Run hypothesis testing on Depresjon actigraphy data."""
    log("Loading Depresjon dataset...")
    features_df, daily, clinical = build_depresjon_dataset()

    # Aggregate to subject level (mean of temporal features)
    feature_cols = [c for c in features_df.columns if c not in ["subject_id", "date", "depressed"]]
    log(f"Testing {len(feature_cols)} features across {features_df['subject_id'].nunique()} subjects")

    subject_features = features_df.groupby("subject_id")[feature_cols].mean().reset_index()

    # Merge labels
    label_map = features_df.groupby("subject_id")["depressed"].first()
    subject_features["depressed"] = subject_features["subject_id"].map(label_map)

    labels = subject_features["depressed"].values

    results = []
    for i, feat in enumerate(feature_cols):
        vals = subject_features[feat].values
        result = test_feature(vals, labels)
        if result is not None:
            result["feature"] = feat
            result["dataset"] = "depresjon"

            # Categorize
            if "autocorr" in feat:
                result["stat_type"] = "autocorrelation"
            elif "_cv" in feat:
                result["stat_type"] = "coefficient_of_variation"
            elif "_std" in feat:
                result["stat_type"] = "standard_deviation"
            elif "_slope" in feat:
                result["stat_type"] = "slope"
            elif "_mean" in feat:
                result["stat_type"] = "mean"
            else:
                result["stat_type"] = "other"

            results.append(result)

        if (i + 1) % 25 == 0:
            log(f"  Tested {i+1}/{len(feature_cols)} features...")

    results_df = pd.DataFrame(results)

    # FDR correction
    if len(results_df) > 0:
        reject, p_adj, _, _ = multipletests(results_df["p_value"], method=FDR_METHOD)
        results_df["p_adjusted"] = p_adj
        results_df["status"] = np.where(
            (results_df["p_adjusted"] < SIGNIFICANCE_THRESHOLD) &
            (results_df["cohens_d"] >= EFFECT_SIZE_THRESHOLD),
            "KEEP", "DISCARD"
        )
    else:
        results_df["p_adjusted"] = []
        results_df["status"] = []

    n_sig = (results_df["status"] == "KEEP").sum()
    log(f"Depresjon results: {n_sig}/{len(results_df)} significant after FDR")

    os.makedirs(RESULTS_DIR, exist_ok=True)
    results_df.to_csv(RESULTS_DEPRESJON, sep="\t", index=False)
    log(f"Saved to {RESULTS_DEPRESJON}")

    return results_df


def cross_validate_findings():
    """Compare significant findings across both datasets."""
    log("Cross-validating findings across datasets...")

    # Load both result sets
    baig_path = os.path.join(RESULTS_DIR, "results.tsv")
    if not os.path.exists(baig_path):
        log("WARNING: Baigutanova results not found. Run run_overnight.py first.")
        return None

    baig = pd.read_csv(baig_path, sep="\t")
    dep = pd.read_csv(RESULTS_DEPRESJON, sep="\t")

    baig_sig = baig[baig["status"] == "KEEP"].copy()
    dep_sig = dep[dep["status"] == "KEEP"].copy()

    log(f"Baigutanova (HRV+Sleep): {len(baig_sig)} significant features")
    log(f"Depresjon (Actigraphy): {len(dep_sig)} significant features")

    # Map feature types for cross-dataset comparison
    # We can't compare exact features (different modalities), but we compare
    # STATISTICAL PATTERN TYPES: autocorrelation, CV, std, slope, mean
    def get_stat_type(feat):
        if "autocorr" in feat:
            return "autocorrelation"
        elif "_cv" in feat:
            return "coefficient_of_variation"
        elif "_std" in feat and "activity_std" not in feat:
            return "standard_deviation"
        elif "_slope" in feat:
            return "slope"
        elif "_mean" in feat:
            return "mean"
        else:
            return "other"

    baig_sig["stat_type"] = baig_sig["feature"].apply(get_stat_type)
    dep_sig["stat_type"] = dep_sig["feature"].apply(get_stat_type)

    # Compare statistical pattern prevalence
    cross_results = []

    for stat_type in ["autocorrelation", "coefficient_of_variation", "standard_deviation", "slope", "mean"]:
        baig_count = (baig_sig["stat_type"] == stat_type).sum()
        dep_count = (dep_sig["stat_type"] == stat_type).sum()
        baig_pct = baig_count / max(len(baig_sig), 1) * 100
        dep_pct = dep_count / max(len(dep_sig), 1) * 100

        baig_best_d = baig_sig[baig_sig["stat_type"] == stat_type]["cohens_d"].max() if baig_count > 0 else 0
        dep_best_d = dep_sig[dep_sig["stat_type"] == stat_type]["cohens_d"].max() if dep_count > 0 else 0

        cross_results.append({
            "stat_type": stat_type,
            "baig_count": baig_count,
            "baig_pct": round(baig_pct, 1),
            "baig_best_d": round(baig_best_d, 3),
            "dep_count": dep_count,
            "dep_pct": round(dep_pct, 1),
            "dep_best_d": round(dep_best_d, 3),
            "generalizes": "YES" if baig_count > 0 and dep_count > 0 else "NO",
        })

    cross_df = pd.DataFrame(cross_results)
    cross_df.to_csv(RESULTS_CROSS, sep="\t", index=False)

    log("\n=== CROSS-DATASET VALIDATION ===")
    log(f"{'Stat Type':<30} {'Baigutanova':<15} {'Depresjon':<15} {'Generalizes?'}")
    log("-" * 75)
    for _, row in cross_df.iterrows():
        log(f"{row['stat_type']:<30} {row['baig_count']:>5} ({row['baig_pct']:>5.1f}%) "
            f"{row['dep_count']:>5} ({row['dep_pct']:>5.1f}%)   {row['generalizes']}")

    # Key conclusion
    variability_types = ["autocorrelation", "coefficient_of_variation", "standard_deviation"]
    var_generalizes = sum(1 for r in cross_results if r["stat_type"] in variability_types and r["generalizes"] == "YES")
    log(f"\nCritical slowing down indicators generalizing: {var_generalizes}/3")
    if var_generalizes >= 2:
        log("STRONG EVIDENCE: Temporal dynamics features generalize across modalities!")
    elif var_generalizes >= 1:
        log("MODERATE EVIDENCE: Some temporal dynamics features generalize.")
    else:
        log("WEAK EVIDENCE: Temporal dynamics features may be modality-specific.")

    return cross_df


if __name__ == "__main__":
    log("=== AutoBiomarker Cross-Dataset Validation ===\n")

    # Step 1: Run on Depresjon
    dep_results = run_depresjon_autoresearch()

    # Step 2: Cross-validate
    if dep_results is not None and len(dep_results) > 0:
        cross = cross_validate_findings()

    # Step 3: Print top Depresjon findings
    if len(dep_results[dep_results["status"] == "KEEP"]) > 0:
        top = dep_results[dep_results["status"] == "KEEP"].sort_values("cohens_d", ascending=False).head(15)
        log("\n=== TOP 15 DEPRESJON FINDINGS ===")
        for _, row in top.iterrows():
            log(f"  {row['feature']:<40} d={row['cohens_d']:.3f}  AUC={row['auc']:.3f}  p_adj={row['p_adjusted']:.4f}")
    else:
        log("\nNo significant findings in Depresjon dataset.")
        log("Top 10 by effect size (regardless of significance):")
        top = dep_results.sort_values("cohens_d", ascending=False).head(10)
        for _, row in top.iterrows():
            log(f"  {row['feature']:<40} d={row['cohens_d']:.3f}  AUC={row['auc']:.3f}  p={row['p_value']:.4f}")
