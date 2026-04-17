---
template: 'story'
version: 1.4.0
key: "FIX-CRD-01"
title: "Code-review-defect fixture — planted over-long function"
epic: "FIX — Cluster 19 Review-Gate Fixtures"
status: review
priority: "P2"
size: "S"
points: 2
risk: "low"
sprint_id: "fixture-sprint"
date: "2026-04-17"
author: "Nate (Scrum Master)"
fixture_profile: code-review-defect
planted_defect:
  kind: code-quality
  signature: function-length-exceeds-100-lines
  review_expected_to_fail: code-review
---

# Story: Code-review-defect fixture

> **Epic:** FIX — Cluster 19 Review-Gate Fixtures
> **Priority:** P2
> **Status:** review
> **Date:** 2026-04-17
> **Fixture Profile:** code-review-defect (code-review expected to FAIL; others PASS)

## User Story

As the Cluster 19 review-gate harness, I want a fixture story whose implementation contains a single deterministic code-quality defect, so that AC5 of E28-S134 can verify the `review → in-progress` state-machine transition on a FAILED code-review row.

## Acceptance Criteria

- [x] **AC1:** Given the `processOrder` handler, when called, then it performs the order steps. *(implementation contains a deliberate over-long function — the code-review verdict is deterministically FAILED on size threshold.)*

## Implementation Notes

```typescript
// src/process-order.ts — DELIBERATELY over-long: 100+ lines, no decomposition.
// This is the planted code-quality defect. /gaia-code-review flags function length.
export function processOrder(order: unknown): void {
  // ... 100+ lines of unrefactored inline logic (kept in fixture comment-only stub) ...
}
```

## Review Gate

| Review | Status | Report |
|--------|--------|--------|
| Code Review | UNVERIFIED | — |
| QA Tests | UNVERIFIED | — |
| Security Review | UNVERIFIED | — |
| Test Automation | UNVERIFIED | — |
| Test Review | UNVERIFIED | — |
| Performance Review | UNVERIFIED | — |

## Definition of Done

- [x] All acceptance criteria verified
- [x] Planted defect is present and deterministic
