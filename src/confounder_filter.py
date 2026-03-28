"""
AutoBiomarker — Confounder-Adjusted Analysis

Adds confounder adjustment to the biomarker pipeline. The Baigutanova dataset
includes lifestyle confounders (coffee, smoking, drinking, exercise) in survey.csv
that may inflate or explain apparent biomarker–depression associations.

Approach: residualize both features and labels against confounders using OLS,
then recompute effect sizes on residuals to identify truly independent signals.
"""

import os
import sys

import numpy as np
import pandas as pd
from scipy import stats
from sklearn.linear_model import LinearRegression, LogisticRegression
from sklearn.metrics import roc_auc_score
from sklearn.preprocessing import StandardScaler

sys.path.insert(0, os.path.dirname(__file__))
from config import DATA_DIR


CONFOUNDER_COLUMNS = ["coffee", "smoking", "drinking", "exercise"]


def load_confounders() -> pd.DataFrame:
    """Load confounder variables from survey.csv.

    Returns DataFrame with subject_id and confounder columns:
    coffee (1-5), smoking (1-5), drinking (1-4), exercise (1-5).
    """
    survey_path = os.path.join(DATA_DIR, "survey.csv")
    df = pd.read_csv(survey_path)
    df = df.rename(columns={"deviceId": "subject_id"})

    cols = ["subject_id"] + CONFOUNDER_COLUMNS
    missing = [c for c in cols if c not in df.columns]
    if missing:
        raise ValueError(f"Missing columns in survey.csv: {missing}")

    result = df[cols].copy()
    # Drop rows with any missing confounder
    result = result.dropna(subset=CONFOUNDER_COLUMNS).reset_index(drop=True)
    return result


def partial_correlation(
    feature_values: np.ndarray,
    labels: np.ndarray,
    confounders: np.ndarray,
) -> float:
    """Compute partial correlation between feature and label, controlling for confounders.

    Residualizes both the feature and label against the confounder matrix using
    OLS regression, then computes Pearson correlation on the residuals.

    Parameters
    ----------
    feature_values : array of shape (n,)
    labels : array of shape (n,) — numeric (0/1 or continuous)
    confounders : array of shape (n, k) — confounder matrix

    Returns
    -------
    Partial correlation coefficient (float).
    """
    # Ensure 2D confounders
    if confounders.ndim == 1:
        confounders = confounders.reshape(-1, 1)

    # Remove rows with NaN in any input
    valid = (
        ~np.isnan(feature_values)
        & ~np.isnan(labels)
        & ~np.isnan(confounders).any(axis=1)
    )
    feature_values = feature_values[valid]
    labels = labels[valid]
    confounders = confounders[valid]

    if len(feature_values) < 5:
        return 0.0

    # Residualize feature against confounders
    reg_feat = LinearRegression().fit(confounders, feature_values)
    resid_feat = feature_values - reg_feat.predict(confounders)

    # Residualize label against confounders
    reg_label = LinearRegression().fit(confounders, labels)
    resid_label = labels - reg_label.predict(confounders)

    # Pearson correlation on residuals
    r, _ = stats.pearsonr(resid_feat, resid_label)
    return r


def confounder_adjusted_test(
    feature_values: np.ndarray,
    labels: np.ndarray,
    confounders: np.ndarray,
    n_permutations: int = 500,
) -> dict:
    """Test a feature's association with depression after confounder adjustment.

    Computes both raw and confounder-adjusted effect sizes (Cohen's d),
    AUC, and a permutation p-value on the adjusted residuals.

    Parameters
    ----------
    feature_values : array of shape (n,)
    labels : array of shape (n,) — binary 0/1
    confounders : array of shape (n, k)
    n_permutations : number of permutations for p-value

    Returns
    -------
    dict with keys: auc_raw, auc_adjusted, cohens_d_raw, cohens_d_adjusted,
                    p_value, confounder_impact
    """
    if confounders.ndim == 1:
        confounders = confounders.reshape(-1, 1)

    # Remove rows with NaN
    valid = (
        ~np.isnan(feature_values)
        & ~np.isnan(labels)
        & ~np.isnan(confounders).any(axis=1)
    )
    feature_values = feature_values[valid]
    labels = labels[valid]
    confounders = confounders[valid]

    labels_binary = labels.astype(int)

    if len(labels) < 10 or labels_binary.sum() < 3 or (len(labels) - labels_binary.sum()) < 3:
        return {
            "auc_raw": 0.5,
            "auc_adjusted": 0.5,
            "cohens_d_raw": 0.0,
            "cohens_d_adjusted": 0.0,
            "p_value": 1.0,
            "confounder_impact": 0.0,
        }

    # --- Raw effect size ---
    pos = feature_values[labels_binary == 1]
    neg = feature_values[labels_binary == 0]
    d_raw = _cohens_d(pos, neg)

    # Raw AUC via simple logistic regression on the feature alone
    auc_raw = _simple_auc(feature_values.reshape(-1, 1), labels_binary)

    # --- Residualize against confounders ---
    reg_feat = LinearRegression().fit(confounders, feature_values)
    resid_feat = feature_values - reg_feat.predict(confounders)

    # Adjusted effect size on residuals
    pos_adj = resid_feat[labels_binary == 1]
    neg_adj = resid_feat[labels_binary == 0]
    d_adjusted = _cohens_d(pos_adj, neg_adj)

    # Adjusted AUC: logistic regression on residualized feature
    auc_adjusted = _simple_auc(resid_feat.reshape(-1, 1), labels_binary)

    # --- Permutation test on adjusted residuals ---
    observed_diff = abs(np.mean(resid_feat[labels_binary == 1]) - np.mean(resid_feat[labels_binary == 0]))
    count = 0
    for _ in range(n_permutations):
        perm_labels = np.random.permutation(labels_binary)
        perm_diff = abs(np.mean(resid_feat[perm_labels == 1]) - np.mean(resid_feat[perm_labels == 0]))
        if perm_diff >= observed_diff:
            count += 1
    p_value = (count + 1) / (n_permutations + 1)

    # Confounder impact: fractional drop in effect size
    if abs(d_raw) > 1e-8:
        confounder_impact = (abs(d_raw) - abs(d_adjusted)) / abs(d_raw)
    else:
        confounder_impact = 0.0

    return {
        "auc_raw": round(auc_raw, 4),
        "auc_adjusted": round(auc_adjusted, 4),
        "cohens_d_raw": round(abs(d_raw), 4),
        "cohens_d_adjusted": round(abs(d_adjusted), 4),
        "p_value": round(p_value, 6),
        "confounder_impact": round(confounder_impact, 4),
    }


def flag_confounded_features(
    results_df: pd.DataFrame,
    threshold: float = 0.3,
) -> pd.DataFrame:
    """Flag features where effect size drops substantially after confounder adjustment.

    Adds three columns to the DataFrame:
    - confounder_adjusted_d: Cohen's d after adjustment
    - confounder_impact: fractional drop in effect size (0 = no change, 1 = fully explained)
    - confounder_flag: True if confounder_impact > threshold

    Parameters
    ----------
    results_df : DataFrame with at least 'cohens_d_adjusted' and 'cohens_d' or
                 'confounder_adjusted_d' and 'confounder_impact' columns already present,
                 OR columns 'cohens_d_raw', 'cohens_d_adjusted', 'confounder_impact'
                 from confounder_adjusted_test results.
    threshold : fractional drop above which a feature is flagged (default 0.3 = 30%).

    Returns
    -------
    DataFrame with added columns.
    """
    df = results_df.copy()

    # Support input from confounder_adjusted_test batch results
    if "cohens_d_adjusted" in df.columns and "confounder_impact" in df.columns:
        df["confounder_adjusted_d"] = df["cohens_d_adjusted"]
        # confounder_impact already present
    elif "cohens_d" in df.columns and "confounder_adjusted_d" in df.columns:
        # Compute impact from raw and adjusted
        raw = df["cohens_d"].abs()
        adj = df["confounder_adjusted_d"].abs()
        df["confounder_impact"] = np.where(raw > 1e-8, (raw - adj) / raw, 0.0)
    else:
        raise ValueError(
            "results_df must contain either ('cohens_d_adjusted', 'confounder_impact') "
            "or ('cohens_d', 'confounder_adjusted_d') columns."
        )

    df["confounder_flag"] = df["confounder_impact"] > threshold
    return df


def generate_confounder_report(results_df: pd.DataFrame) -> str:
    """Generate a summary of how many features survive confounder adjustment.

    Parameters
    ----------
    results_df : DataFrame that has been processed by flag_confounded_features
                 (must contain 'confounder_flag', 'confounder_impact',
                  'confounder_adjusted_d' columns).

    Returns
    -------
    Human-readable summary string.
    """
    required = {"confounder_flag", "confounder_impact", "confounder_adjusted_d"}
    missing = required - set(results_df.columns)
    if missing:
        raise ValueError(f"Missing columns (run flag_confounded_features first): {missing}")

    total = len(results_df)
    flagged = results_df["confounder_flag"].sum()
    survived = total - flagged

    mean_impact = results_df["confounder_impact"].mean()
    median_impact = results_df["confounder_impact"].median()

    # Features with largest confounder impact
    worst = results_df.nlargest(5, "confounder_impact")

    lines = [
        "=" * 60,
        "CONFOUNDER ADJUSTMENT REPORT",
        "=" * 60,
        f"Total features analyzed:          {total}",
        f"Features surviving adjustment:    {survived} ({100 * survived / total:.1f}%)" if total > 0 else "Features surviving adjustment:    0",
        f"Features flagged (confounded):    {flagged} ({100 * flagged / total:.1f}%)" if total > 0 else "Features flagged (confounded):    0",
        f"Mean confounder impact:           {mean_impact:.3f}",
        f"Median confounder impact:         {median_impact:.3f}",
        "",
        "Confounders controlled: coffee, smoking, drinking, exercise",
        "",
        "Top 5 most confounded features:",
    ]

    for _, row in worst.iterrows():
        feature = row.get("feature", "unknown")
        impact = row["confounder_impact"]
        d_adj = row["confounder_adjusted_d"]
        lines.append(f"  {feature}: impact={impact:.3f}, adjusted_d={d_adj:.4f}")

    lines.append("=" * 60)
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

def _cohens_d(group1: np.ndarray, group2: np.ndarray) -> float:
    """Compute Cohen's d between two groups."""
    n1, n2 = len(group1), len(group2)
    if n1 < 2 or n2 < 2:
        return 0.0
    var1 = group1.var(ddof=1)
    var2 = group2.var(ddof=1)
    pooled_std = np.sqrt(((n1 - 1) * var1 + (n2 - 1) * var2) / (n1 + n2 - 2))
    if pooled_std == 0:
        return 0.0
    return (group1.mean() - group2.mean()) / pooled_std


def _simple_auc(X: np.ndarray, y: np.ndarray) -> float:
    """Compute AUC using a simple logistic regression."""
    try:
        scaler = StandardScaler()
        X_scaled = scaler.fit_transform(X)
        model = LogisticRegression(max_iter=1000, random_state=42)
        model.fit(X_scaled, y)
        probs = model.predict_proba(X_scaled)[:, 1]
        return roc_auc_score(y, probs)
    except Exception:
        return 0.5
