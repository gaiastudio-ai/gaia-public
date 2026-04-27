---
template: 'ci-setup'
version: 1.0.0
date: "2026-04-25"
---

# CI Setup — Sample Project (E42-S15 negative fixture, missing secrets)

## CI Platform

GitHub Actions.

## Pipeline Stages

- build
- lint
- test
- coverage

## Quality Gates

Minimum coverage threshold: 80%.

## Deployment Strategy

staging → production → rollback.

## Monitoring and Notifications

Failure alerts and status badge.

## Pipeline Config

Generated `.github/workflows/ci.yml`.

(Intentionally omits the Secrets Management section — should fail SV-04.)
