---
title: Architecture — E42-S9 Positive Fixture (edited)
date: 2026-04-24
product: "Helix Cross-Border Payments"
version: "0.2.0"
---

# Architecture Document: Helix Cross-Border Payments

> **Project:** Helix
> **Date:** 2026-04-24
> **Author:** Theo
> **Version:** 0.2.0

## 1. System Overview

Helix is a cross-border payments console addressing FR-001 and FR-002. This edit adds the
Partner Webhook Delivery component (FR-003) and introduces an at-least-once outbox ADR.

## 2. Architecture Decisions

The Decision Log captures significant decisions inline as table rows.

| ID | Decision | Context | Consequences | Status | Addresses |
|----|----------|---------|--------------|--------|-----------|
| ADR-01 | Adopt TypeScript + Node 20 | Team expertise and ecosystem maturity | Uniform language across services | Accepted | FR-001 |
| ADR-02 | Use Postgres 16 for payment state | ACID guarantees for settlement finality | Strong consistency at cost of scale | Accepted | FR-002, FR-005 |
| ADR-03 | Rate-lock state machine in Redis | Sub-second expiry enforcement | Adds Redis dependency | Superseded by ADR-05 | FR-002 |
| ADR-04 | Webhook delivery via outbox pattern | At-least-once semantics with idempotency | Storage overhead for outbox table | Accepted | FR-003 |
| ADR-05 | Rate-lock FSM in Postgres (replaces ADR-03) | Single-system correctness; remove Redis | Slight TTL precision tradeoff | Accepted | FR-002 | Supersedes ADR-03 |

## 3. System Components

### 3.1 Payment Orchestrator

- **Responsibility:** initiates, locks, and confirms payments on the corridor
- **Technology:** TypeScript + Fastify, Node 20
- **Interfaces:** REST API at `/v1/payments`; gRPC to the settlement engine

### 3.2 Settlement Engine

- **Responsibility:** drives funds movement through correspondent banks
- **Technology:** Go 1.22 + gRPC streaming

### 3.3 Partner Webhook Delivery

- **Responsibility:** at-least-once webhook delivery (FR-003)
- **Technology:** TypeScript + Fastify + Postgres outbox
- **Interfaces:** REST API at `/v1/webhooks`

## 4. Data Architecture

Key entities: Payment, Quote, ExceptionTicket, Corridor, WebhookOutbox (new for FR-003).
Data flow: orchestrator → Postgres → outbox → webhook delivery worker.

## 5. Integration Points

| System | Protocol | Direction | Purpose |
|--------|----------|-----------|---------|
| SWIFT MT103 | message-queue | out | initiate correspondent settlement |
| Reconciliation warehouse | Kafka | out | FR-005 history export |
| Partner webhooks | REST | out | FR-003 event delivery |

### API Design

Endpoints: `POST /v1/payments`, `POST /v1/webhooks`. OAuth2 client-credentials + RBAC.

## 6. Infrastructure

Deployment topology: dev, staging, prod on Kubernetes (EKS). GitOps via ArgoCD.

## 7. Security Architecture

TLS 1.3, AES-256 at rest, PII tokenisation.

## 8. Cross-Cutting Concerns

- **Logging:** structured JSON logs with correlation IDs
- **Monitoring:** Prometheus metrics
- **Error handling:** RFC 7807 problem+json responses

## Version History

| Date | Change | Reason | CR/Reference |
|------|--------|--------|-------------|
| 2026-04-20 | Initial release | create-architecture | — |
| 2026-04-24 | Add Partner Webhook Delivery component; supersede rate-lock ADR-03 with ADR-05 | adversarial-review | CR-102 |

## Cascade Assessment

Pending Cascades — downstream artifact impact classification from this edit:

| Downstream Artifact | Impact | Recommended Action |
|---------------------|--------|--------------------|
| Epics and Stories | SIGNIFICANT | /gaia-add-stories |
| Test Plan | MINOR | /gaia-test-design |
| Infrastructure Design | NONE | no action |
| Traceability Matrix | MINOR | /gaia-trace |

Recorded in architect-sidecar memory at `_memory/architect-sidecar/architecture-decisions.md`.

## Review Findings Incorporated

Adversarial review 2026-04-24 amended findings:

- F-11 (high): bounded retry for webhook outbox — incorporated in §3.3
- F-12 (medium): supersede Redis FSM — incorporated via ADR-05

Before/after mapping: ADR-03 (Accepted → Superseded by ADR-05), §3 added §3.3.
