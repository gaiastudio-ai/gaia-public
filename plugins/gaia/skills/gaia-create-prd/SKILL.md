---
name: gaia-create-prd
description: Create a Product Requirements Document through collaborative discovery with the pm subagent (Derek) — Cluster 5 planning skill. Use when the user wants to produce a validated PRD from an existing product brief, covering goals, functional/non-functional requirements, user journeys, data requirements, integrations, and success criteria.
argument-hint: "[product-brief-path]"
context: fork
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Agent]
---

## Setup

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-create-prd/scripts/setup.sh

## Memory

!${CLAUDE_PLUGIN_ROOT}/scripts/memory-loader.sh pm all

## Mission

You are orchestrating the creation of a Product Requirements Document (PRD). The PRD authoring is delegated to the **pm** subagent (Derek), who conducts user interviews, elicits requirements, and produces the final artifact. You load the product brief, validate inputs, coordinate the multi-step flow, and write the output to `docs/planning-artifacts/prd.md` using the canonical `prd-template.md` template structure.

This skill is the native Claude Code conversion of the legacy `_gaia/lifecycle/workflows/2-planning/create-prd` workflow (brief Cluster 5, story P5-S1 / E28-S40). The step ordering, prompts, and output path are preserved verbatim from the legacy `instructions.xml` — do not restructure, re-prompt, or reorder.

## Critical Rules

- A product brief MUST exist before starting. The `[product-brief-path]` argument is required — fail fast with "product-brief-path required" error if missing.
- If the product brief file does not exist at the supplied path, fail pre-flight with "product brief not found at <path>" — do not create a partial PRD.
- Every requirement must have a unique ID: `FR-###` (functional), `NFR-###` (non-functional).
- Requirements must be discoverable from user interviews, not guessed.
- Each requirement must have testable acceptance criteria.
- PRD authoring prompts are delegated to the `pm` subagent (Derek) via native Claude Code subagent invocation — do NOT inline Derek's persona into this skill body. If the pm subagent (E28-S21) is not available, fail with "pm subagent not available — install E28-S21" error.
- If `docs/planning-artifacts/prd.md` already exists, warn the user: "An existing PRD was found. Continuing will overwrite it. Confirm to proceed or abort." Do not silently overwrite.
- Template resolution: load `prd-template.md` from this skill directory. If `custom/templates/prd-template.md` exists and is non-empty, use the custom template instead — the custom template takes full precedence over the framework default (ADR-020 / FR-101).

## Steps

### Step 1 — Load Product Brief

- Validate that `[product-brief-path]` argument was provided. If missing, fail fast: "product-brief-path required — provide the path to the product brief file."
- Read the product brief at the supplied path.
- Extract: vision, target users, problem statement, proposed solution.
- Extract: scope and boundaries, risks and assumptions, competitive landscape, success metrics.
- If `docs/planning-artifacts/prd.md` already exists: warn "An existing PRD was found at docs/planning-artifacts/prd.md. Continuing will overwrite it. Confirm with user before proceeding."

### Step 2 — User Interviews

Delegate to the **pm** subagent (Derek) via `agents/pm` to conduct user interviews.

The pm subagent asks the user:

1. Who are the primary user types?
2. What are their top 3 needs?
3. What frustrates them most about current solutions?

Structure responses into user need statements.

### Step 3 — Functional Requirements

Delegate to the **pm** subagent (Derek) to elicit and structure functional requirements:

- List features organized by priority: Must-Have, Should-Have, Nice-to-Have.
- Each feature needs: description, user story format, acceptance criteria.
- Assign unique IDs: FR-001, FR-002, ... — IDs are sequential and never reused.
- Cross-reference with product brief: verify each FR is traceable to the brief's proposed solution or key features. Flag any FR that introduces scope not present in the brief — confirm with user before including.

### Step 4 — Non-Functional Requirements

Delegate to the **pm** subagent (Derek) to define non-functional requirements:

- Define: performance targets, security requirements, accessibility standards.
- Define: scalability needs, reliability targets, compliance requirements.
- Assign unique IDs: NFR-001, NFR-002, ... — IDs are sequential and never reused.
- Each NFR MUST include a measurable target with a specific threshold (e.g., "response time < 200ms at p95", "99.9% uptime", "WCAG 2.1 AA compliance"). Reject vague qualifiers like "fast", "secure", "scalable" without numeric criteria.

### Step 5 — User Journeys

- Map key user flows with happy path and error paths.
- Include: entry point, steps, decision points, exit conditions.

### Step 6 — Data Requirements

- Identify data stored, processed, and exchanged.
- Define data retention, privacy, and security policies.

### Step 7 — Integration Requirements

- List external systems, APIs, and third-party services.
- Define integration patterns and data exchange formats.
- For each critical dependency: define failure mode, fallback behavior, and SLA expectations.

### Step 8 — Out of Scope

- List features, integrations, and use cases explicitly excluded from this release.
- For each exclusion: state what is excluded and why (deferred, not needed, separate product).
- Cross-reference with product brief: items listed as out-of-scope in the brief's "Scope and Boundaries" section must appear here. Flag any brief out-of-scope item missing from this list.

### Step 9 — Constraints and Assumptions

- Document technical, budget, timeline, and team constraints.
- List all assumptions that requirements depend on.
- Cross-reference with product brief: carry forward every risk and assumption from the brief's "Risks and Assumptions" section. Each must appear in this section or be explicitly noted as resolved with justification.

### Step 10 — Success Criteria

- Define measurable acceptance criteria for each feature.
- Define overall product success metrics.
- Cross-reference with product brief: every metric from the brief's "Success Metrics" section must have a corresponding measurable criterion in the PRD. Flag any brief metric not covered.

### Step 11 — Generate Output

Load the `prd-template.md` template from this skill directory (or from `custom/templates/prd-template.md` if a custom override exists and is non-empty).

Write the PRD to `docs/planning-artifacts/prd.md` with all sections populated:

- Overview
- Goals and Non-Goals
- User Stories
- Functional Requirements (prioritized with FR-### IDs)
- Non-Functional Requirements (with NFR-### IDs and measurable targets)
- Out of Scope
- UX Requirements
- Technical Constraints
- Dependencies (with failure modes, fallback behaviors, SLA expectations)
- Milestones
- Requirements Summary table (all FR and NFR IDs with description, priority, status)
- Open Questions

### Step 12 — Adversarial Review

- Read `${CLAUDE_PLUGIN_ROOT}/knowledge/adversarial-triggers.yaml` to evaluate trigger rules. (This policy table ships inside the plugin under ADR-041's `knowledge/` convention; the legacy v1 location `_gaia/_config/adversarial-triggers.yaml` is retired and no longer used.) Determine the current `change_type`: if invoked with a change_type context (e.g., from add-feature triage), use that value. If no context is available (standalone PRD creation), default to "feature".
- Look up the trigger rule for `change_type` + artifact "prd". If adversarial is false for this combination: skip the adversarial review. Add a "## Review Findings Incorporated" section with "Adversarial review not triggered — change type: {change_type}".
- If adversarial is true: spawn a subagent to run the adversarial review task against `docs/planning-artifacts/prd.md`.
- When subagent returns: verify `adversarial-review-prd-*.md` exists in `docs/planning-artifacts/`.

### Step 13 — Incorporate Adversarial Findings

- Read `docs/planning-artifacts/adversarial-review-prd-*.md` — extract critical and high severity findings.
- For each critical/high finding: add as a new requirement or refine an existing requirement in the PRD.
- Add a "## Review Findings Incorporated" section to the PRD listing each finding, its severity, and how it was addressed (new requirement added / existing requirement refined / acknowledged as risk).
- Write the updated PRD to `docs/planning-artifacts/prd.md`.

## Finalize

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-create-prd/scripts/finalize.sh

## Next Steps

- Primary: `/gaia-create-ux` — Create UX design specifications for the validated PRD.
