# VCP-FIX-03 — Iteration 3 failure triggers user prompt

> Covers AC2 of E44-S2. LLM-checkable.

## Setup

Artifact with un-converging CRITICAL findings — every fix attempt produces a new (or the same) CRITICAL finding.

## Steps

1. Iteration 1: CRITICAL → fix applied → record.
2. Iteration 2: CRITICAL → fix applied → record.
3. Iteration 3: CRITICAL → fix applied → record. `iteration` becomes 4.
4. `iteration > 3` → HALT.
5. Display the canonical prompt verbatim:
   ```
   Iteration 3 of Val auto-fix did not converge. Choose: [c] Continue — apply next fix and re-send | [a] Accept as-is — record unresolved findings as open questions | [x] Abort — preserve checkpoint and exit
   ```

## Assertions

- Skill HALTS after iteration 3.
- The prompt is presented exactly once, character-for-character matching the canonical text.
- Exactly **3** options are surfaced — `[c]`, `[a]`, `[x]`.
- No 4th automatic Val invocation runs before user input is received.
- `checkpoint.custom.val_loop_iterations` contains exactly 3 records before the prompt.
