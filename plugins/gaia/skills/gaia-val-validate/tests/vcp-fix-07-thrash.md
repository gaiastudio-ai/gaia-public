# VCP-FIX-07 — Thrash observability

> Covers AC4 and AC-EC4 of E44-S2. LLM-checkable.

## Setup

Artifact such that the upstream skill's fix attempt produces a byte-identical artifact (no-op fix), and Val returns the same findings on the next iteration.

## Steps

1. Iteration 1: Val returns CRITICAL → "fix" applied (byte-identical result) → record.
2. Iteration 2: Val returns identical CRITICAL → byte-identical "fix" → record.
3. Iteration 3: same → record.
4. Iteration-3 prompt presented per AC2.

## Assertions

- Each iteration record contains its own copy of `findings` and `fix_diff_summary` (the latter is empty or marked as a no-op for thrash iterations).
- Records are distinguishable by `iteration_number = 1, 2, 3`.
- A `"thrash"` warning is logged into iterations 2 and 3 (since iteration 1 has no prior to compare against).
- The thrash detection does NOT short-circuit the 3-cap; the loop runs all 3 iterations and only then presents the prompt.
