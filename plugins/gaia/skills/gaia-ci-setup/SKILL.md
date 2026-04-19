---
name: gaia-ci-setup
description: Scaffold a CI pipeline with quality checks. Use when "setup CI pipeline" or /gaia-ci-setup.
argument-hint: "[--preset solo|small-team|standard|enterprise|custom]"
allowed-tools: [Read, Grep, Glob, Bash, Write, Edit]
---

## Setup

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-ci-setup/scripts/setup.sh

## Mission

You are scaffolding a CI/CD pipeline for the project. You detect the CI platform, select a promotion chain preset (or build a custom chain), define pipeline quality gates, configure secrets management, set deployment strategy, and generate the pipeline configuration file.

This skill is the native Claude Code conversion of the legacy `_gaia/testing/workflows/ci-setup` workflow (Cluster 11, story E28-S86, ADR-042). It follows the canonical skill pattern established by E28-S66 (code-review).

**Write context:** This skill uses `allowed-tools: Read Grep Glob Bash Write Edit` because it writes pipeline configuration files and modifies `global.yaml`.

**Foundation script integration (ADR-042):** This skill relies on `validate-gate.sh` from `plugins/gaia/scripts/` as a dependency check in `setup.sh` (the foundation script must be present and executable before the skill body runs). The skill's `finalize.sh` does NOT post-check `ci_setup_exists` — removed by E28-S199, since this skill is the producer of `docs/test-artifacts/ci-setup.md` and a post-check on the producer's own output is tautological (success path) or misleading (failure path). Deterministic operations (config resolution, gate verification) belong in bash scripts, not LLM prompts.

## Critical Rules

- Knowledge fragments are bundled in this skill's `knowledge/` directory -- load them JIT when referenced by a step.
- Before scaffolding, check for existing CI config files (`.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile`, `.circleci/config.yml`). If found, warn the user and offer to merge or overwrite rather than silently replacing (AC-EC1).
- The `validate-gate.sh` foundation script (E28-S15) MUST be present and executable at `plugins/gaia/scripts/validate-gate.sh`. If missing or not executable, HALT with: "validate-gate.sh not found or not executable -- dependency E28-S15 must be installed first" (AC-EC3, AC-EC5).
- The `resolve-config.sh` foundation script (E28-S19) MUST be present and executable. If missing, HALT with dependency error.
- The promotion chain written to `global.yaml` MUST use the canonical field order: id, name, branch, ci_provider, merge_strategy, ci_checks (AC4, ADR-033).
- Pipeline configuration MUST include quality gate checks: lint, unit, test at minimum.
- Sprint-status.yaml is NEVER written by this skill (Sprint-Status Write Safety rule).

## Steps

### Step 1 -- Detect CI Platform

- Scan for existing CI config files in the project: `.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile`, `.circleci/config.yml`.
- If existing config found: warn the user and present options -- merge with existing, overwrite, or abort (AC-EC1).
- If no config found: note that no existing CI platform was detected.
- Ask which CI platform to use: GitHub Actions, GitLab CI, Jenkins, CircleCI, or other.

### Step 2 -- Preset Selection (Promotion Chain)

- Check if `ci_cd.promotion_chain` already exists in `global.yaml`.
- If it exists: warn user and offer [o]verwrite / [s]kip / [e]dit (redirect to `/gaia-ci-edit`).
- Present the 4 canonical presets: solo, small-team, standard, enterprise, plus custom.
- In YOLO mode: auto-select `standard` preset.
- For custom: prompt for each environment field (id, name, branch, ci_provider, merge_strategy, ci_checks).
- Write the selected chain to `global.yaml` preserving all existing fields.

### Step 3 -- Define Pipeline

- Configure build, lint, test, coverage, and deploy gates.
- Map gates to the selected CI platform's syntax.

### Step 4 -- Quality Gates

- Load knowledge fragment: `knowledge/contract-testing.md` for consumer-driven contract patterns in CI pipelines
- Define pass/fail thresholds: coverage percentage, test pass rate.
- Configure gate enforcement (blocking vs advisory).

### Step 5 -- Secrets Management

- Identify required secrets from architecture and PRD.
- Document how to add secrets to the selected CI platform.
- Define environment-level separation for staging vs production secrets.

### Step 6 -- Deployment Strategy

- Define staging deployment: auto-deploy on merge after gates pass.
- Define production deployment: manual approval gate.
- Define rollback procedure.

### Step 7 -- Monitoring and Notifications

- Configure pipeline failure notifications.
- Add pipeline status badge for README.
- Recommend metrics dashboard for pipeline health.

### Step 8 -- Generate Pipeline Config

- Generate the CI config file (e.g., `.github/workflows/ci.yml`) for the selected platform.
- Validate the generated config syntax.

### Step 9 -- Generate Output

- Generate the CI/CD pipeline configuration document at `docs/test-artifacts/ci-setup.md`.
- Include: pipeline stages, quality gates, secrets management, deployment strategy, monitoring setup.

## Finalize

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-ci-setup/scripts/finalize.sh
