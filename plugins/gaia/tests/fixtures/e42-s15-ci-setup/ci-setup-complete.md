---
template: 'ci-setup'
version: 1.0.0
date: "2026-04-25"
---

# CI Setup — Sample Project (E42-S15 fixture, all 6 SV items satisfied)

## CI Platform

GitHub Actions confirmed by user.

## Pipeline Stages

The pipeline defines the following stages:

- build
- lint
- test
- coverage

## Quality Gates

Quality gate thresholds:

- Minimum coverage threshold: 80%
- Test pass rate threshold: 100%

Gates are enforced (blocking, not advisory).

## Secrets Management

Required secrets and environment separation are documented:

- `STAGING_DEPLOY_TOKEN` — staging environment
- `PRODUCTION_DEPLOY_TOKEN` — production environment

## Deployment Strategy

Deployment is staged: staging → production → rollback procedure.

- staging: auto-deploy on merge after gates pass
- production: manual approval gate
- rollback: revert merge commit and re-deploy previous tag

## Monitoring and Notifications

Failure alerts configured via Slack webhook. Status badge added to README.

## Pipeline Config

Generated `.github/workflows/ci.yml` with all stages above.
