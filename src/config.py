"""
AutoBiomarker — Configuration
"""

import os

# Load .env file if present
_env_path = os.path.join(os.path.dirname(__file__), "..", ".env")
if os.path.exists(_env_path):
    with open(_env_path) as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                key, val = line.split("=", 1)
                os.environ.setdefault(key.strip(), val.strip())

# Nebius Token Factory
NEBIUS_API_KEY = os.environ.get("NEBIUS_API_KEY", "")
NEBIUS_BASE_URL = "https://api.tokenfactory.nebius.com/v1/"
NEBIUS_MODEL = "meta-llama/Llama-3.3-70B-Instruct"

# Budget safeguard ($70 limit)
NEBIUS_BUDGET_LIMIT = float(os.environ.get("NEBIUS_BUDGET_LIMIT", "70"))
NEBIUS_COST_PER_1K_TOKENS = 0.0013  # Llama 3.3 70B approx rate
NEBIUS_MAX_LLM_CALLS = 200  # hard cap on LLM hypothesis generation calls

# Dataset paths (flat CSVs in data/)
DATA_DIR = os.path.join(os.path.dirname(__file__), "..", "data")

# Results
RESULTS_DIR = os.path.join(os.path.dirname(__file__), "..", "results")
RESULTS_TSV = os.path.join(RESULTS_DIR, "results.tsv")

# Autoresearch loop
MAX_HYPOTHESES = 5000
SIGNIFICANCE_THRESHOLD = 0.01  # adjusted p-value
EFFECT_SIZE_THRESHOLD = 0.3    # Cohen's d minimum
FDR_METHOD = "fdr_bh"          # Benjamini-Hochberg

# Feature extraction
ROLLING_WINDOWS = [3, 5, 7, 14, 21, 28]  # days — full range up to study length
TEMPORAL_LAGS = [3, 5, 7, 14]    # days ahead to predict

# Clinical thresholds
PHQ9_CLINICALLY_MEANINGFUL_CHANGE = 5  # Minimally important difference
PHQ9_MILD_THRESHOLD = 5
PHQ9_MODERATE_THRESHOLD = 10
PHQ9_SEVERE_THRESHOLD = 15
