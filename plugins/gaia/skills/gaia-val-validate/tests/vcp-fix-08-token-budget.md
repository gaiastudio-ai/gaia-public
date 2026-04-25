# VCP-FIX-08 — Token budget verification (NFR-VCP-2)

> Covers AC5 of E44-S2. Off-line sampling integration test wired to the
> harness in `token-budget-harness.md`.

## Setup

A representative mid-size artifact (5–10 KB) with a controllable number of CRITICAL findings.

## Single-pass baseline

Run a single `/gaia-val-validate` invocation against the artifact with NO findings present. Record `tokens_consumed` as the baseline `B`.

## 3-iteration loop sample

Run a 3-iteration auto-fix loop (e.g., the VCP-FIX-07 thrash setup is convenient because it deterministically runs all 3 iterations). For each iteration `i`, record `tokens_consumed[i]`.

## Assertions

- For every iteration `i ∈ {1, 2, 3}`: `tokens_consumed[i] <= 2 * B` (per-iteration ≤ 2x baseline).
- `tokens_consumed[1] + tokens_consumed[2] + tokens_consumed[3] <= 6 * B` (total ≤ 6x baseline).
- If the runtime token-counting primitive is unavailable (`tokens_consumed = null`), the harness records "measurement unavailable" and the assertion falls back to the off-line sample (AC-EC8). The loop itself MUST proceed normally.
