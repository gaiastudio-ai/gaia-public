---
title: Product Brief — E42-S5 Negative Fixture (missing Vision Statement)
date: 2026-04-24
product: "Helix Cross-Border Payments"
---

# Product Brief: Helix Cross-Border Payments

<!-- Vision Statement section intentionally stripped to exercise VCP-CHK-10. -->

## Target Users

We serve finance operators at mid-market B2B companies operating across currency corridors.

- **Persona A — Dana, AP Manager at a US→EU SaaS firm**
  - Role: Accounts-payable manager responsible for weekly international payroll and vendor runs.
  - Goals: Hit payroll cutoffs reliably; reduce FX slippage; keep audit trails clean.
  - Pain points: 2–5 day settlement, opaque correspondent-bank fees, manual reconciliation.
  - Context: Uses NetSuite + a traditional wire platform; no crypto tooling permitted by treasury policy.

- **Persona B — Marco, Treasurer at a LATAM→US manufacturing distributor**
  - Role: Treasurer owning working-capital optimisation across three subsidiaries.
  - Goals: Predictable FX rate for monthly settlements; sub-day finality.
  - Pain points: Inconsistent quoted rates, delayed confirmations, bank holiday drag.
  - Context: Uses SAP; strict compliance with BACEN reporting.

## Problem Statement

B2B cross-border payments remain expensive (2–4% all-in), slow (T+2 to T+5), and opaque. Treasurers cannot commit to vendor-cash-flow plans because settlement windows are unpredictable and correspondent-bank fees are discovered after the fact.

## Proposed Solution

Helix offers an API-first payments platform that settles cross-border payouts via a network of licensed local partners, wrapped in an all-in quoted rate locked at initiation.

## Key Features

1. **All-in rate lock at initiation (differentiator)** — customers see the landed amount before authorising.
2. **T+0 to T+1 settlement across the top-12 corridors** — measured finality, not best-effort.
3. **Idempotent payments API** — safe retries, webhook-driven confirmations.
4. **Operator console with exception triage** — queue for AML holds and partial fills.
5. **Reconciliation export** — NetSuite / SAP / QuickBooks connectors out of the box.
6. **Audit-grade compliance trail** — full KYC + travel-rule + sanctions packet per transaction.

## Scope and Boundaries

**In scope**

- 12 corridors on launch.
- B2B payouts up to $500k per transaction.

**Out of scope**

- Consumer P2P payments.
- Crypto-on-ramp or stablecoin settlement.

## Risks and Assumptions

- **Risk:** Local-partner license revocation in any single corridor could sever that corridor; mitigation is a two-partner-minimum per corridor target.
- **Assumption:** Mid-market treasurers will switch rails if predictable finality is demonstrated in a 60-day pilot.

## Competitive Landscape

| Competitor | Positioning | Helix Differentiation |
|------------|-------------|-----------------------|
| Wise Business | Strong UX, limited corridor depth for B2B | All-in rate lock + audit packet |
| Airwallex | Strong APAC, weaker LATAM | LATAM priority |
| SWIFT gpi | Incumbent rail, slow finality | Eliminates correspondent chain |

## Success Metrics

- **North-star KPI:** 95% of transactions settle within 4 hours.
- **Activation:** 30 paying customers by month 9.
- **Revenue:** $6M ARR run-rate by month 18.

## Next Steps

- Primary: `/gaia-create-prd` — expand this brief into the full PRD.
