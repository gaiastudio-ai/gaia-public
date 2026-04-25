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

> `!scripts/write-checkpoint.sh gaia-create-arch 1 project_name="$PROJECT_NAME" arch_version="$ARCH_VERSION"`

### Step 2 — Detect Mode

- Check `docs/planning-artifacts/prd.md` header for "Mode: Brownfield".
- If brownfield mode detected: set mode to brownfield. Use brownfield architecture template.
- If no brownfield header: set mode to greenfield. Load `architecture-template.md` from this skill directory. If `custom/templates/architecture-template.md` exists and is non-empty, use the custom template instead.

> `!scripts/write-checkpoint.sh gaia-create-arch 2 project_name="$PROJECT_NAME" arch_version="$ARCH_VERSION" arch_mode="$ARCH_MODE"`

### Step 3 — Technology Selection

Delegate to the **architect** subagent (Theo) via `agents/architect` to select the technology stack.

- Greenfield: select tech stack with rationale for each choice. Consider: team expertise, scalability needs, ecosystem maturity.
- Brownfield: discover existing tech stack from project-documentation.md and code scan. Mark ADR status as "Existing" for discovered decisions.
- If brownfield artifacts were loaded in Step 1: reference the existing tech stack, constraints, and integration points when evaluating technology choices.
- Record decision as ADR in the architecture document's Decision Log table.
- Present recommended technology stack to the user for confirmation.

> `!scripts/write-checkpoint.sh gaia-create-arch 3 project_name="$PROJECT_NAME" arch_version="$ARCH_VERSION" section_slug=technology-selection`

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

> `!scripts/write-checkpoint.sh gaia-create-arch 4 project_name="$PROJECT_NAME" arch_version="$ARCH_VERSION" section_slug=system-architecture`

### Step 5 — Data Architecture

Delegate to the **architect** subagent (Theo) via `agents/architect` to design data architecture.

- Design database schema and data model.
- Define data flow between components.
- Specify data storage, caching, and replication strategies.

> `!scripts/write-checkpoint.sh gaia-create-arch 5 project_name="$PROJECT_NAME" arch_version="$ARCH_VERSION" section_slug=data-architecture`

### Step 6 — API Design

Delegate to the **architect** subagent (Theo) via `agents/architect` to design APIs.

- Define API endpoint overview.
- Specify authentication and authorization strategy.
- Document API versioning approach.

> `!scripts/write-checkpoint.sh gaia-create-arch 6 project_name="$PROJECT_NAME" arch_version="$ARCH_VERSION" section_slug=api-design`

### Step 7 — Infrastructure and Cross-Cutting Concerns

Delegate to the **architect** subagent (Theo) via `agents/architect` to define infrastructure.

- Define deployment topology and environments (dev, staging, prod).
- Specify hosting, containerization, and orchestration choices.
- Define monitoring and logging strategy.
- Define security architecture: if threat-model.md was loaded, cross-reference identified threats and map each critical/high threat to an architectural mitigation. If no threat model exists, prompt user for key security requirements.
- Brownfield: document security architecture, cross-cutting concerns with current state and gaps. Define migration strategy. Cross-reference api-documentation.md, event-catalog.md, dependency-map.md in the Integration Architecture section.

> `!scripts/write-checkpoint.sh gaia-create-arch 7 project_name="$PROJECT_NAME" arch_version="$ARCH_VERSION" section_slug=infra-and-cross-cutting`

### Step 8 — Architecture Decision Records

Delegate to the **architect** subagent (Theo) via `agents/architect` to compile ADRs.

- Review all decisions made in Steps 3-7.
- Ensure each significant decision is recorded as ADR with: Title, Date, Status, Context, Decision, Alternatives Considered, Consequences, Addresses (FR/NFR IDs).
- Brownfield: mark existing decisions as status "Existing", new gap-related decisions as "Proposed".
- Generate a "Decision to Requirement Mapping" table mapping each ADR to the FR/NFR IDs it addresses. Flag any FR/NFR from the PRD with no corresponding ADR as a coverage gap.

> `!scripts/write-checkpoint.sh gaia-create-arch 8 project_name="$PROJECT_NAME" arch_version="$ARCH_VERSION" adr_count="$ADR_COUNT"`

### Step 9 — Generate Output

- Write the architecture document to `docs/planning-artifacts/architecture.md` using the `architecture-template.md` section structure.
- Greenfield: include technology stack, system architecture, data architecture, API design, infrastructure plan, ADR references, and Decision-to-Requirement Mapping table.
- Brownfield: include C4 diagrams, sequence diagrams, data flow diagram, as-is/target delta table, migration strategy, and cross-references.

> After artifact write: run open-question detection snippet
> `!${CLAUDE_PLUGIN_ROOT}/scripts/detect-open-questions.sh docs/planning-artifacts/architecture.md`

> `!scripts/write-checkpoint.sh gaia-create-arch 9 project_name="$PROJECT_NAME" arch_version="$ARCH_VERSION" --paths docs/planning-artifacts/architecture.md`

### Step 10 — Optional: API Design Review

- Ask user: "Would you like to review the API design against REST standards? Recommended if your architecture includes APIs. (yes / skip)"
- If yes: invoke the API design review task.
- If skip: API review can be run anytime later with /gaia-review-api.

> `!scripts/write-checkpoint.sh gaia-create-arch 10 project_name="$PROJECT_NAME" arch_version="$ARCH_VERSION" api_review_run="$API_REVIEW_RUN"`

### Step 11 — Adversarial Review

- Read adversarial-triggers.yaml to evaluate trigger rules.
- If adversarial review is triggered: spawn a subagent for adversarial review of the architecture document.
- If not triggered: add "## Review Findings Incorporated" section noting the review was not triggered.

> `!scripts/write-checkpoint.sh gaia-create-arch 11 project_name="$PROJECT_NAME" arch_version="$ARCH_VERSION" adversarial_triggered="$ADVERSARIAL_TRIGGERED"`

### Step 12 — Incorporate Adversarial Findings

- Read adversarial review findings.
- For each critical/high finding: update the architecture — add missing components, revise decisions, strengthen security/scalability, update ADRs.
- Add a "## Review Findings Incorporated" section to the architecture document listing each finding, its severity, and how it was addressed.
- Write the final architecture document.

> After artifact write: run open-question detection snippet
> `!${CLAUDE_PLUGIN_ROOT}/scripts/detect-open-questions.sh docs/planning-artifacts/architecture.md`

> `!scripts/write-checkpoint.sh gaia-create-arch 12 project_name="$PROJECT_NAME" arch_version="$ARCH_VERSION" --paths docs/planning-artifacts/architecture.md`

## Validation

<!--
  E42-S8 — V1→V2 33-item checklist port (FR-341, FR-359, VCP-CHK-15, VCP-CHK-16).
  Classification (33 items total):
    - Script-verifiable: 25 (SV-01..SV-25) — enforced by finalize.sh.
    - LLM-checkable:      8 (LLM-01..LLM-08) — evaluated by the host LLM
      against the architecture artifact at finalize time.
  Exit code 0 when all 25 script-verifiable items PASS; non-zero otherwise.

  The V1 source checklist at _gaia/lifecycle/workflows/3-solutioning/create-architecture/
  checklist.md carried 17 bulleted items. The story 33-item count is
  authoritative: the 17 V1 bullets are expanded here to 33 by
  (a) adding envelope items SV-01..SV-03 (artifact presence, non-empty,
  frontmatter), (b) splitting "All required sections present" into
  per-section presence checks (SV-04..SV-11 — System Overview,
  Architecture Decisions, System Components, Data Architecture,
  Integration Points, Infrastructure, Security Architecture,
  Cross-Cutting Concerns), (c) preserving the V1 body-sanity anchors
  verbatim as SV-12..SV-19 (Stack selected with rationale, Component
  diagram described, Service boundaries defined, Data model defined,
  Data flow documented, Endpoints overviewed, Auth strategy defined,
  Deployment topology described), (d) adding Decision Log structural
  checks (SV-20..SV-22 — table present, ADRs present (V1 "Decisions
  recorded"), ADR fields populated), (e) preserving SV-23 (cross-
  cutting documented) and gate/output items SV-24..SV-25 (Review
  Findings Incorporated section; FR-### traceability), and (f) pulling
  8 LLM-checkable items (LLM-01..LLM-08) from the V1 semantic bullets
  (tech-stack trade-offs, communication pattern coherence, ADR
  rationale quality, Decision-to-Requirement coverage, security vs
  threat model, env progression, cross-cutting adequacy, adversarial
  incorporation traceability).

  The VCP-CHK-16 anchor is SV-21 — "Decisions recorded". This is the
  V1 phrase verbatim and MUST appear in violation output when the
  Decision Log table is heading-only (AC-EC5).

  Per-item LLM-checkable timeout contract: 30s wall-clock per item
  (AC-EC7). Malformed verdict (no explicit PASS/FAIL) is treated as
  FAIL — never skip (AC-EC4).

  Invoked by `finalize.sh` at post-complete (per §10.31.1). Validation
  runs BEFORE the checkpoint and lifecycle-event writes (observability
  is never suppressed by checklist outcome — story AC5).

  See docs/implementation-artifacts/E42-S8-port-gaia-create-arch-33-item-checklist-to-v2.md.
-->

- [script-verifiable] SV-01 — Output file exists at docs/planning-artifacts/architecture.md
- [script-verifiable] SV-02 — Output artifact is non-empty
- [script-verifiable] SV-03 — Artifact has frontmatter or top-level title
- [script-verifiable] SV-04 — System Overview section present
- [script-verifiable] SV-05 — Architecture Decisions section present (Decision Log)
- [script-verifiable] SV-06 — System Components section present
- [script-verifiable] SV-07 — Data Architecture section present
- [script-verifiable] SV-08 — Integration Points section present
- [script-verifiable] SV-09 — Infrastructure section present
- [script-verifiable] SV-10 — Security Architecture section present
- [script-verifiable] SV-11 — Cross-Cutting Concerns section present
- [script-verifiable] SV-12 — Stack selected with rationale
- [script-verifiable] SV-13 — Component diagram described
- [script-verifiable] SV-14 — Service boundaries defined
- [script-verifiable] SV-15 — Data model defined
- [script-verifiable] SV-16 — Data flow documented
- [script-verifiable] SV-17 — Endpoints overviewed
- [script-verifiable] SV-18 — Auth strategy defined
- [script-verifiable] SV-19 — Deployment topology described
- [script-verifiable] SV-20 — Decision Log table present with markdown table structure
- [script-verifiable] SV-21 — Decisions recorded (Decision Log table has at least one ADR row)
- [script-verifiable] SV-22 — Each ADR has context, decision, consequences (ADR row fields populated)
- [script-verifiable] SV-23 — Cross-cutting concerns documented
- [script-verifiable] SV-24 — Review Findings Incorporated section present
- [script-verifiable] SV-25 — At least one FR-### identifier referenced (traceability)
- [LLM-checkable] LLM-01 — Trade-offs documented (tech-stack choices justified against alternatives)
- [LLM-checkable] LLM-02 — Communication patterns specified (sync vs async, at-least-once vs exactly-once)
- [LLM-checkable] LLM-03 — Each ADR has context, decision, consequences with sound rationale
- [LLM-checkable] LLM-04 — Decision-to-Requirement Mapping — every ADR maps to at least one FR/NFR; no orphaned FR/NFR
- [LLM-checkable] LLM-05 — Security architecture addresses identified threats (threat-model cross-reference where present)
- [LLM-checkable] LLM-06 — Environments defined (dev, staging, prod) with progression rules explicit
- [LLM-checkable] LLM-07 — Monitoring, logging, and error-handling strategies adequate for the system scale
- [LLM-checkable] LLM-08 — Adversarial review findings properly incorporated with traceable before/after mapping

## Finalize

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-create-arch/scripts/finalize.sh
