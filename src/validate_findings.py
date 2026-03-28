"""
AutoBiomarker — Validation Tests

1. Global FDR: Apply BH-FDR across ALL 271 persistent search results
2. Permutation null: Run entire search with shuffled labels (100 times)
3. Hold-out: 35 discovery / 14 validation split
4. Cross-dataset: Test interactions on Depresjon

Usage:
  python validate_findings.py
"""

import os
import sys
import time
import numpy as np
import pandas as pd
from statsmodels.stats.multitest import multipletests
from sklearn.metrics import roc_auc_score

sys.path.insert(0, os.path.dirname(__file__))

from config import RESULTS_DIR, PHQ9_MILD_THRESHOLD
from data_loader import (
    load_hrv_metrics, load_sleep_diary, load_clinical_metadata,
    compute_daily_hrv, build_merged_dataset,
)
from feature_extractor import compute_early_warning_signals, get_feature_names
from hypothesis import BiomarkerHypothesis, HypothesisEvaluator

PERSISTENT_RESULTS = os.path.join(RESULTS_DIR, "persistent_search_results.tsv")


def log(msg):
    print(msg)


def test1_global_fdr():
    """Apply BH-FDR across ALL 271 results, not per-round."""
    log("\n" + "=" * 60)
    log("TEST 1: Global FDR across ALL 271 persistent search results")
    log("=" * 60)

    df = pd.read_csv(PERSISTENT_RESULTS, sep="\t")
    log(f"Loaded {len(df)} results")

    # Get raw p-values
    p_values = df["p_value"].values

    # Apply global BH-FDR
    reject, p_adj_global, _, _ = multipletests(p_values, method="fdr_bh", alpha=0.05)

    df["p_adj_global"] = p_adj_global
    df["significant_global"] = reject

    n_sig = reject.sum()
    log(f"\nResults: {n_sig} / {len(df)} survive GLOBAL FDR (alpha=0.05)")

    if n_sig > 0:
        sig = df[df["significant_global"]].sort_values("cohens_d", ascending=False)
        log("\nGlobally significant features:")
        for _, r in sig.iterrows():
            log(f"  {r['feature']}: d={r['cohens_d']:.3f}, p={r['p_value']:.4f}, "
                f"p_adj_global={r['p_adj_global']:.4f}, AUC={r['auc']:.3f}")
    else:
        log("\nNO features survive global FDR.")
        # Show closest
        closest = df.nsmallest(5, "p_adj_global")
        log("Closest to significance:")
        for _, r in closest.iterrows():
            log(f"  {r['feature']}: d={r['cohens_d']:.3f}, p={r['p_value']:.4f}, "
                f"p_adj_global={r['p_adj_global']:.4f}")

    return n_sig


def test2_permutation_null(n_permutations=100):
    """Run the search with shuffled labels to build null distribution."""
    log("\n" + "=" * 60)
    log(f"TEST 2: Permutation Null ({n_permutations} shuffles)")
    log("How often do we get 'significant' findings by chance?")
    log("=" * 60)

    # Load data
    log("Loading data...")
    hrv = load_hrv_metrics()
    daily_hrv = compute_daily_hrv(hrv)
    sleep = load_sleep_diary()
    clinical = load_clinical_metadata()
    merged = build_merged_dataset(daily_hrv, sleep, clinical)
    features_df = compute_early_warning_signals(merged)

    phq9_map = clinical.set_index("subject_id")["PHQ9"].to_dict()
    outcome = features_df["subject_id"].map(phq9_map)
    real_labels = (outcome >= PHQ9_MILD_THRESHOLD).astype(float)
    subject_ids = features_df["subject_id"]

    # Get the 3 significant interaction features
    sig_features = [
        ("rmssd_3d_slope", "sleep_dur_3d_autocorr"),
        ("rmssd_3d_slope", "lfhf_3d_slope"),
        ("lfhf_21d_slope", "sleep_qual_21d_mean"),
    ]

    evaluator = HypothesisEvaluator()

    # For each feature pair, test with real labels and count how many permutations beat it
    log("\nTesting each significant feature under permutation null...\n")

    for feat1, feat2 in sig_features:
        if feat1 not in features_df.columns or feat2 not in features_df.columns:
            log(f"  SKIP: {feat1} or {feat2} not in features")
            continue

        # Real result
        hyp = BiomarkerHypothesis(
            id=99999, feature=feat1, threshold=None, direction="above",
            outcome="phq9_mild", temporal_lag=7,
            description="validation", combination=feat2,
        )
        real_result = evaluator.evaluate(hyp, features_df, real_labels, subject_ids)
        real_d = abs(real_result.cohens_d)
        real_p = real_result.p_value

        # Permutation: shuffle labels at SUBJECT level
        unique_subjects = features_df["subject_id"].unique()
        subject_labels = {}
        for s in unique_subjects:
            mask = features_df["subject_id"] == s
            subject_labels[s] = real_labels[mask].iloc[0]

        null_d_values = []
        null_p_values = []
        count_beat_real = 0

        for perm in range(n_permutations):
            # Shuffle subject-level labels
            shuffled_label_map = dict(zip(
                unique_subjects,
                np.random.permutation(list(subject_labels.values()))
            ))
            shuffled_labels = features_df["subject_id"].map(shuffled_label_map).astype(float)

            perm_result = evaluator.evaluate(hyp, features_df, shuffled_labels, subject_ids)
            null_d = abs(perm_result.cohens_d)
            null_d_values.append(null_d)
            null_p_values.append(perm_result.p_value)

            if null_d >= real_d:
                count_beat_real += 1

        empirical_p = count_beat_real / n_permutations
        log(f"  {feat1} x {feat2}:")
        log(f"    Real d={real_d:.3f}, real p={real_p:.4f}")
        log(f"    Null d: mean={np.mean(null_d_values):.3f}, "
            f"max={np.max(null_d_values):.3f}, std={np.std(null_d_values):.3f}")
        log(f"    Empirical p (d >= real_d): {empirical_p:.4f} "
            f"({count_beat_real}/{n_permutations} permutations beat real)")
        log(f"    {'VALID' if empirical_p < 0.05 else 'LIKELY OVERFITTED'}")
        log("")

    # Also: how many "significant per-round" findings do we get with shuffled labels?
    log("Running full per-round FDR simulation with shuffled labels...")
    n_sig_per_shuffle = []

    for perm in range(min(20, n_permutations)):  # 20 full simulations
        shuffled_label_map = dict(zip(
            unique_subjects,
            np.random.permutation(list(subject_labels.values()))
        ))
        shuffled_labels = features_df["subject_id"].map(shuffled_label_map).astype(float)

        # Test all 3 features in one "round" of 3
        round_results = []
        for feat1, feat2 in sig_features:
            if feat1 not in features_df.columns or feat2 not in features_df.columns:
                continue
            hyp = BiomarkerHypothesis(
                id=99999, feature=feat1, threshold=None, direction="above",
                outcome="phq9_mild", temporal_lag=7,
                description="perm", combination=feat2,
            )
            r = evaluator.evaluate(hyp, features_df, shuffled_labels, subject_ids)
            round_results.append(r)

        if round_results:
            corrected = evaluator.apply_fdr_correction(round_results)
            n_keep = sum(1 for r in corrected if r.status == "KEEP")
            n_sig_per_shuffle.append(n_keep)

    if n_sig_per_shuffle:
        log(f"\nPer-round FDR simulation (20 shuffles, 3 tests per round):")
        log(f"  Significant per shuffle: {n_sig_per_shuffle}")
        log(f"  Mean: {np.mean(n_sig_per_shuffle):.2f}")
        log(f"  Got >=1 significant: {sum(1 for x in n_sig_per_shuffle if x >= 1)}/20 "
            f"({sum(1 for x in n_sig_per_shuffle if x >= 1)/20*100:.0f}%)")
        log(f"  Got >=3 significant: {sum(1 for x in n_sig_per_shuffle if x >= 3)}/20 "
            f"({sum(1 for x in n_sig_per_shuffle if x >= 3)/20*100:.0f}%)")


def test3_holdout():
    """35/14 discovery/validation split."""
    log("\n" + "=" * 60)
    log("TEST 3: Hold-out Validation (35 discovery / 14 validation)")
    log("=" * 60)

    # Load data
    hrv = load_hrv_metrics()
    daily_hrv = compute_daily_hrv(hrv)
    sleep = load_sleep_diary()
    clinical = load_clinical_metadata()
    merged = build_merged_dataset(daily_hrv, sleep, clinical)
    features_df = compute_early_warning_signals(merged)

    phq9_map = clinical.set_index("subject_id")["PHQ9"].to_dict()
    outcome = features_df["subject_id"].map(phq9_map)
    labels = (outcome >= PHQ9_MILD_THRESHOLD).astype(float)

    unique_subjects = features_df["subject_id"].unique()
    subject_label_map = {}
    for s in unique_subjects:
        mask = features_df["subject_id"] == s
        subject_label_map[s] = labels[mask].iloc[0]

    # Stratified split: keep class ratio similar
    pos_subjects = [s for s, l in subject_label_map.items() if l == 1]
    neg_subjects = [s for s, l in subject_label_map.items() if l == 0]

    np.random.seed(42)
    np.random.shuffle(pos_subjects)
    np.random.shuffle(neg_subjects)

    # ~70% discovery
    n_pos_disc = int(len(pos_subjects) * 0.7)
    n_neg_disc = int(len(neg_subjects) * 0.7)

    disc_subjects = set(pos_subjects[:n_pos_disc] + neg_subjects[:n_neg_disc])
    val_subjects = set(pos_subjects[n_pos_disc:] + neg_subjects[n_neg_disc:])

    log(f"Discovery: {len(disc_subjects)} subjects, Validation: {len(val_subjects)} subjects")

    disc_mask = features_df["subject_id"].isin(disc_subjects)
    val_mask = features_df["subject_id"].isin(val_subjects)

    sig_features = [
        ("rmssd_3d_slope", "sleep_dur_3d_autocorr"),
        ("rmssd_3d_slope", "lfhf_3d_slope"),
        ("lfhf_21d_slope", "sleep_qual_21d_mean"),
    ]

    evaluator = HypothesisEvaluator()

    for feat1, feat2 in sig_features:
        if feat1 not in features_df.columns or feat2 not in features_df.columns:
            log(f"  SKIP: {feat1} or {feat2} not in features")
            continue

        # Discovery set
        disc_df = features_df[disc_mask].copy()
        disc_labels = labels[disc_mask]
        disc_subj = features_df.loc[disc_mask, "subject_id"]

        hyp = BiomarkerHypothesis(
            id=99999, feature=feat1, threshold=None, direction="above",
            outcome="phq9_mild", temporal_lag=7,
            description="holdout", combination=feat2,
        )
        disc_result = evaluator.evaluate(hyp, disc_df, disc_labels, disc_subj)

        # Validation set
        val_df = features_df[val_mask].copy()
        val_labels = labels[val_mask]
        val_subj = features_df.loc[val_mask, "subject_id"]

        val_result = evaluator.evaluate(hyp, val_df, val_labels, val_subj)

        log(f"\n  {feat1} x {feat2}:")
        log(f"    Discovery (n={len(disc_subjects)}): d={disc_result.cohens_d:.3f}, "
            f"p={disc_result.p_value:.4f}, AUC={disc_result.auc:.3f}")
        log(f"    Validation (n={len(val_subjects)}): d={val_result.cohens_d:.3f}, "
            f"p={val_result.p_value:.4f}, AUC={val_result.auc:.3f}")

        # Check if effect direction is consistent
        same_direction = (disc_result.cohens_d > 0) == (val_result.cohens_d > 0)
        log(f"    Direction consistent: {'YES' if same_direction else 'NO'}")
        log(f"    Validation p < 0.05: {'YES' if val_result.p_value < 0.05 else 'NO'}")


def test4_cross_dataset():
    """Test interactions on Depresjon dataset."""
    log("\n" + "=" * 60)
    log("TEST 4: Cross-Dataset (Depresjon actigraphy)")
    log("=" * 60)

    try:
        from data_loader_depresjon import build_depresjon_dataset
    except ImportError:
        log("  SKIP: data_loader_depresjon not available")
        return

    try:
        features, daily, clinical = build_depresjon_dataset()
    except Exception as e:
        log(f"  SKIP: Could not load Depresjon dataset: {e}")
        return

    feature_cols = [c for c in features.columns if c not in ["subject_id", "date", "depressed"]]
    log(f"Depresjon: {len(features['subject_id'].unique())} subjects, {len(feature_cols)} features")

    # Check which of our interaction features exist
    sig_features = [
        ("rmssd_3d_slope", "sleep_dur_3d_autocorr"),
        ("rmssd_3d_slope", "lfhf_3d_slope"),
        ("lfhf_21d_slope", "sleep_qual_21d_mean"),
    ]

    for feat1, feat2 in sig_features:
        has1 = feat1 in features.columns
        has2 = feat2 in features.columns
        log(f"  {feat1}: {'found' if has1 else 'NOT FOUND'}")
        log(f"  {feat2}: {'found' if has2 else 'NOT FOUND'}")

        if has1 and has2:
            label_map = clinical.set_index("subject_id")["depressed"].to_dict()
            labels = features["subject_id"].map(label_map).astype(float)
            subject_ids = features["subject_id"]

            evaluator = HypothesisEvaluator()
            hyp = BiomarkerHypothesis(
                id=99999, feature=feat1, threshold=None, direction="above",
                outcome="depressed", temporal_lag=7,
                description="cross-dataset", combination=feat2,
            )
            result = evaluator.evaluate(hyp, features, labels, subject_ids)
            log(f"    Depresjon result: d={result.cohens_d:.3f}, p={result.p_value:.4f}, AUC={result.auc:.3f}")
        log("")


if __name__ == "__main__":
    start = time.time()

    n_global = test1_global_fdr()
    test2_permutation_null(n_permutations=100)
    test3_holdout()
    test4_cross_dataset()

    elapsed = time.time() - start
    log(f"\n{'='*60}")
    log(f"ALL VALIDATION TESTS COMPLETE ({elapsed/60:.1f} min)")
    log(f"{'='*60}")
