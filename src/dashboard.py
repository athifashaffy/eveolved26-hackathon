"""
AutoBiomarker — Streamlit Dashboard

Visualize overnight autoresearch results.
Run: streamlit run dashboard.py
"""

import os
import sys
import numpy as np
import pandas as pd
import streamlit as st
import plotly.express as px
import plotly.graph_objects as go
from plotly.subplots import make_subplots

sys.path.insert(0, os.path.dirname(__file__))
from config import RESULTS_DIR, DATA_DIR, PHQ9_MILD_THRESHOLD

RESULTS_TSV = os.path.join(RESULTS_DIR, "results.tsv")

st.set_page_config(
    page_title="AutoBiomarker — Results",
    page_icon="🧬",
    layout="wide",
)


@st.cache_data
def load_results():
    if not os.path.exists(RESULTS_TSV):
        # Try intermediate
        intermediates = sorted(
            [f for f in os.listdir(RESULTS_DIR) if f.startswith("results_intermediate")],
            reverse=True,
        )
        if intermediates:
            return pd.read_csv(os.path.join(RESULTS_DIR, intermediates[0]), sep="\t")
        return None
    return pd.read_csv(RESULTS_TSV, sep="\t")


@st.cache_data
def load_raw_data():
    try:
        from data_loader import (
            load_hrv_metrics, compute_daily_hrv,
            load_sleep_diary, load_clinical_metadata, build_merged_dataset,
        )
        hrv = load_hrv_metrics()
        daily_hrv = compute_daily_hrv(hrv)
        sleep = load_sleep_diary()
        clinical = load_clinical_metadata()
        merged = build_merged_dataset(daily_hrv, sleep, clinical)
        return merged, clinical
    except Exception as e:
        st.warning(f"Could not load raw data: {e}")
        return None, None


def main():
    st.title("🧬 AutoBiomarker — Autonomous Discovery Results")
    st.markdown("*Critical slowing down indicators for depression from wearable data*")

    # Load results
    df = load_results()
    if df is None:
        st.error("No results found. Run `python run_overnight.py` first.")
        # Show log if available
        log_path = os.path.join(RESULTS_DIR, "overnight_log.txt")
        if os.path.exists(log_path):
            st.subheader("Overnight Log")
            with open(log_path) as f:
                st.code(f.read(), language="text")
        return

    # ---- Summary metrics ----
    col1, col2, col3, col4 = st.columns(4)
    n_total = len(df)
    n_keep = len(df[df["status"] == "KEEP"])
    best_auc = df[df["status"] == "KEEP"]["auc"].max() if n_keep > 0 else 0
    best_d = df[df["status"] == "KEEP"]["cohens_d"].max() if n_keep > 0 else 0

    col1.metric("Hypotheses Tested", f"{n_total:,}")
    col2.metric("Significant (FDR)", f"{n_keep:,}")
    col3.metric("Best AUC", f"{best_auc:.3f}")
    col4.metric("Best Cohen's d", f"{best_d:.3f}")

    st.divider()

    # ---- Tabs ----
    tab1, tab2, tab3, tab4, tab5, tab6 = st.tabs([
        "📊 Top Findings", "🔬 Volcano Plot", "📈 Feature Categories",
        "🧪 Patient Trajectories", "🔄 Cross-Dataset", "📋 Full Results"
    ])

    # ---- Tab 1: Top Findings ----
    with tab1:
        st.subheader("Top Biomarker Findings (Significant after FDR)")
        kept = df[df["status"] == "KEEP"].sort_values("cohens_d", ascending=False)

        if len(kept) == 0:
            st.warning("No significant findings yet.")
        else:
            # Top 20 table
            display_cols = ["feature", "auc", "cohens_d", "p_adjusted", "ci_lower", "ci_upper", "description"]
            st.dataframe(
                kept.head(20)[display_cols].style.format({
                    "auc": "{:.3f}",
                    "cohens_d": "{:.3f}",
                    "p_adjusted": "{:.4f}",
                    "ci_lower": "{:.3f}",
                    "ci_upper": "{:.3f}",
                }),
                use_container_width=True,
                height=500,
            )

            # Bar chart of top features
            top20 = kept.head(20).copy()
            top20["feature_short"] = top20["feature"].apply(lambda x: x[:40])
            fig = px.bar(
                top20,
                x="cohens_d",
                y="feature_short",
                orientation="h",
                color="auc",
                color_continuous_scale="viridis",
                title="Top 20 Biomarkers by Effect Size (Cohen's d)",
                labels={"cohens_d": "Cohen's d", "feature_short": "Feature", "auc": "AUC"},
            )
            fig.update_layout(height=600, yaxis=dict(autorange="reversed"))
            st.plotly_chart(fig, use_container_width=True)

    # ---- Tab 2: Volcano Plot ----
    with tab2:
        st.subheader("Volcano Plot — Effect Size vs Significance")
        plot_df = df.copy()
        plot_df["neg_log_p"] = -np.log10(plot_df["p_adjusted"].clip(lower=1e-10))
        plot_df["significant"] = plot_df["status"] == "KEEP"

        fig = px.scatter(
            plot_df,
            x="cohens_d",
            y="neg_log_p",
            color="significant",
            color_discrete_map={True: "#00d4aa", False: "#555555"},
            hover_data=["feature", "auc", "p_adjusted"],
            title="Volcano Plot: Effect Size vs Statistical Significance",
            labels={
                "cohens_d": "Cohen's d (effect size)",
                "neg_log_p": "-log₁₀(p_adjusted)",
                "significant": "Significant",
            },
        )
        fig.add_hline(y=-np.log10(0.01), line_dash="dash", line_color="red",
                      annotation_text="p=0.01 threshold")
        fig.add_vline(x=0.3, line_dash="dash", line_color="orange",
                      annotation_text="d=0.3 threshold")
        fig.update_layout(height=600)
        st.plotly_chart(fig, use_container_width=True)

    # ---- Tab 3: Feature Categories ----
    with tab3:
        st.subheader("Findings by Feature Category")
        kept = df[df["status"] == "KEEP"].copy()

        if len(kept) > 0:
            def categorize(feat):
                if "×" in feat:
                    return "Interaction"
                if feat.startswith("rmssd_"):
                    return "RMSSD (HRV)"
                if feat.startswith("hr_"):
                    return "Heart Rate"
                if feat.startswith("lfhf_"):
                    return "LF/HF Ratio"
                if feat.startswith("sleep_dur"):
                    return "Sleep Duration"
                if feat.startswith("sleep_qual"):
                    return "Sleep Quality"
                if feat.startswith("sleep_lat"):
                    return "Sleep Latency"
                if feat.startswith("sleep_onset"):
                    return "Sleep Onset Time"
                if feat.startswith("digital"):
                    return "Digital Allostatic Load"
                return "Other"

            kept["category"] = kept["feature"].apply(categorize)

            # Count by category
            cat_counts = kept.groupby("category").agg(
                count=("feature", "size"),
                best_auc=("auc", "max"),
                best_d=("cohens_d", "max"),
            ).sort_values("count", ascending=False)

            col1, col2 = st.columns(2)

            with col1:
                fig = px.pie(
                    cat_counts.reset_index(),
                    names="category",
                    values="count",
                    title="Significant Findings by Category",
                    color_discrete_sequence=px.colors.qualitative.Set2,
                )
                st.plotly_chart(fig, use_container_width=True)

            with col2:
                st.dataframe(cat_counts, use_container_width=True)

            # Feature type breakdown (stat type)
            def stat_type(feat):
                if "autocorr" in feat:
                    return "Autocorrelation (sluggishness)"
                if "_cv" in feat:
                    return "Coefficient of Variation"
                if "_std" in feat:
                    return "Standard Deviation (wobbling)"
                if "_slope" in feat:
                    return "Slope (trend)"
                if "_mean" in feat:
                    return "Mean (level)"
                if "×" in feat:
                    return "Interaction"
                return "Other"

            kept["stat_type"] = kept["feature"].apply(stat_type)
            stat_counts = kept.groupby("stat_type").size().reset_index(name="count")

            fig = px.bar(
                stat_counts.sort_values("count", ascending=False),
                x="stat_type",
                y="count",
                title="Significant Findings by Statistical Feature Type",
                color="count",
                color_continuous_scale="teal",
            )
            st.plotly_chart(fig, use_container_width=True)

            st.info(
                "**Key insight:** If variability features (CV, std, autocorr) dominate over "
                "level features (mean), this supports the **critical slowing down** hypothesis — "
                "it's not HOW LOW your HRV is, but HOW MUCH IT WOBBLES that predicts depression."
            )

    # ---- Tab 4: Patient Trajectories ----
    with tab4:
        st.subheader("Individual Patient Trajectories")
        merged, clinical = load_raw_data()

        if merged is not None and clinical is not None:
            subjects = sorted(merged["subject_id"].unique())
            phq9_map = clinical.set_index("subject_id")["PHQ9"].to_dict()

            # Color by depression status
            dep_subjects = [s for s in subjects if phq9_map.get(s, 0) >= PHQ9_MILD_THRESHOLD]
            healthy_subjects = [s for s in subjects if phq9_map.get(s, 0) < PHQ9_MILD_THRESHOLD]

            selected = st.selectbox(
                "Select subject",
                subjects,
                format_func=lambda s: f"{s} (PHQ-9={phq9_map.get(s, '?')}, "
                                      f"{'Depressed' if s in dep_subjects else 'Healthy'})",
            )

            subj_data = merged[merged["subject_id"] == selected].sort_values("date")

            if len(subj_data) > 0:
                # Plot HRV and sleep over time
                fig = make_subplots(
                    rows=3, cols=1,
                    subplot_titles=["Daily RMSSD (HRV)", "Sleep Duration", "Sleep Efficiency"],
                    shared_xaxes=True,
                    vertical_spacing=0.08,
                )

                if "RMSSD_mean" in subj_data.columns:
                    fig.add_trace(
                        go.Scatter(x=subj_data["date"], y=subj_data["RMSSD_mean"],
                                   name="RMSSD", line=dict(color="#00d4aa")),
                        row=1, col=1,
                    )

                if "sleep_duration" in subj_data.columns:
                    fig.add_trace(
                        go.Scatter(x=subj_data["date"], y=subj_data["sleep_duration"],
                                   name="Sleep Duration (h)", line=dict(color="#6c5ce7")),
                        row=2, col=1,
                    )

                if "sleep_quality_score" in subj_data.columns:
                    fig.add_trace(
                        go.Scatter(x=subj_data["date"], y=subj_data["sleep_quality_score"],
                                   name="Sleep Efficiency", line=dict(color="#ff6b6b")),
                        row=3, col=1,
                    )

                phq_score = phq9_map.get(selected, "?")
                fig.update_layout(
                    height=600,
                    title=f"Subject {selected} — PHQ-9: {phq_score} "
                          f"({'Depressed' if selected in dep_subjects else 'Healthy'})",
                    showlegend=True,
                )
                st.plotly_chart(fig, use_container_width=True)

            # Group comparison
            st.subheader("Group Comparison: Depressed vs Healthy")
            if "RMSSD_mean" in merged.columns:
                merged_with_group = merged.copy()
                merged_with_group["group"] = merged_with_group["subject_id"].apply(
                    lambda s: "PHQ≥5 (Depressed)" if s in dep_subjects else "PHQ<5 (Healthy)"
                )
                daily_means = merged_with_group.groupby(["date", "group"])["RMSSD_mean"].mean().reset_index()

                fig = px.line(
                    daily_means,
                    x="date",
                    y="RMSSD_mean",
                    color="group",
                    title="Average Daily RMSSD by Depression Status",
                    color_discrete_map={
                        "PHQ≥5 (Depressed)": "#ff6b6b",
                        "PHQ<5 (Healthy)": "#00d4aa",
                    },
                )
                st.plotly_chart(fig, use_container_width=True)
        else:
            st.info("Raw data not available. Place CSV files in data/ directory.")

    # ---- Tab 5: Cross-Dataset Validation ----
    with tab5:
        st.subheader("Cross-Dataset Validation")
        st.markdown("*Do temporal dynamics features generalize across different sensor modalities?*")

        # Load cross-dataset results
        cross_path = os.path.join(RESULTS_DIR, "results_cross_validation.tsv")
        dep_path = os.path.join(RESULTS_DIR, "results_depresjon.tsv")
        model_path = os.path.join(RESULTS_DIR, "models", "cross_dataset_results.csv")

        col1, col2 = st.columns(2)
        with col1:
            st.markdown("### Datasets")
            st.markdown("""
| Dataset | Modality | Subjects | Sensor |
|---------|----------|----------|--------|
| **Baigutanova** | HRV + Sleep | 49 | Wearable (5-min) |
| **Depresjon** | Motor Activity | 55 | Actigraph (1-min) |
""")

        with col2:
            if os.path.exists(model_path):
                model_results = pd.read_csv(model_path)
                st.markdown("### Model Performance")
                st.dataframe(model_results.style.format({
                    "auc": "{:.3f}", "f1": "{:.3f}",
                }), use_container_width=True)

        if os.path.exists(model_path):
            model_results = pd.read_csv(model_path)
            fig = px.bar(
                model_results,
                x="dataset", y="auc",
                color="auc",
                color_continuous_scale="viridis",
                title="AUC by Dataset / Transfer Condition",
                labels={"auc": "AUC", "dataset": ""},
            )
            fig.add_hline(y=0.5, line_dash="dash", line_color="red",
                          annotation_text="Random chance")
            fig.update_layout(height=400)
            st.plotly_chart(fig, use_container_width=True)

        if os.path.exists(cross_path):
            cross_df = pd.read_csv(cross_path, sep="\t")
            st.markdown("### Temporal Pattern Generalization")
            st.dataframe(cross_df, use_container_width=True)

            fig = px.bar(
                cross_df,
                x="stat_type",
                y=["baig_count", "dep_count"],
                barmode="group",
                title="Significant Features by Statistical Type (Both Datasets)",
                labels={"value": "Count", "stat_type": "Feature Type"},
            )
            st.plotly_chart(fig, use_container_width=True)

        if os.path.exists(dep_path):
            dep_df = pd.read_csv(dep_path, sep="\t")
            st.markdown("### Top Depresjon (Actigraphy) Features")
            top_dep = dep_df.sort_values("cohens_d", ascending=False).head(15)
            st.dataframe(top_dep[["feature", "auc", "cohens_d", "p_value", "p_adjusted"]].style.format({
                "auc": "{:.3f}", "cohens_d": "{:.3f}", "p_value": "{:.4f}", "p_adjusted": "{:.4f}",
            }), use_container_width=True)

        st.info(
            "**Key finding:** A model trained on HRV temporal dynamics (Baigutanova) achieves "
            "AUC 0.66 when transferred to motor activity data (Depresjon) — temporal pattern "
            "features generalize across sensor modalities, supporting the critical slowing down "
            "hypothesis as a universal early warning signal."
        )

    # ---- Tab 6: Full Results ----
    with tab6:
        st.subheader("Full Results Table")
        st.dataframe(
            df.sort_values("cohens_d", ascending=False).style.format({
                "auc": "{:.3f}",
                "cohens_d": "{:.3f}",
                "p_value": "{:.4f}",
                "p_adjusted": "{:.4f}",
                "ci_lower": "{:.3f}",
                "ci_upper": "{:.3f}",
            }),
            use_container_width=True,
            height=600,
        )

        # Download button
        csv = df.to_csv(index=False)
        st.download_button(
            "Download Results CSV",
            csv,
            "autobiomarker_results.csv",
            "text/csv",
        )

    # ---- Sidebar: Overnight Log ----
    with st.sidebar:
        st.header("Overnight Run Log")
        log_path = os.path.join(RESULTS_DIR, "overnight_log.txt")
        if os.path.exists(log_path):
            with open(log_path) as f:
                log_text = f.read()
            st.code(log_text[-3000:], language="text")  # Last 3000 chars
        else:
            st.info("No log file yet.")

        st.divider()
        st.markdown("**AutoBiomarker** — Evolved26 Toronto")
        st.markdown("Adapted from Karpathy's autoresearch")


if __name__ == "__main__":
    main()
