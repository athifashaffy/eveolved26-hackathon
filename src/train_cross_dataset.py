"""
AutoBiomarker — Cross-Dataset Model Training

1. Train on Depresjon alone → AUC
2. Train on Baigutanova alone → AUC (already done)
3. Train on combined → AUC (generalization test)
"""

import os
import sys
import json
import pickle
import warnings
import numpy as np
import pandas as pd
from sklearn.preprocessing import StandardScaler
from sklearn.linear_model import LogisticRegression
from sklearn.ensemble import GradientBoostingClassifier
from sklearn.pipeline import Pipeline
from sklearn.model_selection import LeaveOneGroupOut, cross_val_predict
from sklearn.metrics import roc_auc_score, f1_score, classification_report
from sklearn.feature_selection import SelectKBest, f_classif

warnings.filterwarnings("ignore")
sys.path.insert(0, os.path.dirname(__file__))
from config import RESULTS_DIR, DATA_DIR, PHQ9_MILD_THRESHOLD

MODELS_DIR = os.path.join(RESULTS_DIR, "models")
os.makedirs(MODELS_DIR, exist_ok=True)


def load_baigutanova_features():
    """Load subject-level features from Baigutanova dataset."""
    from data_loader import load_hrv_metrics, compute_daily_hrv, load_sleep_diary, load_clinical_metadata, build_merged_dataset
    from feature_extractor import compute_early_warning_signals

    hrv = load_hrv_metrics()
    daily_hrv = compute_daily_hrv(hrv)
    sleep = load_sleep_diary()
    clinical = load_clinical_metadata()
    merged = build_merged_dataset(daily_hrv, sleep, clinical)
    features = compute_early_warning_signals(merged)

    feature_cols = [c for c in features.columns if c not in ["subject_id", "date"]]
    subj = features.groupby("subject_id")[feature_cols].mean().reset_index()

    phq_map = clinical.set_index("subject_id")["PHQ9"].to_dict()
    subj["depressed"] = subj["subject_id"].apply(lambda s: 1 if phq_map.get(s, 0) >= PHQ9_MILD_THRESHOLD else 0)
    subj["dataset"] = "baigutanova"

    return subj, feature_cols


def load_depresjon_features():
    """Load subject-level features from Depresjon dataset."""
    from data_loader_depresjon import build_depresjon_dataset

    features, daily, clinical = build_depresjon_dataset()

    feature_cols = [c for c in features.columns if c not in ["subject_id", "date", "depressed"]]
    subj = features.groupby("subject_id")[feature_cols].mean().reset_index()

    label_map = clinical.set_index("subject_id")["depressed"].to_dict()
    subj["depressed"] = subj["subject_id"].map(label_map)
    subj["dataset"] = "depresjon"

    return subj, feature_cols


def train_and_evaluate(X, y, groups, dataset_name, feature_cols):
    """Train with LOGO-CV and return metrics."""
    logo = LeaveOneGroupOut()

    # Impute NaN with column median
    for j in range(X.shape[1]):
        col = X[:, j]
        if np.any(np.isnan(col)):
            median = np.nanmedian(col)
            col[np.isnan(col)] = median if not np.isnan(median) else 0
            X[:, j] = col

    # Pipeline: scale → select top features → classify
    pipe = Pipeline([
        ("scaler", StandardScaler()),
        ("select", SelectKBest(f_classif, k=min(20, X.shape[1]))),
        ("clf", LogisticRegression(C=0.1, max_iter=1000, class_weight="balanced")),
    ])

    try:
        y_pred_proba = cross_val_predict(pipe, X, y, groups=groups, cv=logo, method="predict_proba")[:, 1]
        y_pred = (y_pred_proba >= 0.5).astype(int)
        auc = roc_auc_score(y, y_pred_proba)
        f1 = f1_score(y, y_pred)
    except Exception as e:
        print(f"  ERROR: {e}")
        return None

    print(f"\n  {dataset_name}: AUC={auc:.3f}, F1={f1:.3f}")
    print(f"    n={len(y)}, pos={y.sum()}, neg={(1-y).sum()}")
    print(f"    Features: {X.shape[1]} → {min(20, X.shape[1])} selected")

    return {"dataset": dataset_name, "auc": auc, "f1": f1, "n": len(y),
            "n_pos": int(y.sum()), "n_features": X.shape[1]}


def main():
    print("=== Cross-Dataset Model Training ===\n")

    # Load both datasets
    print("Loading Baigutanova...")
    baig, baig_cols = load_baigutanova_features()
    print(f"  {len(baig)} subjects, {len(baig_cols)} features")

    print("Loading Depresjon...")
    dep, dep_cols = load_depresjon_features()
    print(f"  {len(dep)} subjects, {len(dep_cols)} features")

    results = []

    # 1. Baigutanova alone
    print("\n--- Baigutanova (HRV+Sleep) ---")
    X_baig = baig[baig_cols].values
    y_baig = baig["depressed"].values
    g_baig = baig["subject_id"].values
    r = train_and_evaluate(X_baig, y_baig, g_baig, "Baigutanova", baig_cols)
    if r:
        results.append(r)

    # 2. Depresjon alone
    print("\n--- Depresjon (Actigraphy) ---")
    X_dep = dep[dep_cols].values
    y_dep = dep["depressed"].values
    g_dep = dep["subject_id"].values
    r = train_and_evaluate(X_dep, y_dep, g_dep, "Depresjon", dep_cols)
    if r:
        results.append(r)

    # 3. Find shared feature TYPES (same statistical patterns, different modalities)
    # Both datasets have: *_mean, *_std, *_cv, *_slope, *_autocorr for various windows
    # Rename to generic: signal_Xd_stat
    print("\n--- Combined (shared temporal patterns) ---")

    def genericize_features(df, cols):
        """Rename modality-specific features to generic temporal pattern names.
        If multiple source cols map to the same generic name, keep the first."""
        rename_map = {}
        seen_generic = set()
        for c in cols:
            parts = c.split("_")
            for i, p in enumerate(parts):
                if p.endswith("d") and p[:-1].isdigit():
                    generic = "signal_" + "_".join(parts[i:])
                    if generic not in seen_generic:
                        rename_map[c] = generic
                        seen_generic.add(generic)
                    break
        renamed = df[list(rename_map.keys())].rename(columns=rename_map)
        return renamed, sorted(seen_generic)

    baig_generic, bg_cols = genericize_features(baig, baig_cols)
    dep_generic, dg_cols = genericize_features(dep, dep_cols)

    # Find shared generic columns
    shared_cols = sorted(set(bg_cols) & set(dg_cols))
    print(f"  Shared temporal pattern features: {len(shared_cols)}")

    if len(shared_cols) >= 5:
        baig_generic["subject_id"] = baig["subject_id"].values
        baig_generic["depressed"] = baig["depressed"].values
        baig_generic["dataset"] = "baig"

        dep_generic["subject_id"] = dep["subject_id"].values
        dep_generic["depressed"] = dep["depressed"].values
        dep_generic["dataset"] = "dep"

        combined = pd.concat([baig_generic[shared_cols + ["subject_id", "depressed", "dataset"]],
                              dep_generic[shared_cols + ["subject_id", "depressed", "dataset"]]],
                             ignore_index=True)

        X_comb = combined[shared_cols].values
        y_comb = combined["depressed"].values
        g_comb = combined["subject_id"].values

        # Replace NaN with column median
        for j in range(X_comb.shape[1]):
            col = X_comb[:, j]
            median = np.nanmedian(col)
            col[np.isnan(col)] = median
            X_comb[:, j] = col

        r = train_and_evaluate(X_comb, y_comb, g_comb, "Combined", shared_cols)
        if r:
            results.append(r)

        # 4. Cross-dataset transfer: train on one, test on other
        print("\n--- Transfer: Train Baigutanova → Test Depresjon ---")
        pipe = Pipeline([
            ("scaler", StandardScaler()),
            ("select", SelectKBest(f_classif, k=min(15, len(shared_cols)))),
            ("clf", LogisticRegression(C=0.1, max_iter=1000, class_weight="balanced")),
        ])

        X_train = baig_generic[shared_cols].fillna(0).values
        y_train = baig["depressed"].values
        X_test = dep_generic[shared_cols].fillna(0).values
        y_test = dep["depressed"].values

        pipe.fit(X_train, y_train)
        y_pred_proba = pipe.predict_proba(X_test)[:, 1]
        try:
            transfer_auc = roc_auc_score(y_test, y_pred_proba)
            print(f"  Transfer AUC: {transfer_auc:.3f}")
            results.append({"dataset": "Transfer_Baig→Dep", "auc": transfer_auc, "f1": 0,
                          "n": len(y_test), "n_pos": int(y_test.sum()), "n_features": len(shared_cols)})
        except Exception as e:
            print(f"  Transfer failed: {e}")

        print("\n--- Transfer: Train Depresjon → Test Baigutanova ---")
        pipe2 = Pipeline([
            ("scaler", StandardScaler()),
            ("select", SelectKBest(f_classif, k=min(15, len(shared_cols)))),
            ("clf", LogisticRegression(C=0.1, max_iter=1000, class_weight="balanced")),
        ])
        pipe2.fit(X_test, y_test)
        y_pred_proba2 = pipe2.predict_proba(X_train)[:, 1]
        try:
            transfer_auc2 = roc_auc_score(y_train, y_pred_proba2)
            print(f"  Transfer AUC: {transfer_auc2:.3f}")
            results.append({"dataset": "Transfer_Dep→Baig", "auc": transfer_auc2, "f1": 0,
                          "n": len(y_train), "n_pos": int(y_train.sum()), "n_features": len(shared_cols)})
        except Exception as e:
            print(f"  Transfer failed: {e}")

    # Save summary
    results_df = pd.DataFrame(results)
    results_df.to_csv(os.path.join(MODELS_DIR, "cross_dataset_results.csv"), index=False)

    print("\n\n=== SUMMARY ===")
    print(results_df.to_string(index=False))

    # Save combined model
    if len(shared_cols) >= 5:
        print("\n\nTraining final combined model on all data...")
        X_all = combined[shared_cols].fillna(0).values
        y_all = combined["depressed"].values

        final_pipe = Pipeline([
            ("scaler", StandardScaler()),
            ("select", SelectKBest(f_classif, k=min(20, len(shared_cols)))),
            ("clf", GradientBoostingClassifier(n_estimators=100, max_depth=3,
                                               learning_rate=0.1, random_state=42)),
        ])
        final_pipe.fit(X_all, y_all)

        model_path = os.path.join(MODELS_DIR, "cross_dataset_model.pkl")
        with open(model_path, "wb") as f:
            pickle.dump(final_pipe, f)

        meta = {
            "datasets": ["baigutanova", "depresjon"],
            "n_subjects": len(combined),
            "shared_features": shared_cols,
            "n_features_selected": min(20, len(shared_cols)),
        }
        with open(os.path.join(MODELS_DIR, "cross_dataset_meta.json"), "w") as f:
            json.dump(meta, f, indent=2)

        print(f"Saved combined model to {model_path}")


if __name__ == "__main__":
    main()
