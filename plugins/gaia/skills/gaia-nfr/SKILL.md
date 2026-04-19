---
name: gaia-nfr
description: Assess non-functional requirements covering performance, scalability, reliability, and security. Use when "assess NFRs" or /gaia-nfr.
argument-hint: "[story-key]"
context: main
tools: Read, Write, Edit, Grep, Glob, Bash
---

## Setup

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-nfr/scripts/setup.sh

## Mission

You are producing an NFR assessment report covering performance, scalability, reliability, and security requirements. Each dimension is rated with risk levels (high, medium, low) with justification. The output is written to `docs/test-artifacts/nfr-assessment.md`.

This skill is the native Claude Code conversion of the legacy `_gaia/testing/workflows/nfr-assessment` workflow (E28-S88, Cluster 12, ADR-041). The step ordering, prompts, and output path are preserved from the legacy instructions.xml.

**Main context semantics (ADR-041):** This skill runs under `context: main` with full tool access. It reads project state (architecture, PRD, story) and produces an output document.

## Critical Rules

- Knowledge fragments are bundled in this skill's `knowledge/` directory -- load them JIT when referenced by a step.
- A story key or project context MUST be available. If no story key is provided as an argument and no project context can be loaded, prompt: "Provide a story key or confirm project-level assessment."
- Assess all dimensions: performance, security, reliability, and scalability.
- Rate risks: high, medium, low with justification for each rating.
- Output MUST be written to `docs/test-artifacts/nfr-assessment.md`.
- Sprint-status.yaml is NEVER written by this skill (Sprint-Status Write Safety rule).

## Steps

### Step 1 -- Load NFRs

- Load knowledge fragment: `knowledge/risk-governance.md` for risk-based assessment methodology
- Read NFRs from PRD at `docs/planning-artifacts/prd.md` if available.
- Read NFRs from architecture document at `docs/planning-artifacts/architecture.md` if available.
- If neither document exists, proceed with generic NFR assessment based on common patterns.
- Extract: response time targets, throughput requirements, availability SLAs, security requirements, data protection obligations.

### Step 2 -- Performance Assessment

- Assess response time targets: P50, P95, P99 latency expectations.
- Assess throughput requirements: requests per second, concurrent users.
- Assess resource limits: CPU, memory, storage, network bandwidth.
- Rate performance risk level (high/medium/low) with justification.
- Identify performance-sensitive paths and bottleneck candidates.

### Step 3 -- Security Assessment

- Assess authentication mechanisms and strength.
- Assess authorization model and access control boundaries.
- Assess data protection: encryption at rest and in transit, PII handling.
- Rate security risk level (high/medium/low) with justification.
- Reference OWASP Top 10 categories where applicable.

### Step 4 -- Reliability Assessment

- Assess availability targets: uptime SLA (99.9%, 99.95%, 99.99%).
- Assess fault tolerance: graceful degradation, circuit breakers, fallback paths.
- Assess recovery: RTO (Recovery Time Objective), RPO (Recovery Point Objective).
- Rate reliability risk level (high/medium/low) with justification.

### Step 5 -- Scalability Assessment

- Assess horizontal scaling capability: stateless services, load distribution.
- Assess vertical scaling limits: single-node capacity ceilings.
- Assess data tier scalability: database sharding, read replicas, caching layers.
- Rate scalability risk level (high/medium/low) with justification.

### Step 6 -- Migration Assessment (Brownfield)

This step is **optional** -- activate only when brownfield indicators are present.

- If PRD contains "Mode: Brownfield" or project has `docs/planning-artifacts/brownfield-assessment.md`: activate this step.
- Evaluate data migration performance, backward compatibility, dual-write latency, legacy API parity, and session continuity.
- Rate each migration risk dimension: high, medium, low with justification.
- If no brownfield indicators are found: skip this step entirely.

### Step 7 -- Generate Report

- Compile NFR assessment report with:
  - Executive summary with overall risk posture
  - Performance assessment with risk rating and justification
  - Security assessment with risk rating and justification
  - Reliability assessment with risk rating and justification
  - Scalability assessment with risk rating and justification
  - Migration assessment (if brownfield, otherwise omit)
  - Consolidated risk matrix: dimension, risk level, probability, impact
- Write output to `docs/test-artifacts/nfr-assessment.md`.

## Finalize

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-nfr/scripts/finalize.sh
