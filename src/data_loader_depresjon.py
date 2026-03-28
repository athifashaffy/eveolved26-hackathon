"""
AutoBiomarker — Data Loader for Depresjon (Simula) dataset

Dataset: 55 participants (23 depressed + 32 controls), actigraphy at 1-min intervals
Source: Garcia-Ceja et al., ACM MMSys 2018
Files:
  - scores.csv: clinical metadata (MADRS scores, demographics)
  - condition/*.csv: actigraphy for depressed patients
  - control/*.csv: actigraphy for healthy controls
"""

import os
import glob
import pandas as pd
import numpy as np
from config import DATA_DIR, ROLLING_WINDOWS

DEPRESJON_DIR = os.path.join(DATA_DIR, "depresjon", "data")


def load_actigraphy() -> pd.DataFrame:
    """Load all actigraphy files and compute daily activity summaries."""
    rows = []

    for group, label in [("condition", 1), ("control", 0)]:
        pattern = os.path.join(DEPRESJON_DIR, group, f"{group}_*.csv")
        files = sorted(glob.glob(pattern))
        for fpath in files:
            fname = os.path.basename(fpath).replace(".csv", "")
            df = pd.read_csv(fpath)
            df["subject_id"] = fname
            df["depressed"] = label
            rows.append(df)

    all_data = pd.concat(rows, ignore_index=True)
    all_data["timestamp"] = pd.to_datetime(all_data["timestamp"])
    all_data["date"] = pd.to_datetime(all_data["date"])

    print(f"Loaded actigraphy: {len(all_data):,} rows, {all_data['subject_id'].nunique()} subjects")
    return all_data


def compute_daily_activity(actigraphy: pd.DataFrame) -> pd.DataFrame:
    """Aggregate minute-level actigraphy to daily summaries.

    Computed metrics mirror HRV daily summaries:
    - activity_mean: average motor activity (analogous to HR mean)
    - activity_std: within-day variability
    - activity_max: peak activity
    - activity_total: total daily counts
    - active_minutes: minutes with activity > 0
    - rest_ratio: proportion of zero-activity minutes (rest proxy)
    - activity_entropy: Shannon entropy of activity distribution (regularity)
    """
    daily = actigraphy.groupby(["subject_id", "date", "depressed"]).agg(
        activity_mean=("activity", "mean"),
        activity_std=("activity", "std"),
        activity_max=("activity", "max"),
        activity_total=("activity", "sum"),
        active_minutes=("activity", lambda x: (x > 0).sum()),
        total_minutes=("activity", "size"),
    ).reset_index()

    daily["rest_ratio"] = 1 - (daily["active_minutes"] / daily["total_minutes"])

    # Activity entropy (binned into 10 levels)
    def _entropy(group):
        vals = group["activity"].values
        if len(vals) == 0:
            return 0.0
        bins = np.linspace(0, vals.max() + 1, 11)
        counts, _ = np.histogram(vals, bins=bins)
        probs = counts / counts.sum()
        probs = probs[probs > 0]
        return -np.sum(probs * np.log2(probs))

    entropy = actigraphy.groupby(["subject_id", "date"]).apply(_entropy, include_groups=False).reset_index(name="activity_entropy")
    daily = daily.merge(entropy, on=["subject_id", "date"], how="left")

    print(f"Computed daily activity: {len(daily)} rows, {daily['subject_id'].nunique()} subjects")
    return daily


def load_clinical_metadata() -> pd.DataFrame:
    """Load MADRS scores and demographics from scores.csv."""
    path = os.path.join(DEPRESJON_DIR, "scores.csv")
    df = pd.read_csv(path)

    df = df.rename(columns={
        "number": "subject_id",
        "madrs1": "MADRS_1",
        "madrs2": "MADRS_2",
    })

    # Use group assignment: condition_* = depressed, control_* = healthy
    df["depressed"] = df["subject_id"].apply(lambda x: 1 if x.startswith("condition") else 0)

    # Use MADRS_1 as primary severity score (analogous to PHQ-9)
    df["severity_score"] = df["MADRS_1"]

    # Parse age ranges to midpoint
    def _age_mid(age_str):
        try:
            parts = str(age_str).split("-")
            return (int(parts[0]) + int(parts[1])) / 2
        except Exception:
            return np.nan

    df["age_mid"] = df["age"].apply(_age_mid)

    print(f"Loaded clinical metadata: {len(df)} subjects")
    print(f"  MADRS range: {df['MADRS_1'].min()}-{df['MADRS_1'].max()}, "
          f"mean={df['MADRS_1'].mean():.1f}")
    print(f"  Depressed (MADRS>=20): {df['depressed'].sum()} / {len(df)}")
    return df


def compute_temporal_features(daily: pd.DataFrame) -> pd.DataFrame:
    """Compute rolling temporal dynamics features on daily activity data.

    Same statistical features as HRV pipeline but applied to:
    - activity_mean (analogous to RMSSD)
    - activity_std (within-day variability)
    - rest_ratio (analogous to sleep quality)
    - activity_entropy (regularity)
    """
    from feature_extractor import compute_rolling_stats

    all_features = []

    for subject_id, subj_df in daily.groupby("subject_id"):
        subj_df = subj_df.sort_values("date").copy()
        features = pd.DataFrame(index=subj_df.index)
        features["subject_id"] = subject_id
        features["date"] = subj_df["date"].values

        # Motor activity temporal features (analogous to RMSSD)
        activity_feats = compute_rolling_stats(subj_df["activity_mean"], prefix="activity")
        features = pd.concat([features, activity_feats], axis=1)

        # Within-day variability temporal features
        if "activity_std" in subj_df.columns:
            std_feats = compute_rolling_stats(subj_df["activity_std"], prefix="activity_std")
            features = pd.concat([features, std_feats], axis=1)

        # Rest ratio temporal features (analogous to sleep quality)
        if "rest_ratio" in subj_df.columns:
            rest_feats = compute_rolling_stats(subj_df["rest_ratio"], prefix="rest_ratio")
            features = pd.concat([features, rest_feats], axis=1)

        # Entropy temporal features
        if "activity_entropy" in subj_df.columns:
            ent_feats = compute_rolling_stats(subj_df["activity_entropy"], prefix="entropy")
            features = pd.concat([features, ent_feats], axis=1)

        # Active minutes temporal features
        if "active_minutes" in subj_df.columns:
            act_min_feats = compute_rolling_stats(subj_df["active_minutes"], prefix="active_min")
            features = pd.concat([features, act_min_feats], axis=1)

        all_features.append(features)

    result = pd.concat(all_features, ignore_index=True)
    feature_cols = [c for c in result.columns if c not in ["subject_id", "date"]]
    print(f"Extracted {len(feature_cols)} temporal features for {result['subject_id'].nunique()} subjects (Depresjon)")
    return result


def build_depresjon_dataset() -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    """Full pipeline: load → daily → features → clinical.

    Returns (features_df, daily_df, clinical_df)
    """
    actigraphy = load_actigraphy()
    daily = compute_daily_activity(actigraphy)
    clinical = load_clinical_metadata()
    features = compute_temporal_features(daily)

    # Merge depressed label from clinical
    label_map = clinical.set_index("subject_id")["depressed"].to_dict()
    features["depressed"] = features["subject_id"].map(label_map)

    return features, daily, clinical


if __name__ == "__main__":
    print("=== Loading Depresjon Dataset ===\n")
    features, daily, clinical = build_depresjon_dataset()
    print(f"\nFeatures shape: {features.shape}")
    feature_cols = [c for c in features.columns if c not in ["subject_id", "date", "depressed"]]
    print(f"Feature columns: {len(feature_cols)}")
    print(f"\nDepressed: {features['depressed'].sum()} subjects")
    print(f"Healthy: {(features['depressed'] == 0).sum()} day-rows")
