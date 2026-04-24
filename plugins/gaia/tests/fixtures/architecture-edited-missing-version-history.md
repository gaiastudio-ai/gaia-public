---
title: Architecture — E42-S9 Negative Fixture (missing Version History)
date: 2026-04-24
product: "Helix Cross-Border Payments"
version: "0.2.0"
---

# Architecture Document: Helix Cross-Border Payments

## 1. System Overview

Helix is a cross-border payments console addressing FR-001 and FR-002.

## 2. Architecture Decisions

| ID | Decision | Context | Consequences | Status | Addresses |
|----|----------|---------|--------------|--------|-----------|
| ADR-01 | Adopt TypeScript + Node 20 | Team expertise | Uniform tech | Accepted | FR-001 |
| ADR-04 | Webhook delivery via outbox pattern | At-least-once | Outbox overhead | Accepted | FR-003 |

## 3. System Components

### 3.1 Payment Orchestrator
- **Responsibility:** initiates payments

### 3.3 Partner Webhook Delivery
- **Responsibility:** webhook delivery (FR-003)

## 4. Data Architecture
Entities: Payment, WebhookOutbox.

## 5. Integration Points
| System | Protocol | Direction | Purpose |
|--------|----------|-----------|---------|
| Partner webhooks | REST | out | FR-003 event delivery |

## 6. Infrastructure
EKS, ArgoCD.

## 7. Security Architecture
OAuth2 + RBAC.

## 8. Cross-Cutting Concerns
Prometheus metrics, RFC 7807.

## Cascade Assessment

| Downstream Artifact | Impact | Recommended Action |
|---------------------|--------|--------------------|
| Epics and Stories | SIGNIFICANT | /gaia-add-stories |
| Test Plan | MINOR | /gaia-test-design |
| Infrastructure Design | NONE | no action |
| Traceability Matrix | MINOR | /gaia-trace |

## Review Findings Incorporated

Adversarial review not triggered — minor edit.
