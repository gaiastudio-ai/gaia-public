---
name: gaia-infra-design
description: Design infrastructure topology and IaC structure through collaborative discovery with the devops subagent (Soren) — Cluster 6 architecture skill. Use when the user wants to produce an infrastructure design document covering deployment topology, environment design, IaC structure, and observability plan.
context: fork
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Agent]
---

## Setup

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-infra-design/scripts/setup.sh

## Mission

You are orchestrating the creation of an Infrastructure Design document. The infrastructure authoring is delegated to the **devops** subagent (Soren), who designs deployment topology, environment layout, IaC structure, and observability plans. You load the architecture document, validate inputs, coordinate the multi-step flow, and write the output to `docs/planning-artifacts/infrastructure-design.md`.

This skill is the native Claude Code conversion of the legacy `_gaia/lifecycle/workflows/3-solutioning/infrastructure-design` workflow (brief Cluster 6, story P6-S5 / E28-S49). The step ordering, prompts, and output path are preserved verbatim from the legacy `instructions.xml` — do not restructure, re-prompt, or reorder.

## Critical Rules

- An architecture document MUST exist at `docs/planning-artifacts/architecture.md` before starting. If missing, fail fast with "Architecture doc not found at docs/planning-artifacts/architecture.md — run /gaia-create-arch first."
- Every significant infrastructure decision must be recorded in the devops-sidecar memory.
- Every environment must have a defined purpose and access policy.
- Infrastructure authoring is delegated to the `devops` subagent (Soren) via native Claude Code subagent invocation — do NOT inline Soren's persona into this skill body. If the devops subagent (E28-S21) is not available, fail with "devops subagent not available — install E28-S21" error.
- If `docs/planning-artifacts/infrastructure-design.md` already exists, warn the user: "An existing infrastructure design document was found. Continuing will overwrite it. Confirm to proceed or abort." Do not silently overwrite.

## Steps

### Step 1 — Load Architecture

- Read `docs/planning-artifacts/architecture.md`.
- Extract component inventory, service boundaries, data stores.
- Identify compute, storage, and networking requirements.

### Step 2 — Environment Design

Delegate to the **devops** subagent (Soren) via `agents/devops` to design environments.

- Define environments: dev, staging, production (+ preview if needed).
- Specify environment parity strategy — how close staging mirrors production.
- Define access policies and promotion gates between environments.

### Step 3 — Deployment Topology

Delegate to the **devops** subagent (Soren) via `agents/devops` to design the deployment topology.

- Define container orchestration strategy (Kubernetes, ECS, serverless, etc.).
- Design service mesh and load balancing approach.
- Specify scaling strategy: horizontal, vertical, auto-scaling triggers.
- Define networking: VPC, subnets, security groups, CDN.

### Step 4 — IaC Structure

Delegate to the **devops** subagent (Soren) via `agents/devops` to define infrastructure-as-code.

- Define Infrastructure-as-Code project structure and module design.
- Specify IaC tool and conventions (Terraform, Pulumi, CloudFormation).
- Design module boundaries matching service boundaries.
- Define state management strategy.

### Step 5 — Observability Plan

Delegate to the **devops** subagent (Soren) via `agents/devops` to define observability.

- Define logging strategy: structured logs, log aggregation, retention.
- Define metrics: application metrics, infrastructure metrics, custom dashboards.
- Define tracing: distributed tracing, correlation IDs.
- Define alerting: SLO-based alerts, escalation policies, on-call rotation.

### Step 6 — Generate Output

- Record key decisions in devops-sidecar memory.
- Write the infrastructure design document to `docs/planning-artifacts/infrastructure-design.md` with: environment matrix, deployment topology, IaC structure, observability plan, and decision rationale.

## Finalize

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-infra-design/scripts/finalize.sh
