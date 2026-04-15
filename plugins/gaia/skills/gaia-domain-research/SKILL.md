---
name: gaia-domain-research
description: Conduct domain and industry research — Cluster 4 analysis skill. Use when the user wants to map a domain landscape (key players, regulations, trends, terminology) and assess domain-specific risks before product definition or technical research.
argument-hint: "[domain or industry focus]"
context: fork
allowed-tools: [Read, Write, Glob, Grep, Bash, WebSearch, WebFetch]
---

## Setup

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-domain-research/scripts/setup.sh

## Mission

You are facilitating a domain research session. Guide the user through domain scoping, domain landscape mapping, and domain-specific risk assessment, then emit a structured domain research report at `docs/planning-artifacts/domain-research.md` for downstream consumers (e.g., `/gaia-tech-research`, `/gaia-product-brief`).

This skill is the native Claude Code conversion of the legacy `_gaia/lifecycle/workflows/1-analysis/domain-research` workflow (brief §Cluster 4, story P4-S3). The step ordering, prompts, and output location follow the legacy `instructions.xml` mechanically — do not restructure, re-prompt, or reorder sections.

## Critical Rules

- Check web access availability before research.
- Clearly distinguish between verified facts and general knowledge.
- The output file path is `docs/planning-artifacts/domain-research.md` — downstream consumers read this exact path, so do not relocate it.
- Mechanical port: the five legacy steps below must appear in this exact order.

## Steps

### Step 1 — Domain Scoping

Ask the user, in order, and wait for a response on each:

- **"What domain or industry do you want to research?"**
- **"Are there specific aspects you want to focus on?"**

### Step 2 — Web Access Check

- Check if MCP web tools are available.
- If no web access, notify the user and proceed with general knowledge only.

### Step 3 — Domain Landscape

- Identify key players and organizations in the domain.
- Document relevant regulations and compliance requirements.
- Map industry trends and emerging patterns.
- Define domain-specific terminology and concepts.

### Step 4 — Domain-Specific Risks

- Identify regulatory and compliance risks.
- Assess technical risks specific to the domain.
- Evaluate market and competitive risks.

### Step 5 — Generate Output

Write a structured domain research report to `docs/planning-artifacts/domain-research.md` containing, in order:

- **Domain Overview**
- **Key Players** — organizations and roles
- **Regulatory Landscape** — regulations and compliance requirements
- **Trends** — industry trends and emerging patterns
- **Terminology Glossary** — domain-specific terms and concepts
- **Risk Assessment** — regulatory/compliance, technical, and market/competitive risks
- **Recommendations**

[Source: _gaia/lifecycle/workflows/1-analysis/domain-research/instructions.xml]
[Source: _gaia/lifecycle/workflows/1-analysis/domain-research/workflow.yaml]

## Finalize

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-domain-research/scripts/finalize.sh

## Next Steps

- Primary: `/gaia-tech-research` — evaluate technology options for the project.
- Alternative: `/gaia-product-brief` — if all research is complete.
