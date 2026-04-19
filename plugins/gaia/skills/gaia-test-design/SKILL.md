---
name: gaia-test-design
description: Create risk-based test plans through collaborative discovery with the test-architect subagent (Sable). Use when "design test plan" or /gaia-test-design.
context: fork
tools: Read, Write, Edit, Grep, Glob, Bash, Agent
---

## Setup

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-test-design/scripts/setup.sh

## Memory

!${CLAUDE_PLUGIN_ROOT}/scripts/memory-loader.sh test-architect all

## Mission

You are orchestrating the creation of a risk-based Test Plan. The test planning is delegated to the **test-architect** subagent (Sable), who conducts risk assessment, designs test strategy, and produces the final artifact. You load upstream artifacts (architecture, PRD, project context), validate inputs, coordinate the multi-step flow, and write the output to `docs/test-artifacts/test-plan.md` using the bundled `test-plan-template.md` template structure.

This skill is the native Claude Code conversion of the legacy `_gaia/testing/workflows/test-design` workflow (E28-S82, Cluster 11). The step ordering, prompts, and output path are preserved verbatim from the legacy `instructions.xml` -- do not restructure, re-prompt, or reorder.

## Critical Rules

- Knowledge fragments are bundled in this skill's `knowledge/` directory -- load them JIT when referenced by a step.
- Start with risk assessment -- not all areas need equal coverage.
- Define quality gates for the CI pipeline.
- The test plan template MUST exist at `${CLAUDE_PLUGIN_ROOT}/skills/gaia-test-design/test-plan-template.md` and be non-empty. If the template file is empty (0 bytes) or missing, halt with: "Test plan template not found or empty -- cannot produce test plan without template."
- If architecture.md is missing at `docs/planning-artifacts/architecture.md`: proceed with reduced risk context, log a WARNING ("Architecture document not found -- producing test plan with generic risk ratings"), and use generic risk ratings instead of architecture-informed ones.
- If prd.md is missing at `docs/planning-artifacts/prd.md`: proceed with reduced context, log a WARNING ("PRD not found -- test plan scope may be incomplete").
- Test planning is delegated to the test-architect subagent (Sable) via native Claude Code subagent invocation -- do NOT inline Sable's persona into this skill body. If the test-architect subagent is not available or not registered, halt with: "test-architect subagent not available -- ensure E28-S21 agents are installed."
- Template resolution: load `test-plan-template.md` from this skill directory. If `custom/templates/test-plan-template.md` exists and is non-empty, use the custom template instead -- the custom template takes full precedence over the bundled default (ADR-020 / FR-101).
- Output ALL artifacts to `docs/test-artifacts/`.
- The legacy `val_validate_output: true` flag is preserved -- the output test plan should be validated when Val integration is active.

## Steps

### Step 1 -- Load Project Context

- Read `docs/planning-artifacts/architecture.md` if available -- extract system components, their interactions, and high-risk areas.
- Read `docs/planning-artifacts/prd.md` if available -- extract requirements (functional and non-functional).
- Read `docs/planning-artifacts/project-context.md` if available -- extract project-level context.
- If architecture.md is missing: log WARNING and proceed with generic risk context. Do not halt.
- If prd.md is missing: log WARNING and proceed with reduced scope context. Do not halt.
- Understand system components and their interactions from whatever context is available.

### Step 2 -- Risk Assessment

Delegate to the **test-architect** subagent (Sable) via `agents/test-architect` for risk assessment.

- Load knowledge fragment: `knowledge/risk-governance.md` for probability-impact matrix methodology
- Identify high-risk areas: revenue-critical paths, security-sensitive components, complex business logic, data integrity boundaries.
- Rate each area using probability x impact scoring.
- Produce a risk assessment matrix with columns: Area, Risk Level (H/M/L), Probability, Impact, Coverage Strategy.
- When architecture.md is missing, use generic risk ratings based on common patterns (auth = High, CRUD = Medium, static content = Low).

### Step 3 -- Legacy Integration Boundaries (Brownfield)

This step is **optional** -- activate only when brownfield indicators are present.

- If PRD contains "Mode: Brownfield" or project has `docs/planning-artifacts/brownfield-assessment.md`: activate this step.
- Identify integration boundaries: where new code calls legacy code and vice versa.
- Load knowledge fragment: `knowledge/contract-testing.md` for consumer-driven contract patterns
- For each boundary: define contract test (input/output schema validation between old and new).
- For each legacy API wrapper or adapter: define adapter test (legacy behavior preserved).
- If data migration exists: define migration validation tests (row counts, data integrity, rollback verification).
- If dual-write strategy: define consistency tests (both stores reflect same state).
- Add legacy boundary risks to the risk assessment from Step 2.
- If no brownfield indicators are found: skip this step entirely.

### Step 4 -- Test Strategy

Delegate to the **test-architect** subagent (Sable) via `agents/test-architect` for test strategy design.

- Load knowledge fragment: `knowledge/test-pyramid.md` for test level methodology
- Load knowledge fragment: `knowledge/api-testing-patterns.md` for API and contract test patterns
- Define test levels per component: unit, integration, E2E, contract.
- Apply test pyramid -- most tests at the lowest effective level.
- Map each component to its appropriate test level based on risk assessment.
- Define the test pyramid distribution targets (e.g., 70% unit, 20% integration, 10% E2E).

### Step 5 -- Test Plan

Delegate to the **test-architect** subagent (Sable) via `agents/test-architect` for test plan authoring.

- Create test plan with coverage targets per component.
- Define test naming conventions and organization.
- Specify test data requirements, fixtures, and mocks.
- Define test environment requirements and setup.

### Step 6 -- Quality Gates

Delegate to the **test-architect** subagent (Sable) via `agents/test-architect` for quality gate definition.

- Define automated gates: coverage percentage thresholds, pass rate requirements, performance budgets.
- Specify CI pipeline integration points for each gate.
- Define gate failure behavior (block merge, warn, advisory).

### Step 7 -- Generate Output

- Load the test plan template from `${CLAUDE_PLUGIN_ROOT}/skills/gaia-test-design/test-plan-template.md`.
- GATE: verify the template file exists and is non-empty (file size > 0 bytes). If the template is empty or missing, halt with: "Test plan template not found or empty at test-plan-template.md -- cannot produce test plan without template."
- Check for custom template override: if `custom/templates/test-plan-template.md` exists and is non-empty, use the custom template instead.
- Compile the test plan by populating the template with: risk assessment (Step 2), legacy integration boundaries (Step 3, if applicable), test strategy (Step 4), test plan details (Step 5), quality gates (Step 6).
- Write the compiled test plan to `docs/test-artifacts/test-plan.md`.

### Step 8 -- Optional: Scaffold Test Framework

- Check if the project already has a test framework configured (look for jest.config, vitest.config, playwright.config, pytest.ini, build.gradle test blocks, etc.).
- If no test framework is detected: suggest running `/gaia-test-framework` to scaffold the test framework with appropriate tooling, folder structure, fixture patterns, and a sample test.
- If a test framework already exists: skip this step -- the framework is already configured.
- This step is informational only -- the actual scaffolding is handled by the separate `/gaia-test-framework` skill.

## Finalize

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-test-design/scripts/finalize.sh
