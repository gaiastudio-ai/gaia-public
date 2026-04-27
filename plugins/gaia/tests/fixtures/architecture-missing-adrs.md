---
title: Architecture — E42-S8 Negative Fixture (Decision Log heading-only)
date: 2026-04-24
product: "Helix Cross-Border Payments"
---

# Architecture Document: Helix Cross-Border Payments

> **Project:** Helix
> **Date:** 2026-04-24
> **Author:** Theo

## 1. System Overview

High-level overview addressing FR-001 and FR-002.

## 2. Architecture Decisions

The Decision Log table is present as a heading but the table body has no ADR rows — this
fixture triggers AC-EC5 (Decision Log table empty / ADRs present check failure) and VCP-CHK-16
(negative checklist path). The V1 anchor "Decisions recorded" must appear verbatim in the
violation output.

## 3. System Components

### 3.1 Payment Orchestrator

- **Responsibility:** initiates payments
- **Technology:** TypeScript + Fastify
- **Interfaces:** REST

## 4. Data Architecture

### Data Model

Payment, Quote, ExceptionTicket.

### Data Flow

Data moves through Postgres and Redis.

## 5. Integration Points

| System | Protocol | Direction | Purpose |
|--------|----------|-----------|---------|
| SWIFT | MQ | out | settle |

### API Design

Endpoints: `POST /v1/payments`, `GET /v1/payments/{id}`. Auth: OAuth2. Versioning: URI prefix.

## 6. Infrastructure

Kubernetes across dev, staging, prod environments.

## 7. Security Architecture

TLS 1.3, RBAC, KMS.

## 8. Cross-Cutting Concerns

- **Logging:** JSON
- **Monitoring:** Prometheus
- **Error handling:** RFC 7807

## 9. Risks and Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|-----------|-----------|
| Bank outage | H | M | failover |

## Review Findings Incorporated

Adversarial review deferred — no findings to incorporate.
