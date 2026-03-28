"""
AutoBiomarker — Temporal Feature Extraction

Extracts features that capture TEMPORAL DYNAMICS, not just levels.
These are the features nobody has tested against depression.
"""

import numpy as np
import pandas as pd
from typing import Optional
from config import ROLLING_WINDOWS


def compute_rolling_stats(
    series: pd.Series,
    windows: list[int] = ROLLING_WINDOWS,
    prefix: str = "",
) -> pd.DataFrame:
    """Compute rolling mean, std, slope, autocorrelation, and CV for a time series."""
    result = pd.DataFrame(index=series.index)

    for w in windows:
        col = f"{prefix}_{w}d" if prefix else f"{w}d"

        # Rolling mean
        result[f"{col}_mean"] = series.rolling(w, min_periods=w).mean()

        # Rolling std (variance proxy)
        result[f"{col}_std"] = series.rolling(w, min_periods=w).std()

        # Rolling coefficient of variation (CV) — KEY NOVEL FEATURE
        # HRV-CV has been shown as behavioral biomarker but NEVER tested for depression
        rolling_mean = series.rolling(w, min_periods=w).mean()
        rolling_std = series.rolling(w, min_periods=w).std()
        result[f"{col}_cv"] = rolling_std / rolling_mean.replace(0, np.nan)

        # Rolling slope (trend direction)
        result[f"{col}_slope"] = series.rolling(w, min_periods=w).apply(
            _compute_slope, raw=True
        )

        # Rolling autocorrelation (lag-1) — KEY: CRITICAL SLOWING DOWN INDICATOR
        # Rising autocorrelation = system becoming "sluggish" = approaching tipping point
        result[f"{col}_autocorr"] = series.rolling(w, min_periods=w).apply(
            _compute_autocorr, raw=True
        )

    return result


def _compute_slope(x: np.ndarray) -> float:
    """Linear regression slope over a window."""
    if len(x) < 2 or np.all(np.isnan(x)):
        return np.nan
    t = np.arange(len(x))
    valid = ~np.isnan(x)
    if valid.sum() < 2:
        return np.nan
    coeffs = np.polyfit(t[valid], x[valid], 1)
    return coeffs[0]


def _compute_autocorr(x: np.ndarray) -> float:
    """Lag-1 autocorrelation of a window."""
    if len(x) < 3:
        return np.nan
    x_clean = x[~np.isnan(x)]
    if len(x_clean) < 3:
        return np.nan
    return np.corrcoef(x_clean[:-1], x_clean[1:])[0, 1]


def compute_early_warning_signals(daily_df: pd.DataFrame, subject_col: str = "subject_id") -> pd.DataFrame:
    """Compute critical slowing down indicators for each subject.

    Key metrics:
    1. Rising autocorrelation in HRV (sluggishness)
    2. Rising variance in HRV (wobbling)
    3. HRV-CV (day-to-day variability — novel)
    4. Sleep regularity (SD of sleep onset times)
    5. Mood volatility (rolling SD of mood)
    """
    all_features = []

    for subject_id, subj_df in daily_df.groupby(subject_col):
        subj_df = subj_df.sort_values("date").copy()
        features = pd.DataFrame(index=subj_df.index)
        features["subject_id"] = subject_id
        features["date"] = subj_df["date"].values

        # HRV temporal features (if RMSSD available)
        if "RMSSD_mean" in subj_df.columns:
            hrv_features = compute_rolling_stats(
                subj_df["RMSSD_mean"], prefix="rmssd"
            )
            features = pd.concat([features, hrv_features], axis=1)

        # Heart rate temporal features
        if "heart_rate_mean" in subj_df.columns:
            hr_features = compute_rolling_stats(
                subj_df["heart_rate_mean"], prefix="hr"
            )
            features = pd.concat([features, hr_features], axis=1)

        # LF/HF ratio temporal features (sympathovagal balance)
        if "LF_HF_ratio_mean" in subj_df.columns:
            lfhf_features = compute_rolling_stats(
                subj_df["LF_HF_ratio_mean"], prefix="lfhf"
            )
            features = pd.concat([features, lfhf_features], axis=1)

        # Mood temporal features
        if "mood_score" in subj_df.columns:
            mood_features = compute_rolling_stats(
                subj_df["mood_score"], prefix="mood"
            )
            features = pd.concat([features, mood_features], axis=1)

        # Sleep regularity (SD of sleep onset — novel interaction feature)
        if "sleep_bedtime" in subj_df.columns:
            try:
                bedtimes = pd.to_datetime(subj_df["sleep_bedtime"], format="%H:%M:%S", errors="coerce")
                # Convert to minutes-since-midnight for variability calc
                minutes = bedtimes.dt.hour * 60 + bedtimes.dt.minute
                # Handle after-midnight bedtimes (e.g., 01:00 → 25*60=1500 min conceptually)
                minutes = minutes.where(minutes > 360, minutes + 1440)  # before 6am = next day
                for w in ROLLING_WINDOWS:
                    features[f"sleep_onset_sd_{w}d"] = minutes.rolling(w, min_periods=w).std()
            except Exception:
                pass

        # Sleep quality (efficiency) temporal features
        if "sleep_quality_score" in subj_df.columns:
            sleep_features = compute_rolling_stats(
                subj_df["sleep_quality_score"], prefix="sleep_qual"
            )
            features = pd.concat([features, sleep_features], axis=1)

        # Sleep duration temporal features
        if "sleep_duration" in subj_df.columns:
            dur_features = compute_rolling_stats(
                subj_df["sleep_duration"], prefix="sleep_dur"
            )
            features = pd.concat([features, dur_features], axis=1)

        # Sleep latency temporal features
        if "sleep_latency" in subj_df.columns:
            lat_features = compute_rolling_stats(
                subj_df["sleep_latency"], prefix="sleep_lat"
            )
            features = pd.concat([features, lat_features], axis=1)

        # Digital allostatic load composite (novel)
        # Z-scored: low HRV + poor sleep + high resting HR
        if all(c in subj_df.columns for c in ["RMSSD_mean", "heart_rate_mean", "sleep_quality_score"]):
            rmssd_z = (subj_df["RMSSD_mean"] - subj_df["RMSSD_mean"].mean()) / subj_df["RMSSD_mean"].std()
            hr_z = (subj_df["heart_rate_mean"] - subj_df["heart_rate_mean"].mean()) / subj_df["heart_rate_mean"].std()
            sleep_z = (subj_df["sleep_quality_score"] - subj_df["sleep_quality_score"].mean()) / subj_df["sleep_quality_score"].std()
            # Higher = worse (invert HRV and sleep, keep HR)
            features["digital_allostatic_load"] = (-rmssd_z + hr_z - sleep_z) / 3

        all_features.append(features)

    result = pd.concat(all_features, ignore_index=True)
    feature_cols = [c for c in result.columns if c not in ["subject_id", "date"]]
    print(f"Extracted {len(feature_cols)} temporal features for {result['subject_id'].nunique()} subjects")
    return result


def get_feature_names(features_df: pd.DataFrame) -> list[str]:
    """Get all feature column names (excluding subject_id and date)."""
    return [c for c in features_df.columns if c not in ["subject_id", "date"]]
