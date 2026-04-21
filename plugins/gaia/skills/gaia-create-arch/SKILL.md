---
name: gaia-create-arch
description: Design system architecture through collaborative discovery with the architect subagent (Theo) — Cluster 6 architecture skill. Use when the user wants to produce a validated architecture document from an existing PRD, covering technology selection, system components, data architecture, API design, infrastructure, security architecture, and architecture decision records.
context: fork
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Agent]
---

## Setup

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-create-arch/scripts/setup.sh

## Memory

!${CLAUDE_PLUGIN_ROOT}/scripts/memory-loader.sh architect all

## Mission

You are orchestrating the creation of a System Architecture document. The architecture authoring is delegated to the **architect** subagent (Theo), who conducts technology selection, designs system components, and produces the final artifact. You load the PRD, validate inputs, coordinate the multi-step flow, and write the output to `docs/planning-artifacts/architecture.md` using the carried `architecture-template.md` template structure.

This skill is the native Claude Code conversion of the legacy `_gaia/lifecycle/workflows/3-solutioning/create-architecture` workflow (brief Cluster 6, story P6-S1 / E28-S45). The step ordering, prompts, and output path are preserved verbatim from the legacy `instructions.xml` — do not restructure, re-prompt, or reorder.

## Critical Rules

- A PRD MUST exist at `docs/planning-artifacts/prd.md` before starting. If missing, fail fast with "PRD not found at docs/planning-artifacts/prd.md — run /gaia-create-prd first."
- The PRD MUST contain a "## Review Findings Incorporated" section. If missing, fail fast with "PRD review findings not found — run /gaia-create-prd to complete adversarial review and PRD refinement."
- Every significant technical decision must be recorded as an ADR inline in the Decision Log table of the architecture document.
- Architecture authoring is delegated to the `architect` subagent (Theo) via native Claude Code subagent invocation — do NOT inline Theo's persona into this skill body. If the architect subagent (E28-S21) is not available, fail with "architect subagent not available — install E28-S21" error.
- If `docs/planning-artifacts/architecture.md` already exists, warn the user: "An existing architecture document was found. Continuing will overwrite it. Confirm to proceed or abort." Do not silently overwrite.
- Template resolution: load `architecture-template.md` from this skill directory. If `custom/templates/architecture-template.md` exists and is non-empty, use the custom template instead — the custom template takes full precedence over the framework default (ADR-020 / FR-101).
- ADRs live inline in the architecture document's Decision Log table — there is no separate ADR directory. Preserve the legacy workflow's ADR placement convention.
- Every technical decision must connect to business value.

## Steps

### Step 1 — Load Upstream Artifacts

- Read `docs/planning-artifacts/prd.md` — extract requirements (functional and non-functional).
- GATE: verify prd.md contains a "## Review Findings Incorporated" section. If missing, HALT — run /gaia-create-prd first to complete adversarial review and PRD refinement.
- Read `docs/planning-artifacts/ux-design.md` if available — extract UI requirements.
- Check for brownfield artifacts: `docs/planning-artifacts/brownfield-assessment.md` and `docs/planning-artifacts/project-documentation.md`. If either exists, load them — these contain existing codebase analysis that must inform architecture decisions even if the PRD is not in brownfield mode.
- Check for `docs/planning-artifacts/threat-model.md`. If it exists, load it — identified threats and mitigations must inform the security architecture in Step 7.

### Step 2 — Detect Mode

- Check `docs/planning-artifacts/prd.md` header for "Mode: Brownfield".
- If brownfield mode detected: set mode to brownfield. Use brownfield architecture template.
- If no brownfield header: set mode to greenfield. Load `architecture-template.md` from this skill directory. If `custom/templates/architecture-template.md` exists and is non-empty, use the custom template instead.

### Step 3 — Technology Selection

Delegate to the **architect** subagent (Theo) via `agents/architect` to select the technology stack.

- Greenfield: select tech stack with rationale for each choice. Consider: team expertise, scalability needs, ecosystem maturity.
- Brownfield: discover existing tech stack from project-documentation.md and code scan. Mark ADR status as "Existing" for discovered decisions.
- If brownfield artifacts were loaded in Step 1: reference the existing tech stack, constraints, and integration points when evaluating technology choices.
- Record decision as ADR in the architecture document's Decision Log table.
- Present recommended technology stack to the user for confirmation.

### Step 4 — System Architecture

Delegate to the **architect** subagent (Theo) via `agents/architect` to design the system architecture.

- Greenfield: define component diagram and service boundaries. Describe communication patterns. Record architectural style as ADR.
- Brownfield: document as-is architecture with Mermaid diagrams:
  - System context diagram (C4 Level 1)
  - Container diagram (C4 Level 2)
  - 3-5 sequence diagrams for key system flows
  - Data flow diagram
  - Target architecture for gaps identified in the PRD
  - As-is vs target delta table

### Step 5 — Data Architecture

Delegate to the **architect** subagent (Theo) via `agents/architect` to design data architecture.

- Design database schema and data model.
- Define data flow between components.
- Specify data storage, caching, and replication strategies.

### Step 6 — API Design

Delegate to the **architect** subagent (Theo) via `agents/architect` to design APIs.

- Define API endpoint overview.
- Specify authentication and authorization strategy.
- Document API versioning approach.

### Step 7 — Infrastructure and Cross-Cutting Concerns

Delegate to the **architect** subagent (Theo) via `agents/architect` to define infrastructure.

- Define deployment topology and environments (dev, staging, prod).
- Specify hosting, containerization, and orchestration choices.
- Define monitoring and logging strategy.
- Define security architecture: if threat-model.md was loaded, cross-reference identified threats and map each critical/high threat to an architectural mitigation. If no threat model exists, prompt user for key security requirements.
- Brownfield: document security architecture, cross-cutting concerns with current state and gaps. Define migration strategy. Cross-reference api-documentation.md, event-catalog.md, dependency-map.md in the Integration Architecture section.

### Step 8 — Architecture Decision Records

Delegate to the **architect** subagent (Theo) via `agents/architect` to compile ADRs.

- Review all decisions made in Steps 3-7.
- Ensure each significant decision is recorded as ADR with: Title, Date, Status, Context, Decision, Alternatives Considered, Consequences, Addresses (FR/NFR IDs).
- Brownfield: mark existing decisions as status "Existing", new gap-related decisions as "Proposed".
- Generate a "Decision to Requirement Mapping" table mapping each ADR to the FR/NFR IDs it addresses. Flag any FR/NFR from the PRD with no corresponding ADR as a coverage gap.

### Step 9 — Generate Output

- Write the architecture document to `docs/planning-artifacts/architecture.md` using the `architecture-template.md` section structure.
- Greenfield: include technology stack, system architecture, data architecture, API design, infrastructure plan, ADR references, and Decision-to-Requirement Mapping table.
- Brownfield: include C4 diagrams, sequence diagrams, data flow diagram, as-is/target delta table, migration strategy, and cross-references.

### Step 10 — Optional: API Design Review

- Ask user: "Would you like to review the API design against REST standards? Recommended if your architecture includes APIs. (yes / skip)"
- If yes: invoke the API design review task.
- If skip: API review can be run anytime later with /gaia-review-api.

### Step 11 — Adversarial Review

- Read adversarial-triggers.yaml to evaluate trigger rules.
- If adversarial review is triggered: spawn a subagent for adversarial review of the architecture document.
- If not triggered: add "## Review Findings Incorporated" section noting the review was not triggered.

### Step 12 — Incorporate Adversarial Findings

- Read adversarial review findings.
- For each critical/high finding: update the architecture — add missing components, revise decisions, strengthen security/scalability, update ADRs.
- Add a "## Review Findings Incorporated" section to the architecture document listing each finding, its severity, and how it was addressed.
- Write the final architecture document.

## Finalize

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-create-arch/scripts/finalize.sh
