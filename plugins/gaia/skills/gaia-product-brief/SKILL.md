---
name: gaia-product-brief
description: Create a product brief through collaborative discovery — Cluster 4 analysis skill. Use when the user wants to craft a product brief (vision, users, problem, solution, scope, risks, competitive landscape, success metrics) after an initial brainstorm or research phase.
argument-hint: "[product name or focus]"
context: fork
allowed-tools: [Read, Write, Glob, Grep, Bash]
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

### Step 2 — Vision Statement

- Collaboratively craft the vision statement with the user.
- Incorporate insights from prior analysis if available.
- Ask the user: **"What is the core vision for this product?"** — wait for a response before moving on.

### Step 3 — Target Users

- Define user personas based on research.
- For each persona capture: name, role, goals, pain points, context.

### Step 4 — Problem Statement

- Articulate the core problem being solved.
- Ground the statement in user research, market findings, and domain landscape where available.

### Step 5 — Proposed Solution

- Define the high-level solution approach.
- Capture key features and differentiators.
- Reference technical research for technology selection rationale if available.

### Step 6 — Scope, Risks and Competitive Landscape

- Define what is in-scope for this product and what is explicitly out of scope.
- Document known risks, dependencies, and assumptions the solution depends on.
- Summarize competitive landscape from upstream brainstorm and market research — key competitors, positioning, and differentiation.

### Step 7 — Success Metrics

- Define measurable KPIs and success criteria.
- Include both quantitative and qualitative metrics.

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
- **Next Steps** — per `_gaia/_config/lifecycle-sequence.yaml`

Where `{slug}` is a short kebab-case slug derived from the product vision (e.g., `product-brief-ai-code-review.md`).

## Finalize

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-product-brief/scripts/finalize.sh

## Next Steps

- Primary: `/gaia-create-prd` — expand the brief into a full Product Requirements Document.
- Alternative: `/gaia-market-research` — if competitive landscape needs deeper validation before the PRD.
- Alternative: `/gaia-domain-research` — if domain context is still thin.
