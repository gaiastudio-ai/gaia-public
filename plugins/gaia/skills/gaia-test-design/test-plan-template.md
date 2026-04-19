---
template: 'test-plan'
version: 1.0.0
used_by: ['gaia-test-design']
---

# Test Plan: {feature_name}

> **Project:** {project_name}
> **Date:** {date}
> **Author:** {agent_name}

## Scope

{What is being tested and what is out of scope.}

## Risk Assessment

| Area | Risk Level | Probability | Impact | Coverage Strategy |
|------|-----------|-------------|--------|------------------|
| {area} | {H/M/L} | {H/M/L} | {H/M/L} | {approach} |

## Test Pyramid

### Unit Tests

| Component | Tests | Priority |
|-----------|-------|----------|
| {component} | {description} | {P0-P2} |

### Integration Tests

| Integration | Tests | Priority |
|-------------|-------|----------|
| {integration point} | {description} | {P0-P2} |

### E2E Tests

| Scenario | Steps | Priority |
|----------|-------|----------|
| {user flow} | {description} | {P0-P2} |

## Legacy Integration Boundaries

{If brownfield: contract tests, adapter tests, migration validation tests, consistency tests. If greenfield: N/A.}

## Test Data

{Required test data, fixtures, or mocks.}

## Environment

{Test environment requirements and setup.}

## Quality Gates

- [ ] Unit test coverage >= {target}%
- [ ] All P0 scenarios passing
- [ ] No critical defects open
- [ ] Performance within budget
- [ ] Integration test pass rate >= {target}%
