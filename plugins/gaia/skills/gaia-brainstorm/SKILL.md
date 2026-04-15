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

### Step 2 — Elicit Project Vision

Ask the user the following questions, one at a time, and wait for a response before moving to the next:

1. What is the business idea or problem you want to explore?
2. Who are the target users?
3. What pain points does this address?
4. What makes this different from existing solutions?

### Step 3 — Competitive Landscape

- Based on user-provided information, analyze the competitive landscape.
- No web access — use user-provided info and general knowledge only.
- Identify direct and indirect competitors.
- Map competitive positioning.

### Step 4 — Opportunity Synthesis

- Synthesize findings into 3–5 opportunity areas.
- For each opportunity: describe it, estimate impact, note evidence.
- Rank opportunities by potential impact and feasibility.
- Collect all ideas explored during the session that did not make the top opportunity list into a **Parking Lot** — for each, note the idea, why it was deprioritized, and under what conditions it might become viable.

### Step 5 — Generate Output

Write a structured brainstorm artifact to `docs/creative-artifacts/brainstorm-{slug}.md` containing:

- Vision summary
- Target users
- Pain points
- Competitive landscape
- Opportunity areas (ranked)
- Parking Lot (deprioritized ideas with reasoning and revival conditions)
- Next steps per `_gaia/_config/lifecycle-sequence.yaml`

Where `{slug}` is a short kebab-case slug derived from the project vision (e.g., `brainstorm-ai-code-review.md`).

## Finalize

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-brainstorm/scripts/finalize.sh

## Next Steps

- Primary: `/gaia-market-research` — conduct market research to validate competitive landscape.
- Alternative: `/gaia-domain-research` — if domain-specific research is needed first.
- Alternative: `/gaia-tech-research` — if technology evaluation is needed first.
