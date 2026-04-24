---
template: 'test-plan'
version: 1.0.0
date: "2026-04-24"
---

# Test Plan — Sample Project (E42-S14 fixture, missing SV-06)

## Test Strategy

Apply the test pyramid: unit / integration / e2e / end-to-end. Test levels are
defined per component.

## Risk Assessment

Risk register with probability and impact ratings:

| Risk | Probability | Impact |
|------|-------------|--------|
| R1   | High        | High   |

## Coverage

Coverage targets:

- Unit coverage target: 85%

## Test Environments

Local, staging, prod.

## Test Cases

| ID    | Type | Validates |
|-------|------|-----------|
| TC-01 | Unit | FR-001    |

<!-- E42-S14 negative fixture — SV-06 anchor absent on purpose. -->
