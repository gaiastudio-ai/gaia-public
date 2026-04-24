---
title: Product Requirements Document — E42-S6 Positive Fixture
date: 2026-04-24
product: "Helix Cross-Border Payments"
version: "0.1.0"
---

# PRD: Helix Cross-Border Payments

## Overview

Helix is an API-first cross-border B2B payments platform that settles across 12 major corridors
with rate lock at initiation. This PRD captures the first 18 months of scope, requirements, and
success criteria. Treasurers and AP managers are the primary users.

## Goals and Non-Goals

- Goal: Sub-4-hour settlement finality for 95 percent of transactions across launch corridors.
- Goal: All-in quoted rate lock at initiation, valid for 120 seconds.
- Goal: Audit-grade compliance trail for every transaction.
- Non-Goal: Consumer P2P payments (out of scope for v1).
- Non-Goal: Crypto on-ramp or stablecoin settlement (deferred).

## User Stories

- As Dana, an AP manager, I want predictable settlement windows so I can hit vendor payroll cutoffs.
- As Marco, a treasurer, I want rate-lock at initiation so I can commit to cash-flow plans.
- As an operator, I want an exception triage console so I can resolve AML holds quickly.
- As a compliance officer, I want a full KYC and travel-rule packet per transaction.

## User Personas

- Dana (AP manager) — owns weekly vendor payouts on a US-to-EU corridor.
- Marco (Treasurer) — owns working-capital optimisation across LATAM-to-US flows.
- Opal (Operator) — resolves exceptions from the web console.

## Functional Requirements

Prioritised using MoSCoW.

- **Must**
  - FR-001 — Initiate payment with idempotency key, returns locked quote.
    - Acceptance Criteria:
      - Given a valid idempotency key and payload, when POST /payments is called, then the response contains a rate-locked quote.
      - Given a duplicate idempotency key, when POST /payments is called, then the original response is returned.
  - FR-002 — Confirm payment within the 120-second rate-lock window.
    - Acceptance Criteria:
      - Given an initiated payment, when the user confirms before the lock expires, then the payment is authorised at the locked rate.
      - Given an expired lock, when the user confirms, then the API returns 409 LOCK_EXPIRED.
  - FR-003 — Webhook-driven confirmation events for downstream reconciliation.
    - Acceptance Criteria:
      - Given a confirmed payment, when the corridor partner settles, then a payment.settled webhook is emitted within 30 seconds.
- **Should**
  - FR-004 — Operator console queue for AML exception triage.
    - Acceptance Criteria:
      - Given a payment flagged by AML, when the operator opens the queue, then the item appears with full context.
- **Could**
  - FR-005 — Reconciliation export for NetSuite, SAP, QuickBooks.
    - Acceptance Criteria:
      - Given a month-end cycle, when the export is triggered, then a CSV is delivered to the configured bucket.

## Non-Functional Requirements

- NFR-001 — API uptime 99.95 percent measured monthly.
- NFR-002 — p99 latency under 800 ms on POST /payments.
- NFR-003 — WCAG 2.1 AA compliance for the web console.
- NFR-004 — Encryption at rest (AES-256) and in transit (TLS 1.2+).
- NFR-005 — SOC 2 Type II certification within 12 months of launch.

## User Journeys

Key user flows with happy and error paths.

- **Happy path: Initiate -> Confirm -> Settle**
  1. Dana posts an initiate request with amount and corridor.
  2. Helix returns a locked quote valid for 120 seconds.
  3. Dana confirms within the window.
  4. Helix emits payment.settled on corridor settlement.
- **Error path: Lock expiry**
  1. Dana initiates a payment.
  2. Window closes before confirmation.
  3. Helix returns 409 LOCK_EXPIRED; Dana re-quotes.
- **Error path: AML hold**
  1. Dana initiates.
  2. AML screening flags the counterparty.
  3. Opal triages the hold in the operator console.

## Data Requirements

- Payment records retained for 7 years per FinCEN.
- KYC documents encrypted at rest; access logged for 7 years.
- PII minimised; only counterparty identifiers stored.
- Data residency: EU-origin payments stored in eu-west-1; US in us-east-1.

## Integration Requirements

External systems, APIs, and third-party services.

- NetSuite, SAP, QuickBooks (ERP export).
- Travel-rule vendor (TRP) — REST API, OpenAPI 3.0 spec.
- Sanctions screening vendor (Castellum) — gRPC.
- Local corridor partners — OFX + SWIFT MT103 fallback.

## Out of Scope

The following are explicitly excluded from this release:

- Consumer P2P payments (excluded — separate product line).
- Crypto on-ramp (deferred — licensing not in place).
- Mobile SDK at launch (deferred to v2).
- FX hedging beyond initiation rate lock (not needed for target ACV).

## Constraints and Assumptions

- Technical: Must run on the existing AWS organisation (no Azure).
- Budget: 5 FTE compliance-ops team cap at launch.
- Timeline: General availability within 9 months of kick-off.
- Team: 4 backend, 2 frontend, 1 SRE, 1 compliance engineer.
- Assumption: Mid-market treasurers will pilot for 60 days if finality is demonstrated.

## Success Criteria

- Activation: 30 paying customers each processing ≥ $100k per month by month 9.
- Revenue: $6M ARR run-rate by month 18 at 60 bps average take rate.
- Reliability: 99.95 percent API uptime; p99 latency < 800 ms on initiate.
- Compliance: Zero missed sanctions events; AML false-positive rate below 0.1 percent.
- NPS: Treasurer NPS ≥ 50 at month 12.

## Dependencies

Critical third-party and internal dependencies. Each critical dependency
lists its failure mode and the fallback behavior Helix implements.

- **TRP (travel-rule vendor)**
  - Failure mode: TRP API returns 5xx or times out.
  - Fallback behavior: Retry with exponential backoff up to 3 attempts; on sustained failure,
    queue the payment with status HELD_TRP and notify operator; AML packet completed out-of-band.
- **Castellum (sanctions vendor)**
  - Failure mode: Castellum rate-limits or returns ambiguous verdicts.
  - Fallback behavior: Fall back to the in-house sanctions list (updated hourly); log a degraded
    notice; expedite vendor remediation.
- **Corridor partner network**
  - Failure mode: Partner license suspension in a corridor.
  - Fallback behavior: Route through the secondary partner for that corridor (two-partner minimum).
- **AWS (us-east-1 region)**
  - Failure mode: Regional outage.
  - Fallback behavior: Fail over to us-west-2 within 15 minutes via Route 53 weighted records.

## Milestones

- M1 — Private beta with 5 design partners (month 3).
- M2 — General availability across the top-3 corridors (month 6).
- M3 — Full 12-corridor rollout (month 9).

## Requirements Summary

| ID | Description | Priority | Status |
|----|-------------|----------|--------|
| FR-001 | Initiate payment with idempotency | Must | Proposed |
| FR-002 | Confirm within lock window | Must | Proposed |
| FR-003 | Webhook confirmations | Must | Proposed |
| FR-004 | Operator AML triage | Should | Proposed |
| FR-005 | ERP reconciliation export | Could | Proposed |
| NFR-001 | 99.95 percent uptime | Must | Proposed |
| NFR-002 | p99 < 800 ms | Must | Proposed |
| NFR-003 | WCAG 2.1 AA | Should | Proposed |
| NFR-004 | Encryption at rest + TLS 1.2+ | Must | Proposed |
| NFR-005 | SOC 2 Type II | Should | Proposed |

## Open Questions

- How do we handle cross-region confirmations during regional failover?

## Review Findings Incorporated

- Adversarial review not triggered — change type: feature.
