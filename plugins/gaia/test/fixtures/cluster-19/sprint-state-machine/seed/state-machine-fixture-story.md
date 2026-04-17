---
template: 'story'
version: 1.4.0
used_by: ['E28-S135']
key: "SSM-E2E-01"
title: "Sprint state machine E2E fixture — exercises all 7 states"
epic: "SSM — Cluster 19 Sprint State Machine Fixtures"
status: backlog
priority: "P2"
size: "S"
points: 1
risk: "low"
sprint_id: "fixture-sprint-ssm"
priority_flag: null
origin: null
origin_ref: null
depends_on: []
blocks: []
traces_to: ["FR-333"]
date: "2026-04-17"
author: "Nate (Scrum Master)"
fixture_profile: sprint-state-machine
---

# Story: Sprint state machine E2E fixture — exercises all 7 states

> **Epic:** SSM — Cluster 19 Sprint State Machine Fixtures
> **Priority:** P2
> **Status:** backlog
> **Date:** 2026-04-17
> **Fixture Profile:** sprint-state-machine (immutable canonical exercise story)

## User Story

As the Cluster 19 sprint-state-machine harness, I want an exercise story that can be traversed through all 7 canonical states so that E28-S135 can validate the native `sprint-state.sh` adjacency rules.

## Acceptance Criteria

- [ ] **AC1:** Fixture starts in `backlog`.
- [ ] **AC2:** Fixture can reach `done` via the happy-path sequence.
- [ ] **AC3:** Fixture supports rollback via the `review -> in-progress` branch.

## Tasks / Subtasks

- [ ] Task 1: Exercise all 7 states (AC: #1, #2, #3)

## Review Gate

| Review | Status | Report |
|--------|--------|--------|
| Code Review | PASSED | — |
| QA Tests | PASSED | — |
| Security Review | PASSED | — |
| Test Automation | PASSED | — |
| Test Review | PASSED | — |
| Performance Review | PASSED | — |

> Fixture intentionally has all 6 reviews PASSED so the `review -> done` transition can succeed during AC2 traversal. The fixture is reset to `backlog` between test runs.

## Estimate

- **Points:** 1
- **Developer:** Fixture only — not implemented
