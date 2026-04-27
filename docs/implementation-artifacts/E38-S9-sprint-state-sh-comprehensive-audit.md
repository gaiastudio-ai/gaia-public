---
template: 'story'
version: 1.4.0
used_by: ['create-story']
key: "E38-S9"
title: "sprint-state.sh comprehensive audit + remediation plan"
epic: "E38 — Sprint Planning Quality Gates"
status: review
priority: "P0"
size: "M"
points: 5
risk: "high"
sprint_id: "sprint-28"
priority_flag: null
origin: "tech-debt-review"
origin_ref: "tech-debt-dashboard.md (2026-04-24) — A-090 / A-091 / TD-55 / sprint-27 manual recoveries (3x)"
depends_on: ["E38-S7", "E38-S8"]
blocks: []
traces_to: ["FR-SPQG-4", "NFR-SPQG-1", "ADR-055"]
date: "2026-04-24"
author: "Nate (Scrum Master)"
---

# Story: sprint-state.sh comprehensive audit + remediation plan

> **Status:** review

## Summary

End-to-end audit of `gaia-public/scripts/lib/sprint-state.sh` covering every
subcommand (`list`, `transition`, `reconcile`, `set-status`, `assign`,
`unassign`, `next`, `report`) against the canonical state machine
(`backlog → validating → ready-for-dev → in-progress → review → done`,
with `invalid` as a terminal off-ramp from `validating`). Land a single
remediation backlog (not the fixes themselves — those follow as separate
stories) covering: input validation, glob safety (FR-SPQG-4 / E38-S7),
transition target normalization (E38-S8), atomic writes, lock contention,
exit-code consistency, and bats coverage gaps.

## Acceptance Criteria

- [x] `docs/test-artifacts/sprint-state-sh-audit-report-2026-04.md` exists.
- [x] Every subcommand has: spec snippet, observed behavior, and pass/fail row.
      (See §3 Per-Subcommand Audit Matrix in audit report.)
- [x] All known recoveries from sprint-27 (3x manual recoveries / "PASSED"
      string written instead of "done") are listed with reproducers.
      (See §4 F-4 of audit report.)
- [x] Remediation backlog enumerates each follow-up story with
      target sprint and dependency on E38-S7 / E38-S8.
      (See §6 Remediation Backlog — 7 stories E38-S10..E38-S16.)
- [x] A-090 ("aging debt halt") and A-091 ("UNASSIGNED hard-gate") are
      cross-referenced — confirm whether they fold into existing stories or
      need new ones.
      (See §5 Action Item Cross-Reference — both A-090 and A-091 ruled
      out-of-scope of sprint-state.sh.)
- [x] At least one new bats coverage gap is captured per FR-SPQG-4.
      (10 bats gaps captured BG-1..BG-10 in audit report §4 F-8.)

## Definition of Done

- [x] Audit report drafted at
      `docs/test-artifacts/sprint-state-sh-audit-report-2026-04.md`.
- [ ] Audit report reviewed by Nate (SM) and Soren (DevOps). *(handed off
      to review via /gaia-dev-story status transition)*
- [x] Remediation stories enumerated (status=backlog placeholders) and
      linked to E38. *(creation handed to /gaia-add-stories per audit §6)*
- [x] Action items A-090 and A-091 ruled out-of-scope (see audit §5).

## Open Questions

- [x] Should the audit also cover `review-gate.sh` (closely paired with
      sprint-state transitions)? **Resolved YES** — light pass at audit §7;
      deeper review deferred to proposed E38-S17 (sprint-30).
- [x] Is there any state machine drift between `sprint-state.sh` and
      `status-sync` protocol consumers? **Open** — proposed E38-S15
      (sprint-30) will scan all callers and confirm.

## Subtasks

- [x] Read every code path in `sprint-state.sh` (1664 LOC).
- [x] Cross-reference subcommands against story spec.
- [x] Cross-reference against existing bats coverage (30 tests).
- [x] Document TD-55 reproducer with pre-fix vs post-fix behavior.
- [x] Identify bats coverage gaps (10 captured).
- [x] Cross-reference A-090 / A-091.
- [x] Light pass on `review-gate.sh`.
- [x] Draft remediation backlog (7 follow-up stories).
- [x] Write audit report.

## Implementation Notes

This is a **decision-artifact-only** story — no production code modified.
Sole deliverable is `docs/test-artifacts/sprint-state-sh-audit-report-2026-04.md`.

Notable findings (full list in audit report):

- **F-1 (HIGH):** the bats suite references a `blocked` state that does
  not appear in the canonical state machine (ADR-055 §10). Either the
  canonical list is incomplete or the bats fixtures are stale.
- **F-S1:** the story spec's enumeration of subcommands
  (`list / set-status / assign / unassign / next / report`) does not match
  the actually-implemented surface
  (`get / validate / transition / reconcile / lint-dependencies /
  record-escalation-override`). Likely spec drift.
- **F-4:** TD-55 (PASSED-instead-of-done) is verified fixed in E38-S8;
  reproducer documented per AC requirement.
- **F-7:** exit-code consistency — eight error classes collapsed into
  exit 1; recommend distinct codes (E38-S11 proposed).
- **F-8:** 10 bats coverage gaps captured; remediation in proposed E38-S10.
