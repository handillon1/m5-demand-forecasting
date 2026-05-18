# Retail Demand Forecasting — M5 Dataset

> A Data Science Product Manager project: end-to-end demand forecasting with **SQL + Python + Tableau**, framed as a real DS-PM workflow — PRD → warehouse → model → pre-registered A/B test → executive memo → live dashboard.

**[M5 Demand Forecast Dashboard](https://public.tableau.com/app/profile/dillon.han3625/viz/5DemandForecastPilotResults/M5ForecastDashboard)**

---

## TL;DR

Built an end-to-end retail demand-forecasting solution on the M5 dataset (3,049 SKUs × 10 stores × 1,913 days = 59M sales rows). A LightGBM forecaster with Tweedie objective beats a seasonal-naive baseline by **25.6% on RMSE** (MAE 1.28 → 1.05), and a **pre-registered simulated A/B test** demonstrates a statistically significant **+$12.08/SKU/day lift in cost-adjusted gross margin** (p=0.032, 95% CI $1.77–$23.42).

Recommended action in the [PM memo](docs/PM_memo.md): phased rollout starting with Foods, gated by a confirmation experiment at n=400/arm.

---

## Headline results

| Phase | Result |
|---|---|
| **Data engineering** | PostgreSQL star schema loading 59M rows via bulk COPY (~3 min for the sales fact table). |
| **Modeling** | LightGBM Tweedie reduces 28-day-horizon **RMSE by 25.6%** vs. seasonal-naive (MAE 1.28 → 1.05, bias within ±3%). Consistent gains across categories (Foods 25.0%, Hobbies 27.2%, Household 27.5%). |
| **A/B test** | Pre-registered 200-SKU experiment. Treatment lifts per-SKU mean daily margin by **+$12.08 (+31.9%), p=0.032**. Robust to 2.5% trimming (p=0.013) and category stratification ($12.37 ≈ $12.08). |
| **Business impact** | Annualized lift projection: **$19.7M (lower CI) – $260M (upper CI)**, point estimate $134M. |

---

## Documents (read in this order)

| Document | Purpose |
|---|---|
| [`docs/PRD.md`](docs/PRD.md) | Product Requirements Doc — problem, goal, success metrics, RACI, risks. |
| [`docs/experiment_design.md`](docs/experiment_design.md) | Pre-registered A/B test plan + post-script documenting what was actually run. |
| [`docs/model_card.md`](docs/model_card.md) | Full model technical detail: training data, architecture, performance, failure modes, ethics. |
| [`docs/PM_memo.md`](docs/PM_memo.md) | 1-page executive memo with rollout recommendation. |
| [`docs/resume_bullets.md`](docs/resume_bullets.md) | Role-targeted resume bullets (DS-PM, DS/ML, Analytics). |

---

## Project structure

```
m5-demand-forecasting/
├── README.md                     ← you are here
├── LICENSE
├── environment.yml               ← conda env (pinned)
├── requirements.txt              ← pip alternative
├── .gitignore
├── data/
│   ├── raw/                      ← M5 CSVs (gitignored — download from Kaggle)
│   └── processed/                ← parquet outputs (gitignored)
├── sql/
│   ├── 01_create_schema.sql      ← PostgreSQL star schema
│   ├── 02_dimensions.sql         ← dim_item, dim_store, dim_date
│   ├── 03_fact_sales.sql         ← 59M-row fact table
│   └── 04_views_features.sql     ← lightweight feature view
├── notebooks/
│   ├── 00_load_raw.ipynb         ← CSV → Postgres via psycopg2 COPY
│   ├── 01_eda.ipynb              ← 5 EDA charts + "what a PM should know"
│   ├── 02_baseline_models.ipynb  ← Seasonal-naive baseline
│   ├── 03_lightgbm_forecast.ipynb ← Training + recursive prediction + RMSE/MAE/bias
│   └── 04_ab_test_analysis.ipynb ← Pre-registered A/B test analysis
├── tableau/
│   └── data/                     ← CSV inputs for the dashboard
│   
└── docs/
    ├── PRD.md
    ├── experiment_design.md
    ├── model_card.md
    ├── PM_memo.md
    ├── resume_bullets.md
    └── img/                      ← EDA charts and feature-importance plot
```

---

## How to reproduce

### Prerequisites

- Python 3.11 (Anaconda recommended)
- PostgreSQL 15+ running locally (database name `m5db`)
- Tableau Public Desktop (free, optional — only needed to edit the dashboard)
- Kaggle account to download the M5 dataset (~450 MB)

### Setup

```bash
# 1. Clone the repo
git clone https://github.com/handillon1/m5-demand-forecasting.git
cd m5-demand-forecasting

# 2. Create the Python environment
conda env create -f environment.yml
conda activate m5

# 3. Download M5 data
# Visit https://www.kaggle.com/competitions/m5-forecasting-accuracy/data
# Place these into data/raw/:
#   - sales_train_validation.csv  (or sales_train_evaluation.csv)
#   - calendar.csv
#   - sell_prices.csv

# 4. Create the Postgres database
psql -U postgres -c "CREATE DATABASE m5db;"
```

### Run the pipeline

```bash
# Phase 1: Build the warehouse
psql -U postgres -d m5db -f sql/01_create_schema.sql
jupyter notebook notebooks/00_load_raw.ipynb       # runs the Python loader
psql -U postgres -d m5db -f sql/03_dimensions.sql
psql -U postgres -d m5db -f sql/04_fact_sales.sql
psql -U postgres -d m5db -f sql/05_views_features.sql
psql -U postgres -d m5db -f sql/06_qa_checks.sql

# Phase 2: EDA
jupyter notebook notebooks/01_eda.ipynb

# Phase 3: Models
jupyter notebook notebooks/02_baseline_models.ipynb
jupyter notebook notebooks/03_lightgbm_forecast.ipynb

# Phase 4: A/B test
jupyter notebook notebooks/04_ab_test_analysis.ipynb
```

Each notebook runs top to bottom from a fresh kernel and uses parquet caches to keep re-runs fast.

---

## Methodology highlights

- **PostgreSQL bulk loading via `COPY`** is 5–10× faster than ORM-based `to_sql` for the 60M-row sales fact table. Wide-format CSV (1,913 daily columns) is melted in pandas first because Postgres caps tables at 1,600 columns.
- **Recursive 28-day prediction** uses the model's own outputs to update lag features each day. Day-28 forecasts are built entirely from model-generated lag values — error compounds across the horizon and is one of the known failure modes documented in the [model card](docs/model_card.md).
- **Tweedie objective** in LightGBM handles M5's heavy zero-inflation (73% of (SKU, day) cells have zero sales). Standard regression loss would bias the forecast toward over-prediction on slow movers.
- **Pre-registered A/B test** locks in the hypothesis, KPI formula, sample size, alpha, and decision rule *before* unblinding results. The [experiment design doc](docs/experiment_design.md) includes a post-script with deviations from the plan and which supplementary analyses were run, in keeping with experimentation best practice.
- **Cost-adjusted gross margin KPI** uses asymmetric over/under-stock penalties (20% / 100% of unit price) to match real retail economics. Sensitivity to the cost coefficients is reported explicitly — the result is significant at 20%/100% but tilts non-significant at a more conservative 30%/50%, which informs the rollout recommendation.

---

## Extensions (completed)

- **Quantile regression for prediction intervals.** Trained 5 LightGBM models at q=0.025, 0.25, 0.5, 0.75, 0.975 to produce probabilistic forecasts. The 95% prediction interval is calibrated within 2 pp of target (97.3% empirical vs. 97.5% target). However, conditional-on-positive-demand analysis revealed systematic under-prediction across all quantiles (median empirical coverage 19.7% vs. target 50%), traced to the standard zero-inflation saturation problem in quantile regression. Documented in the [model card](docs/model_card.md#probabilistic-forecasts-quantile-regression-extension); production fix (two-stage hurdle model) deferred to v2.

---

## What I would do next (v2 roadmap)

1. **Hurdle model for probabilistic forecasts** (priority 1) — two-stage architecture: a P(units > 0) classifier feeding a conditional quantile-regression model. Resolves the systematic under-prediction bias diagnosed during the quantile extension.
2. **Confirmation A/B test at n=400 per arm** before any production deployment. Current test had only 58% observed power; the recommended confirmation size is informed by post-hoc power analysis.
3. **Hierarchical reconciliation (MinT)** so store-level forecasts sum cleanly to state and total — required for top-down inventory rollups.
4. **Cold-start handling** via item-similarity embeddings derived from `dept_id` × `cat_id` × launch-week peers. Out of scope for v1.
5. **MLflow tracking** wrapped around `src/train.py` for experiment versioning.
6. **Refactor `notebooks/` → `src/` modules** (`features.py`, `train.py`, `evaluate.py`, `ab_test.py`) for a production-style codebase.

---

## Data source & license

- Sales / calendar / price data: M5 Forecasting Competition (Kaggle, released by Walmart × University of Nicosia, 2020). See the [Kaggle competition page](https://www.kaggle.com/competitions/m5-forecasting-accuracy) for the original license and use restrictions.
- All code and documentation in this repository: MIT License (see [LICENSE](LICENSE)).

---

## Contact

Dillon Han — handillon1@gmail.com