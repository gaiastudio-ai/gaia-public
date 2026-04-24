---
name: gaia-brainstorm
description: Brainstorm a new project idea with structured techniques — Cluster 4 analysis skill. Use when the user wants to explore a business idea, target users, pain points, and opportunity areas before writing a PRD.
argument-hint: "[project idea or topic]"
context: fork
allowed-tools: [Read, Write, Glob, Grep, Bash]
---

## Setup

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-brainstorm/scripts/setup.sh

## Mission

You are facilitating a structured brainstorming session for a new project idea. Guide the user through vision, target users, competitive landscape, and opportunity synthesis, then emit a structured brainstorm artifact at `docs/creative-artifacts/brainstorm-*.md` for downstream consumers (e.g., `/gaia-create-prd`).

This skill is the native Claude Code conversion of the legacy `_gaia/lifecycle/workflows/1-analysis/brainstorm-project` workflow (brief §Cluster 4, story P4-S1). The step ordering, prompts, and output path are preserved verbatim from the legacy `instructions.xml` — do not restructure or re-prompt.

## Critical Rules

- Check `docs/creative-artifacts/` for prior brainstorming output before starting.
- All findings must be grounded in user-provided information — no web access, no fabrication.
- The output file path is `docs/creative-artifacts/brainstorm-{slug}.md` — downstream consumers glob on this pattern, so do not relocate it.

## Steps

### Step 1 — Discover Context

- Check `docs/creative-artifacts/` for prior brainstorming output from the creative module.
- If found, load and incorporate insights into the session.
- If not found, note that no prior creative work exists and proceed.

> `!scripts/write-checkpoint.sh gaia-brainstorm 1 slug="$SLUG" technique="$TECHNIQUE"`

### Step 2 — Elicit Project Vision

Ask the user the following questions, one at a time, and wait for a response before moving to the next:

1. What is the business idea or problem you want to explore?
2. Who are the target users?
3. What pain points does this address?
4. What makes this different from existing solutions?

> `!scripts/write-checkpoint.sh gaia-brainstorm 2 slug="$SLUG" technique="$TECHNIQUE"`

### Step 3 — Competitive Landscape

- Based on user-provided information, analyze the competitive landscape.
- No web access — use user-provided info and general knowledge only.
- Identify direct and indirect competitors.
- Map competitive positioning.

> `!scripts/write-checkpoint.sh gaia-brainstorm 3 slug="$SLUG" technique="$TECHNIQUE"`

### Step 4 — Opportunity Synthesis

- Synthesize findings into 3–5 opportunity areas.
- For each opportunity: describe it, estimate impact, note evidence.
- Rank opportunities by potential impact and feasibility.
- Collect all ideas explored during the session that did not make the top opportunity list into a **Parking Lot** — for each, note the idea, why it was deprioritized, and under what conditions it might become viable.

> `!scripts/write-checkpoint.sh gaia-brainstorm 4 slug="$SLUG" technique="$TECHNIQUE"`

### Step 5 — Generate Output

Write a structured brainstorm artifact to `docs/creative-artifacts/brainstorm-{slug}.md` containing:

- Vision summary
- Target users
- Pain points
- Competitive landscape
- Opportunity areas (ranked)
- Parking Lot (deprioritized ideas with reasoning and revival conditions)
- Next steps per `${CLAUDE_PLUGIN_ROOT}/knowledge/lifecycle-sequence.yaml` (routing table ships inside the plugin under ADR-041's `knowledge/` convention; the legacy v1 location `_gaia/_config/lifecycle-sequence.yaml` is retired and no longer used)

Where `{slug}` is a short kebab-case slug derived from the project vision (e.g., `brainstorm-ai-code-review.md`).

> `!scripts/write-checkpoint.sh gaia-brainstorm 5 slug="$SLUG" technique="$TECHNIQUE" --paths docs/creative-artifacts/brainstorm-${SLUG}.md`

## Validation

<!--
  E42-S1 — V1→V2 24-item checklist port (FR-341, FR-359).
  Classification (24 items total):
    - Script-verifiable: 15 (SV-01..SV-15) — enforced by finalize.sh.
    - LLM-checkable:      9 (LLM-01..LLM-09) — evaluated by the host LLM
      against the brainstorm artifact below.
  Exit code 0 when all script-verifiable items PASS; non-zero otherwise.
  See docs/implementation-artifacts/E42-S1-port-gaia-brainstorm-checklist.md.
-->

- [script-verifiable] SV-01 — Output artifact exists at docs/creative-artifacts/brainstorm-*.md
- [script-verifiable] SV-02 — Output artifact is non-empty
- [script-verifiable] SV-03 — Output filename matches brainstorm-{slug}.md pattern
- [script-verifiable] SV-04 — Vision Summary section present
- [script-verifiable] SV-05 — Target Users section present
- [script-verifiable] SV-06 — Pain Points section present
- [script-verifiable] SV-07 — Differentiators section present
- [script-verifiable] SV-08 — Competitive Landscape section present
- [script-verifiable] SV-09 — Opportunity Areas section present
- [script-verifiable] SV-10 — At least 3 opportunity areas identified
- [script-verifiable] SV-11 — Parking Lot section present
- [script-verifiable] SV-12 — Next Steps section present
- [script-verifiable] SV-13 — Creative-artifacts/ checked for prior outputs
- [script-verifiable] SV-14 — Artifact has frontmatter or top-level title
- [script-verifiable] SV-15 — Opportunities listed as a structured list
- [LLM-checkable] LLM-01 — Business idea clearly articulated
- [LLM-checkable] LLM-02 — Target users well-defined
- [LLM-checkable] LLM-03 — Pain points specific and grounded in user information
- [LLM-checkable] LLM-04 — Differentiators stated clearly vs competitors
- [LLM-checkable] LLM-05 — Direct and indirect competitors identified
- [LLM-checkable] LLM-06 — Competitive positioning mapped
- [LLM-checkable] LLM-07 — Each opportunity has supporting evidence
- [LLM-checkable] LLM-08 — Opportunities ranked by impact and feasibility
- [LLM-checkable] LLM-09 — Parking-lot entries include deprioritization reasoning and revival conditions

## Finalize

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-brainstorm/scripts/finalize.sh

## Next Steps

- Primary: `/gaia-market-research` — conduct market research to validate competitive landscape.
- Alternative: `/gaia-domain-research` — if domain-specific research is needed first.
- Alternative: `/gaia-tech-research` — if technology evaluation is needed first.
