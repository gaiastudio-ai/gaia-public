# Edge case runbooks (AC-EC1..AC-EC10)

LLM-checkable runbooks for each AC-EC scenario in E44-S2. The
script-verifiable encoding side is covered by
`plugins/gaia/tests/e44-s2-val-auto-fix-loop-pattern.bats`.

## AC-EC1 (boundary) — Iteration 1 empty findings

**Setup:** clean artifact, zero verifiable claims, no findings.

**Run:** enter the loop; iteration 1 invokes Val; Val returns `findings: []`.

**Assert:** exactly 1 Val invocation; no fix applied; iteration log contains exactly 1 record (clean); skill proceeds.

## AC-EC2 (error) — Val invocation fails mid-loop

**Setup:** simulate Val timeout / subagent crash / model unavailable on iteration 2.

**Run:** iteration 1 returns CRITICAL → fix applied. Iteration 2 invocation fails before returning a `findings` array.

**Assert:** loop halts immediately with a clear error surfaced to the user; checkpoint preserved at the current iteration; no silent retry-as-success; the failed invocation does NOT count against the 3-cap (i.e., `iteration_number` for the final record is 2 with `revalidation_outcome = val_invocation_failed`, not `clean`).

## AC-EC3 (data) — Invalid prompt input

**Setup:** drive the loop to iteration 3 prompt state.

**Run:** user inputs (in order): empty string, single space, `q`, `1`, `yes`, then finally `c`.

**Assert:** the canonical prompt re-displays after each invalid input — character-for-character the same text; no implicit default selected; only on the final `c` does the loop continue.

## AC-EC4 (timing) — No-op fix diff (thrash)

Covered by VCP-FIX-07. See `vcp-fix-07-thrash.md`.

## AC-EC5 (concurrency) — Two parallel skill invocations

**Setup:** two upstream skills invoke the loop on the same `artifact_path` simultaneously, each with its own checkpoint.

**Run:** each skill executes its own loop. They write to distinct checkpoint paths.

**Assert:** each invocation has its own iteration counter; per-invocation logs are distinguishable by checkpoint path and timestamp; no cross-contamination of iteration numbers; no shared mutable loop state.

## AC-EC6 — Accept-as-is on artifact without `## Open Questions`

Covered by VCP-FIX-05 sub-case B. See `vcp-fix-05-accept-as-is.md`.

## AC-EC7 (security) — YOLO bypass attempt

**Setup:** harness simulates YOLO mode and attempts to auto-answer the iteration-3 prompt with `accept`.

**Run:** drive the loop to iteration 3. The harness injects an auto-answer.

**Assert:** the auto-answer is NOT honored. The loop logs an iteration record with `event_type = yolo_hard_gate_violation`. The loop HALTS and surfaces the violation to the user. The iteration-3 prompt remains the only path forward; there is no branch in the implementation that skips the prompt under YOLO.

## AC-EC8 (environment) — Token measurement unavailable

**Setup:** runtime in a configuration where the token-counting primitive is missing.

**Run:** execute a normal 2-iteration loop.

**Assert:** the loop completes successfully; each iteration record carries `tokens_consumed = null`; a single one-line "measurement unavailable" note is logged; AC5 verification falls back to the off-line sampling harness in `token-budget-harness.md`.

## AC-EC9 (error) — Artifact path missing at Val invocation

**Setup:** delete `artifact_path` between the upstream write step and the first Val invocation.

**Run:** loop attempts iteration 1.

**Assert:** the loop halts BEFORE invoking Val with a clear `artifact not found: {path}` error; checkpoint is preserved; no phantom iteration 1 record is created.

## AC-EC10 (boundary) — Iteration 1 only INFO findings

**Setup:** Val returns `findings` containing only INFO-severity entries on iteration 1.

**Run:** iteration 1 invokes Val; INFO findings returned.

**Assert:** loop exits without applying a fix; INFO findings are logged into the iteration record and surfaced to the user as informational notes; skill proceeds; NO iteration 2 occurs.
