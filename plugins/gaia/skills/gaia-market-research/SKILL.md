---
name: gaia-market-research
description: Conduct market research on competition and customers — Cluster 4 analysis skill. Use when the user wants to analyze competitors, define customer segments, and size a market (TAM/SAM/SOM) before or during product discovery.
argument-hint: "[market or industry focus]"
context: fork
tools: Read, Write, Glob, Grep, Bash, WebSearch, WebFetch
---

## Setup

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-market-research/scripts/setup.sh

## Mission

You are facilitating a market research session. Guide the user through scope definition, competitive analysis, customer research, and market sizing (TAM/SAM/SOM), then emit a structured market research report at `docs/planning-artifacts/market-research.md` for downstream consumers (e.g., `/gaia-domain-research`, `/gaia-product-brief`).

This skill is the native Claude Code conversion of the legacy `_gaia/lifecycle/workflows/1-analysis/market-research` workflow (brief §Cluster 4, story P4-S3). The step ordering, prompts, and output location follow the legacy `instructions.xml` mechanically — do not restructure, re-prompt, or reorder sections.

## Critical Rules

- Check web access availability before proceeding with research.
- If no web access, proceed with user-provided data and general knowledge only.
- State all market sizing assumptions clearly.
- The output file path is `docs/planning-artifacts/market-research.md` — downstream consumers read this exact path, so do not relocate it.
- Mechanical port: the six legacy steps below must appear in this exact order.

## Steps

### Step 1 — Scope Definition

Ask the user, in order, and wait for a response on each:

- **"What market or industry do you want to research?"**
- **"Are there specific competitors you want analyzed?"**
- **"What geographic scope? (global, regional, local)"**

### Step 2 — Web Access Check

- Check if MCP web tools are available for live research.
- If web access is available, proceed with live web research in subsequent steps.
- If no web access, notify the user: *"Web access unavailable. Proceeding with user-provided data and general knowledge. Results may be less comprehensive."*

### Step 3 — Competitive Analysis

- Identify and analyze competitors (direct and indirect).
- For each competitor capture: strengths, weaknesses, market position, pricing model.
- Create a competitive positioning matrix.

### Step 4 — Customer Research

- Define target customer segments.
- Analyze user behavior patterns and needs.
- Identify underserved needs and market gaps.

### Step 5 — Market Sizing

- Estimate Total Addressable Market (TAM).
- Estimate Serviceable Addressable Market (SAM).
- Estimate Serviceable Obtainable Market (SOM).
- State all assumptions clearly.

### Step 6 — Generate Output

Write a structured market research report to `docs/planning-artifacts/market-research.md` containing, in order:

- **Executive Summary**
- **Competitive Analysis** — direct and indirect competitors with strengths, weaknesses, market position, pricing model, and a competitive positioning matrix
- **Customer Segments** — target segments, behavior patterns, needs, and market gaps
- **Market Sizing** — TAM, SAM, SOM with all assumptions stated
- **Key Findings**
- **Strategic Recommendations**

[Source: _gaia/lifecycle/workflows/1-analysis/market-research/instructions.xml]
[Source: _gaia/lifecycle/workflows/1-analysis/market-research/workflow.yaml]

## Finalize

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-market-research/scripts/finalize.sh

## Next Steps

- Primary: `/gaia-domain-research` — research the domain or industry in depth.
- Alternative: `/gaia-tech-research` — if technology evaluation is needed.
- Alternative: `/gaia-product-brief` — if all research is complete.
