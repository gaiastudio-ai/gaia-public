---
template: 'story'
version: 1.4.0
used_by: ['create-story']
key: "E28-S198"
title: "Register prd_exists gate in validate-gate.sh to unblock gaia-add-feature setup"
epic: "E28 — GAIA Native Conversion Program"
status: in-progress
priority: "P1"
size: "S"
points: 2
risk: "low"
sprint_id: null
priority_flag: "release-ready-flip"
origin: "audit-followup"
origin_ref: "E28-S197 triage — docs/implementation-artifacts/E28-S197-b5-triage-findings.md"
depends_on: ["E28-S197"]
blocks: ["release-ready-unconditional-go"]
traces_to: ["ADR-042", "FR-323"]
date: "2026-04-19"
author: "sm"
---

# Story: Register `prd_exists` gate in validate-gate.sh

> **Epic:** E28
> **Priority:** P1 (flips release-ready CONDITIONAL GO → UNCONDITIONAL GO)
> **Status:** ready-for-dev
> **Date:** 2026-04-19
> **Author:** sm (E28-S197 fix-story backlog — #1)

## Problem Statement

E28-S197 triage classified 1 of 8 B5 residuals as a **SkillBug**: `gaia-add-feature/setup.sh` calls `validate-gate.sh prd_exists`, but the gate is not registered — `SUPPORTED_GATES` in `plugins/gaia/scripts/validate-gate.sh` declares 7 gates and `prd_exists` is not among them. Setup halts with a generic "prd.md not found" HALT message that masks the real root cause (`unknown gate type: prd_exists`).

Symptomatically, the skill looks broken against a fresh v2 fixture. Functionally, the fix is mechanical: register the gate and the skill's existing call resolves.

Per the E28-S197 release-ready go/no-go recommendation: this is the ONE outstanding fix that flips the decision from CONDITIONAL GO to UNCONDITIONAL GO. Ship it, and early-adopter release can proceed without a "known limited skills" list for this class of bug.

### Repro

```
$ cd /tmp/fresh-v2-fixture
$ plugins/gaia/skills/gaia-add-feature/scripts/setup.sh
gaia-add-feature/setup.sh: prd.md not found (validate-gate prd_exists failed)
```

Actual root cause visible with `set -x`:

```
+ validate-gate.sh prd_exists
validate-gate: unknown gate type: prd_exists
+ exit 1
```

## User Story

As a **user invoking `/gaia:gaia-add-feature` on a freshly migrated v2 project that already has a PRD**, I want **the skill's setup prereq check to actually validate PRD existence** (not halt on a gate-registration bug), so that **I can triage a new feature request without first having to read the validate-gate source code**.

## Acceptance Criteria

- [x] **AC1:** `plugins/gaia/scripts/validate-gate.sh` registers `prd_exists` as a supported gate in `SUPPORTED_GATES`.
- [x] **AC2:** The `prd_exists` gate resolves the PRD path against `${PLANNING_ARTIFACTS:-${PROJECT_ROOT:-.}/docs/planning-artifacts}/prd.md` and returns 0 if the file exists + is non-empty, non-zero otherwise. Matches the pattern established by `epics_and_stories_exists` and `test_plan_exists`.
- [x] **AC3:** The gate emits the same stable error-format string used by sibling gates ("validate-gate: prd_exists failed — expected: <absolute-path>") so existing error-parsing in skill scripts continues to work.
- [x] **AC4:** `validate-gate.sh --help` lists `prd_exists` in its gate enumeration.
- [x] **AC5:** `validate-gate.sh --list` emits `prd_exists` (matches the `--list` contract E28-S197 verified for the existing 7 gates).
- [x] **AC6:** New bats test file `plugins/gaia/tests/validate-gate-prd-exists.bats` (or extend the existing validate-gate.bats) asserts:
  - prd.md present + non-empty → exit 0
  - prd.md missing → exit non-zero + stable error string
  - prd.md present but zero-byte → exit non-zero (mirror the -s guard used by other gates)
  - `PLANNING_ARTIFACTS` env var override is honored
- [x] **AC7:** Re-running `scripts/audit-v2-migration.sh` on the enriched fixture shows `gaia-add-feature` transitions from FAIL → OK (bucket count drops from 8 to 7).
- [x] **AC8:** Full plugin bats suite passes (572+ tests from post-E28-S196 baseline). *(Verified: 578 passing / 0 failing — 572 baseline + 6 new prd_exists tests.)*

## Tasks / Subtasks

- [x] **Task 1 — Register the gate (AC: 1, 2, 3)**
  - [x] 1.1 Edit `plugins/gaia/scripts/validate-gate.sh`:
    - Add `prd_exists` to `SUPPORTED_GATES` (the CSV at top of file, referenced by E28-S197 findings at line ~65).
    - Add a `prd_exists)` branch to the `gate_path()` case block that returns `${PLANNING_ARTIFACTS:-${PROJECT_ROOT:-.}/docs/planning-artifacts}/prd.md`.
    - Wire the -s non-empty guard (same pattern as `traceability_exists`, `test_plan_exists`).
  - [x] 1.2 Re-run `validate-gate.sh --list` to confirm the new gate appears.

- [x] **Task 2 — Bats regression (AC: 6)**
  - [x] 2.1 Author `plugins/gaia/tests/validate-gate-prd-exists.bats` (or extend existing bats file) with the 4 scenarios in AC6.
  - [x] 2.2 Use the same fixture pattern as existing validate-gate tests.

- [x] **Task 3 — Docs (AC: 4, 5)**
  - [x] 3.1 Update `--help` output in `validate-gate.sh` to include `prd_exists`.
  - [x] 3.2 Update any inline documentation comment at the top of the file.

- [x] **Task 4 — Audit harness green verification (AC: 7)**
  - [x] 4.1 Run `bash gaia-public/scripts/audit-v2-migration.sh` on a fresh /tmp/ fixture.
  - [x] 4.2 Confirm `gaia-add-feature` row is OK. B5 count should drop to 7.

- [x] **Task 5 — Full suite verification (AC: 8)**
  - [x] 5.1 Run the full plugin bats suite. All 572+ pass.

## Dev Notes

- **Do NOT modify `gaia-add-feature/setup.sh`** — its `prd_exists` call is correct. The bug is the missing gate registration, not the call site.
- Follow the existing gate registration pattern exactly — look at `test_plan_exists` or `epics_and_stories_exists` as the reference implementation. Both live in the same case block.
- **Do NOT run `/gaia-migrate apply` against the reporter's workspace.** Use /tmp/ fixtures only for the audit harness invocation.
- **PR target:** `staging` on gaiastudio-ai/gaia-public. Standard /gaia-dev-story flow with YOLO + planning gate active.
- This is the quickest, highest-leverage fix in the triage backlog. Keep scope tight — don't expand into other gate fixes unless they're trivially wired to this one.

## Findings

No out-of-scope issues discovered. The change is a single append to four locations in `validate-gate.sh` (header comment, SUPPORTED_GATES CSV, `gate_path()` case, `print_usage()` heredoc) mirroring the pattern established by `epics_and_stories_exists`. The existing `gaia-add-feature/setup.sh` call site (line 62) needed no modification — the call `"$VALIDATE_GATE" prd_exists` is correct; only the gate registration was missing.

Observed during AC7 verification: in a /tmp/ fixture built with pre-created `prd.md` + `epics-and-stories.md` and invoked with PWD=fixture, the B5 count drops from 6 to 5 (not the 8 → 7 originally predicted). The delta is explained by E28-S197 findings §2a: `validate-gate.sh` uses PWD-relative artifact paths, so a richer PWD-matched fixture enriches additional skills past the bucket boundary. The core AC7 invariant — `gaia-add-feature` transitions FAIL → OK — holds unchanged, and the E28-S200 fixture-enrichment story will close the remaining gap.

## Definition of Done

- [x] All 8 ACs pass
- [x] `validate-gate.sh --list | grep prd_exists` returns non-empty
- [x] `gaia-add-feature` row in audit harness CSV is OK (was FAIL-B5)
- [x] Full plugin bats suite green (578 passing / 0 failing — 572 baseline + 6 new)
- [x] Code compiles — N/A (bash scripts; syntax validated by bats run)
- [x] All tests pass — 578/578 plugin bats tests green
- [x] All acceptance criteria met — AC1–AC8 all checked
- [x] No linting/formatting errors — shell script follows existing formatting
- [x] Code follows project conventions — new gate mirrors epics_and_stories_exists exactly
- [x] No hardcoded secrets or credentials
- [x] All subtasks marked complete
- [x] Documentation updated — --help heredoc and header comment block both include prd_exists
- [ ] PR merged to staging *(auto-checked by Step 16 on successful merge)*
