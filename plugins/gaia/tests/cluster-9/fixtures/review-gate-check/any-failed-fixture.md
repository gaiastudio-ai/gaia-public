---
template: 'story'
version: 1.4.0
used_by: ['create-story']
key: "any-failed"
title: "Review Gate Check fixture — at least one row FAILED"
epic: "E58 — V1 Parity for run-all-reviews"
status: review
priority: "P1"
size: "S"
points: 1
risk: "low"
sprint_id: "sprint-fixture"
priority_flag: null
origin: null
origin_ref: null
depends_on: []
blocks: []
traces_to: []
date: "2026-04-28"
author: "E58-S4 fixture"
---

# Story: Review Gate Check fixture — at least one row FAILED

> **Epic:** E58 — V1 Parity for run-all-reviews
> **Priority:** P1
> **Status:** review
> **Date:** 2026-04-28
> **Author:** E58-S4 fixture

## User Story

As a regression fixture for `review-gate.sh review-gate-check`, I exercise the BLOCKED branch (exit 1) by mixing PASSED, FAILED, and UNVERIFIED rows. FAILED dominates — exit code MUST be 1 regardless of how many other rows are PASSED or UNVERIFIED.

## Acceptance Criteria

- [x] AC1: At least one Review Gate row uses the canonical token `FAILED`.
- [x] AC2: Mix of `PASSED` and `UNVERIFIED` rows present alongside the FAILED row, so the test exercises FAILED dominance over PENDING.

## Tasks / Subtasks

- [x] Task 1: Author the any-FAILED fixture.

## Dev Notes

- Used by `tests/cluster-9/review-gate-check-wiring.bats` (E58-S4, AC2).
- The mix is intentional: 2 PASSED + 1 FAILED + 3 UNVERIFIED — this is the canonical "FAILED dominates PENDING" test (per ADR-054 dominance rules in `review-gate.sh::classify_review_gate`).

## Technical Notes

- The Review Gate table column ordering (`Review | Status | Report`) matches the bundled story template and is what `review-gate.sh::load_canonical_rows` parses.

## Dependencies

None.

## Test Scenarios

| # | Scenario | Input | Expected |
|---|----------|-------|----------|
| 1 | Any-FAILED gate | This fixture | `review-gate.sh review-gate-check` exits 1 |

## Dev Agent Record

### Agent Model Used

Test Fixture

### Debug Log References

### Completion Notes List

### File List

## Findings

> Out-of-scope issues discovered during implementation. Each finding becomes a candidate for a backlog story.

| # | Type | Severity | Finding | Suggested Action |
|---|------|----------|---------|-----------------|
| — | — | — | — | — |

> **Types:** bug, tech-debt, enhancement, missing-setup, documentation
> **Severity:** critical, high, medium, low

## Review Gate

| Review | Status | Report |
|--------|--------|--------|
| Code Review | PASSED | — |
| QA Tests | UNVERIFIED | — |
| Security Review | FAILED | — |
| Test Automation | UNVERIFIED | — |
| Test Review | PASSED | — |
| Performance Review | UNVERIFIED | — |

> Story moves to `done` only when ALL reviews show PASSED.

## Estimate

- **Points:** 1

## Definition of Done

### Acceptance

- [x] All acceptance criteria verified and checked off
- [x] All subtasks marked complete
