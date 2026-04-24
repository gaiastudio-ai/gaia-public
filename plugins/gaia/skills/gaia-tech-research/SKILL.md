---
name: gaia-tech-research
description: Research a technology or tech stack with objective trade-off analysis — Cluster 4 analysis skill. Use when the user wants to evaluate technologies, compare alternatives, and get adoption recommendations before architecture decisions.
argument-hint: "[technology or tech stack to research]"
context: fork
allowed-tools: [Read, Write, Glob, Grep, Bash, WebSearch, WebFetch]
---

## Setup

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-tech-research/scripts/setup.sh

## Mission

You are conducting a technical research session. Guide the user through technology scoping, evaluation, and trade-off analysis, then emit a structured technical research report at `docs/planning-artifacts/technical-research.md` for downstream consumers (e.g., `/gaia-product-brief`, `/gaia-create-arch`).

This skill is the native Claude Code conversion of the legacy `_gaia/lifecycle/workflows/1-analysis/technical-research` workflow (brief §Cluster 4, story P4-S4). The step ordering, prompts, and output location follow the legacy `instructions.xml` mechanically — do not restructure, re-prompt, or reorder sections.

## Critical Rules

- Check web access availability before proceeding with research.
- If no web access, proceed with user-provided data and general knowledge only.
- Provide objective trade-off analysis, not technology advocacy.
- The output file path is `docs/planning-artifacts/technical-research.md` — downstream consumers read this exact path, so do not relocate it.
- Mechanical port: the five legacy steps below must appear in this exact order.

## Steps

### Step 1 — Technology Scoping

Ask the user, in order, and wait for a response on each:

- **"What technologies or tech stack do you want to research?"**
- **"What is the use case or problem context?"**
- **"Are there constraints (team expertise, budget, timeline)?"**

> `!scripts/write-checkpoint.sh gaia-tech-research 1 technology="$TECHNOLOGY" evaluation_criteria="$EVALUATION_CRITERIA"`

### Step 2 — Web Access Check

- Check if MCP web tools are available for live research.
- If web access is available, proceed with live web research in subsequent steps.
- If no web access, notify the user: *"Web access unavailable. Proceeding with user-provided data and general knowledge. Results may be less comprehensive."*

> `!scripts/write-checkpoint.sh gaia-tech-research 2 technology="$TECHNOLOGY" evaluation_criteria="$EVALUATION_CRITERIA"`

### Step 3 — Technology Evaluation

- Assess each technology for: maturity, community size, learning curve, licensing.
- Evaluate ecosystem: libraries, tools, IDE support, documentation quality.
- Check production readiness: stability, performance characteristics, scalability.

> `!scripts/write-checkpoint.sh gaia-tech-research 3 technology="$TECHNOLOGY" evaluation_criteria="$EVALUATION_CRITERIA"`

### Step 4 — Trade-off Analysis

- Create pros/cons matrix for each technology option.
- Compare alternatives across key dimensions.
- Provide recommendation with clear rationale.

> `!scripts/write-checkpoint.sh gaia-tech-research 4 technology="$TECHNOLOGY" evaluation_criteria="$EVALUATION_CRITERIA"`

### Step 5 — Generate Output

Write a structured technical research report to `docs/planning-artifacts/technical-research.md` containing, in order:

- **Technology Overview** — summary of each evaluated technology
- **Evaluation Matrix** — maturity, community, learning curve, licensing, ecosystem, production readiness
- **Trade-off Analysis** — pros/cons matrix and cross-dimensional comparison
- **Recommendation** — recommended technology with clear rationale
- **Migration / Adoption Considerations** — timeline, team ramp-up, risk factors

[Source: _gaia/lifecycle/workflows/1-analysis/technical-research/instructions.xml]
[Source: _gaia/lifecycle/workflows/1-analysis/technical-research/workflow.yaml]

> `!scripts/write-checkpoint.sh gaia-tech-research 5 technology="$TECHNOLOGY" evaluation_criteria="$EVALUATION_CRITERIA" --paths docs/planning-artifacts/technical-research.md`

## Finalize

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-tech-research/scripts/finalize.sh

## Next Steps

- Primary: `/gaia-product-brief` — consolidate all research into a product brief.
- Alternative: `/gaia-advanced-elicitation` — if deeper requirements exploration is needed.
