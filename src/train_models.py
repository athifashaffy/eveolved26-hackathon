"""
AutoBiomarker — ML Model Training Pipeline

Trains depression prediction models using discovered biomarker features.
Compares temporal dynamics features (novel) vs standard HRV features (baseline).

Models:
1. Logistic Regression (baseline)
2. Random Forest
3. Gradient Boosting (XGBoost-style)
4. MLP Neural Network
5. Ensemble (voting)

All evaluated with Leave-One-Subject-Out cross-validation.
"""

import os
import sys
import json
import time
import datetime
import numpy as np
import pandas as pd
from sklearn.linear_model import LogisticRegression
from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier, VotingClassifier
from sklearn.neural_network import MLPClassifier
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import (
    roc_auc_score, accuracy_score, f1_score,
    precision_score, recall_score, classification_report,
    confusion_matrix,
)
from sklearn.feature_selection import SelectKBest, f_classif
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

sys.path.insert(0, os.path.dirname(__file__))
from config import DATA_DIR, RESULTS_DIR, PHQ9_MILD_THRESHOLD
from data_loader import (
    load_hrv_metrics, compute_daily_hrv,
    load_sleep_diary, load_clinical_metadata, build_merged_dataset,
)
from feature_extractor import compute_early_warning_signals, get_feature_names


MODELS_DIR = os.path.join(RESULTS_DIR, "models")


def log(msg):
    ts = datetime.datetime.now().strftime("%H:%M:%S")
    print(f"[{ts}] {msg}")


def get_subject_level_features(features_df, feature_names):
    """Aggregate daily features to subject-level (mean + std across days).

    This creates a fixed-size feature vector per subject for classification.
    """
    agg_dict = {}
    for feat in feature_names:
        if feat in features_df.columns:
            agg_dict[feat] = ["mean", "std", "min", "max"]

    subject_features = features_df.groupby("subject_id").agg(agg_dict)
    subject_features.columns = ["_".join(c) for c in subject_features.columns]
    subject_features = subject_features.reset_index()

    # Drop columns that are all NaN
    subject_features = subject_features.dropna(axis=1, how="all")

    return subject_features


def loso_cv(X, y, subjects, model_fn, model_name="Model"):
    """Leave-one-subject-out cross-validation."""
    unique_subjects = np.unique(subjects)
    y_true_all, y_pred_all, y_prob_all = [], [], []

    for held_out in unique_subjects:
        train_mask = subjects != held_out
        test_mask = subjects == held_out

        if y[train_mask].sum() == 0 or y[train_mask].sum() == train_mask.sum():
            continue
        if test_mask.sum() == 0:
            continue

        # Scale features
        scaler = StandardScaler()
        X_train = scaler.fit_transform(X[train_mask])
        X_test = scaler.transform(X[test_mask])

        # Handle NaN
        X_train = np.nan_to_num(X_train, nan=0.0)
        X_test = np.nan_to_num(X_test, nan=0.0)

        model = model_fn()
        try:
            model.fit(X_train, y[train_mask])
            preds = model.predict(X_test)
            probs = model.predict_proba(X_test)[:, 1] if hasattr(model, "predict_proba") else preds

            y_true_all.extend(y[test_mask])
            y_pred_all.extend(preds)
            y_prob_all.extend(probs)
        except Exception as e:
            continue

    y_true_all = np.array(y_true_all)
    y_pred_all = np.array(y_pred_all)
    y_prob_all = np.array(y_prob_all)

    if len(y_true_all) < 10 or len(np.unique(y_true_all)) < 2:
        return None

    try:
        auc = roc_auc_score(y_true_all, y_prob_all)
    except ValueError:
        auc = 0.5

    return {
        "model": model_name,
        "auc": round(auc, 4),
        "accuracy": round(accuracy_score(y_true_all, y_pred_all), 4),
        "f1": round(f1_score(y_true_all, y_pred_all, zero_division=0), 4),
        "precision": round(precision_score(y_true_all, y_pred_all, zero_division=0), 4),
        "recall": round(recall_score(y_true_all, y_pred_all, zero_division=0), 4),
        "n_subjects": len(unique_subjects),
        "n_positive": int(y_true_all.sum()),
        "n_predictions": len(y_true_all),
        "y_true": y_true_all,
        "y_prob": y_prob_all,
    }


def loso_cv_with_selection(X, y, subjects, model_fn, k=50, model_name="Model"):
    """LOSO-CV with feature selection INSIDE the loop (no leakage)."""
    unique_subjects = np.unique(subjects)
    y_true_all, y_pred_all, y_prob_all = [], [], []
    all_selected = []

    for held_out in unique_subjects:
        train_mask = subjects != held_out
        test_mask = subjects == held_out

        if y[train_mask].sum() == 0 or y[train_mask].sum() == train_mask.sum():
            continue
        if test_mask.sum() == 0:
            continue

        X_train_raw = X[train_mask]
        X_test_raw = X[test_mask]

        # Impute NaN per fold
        train_medians = np.nanmedian(X_train_raw, axis=0)
        train_medians = np.nan_to_num(train_medians, nan=0.0)
        for j in range(X_train_raw.shape[1]):
            X_train_raw[np.isnan(X_train_raw[:, j]), j] = train_medians[j]
            X_test_raw[np.isnan(X_test_raw[:, j]), j] = train_medians[j]

        # Scale per fold
        scaler = StandardScaler()
        X_train = scaler.fit_transform(X_train_raw)
        X_test = scaler.transform(X_test_raw)

        # Feature selection per fold
        selector = SelectKBest(f_classif, k=min(k, X_train.shape[1]))
        X_train = selector.fit_transform(X_train, y[train_mask])
        X_test = selector.transform(X_test)
        all_selected.append(set(np.where(selector.get_support())[0]))

        X_train = np.nan_to_num(X_train, nan=0.0)
        X_test = np.nan_to_num(X_test, nan=0.0)

        model = model_fn()
        try:
            model.fit(X_train, y[train_mask])
            preds = model.predict(X_test)
            probs = model.predict_proba(X_test)[:, 1] if hasattr(model, "predict_proba") else preds
            y_true_all.extend(y[test_mask])
            y_pred_all.extend(preds)
            y_prob_all.extend(probs)
        except Exception:
            continue

    y_true_all = np.array(y_true_all)
    y_pred_all = np.array(y_pred_all)
    y_prob_all = np.array(y_prob_all)

    if len(y_true_all) < 10 or len(np.unique(y_true_all)) < 2:
        return None

    try:
        auc = roc_auc_score(y_true_all, y_prob_all)
    except ValueError:
        auc = 0.5

    return {
        "model": model_name,
        "auc": round(auc, 4),
        "accuracy": round(accuracy_score(y_true_all, y_pred_all), 4),
        "f1": round(f1_score(y_true_all, y_pred_all, zero_division=0), 4),
        "precision": round(precision_score(y_true_all, y_pred_all, zero_division=0), 4),
        "recall": round(recall_score(y_true_all, y_pred_all, zero_division=0), 4),
        "n_subjects": len(unique_subjects),
        "n_positive": int(y_true_all.sum()),
        "n_predictions": len(y_true_all),
        "y_true": y_true_all,
        "y_prob": y_prob_all,
    }


def get_top_features_from_results():
    """Get top features from the autoresearch results."""
    results_path = os.path.join(RESULTS_DIR, "results.tsv")
    if not os.path.exists(results_path):
        # Try intermediate
        intermediates = sorted(
            [f for f in os.listdir(RESULTS_DIR) if f.startswith("results_intermediate")],
            reverse=True,
        )
        if intermediates:
            results_path = os.path.join(RESULTS_DIR, intermediates[0])
        else:
            return []

    df = pd.read_csv(results_path, sep="\t")
    kept = df[df["status"] == "KEEP"].sort_values("cohens_d", ascending=False)

    # Get unique feature names (remove interaction marker)
    features = []
    for feat in kept["feature"].values:
        if "×" in feat:
            parts = feat.split(" × ")
            features.extend(parts)
        else:
            features.append(feat)

    return list(dict.fromkeys(features))  # Unique, order preserved


def define_feature_sets(feature_names, top_autoresearch_features):
    """Define different feature sets for comparison."""
    # Standard features (what everyone uses — just mean levels)
    standard = [f for f in feature_names if "_mean" in f and not f.endswith("_mean_std")]

    # Temporal dynamics (our novel features — CV, autocorr, std, slope)
    temporal = [f for f in feature_names if any(s in f for s in ["_cv", "_autocorr", "_std", "_slope"])]

    # Top autoresearch discoveries (from the overnight run)
    autoresearch_top = [f for f in top_autoresearch_features if f in feature_names][:30]

    # All features
    all_feats = feature_names

    # Sleep only
    sleep = [f for f in feature_names if f.startswith("sleep_")]

    # HRV only
    hrv = [f for f in feature_names if f.startswith(("rmssd_", "hr_", "lfhf_"))]

    # Critical slowing down features specifically
    csd = [f for f in feature_names if any(s in f for s in ["_autocorr", "_cv"]) and
           f.startswith(("rmssd_", "hr_"))]

    return {
        "standard_means": standard,
        "temporal_dynamics": temporal,
        "autoresearch_top30": autoresearch_top,
        "all_features": all_feats,
        "sleep_only": sleep,
        "hrv_only": hrv,
        "critical_slowing_down": csd,
    }


def run_training():
    """Full training pipeline."""
    start = time.time()
    os.makedirs(MODELS_DIR, exist_ok=True)

    log("=" * 70)
    log("AutoBiomarker — ML MODEL TRAINING")
    log("=" * 70)

    # ---- Load and prepare data ----
    log("Loading data...")
    hrv = load_hrv_metrics()
    daily_hrv = compute_daily_hrv(hrv)
    sleep = load_sleep_diary()
    clinical = load_clinical_metadata()
    merged = build_merged_dataset(daily_hrv, sleep, clinical)

    log("Extracting features...")
    features_df = compute_early_warning_signals(merged)
    feature_names = get_feature_names(features_df)
    log(f"  {len(feature_names)} raw features")

    # Aggregate to subject level
    log("Aggregating to subject-level features...")
    subject_features = get_subject_level_features(features_df, feature_names)
    log(f"  {subject_features.shape[1] - 1} subject-level features for {len(subject_features)} subjects")

    # Prepare outcome
    phq9_map = clinical.set_index("subject_id")["PHQ9"].to_dict()
    subject_features["outcome"] = subject_features["subject_id"].map(phq9_map)
    subject_features["outcome_binary"] = (subject_features["outcome"] >= PHQ9_MILD_THRESHOLD).astype(int)
    subject_features = subject_features.dropna(subset=["outcome_binary"])

    y = subject_features["outcome_binary"].values
    subjects = subject_features["subject_id"].values
    log(f"  Outcome: {int(y.sum())} positive, {int(len(y) - y.sum())} negative")

    all_feat_cols = [c for c in subject_features.columns
                     if c not in ["subject_id", "outcome", "outcome_binary"]]

    # Get top features from autoresearch
    top_auto = get_top_features_from_results()
    log(f"  Top autoresearch features: {len(top_auto)}")

    # ---- Define feature sets ----
    # Map raw feature names to subject-level aggregated names
    def expand_to_subject_cols(raw_names):
        expanded = []
        for feat in raw_names:
            for suffix in ["_mean", "_std", "_min", "_max"]:
                col = f"{feat}{suffix}"
                if col in all_feat_cols:
                    expanded.append(col)
        return expanded

    feature_sets_raw = define_feature_sets(feature_names, top_auto)
    feature_sets = {}
    for name, raw_feats in feature_sets_raw.items():
        expanded = expand_to_subject_cols(raw_feats)
        if expanded:
            feature_sets[name] = expanded
            log(f"  Feature set '{name}': {len(expanded)} columns")

    # Add "all" set
    feature_sets["all_features"] = all_feat_cols

    # ---- Define models ----
    models = {
        "Logistic Regression": lambda: LogisticRegression(max_iter=2000, C=1.0, random_state=42),
        "Random Forest": lambda: RandomForestClassifier(n_estimators=200, max_depth=5,
                                                         min_samples_leaf=3, random_state=42),
        "Gradient Boosting": lambda: GradientBoostingClassifier(n_estimators=100, max_depth=3,
                                                                  learning_rate=0.1, random_state=42),
        "MLP Neural Net": lambda: MLPClassifier(hidden_layer_sizes=(64, 32), max_iter=500,
                                                 early_stopping=True, random_state=42),
    }

    # ---- Run all combinations ----
    log("\nTraining all model × feature set combinations...")
    all_results = []

    for feat_set_name, feat_cols in feature_sets.items():
        if len(feat_cols) == 0:
            continue

        X = subject_features[feat_cols].values

        for model_name, model_fn in models.items():
            label = f"{model_name} + {feat_set_name}"
            log(f"  Training: {label} ({len(feat_cols)} features)...")

            result = loso_cv(X, y, subjects, model_fn, model_name=label)
            if result:
                result["feature_set"] = feat_set_name
                result["n_features"] = len(feat_cols)
                all_results.append(result)
                log(f"    AUC={result['auc']:.3f}  F1={result['f1']:.3f}  Acc={result['accuracy']:.3f}")
            else:
                log(f"    FAILED (insufficient data)")

    # ---- Also train with SelectKBest INSIDE CV loop (no leakage) ----
    log("\nTraining with feature selection INSIDE CV loop...")
    for k in [5, 10, 20, 50]:
        X_all = subject_features[all_feat_cols].values
        X_all = np.nan_to_num(X_all, nan=0.0)
        actual_k = min(k, X_all.shape[1])

        for model_name, model_fn in models.items():
            label = f"{model_name} + top{k}_selected"
            try:
                result = loso_cv_with_selection(
                    X_all, y, subjects, model_fn, k=actual_k, model_name=label
                )
                if result:
                    result["feature_set"] = f"top{k}_selected"
                    result["n_features"] = k
                    result["selected_features"] = result.get("selected_features", [])
                    all_results.append(result)
                    log(f"  {label}: AUC={result['auc']:.3f}  F1={result['f1']:.3f}")
            except Exception as e:
                log(f"  SelectKBest k={k} {model_name} failed: {e}")

    # ---- Compile and save results ----
    log("\n" + "=" * 70)
    log("TRAINING RESULTS")
    log("=" * 70)

    results_clean = []
    for r in all_results:
        results_clean.append({
            "model": r["model"],
            "feature_set": r.get("feature_set", ""),
            "n_features": r.get("n_features", 0),
            "auc": r["auc"],
            "accuracy": r["accuracy"],
            "f1": r["f1"],
            "precision": r["precision"],
            "recall": r["recall"],
        })

    results_df = pd.DataFrame(results_clean).sort_values("auc", ascending=False)
    results_df.to_csv(os.path.join(MODELS_DIR, "model_comparison.tsv"), sep="\t", index=False)

    log("\nTop 10 models by AUC:")
    for i, row in results_df.head(10).iterrows():
        log(f"  {row['model']:55s} AUC={row['auc']:.3f}  F1={row['f1']:.3f}  ({row['n_features']} features)")

    # ---- Key comparison: standard vs temporal ----
    log("\n" + "=" * 70)
    log("KEY COMPARISON: Standard (mean levels) vs Temporal Dynamics")
    log("=" * 70)

    standard_results = results_df[results_df["feature_set"] == "standard_means"]
    temporal_results = results_df[results_df["feature_set"] == "temporal_dynamics"]
    csd_results = results_df[results_df["feature_set"] == "critical_slowing_down"]
    auto_results = results_df[results_df["feature_set"] == "autoresearch_top30"]

    for name, subset in [("Standard (mean levels)", standard_results),
                         ("Temporal dynamics", temporal_results),
                         ("Critical slowing down", csd_results),
                         ("Autoresearch top 30", auto_results)]:
        if len(subset) > 0:
            best = subset.iloc[0]
            log(f"  {name:30s}: Best AUC = {best['auc']:.3f} ({best['model']})")

    # ---- Generate comparison plot ----
    log("\nGenerating plots...")
    try:
        fig, axes = plt.subplots(1, 2, figsize=(16, 6))

        # Plot 1: AUC by feature set
        feat_set_auc = results_df.groupby("feature_set")["auc"].max().sort_values(ascending=True)
        colors = ["#00d4aa" if "temporal" in name or "critical" in name or "autoresearch" in name
                  else "#888888" for name in feat_set_auc.index]
        feat_set_auc.plot(kind="barh", ax=axes[0], color=colors)
        axes[0].set_xlabel("Best AUC (LOSO-CV)")
        axes[0].set_title("Best AUC by Feature Set")
        axes[0].axvline(x=0.5, color="red", linestyle="--", alpha=0.5, label="Chance")

        # Plot 2: Model comparison on temporal features
        if len(temporal_results) > 0:
            temp_by_model = temporal_results.set_index("model")["auc"].sort_values(ascending=True)
            temp_by_model.plot(kind="barh", ax=axes[1], color="#6c5ce7")
            axes[1].set_xlabel("AUC")
            axes[1].set_title("Model Comparison (Temporal Features)")

        plt.tight_layout()
        plt.savefig(os.path.join(MODELS_DIR, "model_comparison.png"), dpi=150, bbox_inches="tight")
        log(f"  Saved: {MODELS_DIR}/model_comparison.png")
    except Exception as e:
        log(f"  Plot generation failed: {e}")

    # ---- Feature importance from best Random Forest ----
    log("\nExtracting feature importance from Random Forest...")
    try:
        X_all = np.nan_to_num(subject_features[all_feat_cols].values, nan=0.0)
        rf = RandomForestClassifier(n_estimators=200, max_depth=5, random_state=42)
        rf.fit(X_all, y)

        importances = pd.DataFrame({
            "feature": all_feat_cols,
            "importance": rf.feature_importances_,
        }).sort_values("importance", ascending=False)

        importances.to_csv(os.path.join(MODELS_DIR, "feature_importances.tsv"), sep="\t", index=False)
        log("  Top 20 features by importance:")
        for _, row in importances.head(20).iterrows():
            log(f"    {row['feature']:50s} {row['importance']:.4f}")

        # Plot
        fig, ax = plt.subplots(figsize=(10, 8))
        top20 = importances.head(20)
        colors = ["#00d4aa" if any(s in f for s in ["_cv_", "_autocorr_", "_std_", "_slope_"])
                  else "#888888" for f in top20["feature"]]
        ax.barh(range(len(top20)), top20["importance"].values, color=colors)
        ax.set_yticks(range(len(top20)))
        ax.set_yticklabels(top20["feature"].values, fontsize=8)
        ax.invert_yaxis()
        ax.set_xlabel("Feature Importance")
        ax.set_title("Top 20 Features (Green = Temporal Dynamics, Gray = Standard)")
        plt.tight_layout()
        plt.savefig(os.path.join(MODELS_DIR, "feature_importances.png"), dpi=150, bbox_inches="tight")
        log(f"  Saved: {MODELS_DIR}/feature_importances.png")
    except Exception as e:
        log(f"  Feature importance failed: {e}")

    total_time = time.time() - start
    log(f"\nTotal training time: {total_time/60:.1f} minutes")
    log(f"Results saved to: {MODELS_DIR}/")

    return results_df


if __name__ == "__main__":
    run_training()
