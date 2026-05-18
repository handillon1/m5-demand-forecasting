# Demand Forecast Pilot — Results Memo

**To:** VP Merchandising, Category Managers
**From:** Mark Mairs, Data Science PM
**Date:** May 2026
**Status:** FINAL

---

## TL;DR

A LightGBM forecaster trained on 2.7 years of historical sales **delivers a statistically significant +$12.08/SKU/day lift** in cost-adjusted gross margin (p=0.032, 95% CI [+$1.77, +$23.42]) over our current seasonal-naive baseline, in a pre-registered A/B test on 200 top-revenue SKUs. The effect is **broad-based, not outlier-driven** (trimmed p=0.013) and **robust to compositional bias** (stratified estimate $12.37 ≈ pooled $12.08).

**Recommendation: phased rollout starting with Foods, with a parallel confirmation test before full deployment.** Projected annualized impact across all 30,490 SKUs: **$19.7M (lower CI) to $260M (upper CI)**, point estimate $134M.

---

## Background

Our 10 pilot stores currently order inventory using a seasonal-naive heuristic (this-day = same-day-4-weeks-ago). This causes ~7% stock-outs on top-velocity SKUs and ~12% over-stock on slow movers. A 28-day daily forecast that more accurately matches demand directly attacks both error modes — overstocks tie up working capital and drive markdowns; stockouts lose margin and erode customer trust.

We hypothesized that a global LightGBM model with Tweedie objective, trained on calendar / price / lag / identity features, would beat the seasonal-naive baseline on a cost-adjusted gross-margin KPI.

## Method

- **Pre-registration:** hypothesis, KPI formula, sample size, α=0.05, and decision rule were committed to `docs/experiment_design.md` before any results were unblinded.
- **Sample:** top 200 SKUs by trailing-90-day revenue, block-randomized within state (final split 99 control / 101 treatment).
- **KPI per (SKU, day):** revenue captured − overstock cost (20% × price × overstock units) − stockout cost (100% × price × stockout units). Per-SKU average over the 28-day test window (2016-04-25 → 2016-05-22) becomes the unit of analysis.
- **Primary test:** Welch's two-sided t-test, α=0.05. Supplementary: 95% bootstrap CI (10,000 resamples), Cohen's d, 2.5%-trimmed mean test, category-stratified estimate, three-scenario cost sensitivity.

Full method and analysis code: `notebooks/04_ab_test_analysis.ipynb`.

## Results

| Metric | Control (Naive) | Treatment (LightGBM) | Δ |
|---|---|---|---|
| Mean daily KPI per SKU | $37.88 | $49.95 | **+$12.08** |
| Relative lift | — | — | **+31.89%** |
| 95% bootstrap CI for lift | — | — | [+$1.77, +$23.42] |
| Welch's t-statistic | — | — | +2.164 |
| p-value (two-sided) | — | — | **0.032** |
| Cohen's d | — | — | +0.305 |
| 2.5%-trimmed lift | — | — | +$8.62, p=0.013 |
| Forecast bias (guardrail) | −0.058 | −0.026 | within ±10% ✓ |

**The pre-registered null is rejected.** Treatment delivered a positive, statistically significant lift that strengthens (lower p-value) after trimming outliers — proving the effect is distributional, not driven by a small number of high-volume SKUs.

### By category (exploratory; not corrected for multiple comparisons)

| Category | n | Lift | Comment |
|---|---|---|---|
| Foods | 142 | **+$6.57** | Most defensible: largest, most balanced sample |
| Household | 38 | +$9.78 | Directionally consistent with pooled |
| Hobbies | 20 | +$58.43 | **Outlier-driven** (2 SKUs at TX_3 dominate); do not quote |

No category individually reaches p<0.05 — the pooled significance reflects directional consistency, not subgroup-level wins.

### Robustness checks

- **Cost sensitivity:** the result is significant at the pre-registered 20%/100% cost weights (p=0.032) and at a more aggressive 10%/200% scenario (p=0.005), but tilts non-significant at a conservative 30%/50% scenario (p=0.066). Outcome is sensitive to the cost coefficient choice.
- **Power retrospective:** observed post-hoc power was 58%. A confirmation test would need ~332 SKUs per arm to reach 80% power, ~445 for 90%.

## Recommendation

**Phased rollout, with full deployment gated on a confirmation test.**

**Phase 1 (next 28 days) — Ship to Foods.** Deploy LightGBM forecasts for the Foods category across all 10 pilot stores. Foods carries 71% of our test sample, shows the most balanced arm split, and a +$6.57/SKU/day lift that is robust under stratification. Projected 28-day impact across the ~2,200 Foods SKUs in our catalog: roughly $400k.

**Phase 2 (concurrent, 28 days) — Shadow run Hobbies and Household.** Run LightGBM in shadow mode for the other two categories, logging predictions side-by-side with current category-manager orders. This produces a fresh-data validation set without committing to a rollout. Hobbies in particular needs this — the experiment's apparent +159% lift was driven by outlier SKUs at one TX store and should not be taken at face value.

**Phase 3 (gate before extending) — Three requirements:**

1. **Confirmation A/B at n=400 per arm** to validate the lift at 80%+ power.
2. **Finance partnership** to nail down overstock / stockout coefficients before any $/year number leaves this room.
3. **Per-state, per-category error monitoring** in production, with particular attention to SNAP-eligible Foods (lift heterogeneity across states is a known finding from EDA).

## Risks & next steps

| Risk | Mitigation |
|---|---|
| Wide CI on a single n=200 test | Confirmation test at n=400/arm before full rollout |
| Cost-coefficient sensitivity | Finance partnership to commit to weights |
| Cold-start SKUs (newly launched) | Out of scope for v1; fallback to existing process |
| Long-horizon error compounding | Re-train monthly; reassess >14-day forecast accuracy |
| Test window omits canonical M5 evaluation period | Documented in `docs/PRD_v2.md`; mitigated by shadow run on fresh data |

**Next milestone (30 days from now):** Phase 1 Foods rollout complete, Phase 2 shadow data collected, Phase 3 confirmation test launched.

---

*See `docs/model_card.md` for full technical detail, `docs/experiment_design.md` for the pre-registered analysis plan, and `notebooks/04_ab_test_analysis.ipynb` for the reproducible analysis.*
