---
name: gaia-threat-model
description: Create security threat model using STRIDE/DREAD methodology through collaborative analysis with the security subagent (Zara) — Cluster 6 architecture skill. Use when the user wants to produce a validated threat model document covering asset identification, STRIDE threat analysis, DREAD risk scoring, mitigation strategies, and security requirements.
context: fork
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Agent]
---

## Setup

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-threat-model/scripts/setup.sh

## Memory

!${CLAUDE_PLUGIN_ROOT}/scripts/memory-loader.sh security decision-log

## Mission

You are orchestrating the creation of a Security Threat Model document. The threat analysis and scoring is delegated to the **security** subagent (Zara), who conducts STRIDE analysis, DREAD scoring, and produces mitigation strategies. You load the architecture document, validate inputs, coordinate the multi-step flow, and write the output to `docs/planning-artifacts/threat-model.md`.

This skill is the native Claude Code conversion of the legacy `_gaia/lifecycle/workflows/3-solutioning/security-threat-model` workflow (brief Cluster 6, story P6-S6 / E28-S50). The step ordering, prompts, and output path are preserved verbatim from the legacy `instructions.xml` — do not restructure, re-prompt, or reorder.

## Critical Rules

- An architecture document MUST exist at `docs/planning-artifacts/architecture.md` before starting. If missing, fail fast with "Architecture doc not found at docs/planning-artifacts/architecture.md — run /gaia-create-arch first."
- Use STRIDE methodology for threat identification — all six categories must be evaluated for every component and data flow.
- Use DREAD scoring for risk prioritization — all five dimensions must be rated for every identified threat.
- Record all threat model decisions in security-sidecar memory.
- Threat analysis is delegated to the `security` subagent (Zara) via native Claude Code subagent invocation (`agents/security`) — do NOT inline Zara's persona into this skill body. If the security subagent (E28-S21) is not available, fail with "security subagent not available — install E28-S21" error.
- If `docs/planning-artifacts/threat-model.md` already exists, warn the user: "An existing threat model document was found. Continuing will overwrite it. Confirm to proceed or abort." Do not silently overwrite.

## Steps

### Step 1 — Load Architecture

- Read `docs/planning-artifacts/architecture.md`.
- Extract system components, data flows, and trust boundaries.
- Identify external interfaces, APIs, and user-facing endpoints.

> `!scripts/write-checkpoint.sh gaia-threat-model 1 project_name="$PROJECT_NAME" threat_model_scope=load stride_stage=init`

### Step 2 — Identify Assets

Delegate to the **security** subagent (Zara) via `agents/security` to catalog assets.

- Catalog valuable data and systems: user credentials, PII, financial data, API keys.
- Classify sensitivity: critical, high, medium, low.
- Map asset locations across system components.

> `!scripts/write-checkpoint.sh gaia-threat-model 2 project_name="$PROJECT_NAME" threat_model_scope=assets stride_stage=assets asset_count="$ASSET_COUNT"`

### Step 3 — STRIDE Analysis

Delegate to the **security** subagent (Zara) via `agents/security` to conduct STRIDE analysis.

For each component and data flow, evaluate all six STRIDE categories:

- **Spoofing** — Can identities be faked?
- **Tampering** — Can data be modified in transit or storage?
- **Repudiation** — Can actions be denied without trace?
- **Information Disclosure** — Can data leak to unauthorized parties?
- **Denial of Service** — Can availability be disrupted?
- **Elevation of Privilege** — Can users gain unauthorized access?

> `!scripts/write-checkpoint.sh gaia-threat-model 3 project_name="$PROJECT_NAME" threat_model_scope=stride stride_stage=analysis threat_count="$THREAT_COUNT"`

### Step 4 — DREAD Scoring

Delegate to the **security** subagent (Zara) via `agents/security` to score threats.

For each identified threat, rate 1-10 on each DREAD dimension:

- **Damage potential** — How severe is the impact?
- **Reproducibility** — How easy to reproduce?
- **Exploitability** — How much skill/effort to exploit?
- **Affected users** — What percentage of users impacted?
- **Discoverability** — How easy to find the vulnerability?

Calculate average DREAD score and assign risk level: Critical (8-10), High (6-8), Medium (4-6), Low (1-4).

> `!scripts/write-checkpoint.sh gaia-threat-model 4 project_name="$PROJECT_NAME" threat_model_scope=dread stride_stage=scoring dread_scores_present=true`

### Step 5 — Mitigation Strategies

Delegate to the **security** subagent (Zara) via `agents/security` to propose mitigations.

- For each high and critical risk threat, propose specific mitigations.
- Map mitigations to implementation: code changes, configuration, infrastructure.
- Prioritize mitigations by risk reduction vs implementation effort.

> `!scripts/write-checkpoint.sh gaia-threat-model 5 project_name="$PROJECT_NAME" threat_model_scope=mitigations stride_stage=mitigations mitigation_count="$MITIGATION_COUNT"`

### Step 6 — Security Requirements

Delegate to the **security** subagent (Zara) via `agents/security` to extract requirements.

- Extract security requirements from threat analysis.
- Format as SR-1, SR-2, etc. with clear acceptance criteria.
- Map requirements to architecture components they protect.

> `!scripts/write-checkpoint.sh gaia-threat-model 6 project_name="$PROJECT_NAME" threat_model_scope=requirements stride_stage=requirements sr_count="$SR_COUNT"`

### Step 7 — Generate Output

- Record key decisions in security-sidecar memory.
- Write the threat model document to `docs/planning-artifacts/threat-model.md` with: assets table, STRIDE analysis per component, DREAD scores, risk levels, mitigation strategies, and security requirements list.

> `!scripts/write-checkpoint.sh gaia-threat-model 7 project_name="$PROJECT_NAME" threat_model_scope=output stride_stage=complete --paths docs/planning-artifacts/threat-model.md`

## Finalize

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-threat-model/scripts/finalize.sh
