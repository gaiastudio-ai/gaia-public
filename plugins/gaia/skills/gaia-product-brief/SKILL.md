---
name: gaia-product-brief
description: Create a product brief through collaborative discovery — Cluster 4 analysis skill. Use when the user wants to craft a product brief (vision, users, problem, solution, scope, risks, competitive landscape, success metrics) after an initial brainstorm or research phase.
argument-hint: "[product name or focus]"
context: fork
allowed-tools: [Read, Write, Glob, Grep, Bash]
# Quality gates (FR-347, FR-358 — E45-S2 reference implementation)
# pre_start: enforced by scripts/setup.sh before Step 1 runs.
# post_complete: enforced by scripts/finalize.sh against the generated
#   product brief artifact (docs/creative-artifacts/product-brief-*.md)
#   in addition to the existing 27-item checklist.
quality_gates:
  pre_start:
    - condition: "file_exists:docs/creative-artifacts/brainstorm-*.md"
      error_message: "Run `/gaia-brainstorm` first to create a brainstorm artifact"
  post_complete:
    - condition: "section_present:Vision Statement"
      error_message: "Vision Statement section is required"
    - condition: "section_present:Target Users"
      error_message: "Target Users section is required"
    - condition: "section_present:Problem Statement"
      error_message: "Problem Statement section is required"
    - condition: "section_present:Proposed Solution"
      error_message: "Proposed Solution section is required"
    - condition: "section_present:Key Features"
      error_message: "Key Features section is required"
    - condition: "section_present:Scope and Boundaries"
      error_message: "Scope and Boundaries section is required"
    - condition: "section_present:Risks and Assumptions"
      error_message: "Risks and Assumptions section is required"
    - condition: "section_present:Competitive Landscape"
      error_message: "Competitive Landscape section is required"
    - condition: "section_present:Success Metrics"
      error_message: "Success Metrics section is required"
---

## Setup

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-product-brief/scripts/setup.sh

## Mission

You are facilitating a collaborative discovery session to produce a product brief. Guide the user through vision, target users, problem statement, proposed solution, scope, risks, competitive landscape, and success metrics, then emit a structured product brief artifact at `docs/creative-artifacts/product-brief-*.md` for downstream consumers (e.g., `/gaia-create-prd`).

This skill is the native Claude Code conversion of the legacy `_gaia/lifecycle/workflows/1-analysis/create-product-brief` workflow (brief §Cluster 4, story P4-S2). The step ordering, prompts, and output location follow the legacy `instructions.xml` mechanically — do not restructure, re-prompt, or reorder sections.

## Critical Rules

- All sections must be collaboratively developed with the user — do not invent vision, users, or metrics.
- Ground every claim in upstream artifacts (brainstorm, market research, domain research, technical research) when available; otherwise elicit from the user.
- The output file path is `docs/creative-artifacts/product-brief-{slug}.md` — downstream consumers glob on this pattern, so do not relocate it.
- Mechanical port: the eight legacy steps below must appear in this exact order.

## Steps

### Step 1 — Discover Inputs

- Load prior brainstorm output if available (e.g., `docs/creative-artifacts/brainstorm-*.md`).
- Load market research if available.
- Load domain research if available.
- Load technical research if available.
- Load any other creative outputs under `docs/creative-artifacts/`.
- Summarize what upstream context was found and flag any missing inputs to the user before proceeding.

> `!scripts/write-checkpoint.sh gaia-product-brief 1 product_name="$PRODUCT_NAME" target_user="$TARGET_USER"`

### Step 2 — Vision Statement

- Collaboratively craft the vision statement with the user.
- Incorporate insights from prior analysis if available.
- Ask the user: **"What is the core vision for this product?"** — wait for a response before moving on.

> `!scripts/write-checkpoint.sh gaia-product-brief 2 product_name="$PRODUCT_NAME" target_user="$TARGET_USER"`

### Step 3 — Target Users

- Define user personas based on research.
- For each persona capture: name, role, goals, pain points, context.

> `!scripts/write-checkpoint.sh gaia-product-brief 3 product_name="$PRODUCT_NAME" target_user="$TARGET_USER"`

### Step 4 — Problem Statement

- Articulate the core problem being solved.
- Ground the statement in user research, market findings, and domain landscape where available.

> `!scripts/write-checkpoint.sh gaia-product-brief 4 product_name="$PRODUCT_NAME" target_user="$TARGET_USER"`

### Step 5 — Proposed Solution

- Define the high-level solution approach.
- Capture key features and differentiators.
- Reference technical research for technology selection rationale if available.

> `!scripts/write-checkpoint.sh gaia-product-brief 5 product_name="$PRODUCT_NAME" target_user="$TARGET_USER"`

### Step 6 — Scope, Risks and Competitive Landscape

- Define what is in-scope for this product and what is explicitly out of scope.
- Document known risks, dependencies, and assumptions the solution depends on.
- Summarize competitive landscape from upstream brainstorm and market research — key competitors, positioning, and differentiation.

> `!scripts/write-checkpoint.sh gaia-product-brief 6 product_name="$PRODUCT_NAME" target_user="$TARGET_USER"`

### Step 7 — Success Metrics

- Define measurable KPIs and success criteria.
- Include both quantitative and qualitative metrics.

> `!scripts/write-checkpoint.sh gaia-product-brief 7 product_name="$PRODUCT_NAME" target_user="$TARGET_USER"`

### Step 8 — Generate Output

Write a structured product brief to `docs/creative-artifacts/product-brief-{slug}.md` containing the exact sections below, in order:

- **Vision Statement** — core product vision
- **Target Users** — user personas (name, role, goals, pain points, context for each)
- **Problem Statement** — core problem being solved, grounded in research
- **Proposed Solution** — high-level solution approach
- **Key Features** — feature list with differentiators
- **Scope and Boundaries** — what is in-scope and what is explicitly out of scope
- **Risks and Assumptions** — known risks, dependencies, and assumptions
- **Competitive Landscape** — summary of competitive positioning from upstream research
- **Success Metrics** — measurable KPIs and success criteria
- **Next Steps** — per `${CLAUDE_PLUGIN_ROOT}/knowledge/lifecycle-sequence.yaml` (routing table ships inside the plugin under ADR-041's `knowledge/` convention; the legacy v1 location `_gaia/_config/lifecycle-sequence.yaml` is retired and no longer used)

Where `{slug}` is a short kebab-case slug derived from the product vision (e.g., `product-brief-ai-code-review.md`).

> After artifact write: run open-question detection snippet
> `!${CLAUDE_PLUGIN_ROOT}/scripts/detect-open-questions.sh docs/creative-artifacts/product-brief-${SLUG}.md`

> `!scripts/write-checkpoint.sh gaia-product-brief 8 product_name="$PRODUCT_NAME" target_user="$TARGET_USER" --paths docs/creative-artifacts/product-brief-${SLUG}.md`

## Validation

<!--
  E42-S5 — V1→V2 27-item checklist port (FR-341, FR-359).
  Classification (27 items total):
    - Script-verifiable: 18 (SV-01..SV-18) — enforced by finalize.sh.
    - LLM-checkable:      9 (LLM-01..LLM-09) — evaluated by the host LLM
      against the product-brief artifact at finalize time.
  Exit code 0 when all 18 script-verifiable items PASS; non-zero otherwise.

  The 9 required product-brief sections (per architecture §10.31.1 and
  test plan §11.46.18 VCP-GATE-03) form the spine of the script-verifiable
  subset (SV-04..SV-12). SV-01..SV-03 guard artifact existence, non-empty
  body, and top-level title/frontmatter. SV-13..SV-18 are deeper presence
  checks — Vision body non-empty, ≥1 persona, ≥1 key feature, scope
  carries both in-scope and out-of-scope wording, ≥1 competitor, and
  Success Metrics contains at least one measurable numeric signal
  (percent, currency, duration, NPS). These defend against the most
  common V2-regression: a required heading present but the body left
  empty.

  LLM-checkable items (LLM-01..LLM-09) cover semantic judgement that
  bash cannot reliably assess — coherence, plausibility, rationale,
  credibility, differentiation, measurability, and scope discipline.

  Invoked by `finalize.sh` at post-complete (per §10.31.1).

  See docs/implementation-artifacts/E42-S5-port-gaia-product-brief-27-item-checklist-to-v2.md.
-->

- [script-verifiable] SV-01 — Output artifact exists at docs/creative-artifacts/product-brief-*.md
- [script-verifiable] SV-02 — Output artifact is non-empty
- [script-verifiable] SV-03 — Artifact has frontmatter or top-level title
- [script-verifiable] SV-04 — Vision Statement section present
- [script-verifiable] SV-05 — Target Users section present
- [script-verifiable] SV-06 — Problem Statement section present
- [script-verifiable] SV-07 — Proposed Solution section present
- [script-verifiable] SV-08 — Key Features section present
- [script-verifiable] SV-09 — Scope and Boundaries section present
- [script-verifiable] SV-10 — Risks and Assumptions section present
- [script-verifiable] SV-11 — Competitive Landscape section present
- [script-verifiable] SV-12 — Success Metrics section present
- [script-verifiable] SV-13 — Vision Statement body non-empty
- [script-verifiable] SV-14 — At least one persona listed in Target Users
- [script-verifiable] SV-15 — Key Features list non-empty
- [script-verifiable] SV-16 — Scope and Boundaries documents both in-scope and out-of-scope
- [script-verifiable] SV-17 — At least one competitor listed in Competitive Landscape
- [script-verifiable] SV-18 — Success Metrics contain measurable values
- [LLM-checkable] LLM-01 — Vision statement is coherent and aspirational
- [LLM-checkable] LLM-02 — Target user personas are plausible and grounded in research
- [LLM-checkable] LLM-03 — Problem statement is grounded in user/market research findings
- [LLM-checkable] LLM-04 — Proposed solution addresses the stated problem
- [LLM-checkable] LLM-05 — Key features are prioritised with rationale
- [LLM-checkable] LLM-06 — Risks are credible and assumptions are testable
- [LLM-checkable] LLM-07 — Competitive landscape differentiation is clear
- [LLM-checkable] LLM-08 — Success metrics are measurable and attributable to the product
- [LLM-checkable] LLM-09 — Scope boundaries are defensible against feature creep

## Finalize

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-product-brief/scripts/finalize.sh

## Next Steps

- Primary: `/gaia-create-prd` — expand the brief into a full Product Requirements Document.
- Alternative: `/gaia-market-research` — if competitive landscape needs deeper validation before the PRD.
- Alternative: `/gaia-domain-research` — if domain context is still thin.
