---
template: 'story'
version: 1.4.0
key: "FIX-CLEAN-01"
title: "Clean fixture story — trivial skill conversion for review-gate validation"
epic: "FIX — Cluster 19 Review-Gate Fixtures"
status: review
priority: "P2"
size: "S"
points: 2
risk: "low"
sprint_id: "fixture-sprint"
date: "2026-04-17"
author: "Nate (Scrum Master)"
fixture_profile: clean
---

# Story: Clean fixture story

> **Epic:** FIX — Cluster 19 Review-Gate Fixtures
> **Priority:** P2
> **Status:** review
> **Date:** 2026-04-17
> **Fixture Profile:** clean (all 6 reviews expected to PASS)

## User Story

As the Cluster 19 review-gate harness, I want a defect-free fixture story whose implementation passes all 6 review types, so that AC4 of E28-S134 can verify the `review → done` state-machine transition on an unambiguous all-PASS signal.

## Acceptance Criteria

- [x] **AC1:** Given a trivial `add(a, b)` utility, when called with two numbers, then it returns their sum.
- [x] **AC2:** Given invalid inputs (`null`, `undefined`, non-number), when called, then it throws a typed `TypeError`.

## Implementation Notes

```typescript
// src/add.ts — clean, minimal, fully tested.
export function add(a: number, b: number): number {
  if (typeof a !== 'number' || typeof b !== 'number') {
    throw new TypeError('add(): arguments must be numbers');
  }
  return a + b;
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
- [x] All tests pass
- [x] No hardcoded secrets
