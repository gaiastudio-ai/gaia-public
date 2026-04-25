# VCP-FIX-04 — User chooses "continue" after iteration 3

> Covers AC3 of E44-S2 (post-escape continue semantics). LLM-checkable.

## Setup

Continue from the post-iteration-3 prompt state of VCP-FIX-03.

## Steps — Sub-case A: continue → clean

1. User inputs `c` (or `continue`).
2. Skill applies one more fix and re-invokes Val (this is iteration 4).
3. Val returns `findings: []`.
4. Skill proceeds.

### Assertions A

- Iteration 4 record appended to checkpoint with `iteration_number = 4`.
- No additional prompt shown.
- Skill exits the loop normally.

## Steps — Sub-case B: continue → still findings

1. User inputs `c`.
2. Skill applies fix, re-invokes Val (iteration 4).
3. Val returns CRITICAL/WARNING again.
4. The iteration-3 prompt re-displays.
5. The 3-iteration cap is **not** re-armed — the user is the only escape.

### Assertions B

- Iteration 4 record appended.
- Same canonical prompt text presented again, identical to the first time.
- No implicit cap applied: the loop does not auto-halt at iteration 6 or any other number; only user `accept` or `abort` terminates the post-escape phase.
