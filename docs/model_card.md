# M5 Demand Forecast — Model Card

**Model:** `lgbm_v1` (point) + `lgbm_q{025,250,500,750,975}` (quantile)
**Author:** Mark Mairs
**Last updated:** May 2026

---

## Intended use

Daily unit-sales forecasting for **3,049 Walmart SKUs across 10 stores** in CA, TX, and WI. The model produces point estimates with a **28-day horizon** and (as a v1 extension) prediction intervals at 5 quantile levels.

**In scope**
- Daily forecasts for items with at least 28 days of sales history.
- Aggregation to weekly, monthly, store-level, or category-level totals (via post-hoc sum).
- Use as a baseline for promotional / inventory decision support.

**Out of scope**
- Intraday or hourly forecasting.
- Item cold-start (newly launched SKUs without 28 days of history).
- Causal estimation of pricing or promo elasticity.
- New-store launch forecasting.

---

## Training data

| Property | Value |
|---|---|
| Source | M5 Forecasting Competition (Kaggle / Walmart / Univ. of Nicosia, 2020) |
| Granularity | (item × store × day) |
| Training window | 2013-07-17 → 2016-03-27 (~2.7 years) |
| Validation window | 2016-03-28 → 2016-04-24 (28 days) |
| Test window | 2016-04-25 → 2016-05-22 (28 days, d_1914–d_1941) |
| Training rows | ~31.7M |

**Note on the test window.** The test window is the canonical M5 evaluation period (d_1914–d_1941, 2016-04-25 → 2016-05-22), taken from `sales_train_evaluation.csv` (1,941 days). The 28 days before it (d_1886–d_1913) are the validation window. Results use RMSE/MAE rather than the competition's WRMSSE metric, so they are not directly comparable to the M5 Kaggle leaderboard but are internally consistent.

---

## Architecture — point forecast (`lgbm_v1`)

| Component | Choice |
|---|---|
| Algorithm | LightGBM Regressor |
| Objective | `tweedie` (variance_power = 1.1) — handles zero-inflated count data |
| Learning rate | 0.05 |
| Num leaves | 128 |
| Feature / bagging fraction | 0.8 / 0.8 (bagging_freq = 1) |
| Max iterations | 2,000 with early stopping (patience = 50) |
| Categorical features | item_id, store_id, dept_id, cat_id, state_id, event_name_1, event_type_1 |

### Feature set (21 total)

- **Calendar / context (7):** `wday`, `month`, `year`, `wm_yr_wk`, `snap_ca`, `snap_tx`, `snap_wi`
- **Price (2):** `sell_price`, `price_pct_change`
- **History (5):** `lag_7`, `lag_28`, `roll7_mean`, `roll28_mean`, `roll7_std`
- **Identity (7):** `item_id`, `store_id`, `dept_id`, `cat_id`, `state_id`, `event_name_1`, `event_type_1`

---

## Performance on held-out test window

| Metric | Naive baseline | LightGBM | Δ |
|---|---|---|---|
| MAE | 1.284 | 1.048 | **−18.4%** |
| RMSE | 2.829 | 2.104 | **−25.6%** |
| Bias | −0.056 | −0.025 | closer to zero |

**Acceptance criteria from the PRD: all met.**
- RMSE improvement ≥ 10% ✓ (achieved 25.6%)
- Bias within ±3% ✓ (LightGBM bias −0.025)

### Performance by category

| Category | Naive RMSE | LightGBM RMSE | Improvement |
|---|---|---|---|
| FOODS | 3.50 | 2.63 | 25.0% |
| HOBBIES | 2.27 | 1.65 | **27.2%** |
| HOUSEHOLD | 1.93 | 1.40 | **27.5%** |

Improvements are consistent across categories. The largest *absolute* RMSE reduction is on Foods (high-volume, high-error category), but in *relative* terms LightGBM helps most on Household and Hobbies — categories where seasonal-naive struggles with low-base-rate noise that rolling features smooth out.

### Top features by gain importance

| Rank | Feature | Gain |
|---|---|---|
| 1 | `item_id` | 56,228 |
| 2 | `roll7_mean` | 6,159 |
| 3 | `roll28_mean` | 6,142 |
| 4 | `wm_yr_wk` | 5,242 |
| 5 | `roll7_std` | 5,069 |
| 6 | `store_id` | 4,217 |
| 7 | `wday` | 3,734 |
| 8 | `event_name_1` | 3,684 |
| 9 | `lag_7` | 3,306 |
| 10 | `lag_28` | 3,057 |

**Reading the importance chart:** `item_id` dominates because the model uses SKU identity as a base-rate lookup — expected behavior for a global forecaster across 30,490 series. Notably, rolling means outrank direct lags, which is consistent with high day-to-day noise in retail demand: smoothed history is more predictive than exact point lags. SNAP flags rank mid-pack — meaningful but not dominant.

---

## Probabilistic forecasts (quantile regression extension)

A second set of LightGBM models was trained with `objective="quantile"` at q ∈ {0.025, 0.25, 0.5, 0.75, 0.975} to produce **prediction intervals** alongside the point forecast. Pinball loss and empirical coverage are reported below.

### Pinball loss and unconditional calibration

| Quantile | Pinball loss | Empirical coverage | Target |
|---|---|---|---|
| 0.025 | 0.036 | 54.4% | 2.5% |
| 0.25 | 0.291 | 56.4% | 25.0% |
| 0.50 | 0.457 | 63.4% | 50.0% |
| 0.75 | 0.447 | 77.2% | 75.0% |
| 0.975 | 0.119 | **97.3%** | 97.5% |

**95% prediction interval (q025–q975) empirical coverage: 97.3% — within 2 pp of target.**

### Calibration is dominated by zero-inflation; conditional analysis reveals the truth

Because 73% of (SKU, day) cells have zero sales, lower-quantile predictions saturate at the clipping floor and trivially "cover" all zero actuals. A conditional analysis (restricting to actual > 0, n=388,995) strips out this artifact:

| Quantile | Target | Empirical (conditional) | Gap |
|---|---|---|---|
| 0.025 | 2.5% | **0.0%** | −2.5% |
| 0.25 | 25.0% | **4.3%** | −20.7% |
| 0.50 | 50.0% | **19.7%** | −30.3% |
| 0.75 | 75.0% | **50.0%** | −25.0% |
| 0.975 | 97.5% | 94.2% | −3.3% |

**Finding:** conditional on positive demand, the model is *systematically under-predicting* across all quantiles. The median forecast lands at the 20th percentile of actual non-zero demand. For inventory decisions, this would cause stockouts.

**Root cause:** quantile regression with heavy zero-inflation learns to shrink toward zero to optimize pinball loss on the global distribution. The point-forecast Tweedie model (`lgbm_v1`) handles zero-inflation via explicit point-mass at zero; the quantile objective does not, and shrinks all quantile estimates downward.

**Per-category 95% PI calibration is uniform** at 97.3% across FOODS, HOBBIES, and HOUSEHOLD — the zero-saturation effect dominates uniformly across product groups.

### Recommended production fix: two-stage hurdle model

For production deployment of probabilistic forecasts, implement a hurdle architecture:

1. **Stage 1:** Binary classifier predicting P(units > 0) per (SKU, day) (LightGBM with `objective="binary"`).
2. **Stage 2:** Quantile regression *conditional* on the non-zero subset.
3. **Combined forecast:** if P(units > 0) < threshold, predict 0 at all quantiles; otherwise predict the Stage 2 conditional quantile.

This fixes both the lower-tail saturation and the systematic under-prediction bias on positive days. Estimated effort: 3–4 hours of new modeling work. Deferred to v2.

---

## Known failure modes

- **Cold-start SKUs.** Newly launched items have no lag history. The model falls back on an `item_id`-based base rate, which is unstable until ~28 days of history accumulate.
- **Promo overlap.** Days with multiple concurrent events use only `event_name_1`; secondary events are not encoded.
- **Structural breaks.** SKUs with discontinuations or major price re-positioning during training (see `FOODS_3_090` in `notebooks/01_eda.ipynb`) have lag features that misrepresent the new regime. The model has no change-point detection.
- **Long-horizon decay.** Recursive prediction means errors compound across the 28-day horizon. Day-28 forecasts are based entirely on the model's own day-1 through day-27 outputs.
- **Zero-floor clipping.** Predictions are clipped at zero post-hoc. This biases the forecast slightly toward overprediction on low-volume SKUs.
- **Quantile under-prediction (probabilistic forecasts only).** Conditional on positive demand, all quantile predictions lag actual demand. Documented above; resolved by the hurdle-model fix in v2.

---

## Ethical considerations

- Forecasts feed inventory and pricing decisions. Errors that systematically under-predict in lower-income markets could reduce on-shelf availability for SNAP-eligible items in those communities.
- Performance was evaluated globally and by category. It was **not** stratified by store-level demographics. We recommend per-store and per-state error monitoring before any production rollout, with particular attention to bias in SNAP-eligible Foods.
- The model uses no demographic or customer-PII features. All inputs are at the (item, store, day) granularity.

---

## What we would do next (v2 roadmap)

1. **Hurdle model for probabilistic forecasts** (priority 1) — see "Probabilistic forecasts" section above for the architecture and rationale.
2. **Confirmation A/B test at n=400/arm** — see PM memo. Current pilot has 58% observed power; confirmation test required before production rollout.
3. **Hierarchical reconciliation (MinT)** so store-level forecasts sum cleanly to state and total — required for top-down inventory rollups.
4. **Promo elasticity** as a separate model that feeds `expected_price_lift` into the forecast features.
5. **Cold-start handling** via item-similarity embeddings derived from `dept_id` × `cat_id` × launch-week peers.
6. **MLflow tracking** wrapped around `src/train.py` for experiment versioning.
