---
title: Architecture — E42-S8 Positive Fixture
date: 2026-04-24
product: "Helix Cross-Border Payments"
version: "0.1.0"
---

# Architecture Document: Helix Cross-Border Payments

> **Project:** Helix
> **Date:** 2026-04-24
> **Author:** Theo

## 1. System Overview

Helix is a cross-border payments console addressing FR-001 and FR-002. The system orchestrates
corridor initiation, 120-second rate-lock, AML triage, and reconciliation export. Business value
connects directly to reducing vendor payment failures for mid-market AP managers.

## 2. Architecture Decisions

The Decision Log captures significant decisions inline as table rows (no separate ADR directory
per CLAUDE.md convention).

| ID | Decision | Rationale | Status | Addresses |
|----|----------|-----------|--------|-----------|
| ADR-01 | Adopt TypeScript + Node 20 | Team expertise and ecosystem maturity | Accepted | FR-001 |
| ADR-02 | Use Postgres 16 for payment state | ACID guarantees for settlement finality | Accepted | FR-002, FR-005 |
| ADR-03 | Rate-lock state machine implemented in Redis | Sub-second expiry enforcement | Accepted | FR-002 |
| ADR-04 | Webhook delivery via an outbox pattern | At-least-once semantics with idempotency | Accepted | FR-003 |

## 3. System Components

### 3.1 Payment Orchestrator

- **Responsibility:** initiates, locks, and confirms payments on the corridor
- **Technology:** TypeScript + Fastify, Node 20
- **Interfaces:** REST API at `/v1/payments`; gRPC to the settlement engine

### 3.2 Settlement Engine

- **Responsibility:** drives funds movement through correspondent banks
- **Technology:** Go 1.22 + gRPC streaming
- **Interfaces:** internal gRPC; outbound SWIFT MT103 adapter

### 3.3 Exception Queue

- **Responsibility:** AML flagged-payment triage (FR-004)
- **Technology:** TypeScript + Fastify
- **Interfaces:** REST API at `/v1/exceptions`; streaming websocket for live updates

Communication patterns: synchronous REST for user-facing flows, event-driven messaging between
orchestrator and settlement engine via an at-least-once outbox. Service boundaries align with the
bounded contexts documented in the PRD.

## 4. Data Architecture

### Data Model

Key entities: Payment, Quote, ExceptionTicket, Corridor. Payment has a finite-state machine
(initiated → quoted → locked → confirmed → settled or failed). Each entity traces back to at
least one FR.

### Data Flow

Data moves from the Payment Orchestrator into Postgres (payments, quotes tables), into Redis
(quote lock TTL), and into the Settlement Engine via outbox-driven events. Replication: Postgres
streaming replicas in two AZs. Caching: Redis for quote locks with a 120-second TTL. Backups:
daily snapshots retained 30 days.

## 5. Integration Points

| System | Protocol | Direction | Purpose |
|--------|----------|-----------|---------|
| SWIFT MT103 | message-queue | out | initiate correspondent settlement |
| Sanctions screening | REST | out | AML screening before lock |
| Reconciliation warehouse | Kafka | out | FR-005 history export |
| Partner KYC provider | REST | in/out | identity verification |

### API Design

Endpoints overview: `POST /v1/payments` (initiate), `POST /v1/payments/{id}/confirm` (confirm),
`GET /v1/payments/{id}` (inspect), `GET /v1/payments` (history, FR-005), `POST /v1/exceptions/{id}/release`
(FR-004), `POST /v1/webhooks` (FR-003 subscription management).

Authentication and authorisation: OAuth2 client-credentials for machine clients; RBAC on every
endpoint with least-privilege scopes. API versioning follows a URI-prefix scheme (`/v1/...`) with a
deprecation window of at least 6 months and RFC 7807 error responses.

## 6. Infrastructure

Deployment topology: three environments — dev, staging, prod — on Kubernetes (EKS) with
GitOps via ArgoCD. Production runs across two AZs with a target RTO of 15 minutes and RPO of
5 minutes. Hosting: AWS us-east-1 primary, us-west-2 DR. Containerisation: distroless base
images; orchestration: EKS. Monitoring: Prometheus + Grafana; logging: OpenSearch with a
30-day retention window; tracing: OpenTelemetry collector to Jaeger.

## 7. Security Architecture

Authentication: OAuth2 client-credentials. Authorisation: RBAC at the gateway + per-endpoint
scopes. Data protection: TLS 1.3 in transit; AES-256 at rest; PII tokenisation for vendor names.
Threat mitigations: rate-limit brute-force probes on `/v1/payments`, WAF for OWASP Top 10,
KMS-managed keys for the idempotency-key HMAC.

## 8. Cross-Cutting Concerns

- **Logging:** structured JSON logs with correlation IDs across services
- **Monitoring:** Prometheus metrics for quote-lock expiry counts, confirm success rate, and
  settlement SLA; alert on p95 latency > 800ms
- **Error handling:** RFC 7807 problem+json responses with stable type URIs
- **Resilience:** circuit breakers on outbound calls; exponential backoff with jitter

## 9. Risks and Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|-----------|-----------|
| Correspondent bank outage | H | M | dual-provider failover at the settlement engine |
| Quote lock stampede at expiry | M | M | Redis TTL + jittered re-quote |
| AML queue backlog | H | L | elastic operator pool + SLA paging |

## Decision to Requirement Mapping

| ADR | FR / NFR Addressed |
|-----|-------------------|
| ADR-01 | FR-001, FR-002 |
| ADR-02 | FR-002, FR-005 |
| ADR-03 | FR-002 |
| ADR-04 | FR-003 |

## Review Findings Incorporated

Adversarial review completed 2026-04-24. Findings:

- F-01 (high): add dual-provider failover at settlement engine — incorporated in §9 risk table
- F-02 (medium): explicit idempotency-key HMAC — incorporated in §7 security architecture
- F-03 (medium): tighten quote-lock TTL enforcement — incorporated in §3 and §4
