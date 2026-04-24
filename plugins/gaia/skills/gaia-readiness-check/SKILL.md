---
name: gaia-readiness-check
description: Validate implementation readiness by checking all planning and testing artifacts for completeness, consistency, and cross-artifact contradictions — Cluster 6 architecture skill. Enforces two mandatory quality gates (traceability-matrix.md and ci-setup.md must exist) per ADR-042, then delegates readiness assessment to the architect and devops subagents.
context: fork
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Agent]
---

## Setup

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-readiness-check/scripts/setup.sh

## Memory

!${CLAUDE_PLUGIN_ROOT}/scripts/memory-loader.sh architect all
!${CLAUDE_PLUGIN_ROOT}/scripts/memory-loader.sh devops decision-log

## Mission

Validate that all upstream planning, architecture, testing, and CI artifacts are complete, consistent, and free of cross-artifact contradictions before implementation begins. This skill enforces two mandatory quality gates — `traceability-matrix.md` and `ci-setup.md` must exist — and produces a machine-readable readiness report with PASS/FAIL/CONDITIONAL PASS status.

This skill is the native Claude Code conversion of the legacy `_gaia/lifecycle/workflows/3-solutioning/implementation-readiness` workflow (brief Cluster 6, story P6-S4 / E28-S48). The step ordering, gate enforcement, and output path are preserved from the legacy `instructions.xml`.

## Critical Rules

- Both quality gates are **mandatory** per ADR-042 — there is no "single gate" fallback, no env-var bypass, and no flag to make either gate optional. Partial-pass is a bug.
- `traceability-matrix.md` MUST exist at `docs/test-artifacts/traceability-matrix.md`. If missing, HALT with: "Gate failed: traceability-matrix.md not found. Run /gaia-trace to generate the traceability matrix."
- `ci-setup.md` MUST exist at `docs/test-artifacts/ci-setup.md`. If missing, HALT with: "Gate failed: ci-setup.md not found. Run /gaia-ci-setup to configure the CI pipeline."
- Check ALL artifacts — do not stop at first failure (except for the mandatory gates which halt immediately).
- If the traceability matrix declares its own gate as BLOCKED or FAIL, the readiness report MUST NOT declare traceability_complete: true.
- Output must include a machine-readable PASS/FAIL gate report in YAML frontmatter.
- Architecture assessment is delegated to the `architect` subagent (Theo) via native Claude Code subagent invocation.
- Operational readiness assessment is delegated to the `devops` subagent (Soren) via native Claude Code subagent invocation.

## Steps

### Step 1 — Load All Artifacts

- Read `docs/planning-artifacts/prd.md` — extract requirements (functional and non-functional).
- Read `docs/planning-artifacts/ux-design.md` if available — extract UI requirements.
- Read `docs/planning-artifacts/architecture.md` — extract architecture decisions and components.
- Read `docs/planning-artifacts/epics-and-stories.md` — extract story coverage.
- Read `docs/test-artifacts/traceability-matrix.md` — extract requirement coverage summary.
- Read `docs/test-artifacts/ci-setup.md` — extract pipeline quality gates summary.
- Read `docs/test-artifacts/test-plan.md` if exists — extract risk assessment.
- Read `docs/planning-artifacts/threat-model.md` if exists — extract security requirements.
- Read `docs/planning-artifacts/infrastructure-design.md` if exists — extract deployment topology.
- Note any missing artifacts immediately.

> `!scripts/write-checkpoint.sh gaia-readiness-check 1 project_name="$PROJECT_NAME" gate_status=pending artifacts_inspected_count="$ARTIFACTS_INSPECTED_COUNT" stage=load`

### Step 2 — Completeness Check

- Verify each document exists and has all required sections.
- PRD: overview, personas, requirements, NFRs, journeys, data, integrations, constraints, criteria.
- Architecture: stack, system design, data, API, infrastructure.
- Epics: at least 1 epic with stories, all stories have AC.

> `!scripts/write-checkpoint.sh gaia-readiness-check 2 project_name="$PROJECT_NAME" gate_status=pending artifacts_inspected_count="$ARTIFACTS_INSPECTED_COUNT" stage=completeness`

### Step 3 — Consistency Check

- Verify stories trace to PRD requirements.
- Verify architecture covers all functional areas.
- Verify prd.md contains a "## Review Findings Incorporated" section.
- Verify architecture.md contains a "## Review Findings Incorporated" section.
- Check for terminology consistency across documents.

> `!scripts/write-checkpoint.sh gaia-readiness-check 3 project_name="$PROJECT_NAME" gate_status=pending artifacts_inspected_count="$ARTIFACTS_INSPECTED_COUNT" stage=consistency`

### Step 4 — Cross-Artifact Contradiction Check

Delegate architecture-related contradiction analysis to the **architect** subagent (Theo) via `agents/architect`:

- CHECK 1 — Architecture vs Threat Model (skip if threat-model.md does not exist).
- CHECK 2 — Architecture vs Infrastructure Design (skip if infrastructure-design.md does not exist). Delegate infrastructure topology validation to the **devops** subagent (Soren) via `agents/devops`.
- CHECK 3 — Architecture vs Stories.
- CHECK 4 — PRD NFRs vs Architecture.
- CHECK 5 — Threat Model vs Stories (skip if threat-model.md does not exist).
- CHECK 6 — Auth Strategy Alignment.

Record all contradictions in a structured list with contradiction_id, type, source_artifacts, description, authority_agent, severity (BLOCKING/WARNING), and recommended_resolution.

> `!scripts/write-checkpoint.sh gaia-readiness-check 4 project_name="$PROJECT_NAME" gate_status=pending artifacts_inspected_count="$ARTIFACTS_INSPECTED_COUNT" stage=contradictions contradiction_count="$CONTRADICTION_COUNT"`

### Step 5 — TEA Readiness

- TECHNICAL: Evaluate team expertise against chosen stack.
- ESTIMATION: Check story point estimates for completeness.
- ARCHITECTURE: Count ADRs, check for unresolved proposals.
- TESTING: Verify test strategy is defined and AC are testable.

> `!scripts/write-checkpoint.sh gaia-readiness-check 5 project_name="$PROJECT_NAME" gate_status=pending artifacts_inspected_count="$ARTIFACTS_INSPECTED_COUNT" stage=tea`

### Step 6 — Test Infrastructure Readiness

- Verify traceability-matrix.md covers all PRD requirements.
- Extract the traceability matrix's own gate decision.
- Extract the test implementation rate.
- Verify ci-setup.md defines enforced quality gates.
- Verify test-plan.md exists.

> `!scripts/write-checkpoint.sh gaia-readiness-check 6 project_name="$PROJECT_NAME" gate_status=pending artifacts_inspected_count="$ARTIFACTS_INSPECTED_COUNT" stage=test-infra`

### Step 7 — Security Readiness

- Verify security requirements are documented in PRD.
- Verify authentication/authorization is defined in architecture.
- Verify data privacy requirements are addressed.
- Compliance timeline estimation.

> `!scripts/write-checkpoint.sh gaia-readiness-check 7 project_name="$PROJECT_NAME" gate_status=pending artifacts_inspected_count="$ARTIFACTS_INSPECTED_COUNT" stage=security`

### Step 8 — Operational Readiness

Delegate operational readiness assessment to the **devops** subagent (Soren) via `agents/devops`:

- Rollback: Is a rollback procedure documented?
- Observability: Are logging, metrics, and alerting requirements defined?
- Release strategy: Is the deployment approach defined?

> `!scripts/write-checkpoint.sh gaia-readiness-check 8 project_name="$PROJECT_NAME" gate_status=pending artifacts_inspected_count="$ARTIFACTS_INSPECTED_COUNT" stage=operational`

### Step 9 — Brownfield Completeness Check (optional)

- Skip if `docs/planning-artifacts/brownfield-onboarding.md` does not exist.
- Verify brownfield-specific artifacts (dependency-map, nfr-assessment, api-documentation).

> `!scripts/write-checkpoint.sh gaia-readiness-check 9 project_name="$PROJECT_NAME" gate_status=pending artifacts_inspected_count="$ARTIFACTS_INSPECTED_COUNT" stage=brownfield`

### Step 10 — Generate Gate Report

Write the readiness report to `docs/planning-artifacts/readiness-report.md` with YAML frontmatter containing machine-readable PASS/FAIL status for each check area.

> `!scripts/write-checkpoint.sh gaia-readiness-check 10 project_name="$PROJECT_NAME" gate_status="$GATE_STATUS" artifacts_inspected_count="$ARTIFACTS_INSPECTED_COUNT" stage=report --paths docs/planning-artifacts/readiness-report.md`

### Step 11 — Adversarial Review

Invoke an adversarial review of the readiness report for critical scrutiny.

> `!scripts/write-checkpoint.sh gaia-readiness-check 11 project_name="$PROJECT_NAME" gate_status="$GATE_STATUS" artifacts_inspected_count="$ARTIFACTS_INSPECTED_COUNT" stage=adversarial`

### Step 12 — Incorporate Adversarial Findings

Update the readiness report with adversarial review findings. If any Critical findings exist, set status to FAIL.

> `!scripts/write-checkpoint.sh gaia-readiness-check 12 project_name="$PROJECT_NAME" gate_status="$GATE_STATUS" artifacts_inspected_count="$ARTIFACTS_INSPECTED_COUNT" stage=incorporate --paths docs/planning-artifacts/readiness-report.md`

## Finalize

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-readiness-check/scripts/finalize.sh
