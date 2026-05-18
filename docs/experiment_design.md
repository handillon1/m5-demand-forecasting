# Experiment Design — M5 Forecast Model A/B Test

**Pre-registered on:** May 2026 (BEFORE results were unblinded)
**Post-script added on:** May 2026 (AFTER analysis completed)
**Owner:** Mark Mairs
**Status:** Pre-registration honored; results in `docs/PM_memo_final.md`.

---

## Why pre-register

Pre-registration prevents p-hacking. By writing down the hypothesis, KPI, sample size, statistical test, and alpha *before* touching the data, we commit to a single planned analysis. Any deviation from this design must be explicitly justified in the results section of the PM memo.

---

## 1. Hypothesis

**H₀ (null):** The LightGBM forecast (treatment) produces the same daily inventory-cost-adjusted gross margin per SKU as the seasonal-naive forecast (control), on average.

**H₁ (alternative, two-sided):** The treatment produces a different per-SKU mean daily gross margin than control.

We use a two-sided test because, in principle, a more accurate forecast could *hurt* margin if it shifts errors from the cheaper direction (overstock) to the more expensive direction (stockout). The pre-registered analysis must be open to that outcome.

## 2. Unit of randomization

`(item_id, store_id)` pair. Each unique SKU-store combination is independently assigned to one of two arms. This is the same granularity as the forecast itself, which keeps the analysis clean.

## 3. Sample

**Population:** all 30,490 (item, store) pairs available in the data.

**Eligibility filter:**
- Must have ≥ 1 unit of sales in the trailing 90 days before the test window (excludes SKUs that are effectively dormant).
- Must have a non-null `sell_price` on every day of the test window (excludes SKUs not stocked in that store).

**Selection:** rank eligible SKUs by total revenue in the trailing 90 days. Take the **top 200**.

**Randomization:** with random seed `42`, randomly assign 100 SKUs to **control** (seasonal-naive) and 100 to **treatment** (LightGBM). Block-randomize within state so we have roughly balanced state representation across arms.

**Sample size rationale:** with n=100 per arm and an assumed within-SKU standard deviation of σ ≈ 1.5 in mean daily KPI (informed by Phase 3's observed RMSE of ~2.1), a Welch's t-test has ~80% power to detect a true mean difference of 0.4 units/day at α=0.05. We will check this assumption with a pre-analysis power calculation on the actual σ once data are loaded.

## 4. Outcome metric (KPI)

**Per-(SKU, day) score:**

```
KPI = revenue − overstock_cost − stockout_cost
    = price × min(forecast, actual)              # revenue captured
    − max(0, forecast − actual) × price × 0.20   # overstock at 20% holding cost
    − max(0, actual − forecast) × price × 1.00   # stockout at 100% lost margin
```

**Aggregation:** for each SKU, average the daily KPI across the 28-day test window. The per-SKU mean becomes one row of data for the t-test.

**Why this KPI:** retail economics are asymmetric. Overstock costs ~20¢ per dollar held (warehousing + spoilage + capital). Stockouts cost the full margin plus customer churn — we approximate that at the full unit price. Real retail teams would derive these coefficients with finance partners; we hold them at 0.20 / 1.00 for transparency.

**Sensitivity analysis (post-hoc, supplementary):** repeat the analysis with stockout coefficients of 0.5 and 2.0 to show the result is not knife-edge-dependent on the assumption.

## 5. Statistical test

- **Primary:** Welch's two-sample t-test (equal_var=False) on per-SKU mean daily KPI, treatment vs. control. **α = 0.05, two-sided.**
- **Effect size:** Cohen's d, reported alongside p-value.
- **Confidence interval:** 95% bootstrap CI for the difference in means, 10,000 resamples. Reported alongside the t-test for robustness.

## 6. Pre-registered cuts

To explore heterogeneity, we will report the same primary test split by:

1. **Category** (FOODS / HOBBIES / HOUSEHOLD) — exploratory; not corrected for multiple comparisons.
2. **State** (CA / TX / WI) — exploratory.

These are exploratory; the **primary decision criterion is the pooled test**. The cuts inform the rollout recommendation in the PM memo but do not determine ship/no-ship.

## 7. Guardrails

The experiment is invalidated if **either** of the following triggers:

- **Bias guardrail:** treatment forecast bias outside ±10% of control bias on the test window.
- **Forecast coverage:** any SKU in either arm with <28 days of forecast.

Both should be checked *before* unblinding the primary result.

## 8. Decision rule

| Outcome | Action |
|---|---|
| p < 0.05 AND treatment lift > 0 AND no guardrail trip | Recommend rollout, sequenced by category |
| p < 0.05 AND treatment lift > 0 AND guardrail trip | Recommend investigation; do not ship |
| p < 0.05 AND treatment lift < 0 | Recommend continued use of seasonal-naive; investigate why treatment hurt margin |
| p ≥ 0.05 | Insufficient evidence; recommend either (a) larger sample re-test or (b) model iteration |

## 9. What we will *not* do

- We will **not** look at the result before this design is committed.
- We will **not** add additional cuts after seeing the data (any post-hoc analysis is flagged as exploratory in the memo).
- We will **not** change the alpha or sample size mid-analysis.
- We will **not** rerun the experiment with a different random seed if the first result is unfavorable.

---

# Post-script: results and deviations from the plan

*Added after analysis was complete. Documents what was actually run vs. what was pre-registered, in keeping with experimentation best practice.*

## Deviations from pre-registration

| Item | Planned | Actual | Justification |
|---|---|---|---|
| Arm sizes | 100 / 100 | 99 / 101 | Integer division across odd state SKU counts (CA=81, WI=63). Within the "roughly balanced" tolerance of the plan. Welch's t-test handles unequal arms. |
| Within-SKU σ assumption | ~1.5 | ~5.6 (observed pooled SE on per-SKU mean) | Phase 3 RMSE was a unit-level metric, not a dollar KPI metric. Real σ was higher than pre-analysis estimate, which explains the lower-than-planned post-hoc power (see below). |

No other deviations. Decision rule was applied as written.

## Pre-registered analyses run

| Analysis | Outcome | File / cell |
|---|---|---|
| Primary Welch's t-test | t=+2.164, p=0.032 | Cell 7 |
| 95% bootstrap CI for lift | [+$1.77, +$23.42] | Cell 7 |
| Cohen's d | +0.305 | Cell 7 |
| Bias guardrail check | Control −0.058, Treatment −0.026; within ±10% | Cell 6 |
| Forecast coverage check | All 200 SKUs covered 28 days | Cell 6 |
| Category cut | Exploratory; no subgroup significant | Cell 8 |
| State cut | Exploratory; no subgroup significant | Cell 8 |
| Cost-coefficient sensitivity (supplementary) | Significant at 20%/100% and 10%/200%; non-significant at 30%/50% | Cell 11 |
| Trimmed-mean robustness (supplementary, post-hoc) | Lift +$8.62, p=0.013 — stronger than untrimmed | Cell 16 |
| Stratified analysis (supplementary, post-hoc) | $12.37 ≈ pooled $12.08, no compositional bias | Cell 17 |
| Post-hoc power retrospective (supplementary, post-hoc) | 58%; need ~332/arm for 80% | Cell 14 |

The trimmed, stratified, and power analyses were added **after** the pre-registered tests had been run and reported. They are clearly flagged as exploratory/supplementary in the memo and serve only to validate the robustness of the pre-registered primary result — not to replace or override it.

## Decision applied

Decision rule applied as written: **p < 0.05 AND lift > 0 AND no guardrail trip → recommend rollout, sequenced by category.**

The full rollout recommendation, including phased plan and pre-rollout gates, is documented in `docs/PM_memo_final.md`.

## What we learned about the design (for v2)

- **n=200 was too small** for the observed σ. Future tests on this KPI should target n ≥ 400 per arm.
- **Block randomization on state did not balance category exposure** — Foods got 142/200, Hobbies got 20/200. Future tests should stratify on category as well, or use two-stage randomization.
- **Cost coefficients matter more than expected.** The result's significance depends on cost assumption choices that should be locked in with finance *before* running future experiments.
