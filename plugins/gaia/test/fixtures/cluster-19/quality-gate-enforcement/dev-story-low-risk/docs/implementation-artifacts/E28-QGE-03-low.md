---
key: "E28-QGE-03-low"
title: "Low-risk fixture story (negative control)"
status: ready-for-dev
risk: "low"
sprint_id: "cluster-19-fixture"
---

# Story: Low-risk fixture story (negative control)

> **Status:** ready-for-dev
> **Risk:** low

## User Story

Fixture-only negative control. The `dev-story` atdd gate is scoped to
`risk: high` only. This fixture is `risk: low` and has no atdd artifact —
the gate must NOT fire, proving correct gate scoping.

## Acceptance Criteria

- [ ] AC-FIXTURE: Gate does NOT halt dev-story invocation
