---
key: "E28-QGE-03-high"
title: "High-risk fixture story (missing atdd)"
status: ready-for-dev
risk: "high"
sprint_id: "cluster-19-fixture"
---

# Story: High-risk fixture story (missing atdd)

> **Status:** ready-for-dev
> **Risk:** high

## User Story

Fixture-only. Exists solely to drive the `dev-story` pre-start gate that
requires `docs/test-artifacts/atdd-{story_key}.md` for high-risk stories.
The atdd artifact is deliberately absent from this fixture.

## Acceptance Criteria

- [ ] AC-FIXTURE: Gate halts dev-story invocation
