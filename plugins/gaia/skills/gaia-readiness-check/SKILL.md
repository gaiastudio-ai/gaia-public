---
name: gaia-readiness-check
description: Validate implementation readiness by checking all planning and testing artifacts for completeness, consistency, and cross-artifact contradictions — Cluster 6 architecture skill. Enforces two mandatory quality gates (traceability-matrix.md and ci-setup.md must exist) per ADR-042, then delegates readiness assessment to the architect and devops subagents.
context: fork
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Agent]
# Discover-Inputs Protocol (ADR-062 / FR-346 / E45-S4)
# Strategy: INDEX_GUIDED — readiness-check cross-references many large
# upstream artifacts (PRD, architecture, test plan, epics/stories,
# traceability matrix, ci-setup, threat-model, infra-design). Load each
# artifact's index (heading scan) first; fetch named sections on demand
# during cross-reference checks. Falls back to FULL_LOAD when an artifact
# lacks parseable headings.
discover_inputs: INDEX_GUIDED
discover_inputs_target: "docs/planning-artifacts/prd.md, docs/planning-artifacts/architecture.md, docs/test-artifacts/test-plan.md, docs/planning-artifacts/epics-and-stories.md"
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

> **Loading strategy: INDEX_GUIDED per ADR-062.** Readiness-check
> cross-references up to nine large upstream artifacts — full-loading them
> all would routinely exceed 80K tokens. Heading-scan each artifact first
> (`grep -nE '^#{1,3} '`) to build a section index. The cross-reference
> checks in Steps 2-9 fetch named sections on demand (`sed -n` between
> heading anchors) — never the full body. If any artifact lacks parseable
> headings, fall back to FULL_LOAD for that file only and log the fallback
> in the checkpoint.

- Heading-scan `docs/planning-artifacts/prd.md` for the requirements section index (functional and non-functional).
- Heading-scan `docs/planning-artifacts/ux-design.md` if available for the UI-requirements section index.
- Heading-scan `docs/planning-artifacts/architecture.md` for architecture-decision and component section anchors.
- Heading-scan `docs/planning-artifacts/epics-and-stories.md` for the story-coverage section index.
- Heading-scan `docs/test-artifacts/traceability-matrix.md` for the requirement-coverage summary section.
- Heading-scan `docs/test-artifacts/ci-setup.md` for the pipeline quality-gates summary section.
- Heading-scan `docs/test-artifacts/test-plan.md` if exists for the risk-assessment section.
- Heading-scan `docs/planning-artifacts/threat-model.md` if exists for security-requirement section anchors.
- Heading-scan `docs/planning-artifacts/infrastructure-design.md` if exists for deployment-topology section anchors.
- Note any missing artifacts immediately. Section bodies are loaded on demand by Steps 2-9 via `sed -n` between heading anchors.

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

## Validation

<!--
  E42-S13 — V1→V2 65-item checklist port (FR-341, FR-359, VCP-CHK-25, VCP-CHK-26).
  Classification (65 items total — the highest-count skill in E42):
    - Script-verifiable: 25 (SV-01..SV-25) — enforced by finalize.sh.
    - LLM-checkable:     40 (LLM-01..LLM-40) — evaluated by the host LLM
      against the readiness-report.md artifact at finalize time.
  Exit code 0 when all 25 script-verifiable items PASS; non-zero otherwise.

  V1 source: _gaia/lifecycle/workflows/3-solutioning/implementation-readiness/
  (the V1 command `/gaia-readiness-check` is implemented by the
  `implementation-readiness` workflow — the directory is NOT literally named
  `readiness-check/`). The V1 `checklist.md` ships 52 explicit bullets across
  nine V1 categories (Artifacts, Consistency, Cross-Artifact Contradictions,
  TEA Readiness, Test Infrastructure, Security, Operational Readiness,
  Brownfield Completeness, Report, Output Verification). The story 65-item
  count is authoritative per docs/v1-v2-command-gap-analysis.md §14; the
  remaining 13 items are reconciled from V1 instructions.xml step outputs
  (story Task 1.3) and the V1 per-category step details:
    - per-artifact presence of each upstream file on disk
    - cross-artifact coherence (FR→story, NFR→test, ADR→component,
      epic→story, high-risk→ATDD, terminology consistency)
    - cascade-resolution (contradictions authority/resolution pairs,
      Pending Cascades "Resolved" column populated, no orphan edit
      propagations)
    - traceability (orphan requirements / orphan test cases flagged,
      implementation rate meets gate threshold, CI enforced gates)
    - sizing (numeric points, oversize split plans, ADR resolution
      state, adversarial findings incorporated, testable AC,
      quantified NFR, epic total vs capacity)
    - gate verdict (security / compliance / rollback / observability /
      release strategy / narrative coherence).

  V1 category coverage mapping (65 items):
    Artifact Presence           — SV-01..SV-05, LLM-01..LLM-05        (10)
    Cross-Artifact Coherence    — SV-06..SV-08, LLM-06..LLM-15        (13)
    Cascade Resolution          — SV-09..SV-11, LLM-16..LLM-23        (11)
    Traceability                — SV-12..SV-14, LLM-24..LLM-27        (7)
    Sizing & Velocity           — SV-15..SV-17, LLM-28..LLM-34        (10)
    Gate Verdict                — SV-18..SV-25, LLM-35..LLM-40        (14)
    Total                                                              65

  The VCP-CHK-26 anchor is SV-20 — "status field present in YAML
  frontmatter (PASS/FAIL/CONDITIONAL)". This is the V1 phrase anchor for
  "PASS/FAIL status clear" verbatim and MUST appear in violation output
  when the gate-verdict item fails (story AC2).

  Invoked by `finalize.sh` at post-complete (per §10.31.1). Validation
  runs BEFORE the checkpoint and lifecycle-event writes (observability
  is never suppressed by checklist outcome — story AC5, AC-EC6).

  LLM-checkable contract: each item carries a 30-second per-item
  wall-clock timeout (AC-EC7). If the LLM evaluator returns a malformed
  verdict (no explicit PASS/FAIL), the item is treated as FAIL with
  actionable guidance and evaluation continues with the next item
  (AC-EC4). Timeouts and malformed verdicts MUST NOT cause the skill
  to deadlock.

  See docs/implementation-artifacts/E42-S13-port-gaia-readiness-check-65-item-checklist-to-v2.md.
-->

- [script-verifiable] SV-01 [category: artifact presence] — Readiness report artifact exists
- [script-verifiable] SV-02 [category: artifact presence] — Readiness report artifact is non-empty
- [script-verifiable] SV-03 [category: artifact presence] — Referenced PRD file exists on disk (if referenced)
- [script-verifiable] SV-04 [category: artifact presence] — Referenced architecture file exists on disk (if referenced)
- [script-verifiable] SV-05 [category: artifact presence] — Referenced test-plan file exists on disk (if referenced)
- [script-verifiable] SV-06 [category: cross-artifact coherence] — Completeness section present (## Completeness heading)
- [script-verifiable] SV-07 [category: cross-artifact coherence] — Consistency section present (## Consistency heading)
- [script-verifiable] SV-08 [category: cross-artifact coherence] — Cross-Artifact Contradictions section present
- [script-verifiable] SV-09 [category: cascade resolution] — Pending Cascades section present if cascades tracked
- [script-verifiable] SV-10 [category: cascade resolution] — All Pending Cascades rows have Resolved column populated
- [script-verifiable] SV-11 [category: cascade resolution] — Contradictions table present in report body
- [script-verifiable] SV-12 [category: traceability] — Traceability matrix referenced (traceability-matrix.md mentioned)
- [script-verifiable] SV-13 [category: traceability] — Traceability complete field present in YAML frontmatter
- [script-verifiable] SV-14 [category: traceability] — Test implementation rate recorded
- [script-verifiable] SV-15 [category: sizing] — TEA Readiness section present (## TEA Readiness heading)
- [script-verifiable] SV-16 [category: sizing] — Estimation criteria referenced (points or story sizing mentioned)
- [script-verifiable] SV-17 [category: sizing] — Architecture ADR review recorded (ADR keyword present)
- [script-verifiable] SV-18 [category: gate verdict] — YAML frontmatter present (--- fenced block at top of file)
- [script-verifiable] SV-19 [category: gate verdict] — date field present in YAML frontmatter
- [script-verifiable] SV-20 [category: gate verdict] — status field present in YAML frontmatter (PASS/FAIL/CONDITIONAL)
- [script-verifiable] SV-21 [category: gate verdict] — checks_passed aggregate field present in YAML frontmatter
- [script-verifiable] SV-22 [category: gate verdict] — critical_blockers count field present in YAML frontmatter
- [script-verifiable] SV-23 [category: gate verdict] — contradictions_found count field present in YAML frontmatter
- [script-verifiable] SV-24 [category: gate verdict] — PASS/FAIL verdict emitted in report body or frontmatter
- [script-verifiable] SV-25 [category: gate verdict] — Output Verification section present (## Output Verification heading or equivalent)
- [LLM-checkable] LLM-01 [category: artifact presence] — UX design exists and is complete (when declared)
- [LLM-checkable] LLM-02 [category: artifact presence] — Epics/stories artifact is complete with AC on every story
- [LLM-checkable] LLM-03 [category: artifact presence] — Threat model artifact is complete (when declared)
- [LLM-checkable] LLM-04 [category: artifact presence] — Infrastructure design artifact is complete (when declared)
- [LLM-checkable] LLM-05 [category: artifact presence] — Traceability matrix covers every PRD requirement (deep)
- [LLM-checkable] LLM-06 [category: cross-artifact coherence] — Every PRD functional requirement is covered by at least one story
- [LLM-checkable] LLM-07 [category: cross-artifact coherence] — Every PRD NFR has at least one test case
- [LLM-checkable] LLM-08 [category: cross-artifact coherence] — Architecture components cover every functional area in the PRD
- [LLM-checkable] LLM-09 [category: cross-artifact coherence] — Every ADR is referenced by at least one component
- [LLM-checkable] LLM-10 [category: cross-artifact coherence] — Every epic contains at least one story
- [LLM-checkable] LLM-11 [category: cross-artifact coherence] — Every high-risk story carries ATDD coverage
- [LLM-checkable] LLM-12 [category: cross-artifact coherence] — prd.md contains a "Review Findings Incorporated" section with substantive content
- [LLM-checkable] LLM-13 [category: cross-artifact coherence] — architecture.md contains a "Review Findings Incorporated" section with substantive content
- [LLM-checkable] LLM-14 [category: cross-artifact coherence] — Terminology is consistent across PRD, architecture, and test-plan
- [LLM-checkable] LLM-15 [category: cross-artifact coherence] — Story component references resolve to architecture component inventory
- [LLM-checkable] LLM-16 [category: cascade resolution] — Architecture vs threat model — security requirements aligned (when threat-model.md exists)
- [LLM-checkable] LLM-17 [category: cascade resolution] — Architecture vs infrastructure design — topology aligned (when infrastructure-design.md exists)
- [LLM-checkable] LLM-18 [category: cascade resolution] — PRD NFR targets vs architecture design decisions — coherent
- [LLM-checkable] LLM-19 [category: cascade resolution] — Auth strategy aligned across PRD, architecture, and threat model
- [LLM-checkable] LLM-20 [category: cascade resolution] — Critical/high security requirements covered by story ACs (when threat-model.md exists)
- [LLM-checkable] LLM-21 [category: cascade resolution] — All BLOCKING contradictions listed in blocking_issues
- [LLM-checkable] LLM-22 [category: cascade resolution] — Every recorded contradiction has authority_agent assigned and recommended_resolution populated
- [LLM-checkable] LLM-23 [category: cascade resolution] — No unresolved edit-propagation rows outstanding in the Pending Cascades table
- [LLM-checkable] LLM-24 [category: traceability] — Orphan requirements flagged (FRs/NFRs with no story coverage)
- [LLM-checkable] LLM-25 [category: traceability] — Orphan test cases flagged (tests with no FR/NFR anchor)
- [LLM-checkable] LLM-26 [category: traceability] — Test implementation rate meets the gate threshold declared in traceability-matrix.md
- [LLM-checkable] LLM-27 [category: traceability] — CI enforced quality gates (not advisory-only) confirmed in ci-setup.md
- [LLM-checkable] LLM-28 [category: sizing] — All stories use numeric points (not just T-shirt sizes)
- [LLM-checkable] LLM-29 [category: sizing] — No oversized stories (>13 pts) without a split plan recorded
- [LLM-checkable] LLM-30 [category: sizing] — All ADRs resolved (none left in "Proposed" state)
- [LLM-checkable] LLM-31 [category: sizing] — Adversarial findings incorporated into architecture
- [LLM-checkable] LLM-32 [category: sizing] — Acceptance criteria are testable (every AC has a verifiable condition)
- [LLM-checkable] LLM-33 [category: sizing] — NFR targets are quantified (thresholds, units)
- [LLM-checkable] LLM-34 [category: sizing] — Epic totals reconcile to sprint capacity / velocity data
- [LLM-checkable] LLM-35 [category: gate verdict] — Security requirements documented in PRD are sufficient for the declared stack
- [LLM-checkable] LLM-36 [category: gate verdict] — Compliance timeline estimated when GDPR/PCI-DSS/HIPAA applies
- [LLM-checkable] LLM-37 [category: gate verdict] — Rollback procedure documented and feasible for the declared topology
- [LLM-checkable] LLM-38 [category: gate verdict] — Observability stack (logging, metrics, alerting) defined end-to-end
- [LLM-checkable] LLM-39 [category: gate verdict] — Release strategy defined and infrastructure supports it (canary/blue-green/rolling)
- [LLM-checkable] LLM-40 [category: gate verdict] — Overall readiness verdict narrative is well-reasoned given the category-level verdicts

## Finalize

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-readiness-check/scripts/finalize.sh
