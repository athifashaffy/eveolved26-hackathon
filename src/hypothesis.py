"""
AutoBiomarker — Hypothesis Generator and Evaluator

The core autoresearch loop adapted for biomarker discovery:
  propose hypothesis → extract feature → test statistically → keep/discard → repeat
"""

import json
import os
import time
from dataclasses import dataclass, asdict
from typing import Optional

import numpy as np
import pandas as pd
from scipy import stats
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import roc_auc_score
from sklearn.preprocessing import StandardScaler
from statsmodels.stats.multitest import multipletests

from config import (
    NEBIUS_API_KEY,
    NEBIUS_BASE_URL,
    NEBIUS_MODEL,
    NEBIUS_BUDGET_LIMIT,
    NEBIUS_COST_PER_1K_TOKENS,
    NEBIUS_MAX_LLM_CALLS,
    SIGNIFICANCE_THRESHOLD,
    EFFECT_SIZE_THRESHOLD,
    FDR_METHOD,
    RESULTS_TSV,
    RESULTS_DIR,
)


@dataclass
class BiomarkerHypothesis:
    """A single biomarker hypothesis to test."""
    id: int
    feature: str              # e.g., "rmssd_7d_autocorr"
    threshold: Optional[float]  # e.g., 0.5 (if threshold-based)
    direction: str            # "above" or "below" threshold
    outcome: str              # e.g., "phq9_increase_ge_5"
    temporal_lag: int          # days ahead to predict
    description: str          # human-readable description
    combination: Optional[str] = None  # second feature for interaction


@dataclass
class HypothesisResult:
    """Result of testing a hypothesis."""
    hypothesis_id: int
    feature: str
    auc: float
    p_value: float
    p_adjusted: float
    cohens_d: float
    n_positive: int
    n_negative: int
    ci_lower: float
    ci_upper: float
    status: str              # "KEEP" or "DISCARD"
    description: str


class HypothesisGenerator:
    """Generate biomarker hypotheses — either predefined or LLM-generated."""

    def __init__(self, use_llm: bool = False):
        self.use_llm = use_llm and NEBIUS_API_KEY
        self.tested_features = set()
        self.llm_calls = 0
        self.estimated_cost = 0.0

        if self.use_llm:
            from openai import OpenAI
            self.client = OpenAI(
                base_url=NEBIUS_BASE_URL,
                api_key=NEBIUS_API_KEY,
            )

    def get_predefined_hypotheses(self, feature_names: list[str]) -> list[BiomarkerHypothesis]:
        """Generate predefined hypotheses from available features."""
        hypotheses = []
        h_id = 0

        outcomes = [
            ("phq9_mild", "PHQ-9 ≥ 5 (mild+ depression)"),
            ("phq9_increase", "PHQ-9 increased from baseline"),
        ]

        # ---- Phase 1: Single features (all features × all outcomes) ----
        for feature in feature_names:
            for outcome_key, outcome_desc in outcomes:
                h_id += 1
                hypotheses.append(BiomarkerHypothesis(
                    id=h_id,
                    feature=feature,
                    threshold=None,
                    direction="above",
                    outcome=outcome_key,
                    temporal_lag=7,
                    description=f"Does {feature} predict {outcome_desc}?",
                ))

        # ---- Phase 2: Cross-domain interaction pairs ----
        # Group features by domain
        hrv_feats = [f for f in feature_names if f.startswith(("rmssd_", "hr_", "lfhf_"))]
        sleep_feats = [f for f in feature_names if f.startswith(("sleep_", "digital_"))]
        # Key cross-domain: HRV × Sleep interactions (the three-way gap)
        import itertools
        cross_pairs = list(itertools.product(hrv_feats, sleep_feats))
        # Also within-domain interesting pairs (different stat types)
        autocorr_feats = [f for f in feature_names if "autocorr" in f]
        cv_feats = [f for f in feature_names if "_cv" in f]
        std_feats = [f for f in feature_names if "_std" in f]
        slope_feats = [f for f in feature_names if "_slope" in f]
        # Critical slowing down pairs: autocorr × variance (the two key indicators)
        csd_pairs = list(itertools.product(autocorr_feats, std_feats))

        all_interaction_pairs = cross_pairs + csd_pairs
        # Deduplicate and limit
        seen = set()
        for feat1, feat2 in all_interaction_pairs:
            if feat1 == feat2:
                continue
            pair_key = tuple(sorted([feat1, feat2]))
            if pair_key in seen:
                continue
            seen.add(pair_key)
            for outcome_key, outcome_desc in outcomes:
                h_id += 1
                # Categorize the interaction
                if feat1.startswith(("rmssd_", "hr_", "lfhf_")) and feat2.startswith("sleep_"):
                    desc = f"HRV×Sleep: {feat1} + {feat2}"
                elif "autocorr" in feat1 and "_std" in feat2:
                    desc = f"CriticalSlowingDown: sluggishness({feat1}) + wobbling({feat2})"
                else:
                    desc = f"Interaction: {feat1} + {feat2}"
                hypotheses.append(BiomarkerHypothesis(
                    id=h_id,
                    feature=feat1,
                    threshold=None,
                    direction="above",
                    outcome=outcome_key,
                    temporal_lag=7,
                    description=f"{desc} predicts {outcome_desc}",
                    combination=feat2,
                ))

        n_single = len(feature_names) * len(outcomes)
        n_interact = len(hypotheses) - n_single
        print(f"Generated {len(hypotheses)} predefined hypotheses "
              f"({n_single} single + {n_interact} interactions)")
        return hypotheses

    def generate_llm_hypothesis(
        self,
        prior_results: list[HypothesisResult],
        feature_names: list[str],
    ) -> Optional[BiomarkerHypothesis]:
        """Use Nebius Llama 70B to propose a novel hypothesis based on prior results."""
        if not self.use_llm:
            return None

        # Budget safeguard
        if self.llm_calls >= NEBIUS_MAX_LLM_CALLS:
            print(f"  LLM call limit reached ({NEBIUS_MAX_LLM_CALLS} calls, ~${self.estimated_cost:.2f})")
            return None
        if self.estimated_cost >= NEBIUS_BUDGET_LIMIT * 0.8:
            print(f"  Approaching budget limit (~${self.estimated_cost:.2f} / ${NEBIUS_BUDGET_LIMIT})")
            return None

        # Build context from prior results
        top_results = sorted(
            [r for r in prior_results if r.status == "KEEP"],
            key=lambda r: r.cohens_d,
            reverse=True,
        )[:10]

        results_context = "\n".join(
            f"  - {r.feature}: AUC={r.auc:.3f}, d={r.cohens_d:.3f} ({r.status})"
            for r in top_results
        ) if top_results else "  No significant findings yet."

        available_features = [f for f in feature_names if f not in self.tested_features]

        prompt = f"""You are a computational psychiatry researcher. Based on prior biomarker testing results, propose the NEXT hypothesis to test.

PRIOR RESULTS (top findings):
{results_context}

AVAILABLE UNTESTED FEATURES:
{', '.join(available_features[:50])}

CONTEXT: We have 28 days of daily HRV, sleep, and mood data from 49 participants with PHQ-9 depression scores.

Propose ONE novel biomarker hypothesis. Respond in JSON:
{{
  "feature": "feature_name_from_list",
  "description": "Why this feature might predict depression severity",
  "reasoning": "Based on prior results, this is worth testing because..."
}}"""

        try:
            response = self.client.chat.completions.create(
                model=NEBIUS_MODEL,
                messages=[{"role": "user", "content": prompt}],
                response_format={"type": "json_object"},
                temperature=0.8,
                max_tokens=300,
            )
            result = json.loads(response.choices[0].message.content)

            # Track cost
            self.llm_calls += 1
            tokens_used = getattr(response.usage, 'total_tokens', 500) if response.usage else 500
            self.estimated_cost += (tokens_used / 1000) * NEBIUS_COST_PER_1K_TOKENS

            feature = result.get("feature", "")
            if feature in feature_names:
                self.tested_features.add(feature)
                return BiomarkerHypothesis(
                    id=len(self.tested_features) + 1000,
                    feature=feature,
                    threshold=None,
                    direction="above",
                    outcome="phq9_high",
                    temporal_lag=7,
                    description=result.get("description", "LLM-generated hypothesis"),
                )
        except Exception as e:
            print(f"LLM hypothesis generation failed: {e}")

        return None


class HypothesisEvaluator:
    """Test biomarker hypotheses using leave-one-subject-out cross-validation."""

    def evaluate(
        self,
        hypothesis: BiomarkerHypothesis,
        features_df: pd.DataFrame,
        outcome_series: pd.Series,
        subject_ids: pd.Series,
    ) -> HypothesisResult:
        """Test a single hypothesis.

        Uses leave-one-subject-out CV to compute AUC,
        plus Cohen's d for effect size and bootstrap CI.
        """
        feature_col = hypothesis.feature

        if feature_col not in features_df.columns:
            return self._null_result(hypothesis, "Feature not found")

        X = features_df[[feature_col]].copy()
        if hypothesis.combination and hypothesis.combination in features_df.columns:
            X[hypothesis.combination] = features_df[hypothesis.combination]

        y = outcome_series.values
        subjects = subject_ids.values

        # Drop NaN rows
        valid = X.notna().all(axis=1) & ~np.isnan(y)
        X = X[valid]
        y = y[valid]
        subjects = subjects[valid]

        if len(y) < 10 or y.sum() < 3 or (len(y) - y.sum()) < 3:
            return self._null_result(hypothesis, "Insufficient data")

        # Leave-one-subject-out cross-validation
        unique_subjects = np.unique(subjects)
        y_true_all, y_pred_all = [], []

        for held_out in unique_subjects:
            train_mask = subjects != held_out
            test_mask = subjects == held_out

            if y[train_mask].sum() == 0 or y[train_mask].sum() == train_mask.sum():
                continue

            scaler = StandardScaler()
            X_train = scaler.fit_transform(X[train_mask])
            X_test = scaler.transform(X[test_mask])

            model = LogisticRegression(max_iter=1000, random_state=42)
            try:
                model.fit(X_train, y[train_mask])
                preds = model.predict_proba(X_test)[:, 1]
                y_true_all.extend(y[test_mask])
                y_pred_all.extend(preds)
            except Exception:
                continue

        if len(y_true_all) < 10:
            return self._null_result(hypothesis, "CV failed")

        y_true_all = np.array(y_true_all)
        y_pred_all = np.array(y_pred_all)

        # AUC
        try:
            auc = roc_auc_score(y_true_all, y_pred_all)
        except ValueError:
            return self._null_result(hypothesis, "AUC computation failed")

        # Cohen's d (effect size)
        feature_vals = X[feature_col].values
        group_pos = feature_vals[y.astype(bool)]
        group_neg = feature_vals[~y.astype(bool)]
        cohens_d = self._cohens_d(group_pos, group_neg)

        # Permutation test for p-value
        p_value = self._permutation_test(feature_vals, y, n_permutations=1000)

        # Bootstrap 95% CI for AUC
        ci_lower, ci_upper = self._bootstrap_ci(y_true_all, y_pred_all)

        status = "PENDING"  # Will be set after FDR correction

        return HypothesisResult(
            hypothesis_id=hypothesis.id,
            feature=feature_col + (f" × {hypothesis.combination}" if hypothesis.combination else ""),
            auc=round(auc, 4),
            p_value=round(p_value, 6),
            p_adjusted=0.0,  # Set after FDR correction
            cohens_d=round(abs(cohens_d), 4),
            n_positive=int(y.sum()),
            n_negative=int(len(y) - y.sum()),
            ci_lower=round(ci_lower, 4),
            ci_upper=round(ci_upper, 4),
            status=status,
            description=hypothesis.description,
        )

    @staticmethod
    def apply_fdr_correction(results: list[HypothesisResult]) -> list[HypothesisResult]:
        """Apply Benjamini-Hochberg FDR correction across all tested hypotheses."""
        if not results:
            return results

        p_values = [r.p_value for r in results]
        _, p_adjusted, _, _ = multipletests(p_values, method=FDR_METHOD)

        for r, p_adj in zip(results, p_adjusted):
            r.p_adjusted = round(p_adj, 6)
            if p_adj < SIGNIFICANCE_THRESHOLD and r.cohens_d > EFFECT_SIZE_THRESHOLD:
                r.status = "KEEP"
            else:
                r.status = "DISCARD"

        kept = sum(1 for r in results if r.status == "KEEP")
        print(f"FDR correction: {kept}/{len(results)} hypotheses significant")
        return results

    @staticmethod
    def _cohens_d(group1: np.ndarray, group2: np.ndarray) -> float:
        n1, n2 = len(group1), len(group2)
        if n1 < 2 or n2 < 2:
            return 0.0
        var1, var2 = group1.var(ddof=1), group2.var(ddof=1)
        pooled_std = np.sqrt(((n1 - 1) * var1 + (n2 - 1) * var2) / (n1 + n2 - 2))
        if pooled_std == 0:
            return 0.0
        return (group1.mean() - group2.mean()) / pooled_std

    @staticmethod
    def _permutation_test(feature: np.ndarray, labels: np.ndarray, n_permutations: int = 1000) -> float:
        valid = ~np.isnan(feature)
        feature = feature[valid]
        labels = labels[valid]

        observed = abs(np.mean(feature[labels == 1]) - np.mean(feature[labels == 0]))
        count = 0
        for _ in range(n_permutations):
            perm_labels = np.random.permutation(labels)
            perm_diff = abs(np.mean(feature[perm_labels == 1]) - np.mean(feature[perm_labels == 0]))
            if perm_diff >= observed:
                count += 1
        return (count + 1) / (n_permutations + 1)

    @staticmethod
    def _bootstrap_ci(y_true: np.ndarray, y_pred: np.ndarray, n_boot: int = 1000, alpha: float = 0.05) -> tuple:
        aucs = []
        for _ in range(n_boot):
            idx = np.random.randint(0, len(y_true), len(y_true))
            if len(np.unique(y_true[idx])) < 2:
                continue
            try:
                aucs.append(roc_auc_score(y_true[idx], y_pred[idx]))
            except ValueError:
                continue
        if not aucs:
            return 0.5, 0.5
        return np.percentile(aucs, 100 * alpha / 2), np.percentile(aucs, 100 * (1 - alpha / 2))

    @staticmethod
    def _null_result(hypothesis: BiomarkerHypothesis, reason: str) -> HypothesisResult:
        return HypothesisResult(
            hypothesis_id=hypothesis.id,
            feature=hypothesis.feature,
            auc=0.5,
            p_value=1.0,
            p_adjusted=1.0,
            cohens_d=0.0,
            n_positive=0,
            n_negative=0,
            ci_lower=0.5,
            ci_upper=0.5,
            status="DISCARD",
            description=f"{hypothesis.description} [{reason}]",
        )


def save_results(results: list[HypothesisResult]):
    """Save results to TSV (like autoresearch's results.tsv)."""
    os.makedirs(RESULTS_DIR, exist_ok=True)

    rows = []
    for r in results:
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

    df = pd.DataFrame(rows)
    df.to_csv(RESULTS_TSV, sep="\t", index=False)
    print(f"Results saved to {RESULTS_TSV}")

    # Print top findings
    kept = df[df["status"] == "KEEP"].sort_values("cohens_d", ascending=False)
    if len(kept) > 0:
        print(f"\n{'='*60}")
        print(f"TOP FINDINGS ({len(kept)} significant after FDR correction)")
        print(f"{'='*60}")
        for _, row in kept.head(10).iterrows():
            print(f"  {row['feature']}: AUC={row['auc']}, d={row['cohens_d']}, p_adj={row['p_adjusted']}")
            print(f"    {row['description']}")
    else:
        print("\nNo significant findings after FDR correction.")
