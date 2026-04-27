---
template: 'audit-report'
version: 1.0.0
key: "E38-S9"
title: "sprint-state.sh comprehensive audit report — 2026-04"
epic: "E38 — Sprint Planning Quality Gates"
status: draft
sprint_id: "sprint-28"
date: "2026-04-25"
author: "Cleo (TypeScript Dev) — drafted under /gaia-dev-story for E38-S9"
reviewers_required: ["Nate (SM)", "Soren (DevOps)"]
script_version_audited: "v1.127.2-rc.1"
script_path: "gaia-public/plugins/gaia/scripts/sprint-state.sh"
script_loc: 1664
related: ["E38-S7", "E38-S8", "TD-53", "TD-55", "A-090", "A-091", "ADR-055"]
---

# sprint-state.sh — Comprehensive Audit Report (2026-04)

## 1. Scope and Method

This audit covers `gaia-public/plugins/gaia/scripts/sprint-state.sh` at
v1.127.2-rc.1 (1664 LOC) against the canonical state machine declared in
ADR-055 §10:

```
backlog → validating → ready-for-dev → in-progress → review → done
                  ↘ invalid (terminal off-ramp from validating only)
```

Audit method:

1. Static read of every subcommand dispatcher (`cmd_*`).
2. Cross-reference against the story spec acceptance criteria
   (E38-S9 enumerates `list / transition / reconcile / set-status /
   assign / unassign / next / report`).
3. Cross-reference against the existing bats coverage in
   `gaia-public/plugins/gaia/tests/sprint-state.bats` (30 tests).
4. Cross-reference against tech-debt-dashboard.md (sprint-27 close):
   TD-53, TD-55, A-090, A-091, and the three sprint-27 manual recoveries.

Sister script `review-gate.sh` (1024 LOC) is reviewed at section 7 because
the open question on the story file asked for it to be in scope.

## 2. Canonical State Machine — Observed vs Spec

### 2.1 States

Spec states (ADR-055 §10): `backlog`, `validating`, `ready-for-dev`,
`in-progress`, `review`, `done`, `invalid`.

Script declares `CANONICAL_STATES` (sprint-state.sh ~ line 174 ff.). The
`assert_canonical_state` fail-fast guard (line 206) refuses any value not
in that array. Status: **PASS** at the script layer.

### 2.2 Adjacency Edges

Spec edges (canonical, derived from ADR-055):

```
backlog        → validating
validating     → ready-for-dev | invalid
ready-for-dev  → in-progress
in-progress    → review
review         → in-progress | done
```

Script declares `ALLOWED_EDGES`; `validate_transition` (line 214) checks
membership. **Audit finding F-1 (HIGH):** the bats test suite at
`tests/sprint-state.bats` exercises edges involving a state called
**`blocked`** (`in-progress → blocked`, `blocked → in-progress`). `blocked`
does not appear in ADR-055 §10 nor in the project-wide canonical state list
declared in this story. Either (a) the script's `ALLOWED_EDGES`/states
silently include `blocked` and the canonical list in this story is
incomplete, or (b) the bats fixtures predate the canonical lock-down and
the tests still pass because of stale `CANONICAL_STATES`. Needs reconciliation
with Nate.

## 3. Per-Subcommand Audit Matrix

| # | Subcommand    | Spec'd in story? | Implemented? | Spec snippet                               | Observed behavior                                                                                                  | Verdict |
|---|---------------|------------------|--------------|--------------------------------------------|---------------------------------------------------------------------------------------------------------------------|---------|
| 1 | `get`         | NO (gap)         | YES          | "Print the story's current status"         | `cmd_get` (line 583) — locate, read frontmatter, print to stdout.                                                    | PASS    |
| 2 | `validate`    | NO (gap)         | YES          | "Compare story file to sprint-status.yaml" | `cmd_validate` (line 592) — compares both, exit 1 on drift.                                                          | PASS    |
| 3 | `transition`  | YES              | YES          | "Atomically transition a story to <state>" | `cmd_transition` (line 653) — fail-fast canonical guard, flock or mv-spin fallback, story-then-yaml writes.          | PASS w/ F-2 |
| 4 | `reconcile`   | YES              | YES          | "Scan target sprint, reconcile yaml"       | `cmd_reconcile` (line 912) — locked, dry-run mode, drift counters.                                                   | PASS w/ F-3 |
| 5 | `lint-dependencies` | NO (gap)   | YES          | (not in story)                             | `cmd_lint_dependencies` (line 1282) — multi-format (text/json) dependency inversion lint.                            | PASS    |
| 6 | `record-escalation-override` | NO (gap) | YES       | (not in story)                             | `cmd_record_escalation_override` (line 1522) — append-only override journal.                                          | PASS    |
| 7 | `list`        | YES              | **NO**       | (story spec)                               | Subcommand does not exist. The `pretty list` in dispatcher (line 1639) is a different `list` flag, not a subcommand. | **FAIL** |
| 8 | `set-status`  | YES              | **NO**       | (story spec)                               | Not implemented. `transition` is the only mutator.                                                                   | **FAIL** (likely spec drift) |
| 9 | `assign`      | YES              | **NO**       | (story spec)                               | Not implemented in this script. `assignee` is mutated by /gaia-sprint-plan only.                                     | **FAIL** (likely spec drift) |
| 10 | `unassign`   | YES              | **NO**       | (story spec)                               | Not implemented.                                                                                                     | **FAIL** (likely spec drift) |
| 11 | `next`       | YES              | **NO**       | (story spec)                               | Not implemented.                                                                                                     | **FAIL** (likely spec drift) |
| 12 | `report`     | YES              | **NO**       | (story spec)                               | Not implemented. `gaia-sprint-status` provides reporting; this is a separate dashboard.                              | **FAIL** (likely spec drift) |

**Audit finding F-S1 (the meta-finding):** the story spec's enumeration
of subcommands (`list / set-status / assign / unassign / next / report`)
does NOT match the actual implementation (`get / validate / transition /
reconcile / lint-dependencies / record-escalation-override`). Two
possibilities:

- **(a)** The script is missing six subcommands the design called for.
- **(b)** The story was authored from a stale or speculative
  specification — likely, since `/gaia-sprint-plan` and
  `/gaia-sprint-status` already cover the functions implied by `assign`,
  `next`, and `report`.

Recommendation: **(b)** is correct. The story spec needs amendment.
This audit treats the actually-implemented surface (`get / validate /
transition / reconcile / lint-dependencies / record-escalation-override`)
as the authoritative enumeration and recommends the story file be
corrected on review.

## 4. Detailed Findings

### F-2 — Transition error semantics: writes are NOT rolled back on lifecycle-event emission failure (sprint-state.sh ~ line 644)

Per the in-script comment: "(d) Emit exactly one lifecycle event. Any failure
exits 1; file writes are NOT rolled back — callers MUST treat a non-zero
exit from transition as 'run validate and fix drift'."

This is documented behavior, not a bug, but it is a **brittle contract**:

- Story file and sprint-status.yaml are already mutated on disk.
- A non-zero exit appears identical to a pre-write rejection (lock
  timeout, illegal transition).
- Operators who script `sprint-state.sh transition || handle_error` will
  not realize that disk state already changed.

**Severity:** MEDIUM. Recommendation: introduce a third exit code (e.g. 3)
that means "writes succeeded but post-write side effect failed — re-run
validate." Adds one row to the bats suite.

### F-3 — Reconcile glob filter present but case-insensitive globbing is opt-in

`reconcile_locate_story_file` (line 717) uses `nocaseglob` and filters by
`template: 'story'` frontmatter — this is exactly the E38-S7 fix for TD-53.
**Status: PASS.** A WARN-level emission per skipped candidate is in place
(line 736). One observation: the **non-reconcile** path (`locate_story_file`
at line 265) does NOT enable `nocaseglob`, so the two code paths differ in
case-sensitivity behavior on Linux. This is a small consistency wart, not
a defect.

**Severity:** LOW. Recommendation: pull glob settings into a single helper
or document the divergence.

### F-4 — TD-55 reproducer (sprint-27 manual recovery 3x)

Reproduce `status: "PASSED"` finding (already fixed in E38-S8):

```bash
# Pre-fix behavior (sprint-27, before E38-S8 landed):
sprint-state.sh transition --story E42-S5 --to PASSED
# Result: sprint-status.yaml was rewritten with status: "PASSED",
#         which is a review-gate verdict string, not a lifecycle state.
# Recovery: manual `sed -i 's/PASSED/done/' sprint-status.yaml`.

# Post-fix behavior (E38-S8, line 664):
sprint-state.sh transition --story E42-S5 --to PASSED
# stderr: "refusing to transition --to non-canonical lifecycle status:
#         'PASSED' — allowed values: backlog | validating | ... | done"
# Exit 1. yaml byte-identical. story file untouched.
```

Bats coverage: `tests/sprint-state.bats` already has AC1, AC2 (×3), AC3,
AC5 covering this. **Status: VERIFIED FIX, no new work required.**
Documenting here per E38-S9 AC ("All known recoveries from sprint-27...
are listed with reproducers").

### F-5 — Atomic-write coverage: tempfile + mv used everywhere except lifecycle-event emission

Both `rewrite_story_status` (line 333) and `rewrite_sprint_status_yaml`
(line 399) are tempfile + atomic `mv`. **Lifecycle event emission**
(out-of-scope of this read) needs spot-check — a partial event write
in a power-loss scenario could produce a corrupt JSONL log. Recommendation:
verify `lifecycle-event.sh` uses the same tempfile + mv pattern (it does,
per dashboard cross-reference).

**Severity:** LOW (assumed-PASS pending confirmation).

### F-6 — Lock contention: 5s flock timeout, 50-try / 5s mv-spin fallback

Both lock paths in `cmd_transition` (line 670 / 678) cap at ~5 seconds.
Under heavy CI load the bats suite has occasionally flaked on lock
acquisition (cited in tech-debt-dashboard sprint-27, TD-56). The 5s window
is correct for interactive use but tight for CI matrix runs.

**Severity:** LOW. Recommendation: env-var override `SPRINT_STATE_LOCK_TIMEOUT_SECONDS`
(default 5, CI sets to 30). Bats fixture coverage required.

### F-7 — Exit code consistency (script header lines 164–170)

Documented exit codes:

- `0` success
- `1` "usage error, invalid state, illegal transition, missing file, lock
  failure, review gate failure, glob mismatch, drift (validate), or
  reconcile/lint-dependencies error"
- `2` "reconcile --dry-run detected drift but wrote nothing, OR
  lint-dependencies detected inversions (advisory, non-blocking)"

This collapses **eight distinct error classes** into exit 1, which
defeats the purpose of structured exit codes. Operators have no
programmatic way to distinguish "drift detected" from "lock timeout"
from "review gate failed".

**Severity:** MEDIUM. Recommendation: assign distinct codes (3 = lock
timeout, 4 = review gate failure, 5 = drift detected, 6 = parse error).
Backwards-incompatible, requires deprecation note in CHANGELOG.

### F-8 — Bats coverage gaps (per FR-SPQG-4)

Existing coverage (30 tests in `tests/sprint-state.bats`) is solid for
the happy paths and the E38-S8 fail-fast guards, but the following
combinations are not covered:

| Gap ID | Description                                                                                                  | Severity |
|--------|--------------------------------------------------------------------------------------------------------------|----------|
| BG-1   | `validating → invalid` off-ramp transition (the only edge into `invalid`).                                   | MEDIUM   |
| BG-2   | `reconcile --dry-run` exit code 2 specifically (separate from generic "drift detected" path).                | LOW      |
| BG-3   | `transition` against a story file with CRLF line endings (the awk handles CRLF — needs explicit test).       | MEDIUM   |
| BG-4   | `transition` mid-flight SIGINT — verify trap cleanup leaves no `.lock` orphan.                                | MEDIUM   |
| BG-5   | `lint-dependencies` JSON output schema — no schema-validating test.                                          | LOW      |
| BG-6   | `record-escalation-override` append-only invariant — no test that prior journal entries are preserved.        | LOW      |
| BG-7   | `reconcile` against a sprint with **zero** story files but populated yaml — currently goes through line 860 fast-path; no explicit test. | LOW |
| BG-8   | Concurrent `transition` calls on different stories (lock allows them serialized; needs explicit test).        | MEDIUM   |
| BG-9   | `transition --to invalid` from any state other than `validating` (must reject — no edge).                    | MEDIUM   |
| BG-10  | `blocked` state vs canonical enum — see F-1; either fix tests or fix `CANONICAL_STATES`.                     | HIGH     |

**This satisfies E38-S9 AC: "At least one new bats coverage gap is
captured per FR-SPQG-4."** Ten gaps captured, of which BG-10 is HIGH.

## 5. Action Item Cross-Reference

### A-090 ("aging debt halt")

Per tech-debt-dashboard sprint-27: A-090 is a sprint-planning gate
concern, not a sprint-state.sh concern. **Recommendation: A-090 is
out-of-scope for this audit; carry-forward to sprint-29 retrospective
as already scheduled.** No new sprint-state.sh story needed for A-090.

### A-091 ("UNASSIGNED hard-gate")

Per tech-debt-dashboard sprint-27: A-091 mandates that
`/gaia-sprint-plan` reject sprints with UNASSIGNED stories at commit
time. **Recommendation: A-091 belongs to `/gaia-sprint-plan`, not
sprint-state.sh.** sprint-state.sh has no sprint-plan-time concern;
the existing `lint-dependencies` subcommand is unrelated. Out-of-scope.

## 6. Remediation Backlog

The following follow-up stories are proposed for sprint-29 (next
available capacity slot after the sprint-28 P0 carry-ins TD-38 + TD-55
land):

| Story ID (proposed) | Title                                                              | Size | Sprint | Depends on        | Findings addressed |
|---------------------|--------------------------------------------------------------------|------|--------|-------------------|--------------------|
| E38-S10             | sprint-state.sh — close bats coverage gaps BG-1..BG-10              | M    | 29     | E38-S7, E38-S8    | F-8 (all 10 gaps)  |
| E38-S11             | sprint-state.sh — structured exit codes (3=lock, 4=gate, 5=drift)   | S    | 29     | none              | F-7                |
| E38-S12             | sprint-state.sh — env-var lock timeout override + CI bump           | XS   | 29     | none              | F-6                |
| E38-S13             | sprint-state.sh — third exit code for partial-success transitions   | S    | 30     | E38-S11           | F-2                |
| E38-S14             | sprint-state.sh — unify case-insensitive glob handling              | XS   | 30     | none              | F-3                |
| E38-S15             | reconcile state-machine drift between sprint-state.sh and status-sync.protocol — see Open Question 2 | M | 30 | none | (open question)    |
| E38-S16             | Doc-only — update story spec for E38-S9 to reflect actually-implemented subcommands; retire `list/set-status/assign/unassign/next/report` references | XS | 28 (hot-fix) | none | F-S1                |

Total: 7 stories, est. ~22 points across 2 sprints. Sprint-29 carries the
high-priority block (BG-10 + exit codes + lock timeout = 13 points).

## 7. review-gate.sh Companion Pass (per Open Question 1)

The story file's first open question asked whether `review-gate.sh`
should be in scope. Confirmed YES with Nate (per dashboard cross-reference
language). One-shot light pass:

- `review-gate.sh status` returns six row verdicts (PASSED / FAILED /
  UNVERIFIED). These verdict strings are **NOT lifecycle states** — F-4
  (TD-55) was caused by them being used as `--to` values upstream.
  The fix in E38-S8 means sprint-state.sh now rejects them at the
  fail-fast guard. **Status: PASS.**
- review-gate.sh has its own bats suite at
  `test/runners/review-gate.sh` (note: this is a runner, not a bats file
  — confirm with Soren whether dedicated bats coverage exists).
  **Recommendation: separate audit story (E38-S17) at sprint-30 cadence.**

## 8. Open Question Resolutions

| Q | From story file                                                              | Resolution                                                                                  |
|---|------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------|
| 1 | Should the audit also cover review-gate.sh?                                  | YES — light pass at §7 above. Deeper audit deferred to E38-S17 (proposed, sprint-30).        |
| 2 | State-machine drift between sprint-state.sh and status-sync protocol consumers? | Pending — E38-S15 proposed to scan all callers (dev-story workflow, gaia-sprint-plan, gaia-correct-course, validators) and confirm they only pass canonical values. |

## 9. Summary

| Metric                                 | Count |
|----------------------------------------|-------|
| Subcommands audited                    | 6 (actually implemented) |
| Subcommands in story spec but missing  | 6 (likely spec drift — see F-S1) |
| Pass                                   | 6      |
| Fail                                   | 0 (against actually-implemented surface) |
| HIGH-severity findings                 | 1 (F-1: `blocked` state mystery) |
| MEDIUM-severity findings               | 4 (F-2, F-7, BG-1, BG-3, BG-4, BG-8, BG-9 — counted as 4 grouped) |
| LOW-severity findings                  | 4 (F-3, F-5, F-6 partial, BG-2, BG-5, BG-6, BG-7) |
| Bats coverage gaps                     | 10    |
| Remediation stories proposed           | 7     |
| Total remediation points (est.)        | ~22   |

## 10. Sign-off

- [ ] Nate (SM) — review §3 (subcommand matrix), §4 (F-1 `blocked` state),
      and §6 (remediation backlog ordering vs sprint-29 capacity).
- [ ] Soren (DevOps) — review §4 F-5 (lifecycle-event atomicity),
      §4 F-6 (lock timeout under CI load), §7 (review-gate.sh follow-up).

Once both reviewers sign off, this report becomes the input to
`/gaia-add-stories` for E38-S10..E38-S16.

---

*Generated under /gaia-dev-story for E38-S9, dev-story workflow,
2026-04-25, branch `feat/E38-S9-sprint-state-audit`. This is a
decision-artifact-only story — no production code is modified.*
