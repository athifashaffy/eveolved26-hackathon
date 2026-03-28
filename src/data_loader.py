"""
AutoBiomarker — Data Loader for Baigutanova et al. 2025 dataset

Dataset: 49 participants, 28 days continuous HRV + sleep diary + PHQ-9 + GAD-7
Files:
  - sensor_hrv_filtered.csv: per-5min HRV segments (deviceId, ts_start, rmssd, sdnn, etc.)
  - sleep_diary.csv: daily sleep logs (userId, date, go2bed, sleep_duration, etc.)
  - survey.csv: clinical metadata (deviceId, PHQ9_1, PHQ9_2, PHQ9_F, GAD7_1, etc.)
"""

import os
import pandas as pd
import numpy as np
from config import DATA_DIR


def load_hrv_metrics() -> pd.DataFrame:
    """Load per-segment HRV metrics for all participants."""
    path = os.path.join(DATA_DIR, "sensor_hrv_filtered.csv")
    if not os.path.exists(path):
        raise FileNotFoundError(
            f"HRV file not found at {path}. "
            "Download from: https://springernature.figshare.com/articles/dataset/28509740"
        )

    df = pd.read_csv(path)

    # Rename to standardized column names
    df = df.rename(columns={
        "deviceId": "subject_id",
        "HR": "heart_rate",
        "rmssd": "RMSSD",
        "sdnn": "SDNN",
        "pnn50": "pNN50",
        "lf": "LF",
        "hf": "HF",
        "lf/hf": "LF_HF_ratio",
    })

    # Convert epoch milliseconds to datetime
    df["timestamp"] = pd.to_datetime(df["ts_start"], unit="ms")

    print(f"Loaded HRV metrics: {len(df)} rows, {df['subject_id'].nunique()} subjects")
    return df


def load_sleep_diary() -> pd.DataFrame:
    """Load daily sleep diary logs."""
    path = os.path.join(DATA_DIR, "sleep_diary.csv")
    if not os.path.exists(path):
        raise FileNotFoundError(f"Sleep diary not found at {path}")

    df = pd.read_csv(path)

    # Rename to standardized column names
    df = df.rename(columns={
        "userId": "subject_id",
        "go2bed": "sleep_bedtime",
        "wakeup": "sleep_wake_time",
        "sleep_efficiency": "sleep_quality_score",
    })

    df["date"] = pd.to_datetime(df["date"])

    print(f"Loaded sleep diary: {len(df)} rows, {df['subject_id'].nunique()} subjects")
    return df


def load_clinical_metadata() -> pd.DataFrame:
    """Load baseline clinical assessments (survey.csv).

    Contains PHQ9_1 (baseline), PHQ9_2 (midpoint), PHQ9_F (final),
    plus GAD7, ISI, demographics.
    """
    path = os.path.join(DATA_DIR, "survey.csv")
    if not os.path.exists(path):
        raise FileNotFoundError(f"Survey file not found at {path}")

    df = pd.read_csv(path)

    # Rename to standardized column names
    df = df.rename(columns={
        "deviceId": "subject_id",
        "sex": "gender",
    })

    # Compute BMI
    if "height" in df.columns and "weight" in df.columns:
        df["BMI"] = df["weight"] / ((df["height"] / 100) ** 2)

    # Use PHQ9_1 as baseline PHQ-9
    df["PHQ9"] = df["PHQ9_1"]

    # Compute PHQ-9 change (final - baseline) where available
    if "PHQ9_F" in df.columns:
        df["PHQ9_change"] = df["PHQ9_F"] - df["PHQ9_1"]

    print(f"Loaded clinical metadata: {len(df)} subjects")
    print(f"  PHQ-9 baseline range: {df['PHQ9'].min()}-{df['PHQ9'].max()}, mean={df['PHQ9'].mean():.1f}")
    return df


def compute_daily_hrv(hrv_df: pd.DataFrame) -> pd.DataFrame:
    """Aggregate per-segment HRV to daily summaries."""
    hrv_df = hrv_df.copy()
    hrv_df["date"] = hrv_df["timestamp"].dt.date

    agg_cols = {}
    for col in ["RMSSD", "SDNN", "pNN50", "heart_rate", "LF", "HF", "LF_HF_ratio"]:
        if col in hrv_df.columns:
            agg_cols[col] = ["mean", "std"]

    daily = hrv_df.groupby(["subject_id", "date"]).agg(agg_cols)
    daily.columns = ["_".join(c) for c in daily.columns]
    daily = daily.reset_index()
    daily["date"] = pd.to_datetime(daily["date"])

    print(f"Computed daily HRV: {len(daily)} rows, {daily['subject_id'].nunique()} subjects")
    return daily


def build_merged_dataset(
    daily_hrv: pd.DataFrame,
    sleep_diary: pd.DataFrame,
    clinical: pd.DataFrame,
) -> pd.DataFrame:
    """Merge daily HRV + sleep diary + clinical metadata into one dataset."""
    merged = daily_hrv.merge(sleep_diary, on=["subject_id", "date"], how="outer")
    merged = merged.merge(clinical[["subject_id", "PHQ9", "PHQ9_1", "PHQ9_F",
                                     "PHQ9_change", "GAD7_1", "age", "gender", "BMI"]],
                          on="subject_id", how="left")
    merged = merged.sort_values(["subject_id", "date"]).reset_index(drop=True)

    print(f"Merged dataset: {len(merged)} rows, {merged['subject_id'].nunique()} subjects")
    print(f"Date range: {merged['date'].min()} to {merged['date'].max()}")
    return merged


# Keep backward-compatible names
def load_daily_logs():
    return load_sleep_diary()


if __name__ == "__main__":
    print("=== Loading Baigutanova Dataset ===\n")

    try:
        hrv = load_hrv_metrics()
        daily_hrv = compute_daily_hrv(hrv)
        sleep = load_sleep_diary()
        clinical = load_clinical_metadata()
        merged = build_merged_dataset(daily_hrv, sleep, clinical)

        print(f"\nFinal dataset shape: {merged.shape}")
        print(f"Columns: {list(merged.columns)}")
        print(f"\nPHQ-9 distribution:")
        print(clinical["PHQ9"].describe())
        print(f"\nPHQ-9 >= 5 (mild+): {(clinical['PHQ9'] >= 5).sum()} / {len(clinical)}")
        print(f"PHQ-9 >= 10 (moderate+): {(clinical['PHQ9'] >= 10).sum()} / {len(clinical)}")
    except FileNotFoundError as e:
        print(f"ERROR: {e}")
