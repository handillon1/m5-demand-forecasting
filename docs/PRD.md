# Product Requirements Doc — M5 Demand Forecast v1

**Owner:** Mark Mairs
**Last updated:** May 2026
**Status:** Phase 3 complete; Phase 4 (A/B test) in progress

---

## Problem

Category managers at our 10 pilot stores currently order inventory based on last-week sales plus intuition. This causes a **7% stock-out rate** on top-velocity SKUs and a **12% over-stock rate** on slow movers. The downstream impact: lost revenue from missed sales on the fast movers and tied-up working capital + markdown waste on the slow ones.

## Goal (1-line)

Reduce forecast error (RMSE) on the held-out test window by **≥10%** vs. a seasonal-naive baseline, unlocking a projected $X/store/week in working-capital savings (to be quantified in Phase 4's simulated A/B test).

## Non-goals

- Real-time / intraday forecasting.
- Causal pricing / elasticity modeling.
- Cold-start prediction for items with <28 days of history.
- New-store launch forecasting.

## Success metrics

- **Primary:** RMSE on the held-out test window (d_1914–d_1941, 2016-04-25 → 2016-05-22). See note below on the test window.
- **Secondary:** simulated cost-adjusted gross-margin lift in A/B test (Phase 4).
- **Guardrail:** forecast bias within ±3%.

### Note on the test window

The test window is the canonical M5 evaluation period (d_1914–d_1941, 2016-04-25 → 2016-05-22), taken from `sales_train_evaluation.csv` (1,941 days). The 28 days before it (d_1886–d_1913) are the validation window. Results use RMSE/MAE rather than the competition's WRMSSE metric, so they are not directly comparable to the M5 Kaggle leaderboard but are internally consistent.

## Phase 3 results (recorded for the record)

| Metric | Naive | LightGBM | Δ |
|---|---|---|---|
| MAE | 1.28 | 1.05 | −18.4% |
| RMSE | 2.83 | 2.10 | **−25.6%** |
| Bias | −0.056 | −0.025 | closer to zero |

Acceptance criteria met. See `docs/model_card.md` for full performance breakdown.

## Stakeholders & RACI

| Role | Person |
|---|---|
| Responsible | DS-PM (you) |
| Accountable | VP Merchandising (simulated) |
| Consulted | Store Ops, Supply Chain |
| Informed | Finance, Category Managers |

## Risks & open questions

- **SNAP-day spikes** vary 10–30% across states; the model captures this via state-level SNAP features.
- **Promo overlap** is not fully modeled; only `event_name_1` is used.
- **Data freshness SLA** for downstream production rollout is undefined.
- **Cold-start** for newly launched SKUs: out of scope for v1; flagged in `docs/model_card.md` as a known failure mode.
