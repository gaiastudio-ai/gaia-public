---
title: Product Brief — E42-S5 Positive Fixture
date: 2026-04-24
product: "Helix Cross-Border Payments"
---

# Product Brief: Helix Cross-Border Payments

## Vision Statement

Helix makes cross-border B2B payments settle in minutes instead of days, at a predictable cost, without requiring the sender or receiver to hold crypto or open new banking relationships. Our aspirational north star is the first payments rail where settlement time is measured in seconds and cost is a flat basis-point fee, regardless of corridor.

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

B2B cross-border payments remain expensive (2–4% all-in), slow (T+2 to T+5), and opaque. Treasurers cannot commit to vendor-cash-flow plans because settlement windows are unpredictable and correspondent-bank fees are discovered after the fact. Existing rails (SWIFT, card networks) were not built for the SaaS-era B2B flow volume or the transparency regulations now emerging. Market research with 40 mid-market finance teams (Q1-2026 interviews) confirms finality uncertainty as the #1 operational pain.

## Proposed Solution

Helix offers an API-first payments platform that settles cross-border payouts via a network of licensed local partners, wrapped in an all-in quoted rate locked at initiation. The platform presents a single idempotent API for initiate / confirm / reconcile, and a web console for operator-in-the-loop exceptions. This approach eliminates the correspondent-bank chain for the 12 highest-volume corridors while preserving full compliance artefacts (KYC, travel-rule, sanctions screening).

## Key Features

Key features, prioritised by user value and differentiator weight:

1. **All-in rate lock at initiation (differentiator)** — customers see the landed amount before authorising. Removes hidden FX + correspondent-bank fees.
2. **T+0 to T+1 settlement across the top-12 corridors** — measured finality, not best-effort.
3. **Idempotent payments API** — safe retries, webhook-driven confirmations.
4. **Operator console with exception triage** — queue for AML holds and partial fills.
5. **Reconciliation export** — NetSuite / SAP / QuickBooks connectors out of the box.
6. **Audit-grade compliance trail** — full KYC + travel-rule + sanctions packet per transaction.

## Scope and Boundaries

**In scope**

- 12 corridors on launch (US↔EU, US↔LATAM, US↔APAC selected, UK↔EU).
- B2B payouts up to $500k per transaction.
- REST API + web console; no mobile SDK at launch.

**Out of scope**

- Consumer P2P payments.
- Crypto-on-ramp or stablecoin settlement (licensing deferred).
- FX hedging products beyond the at-initiation rate lock.
- Payroll compliance in jurisdictions not covered by launch corridors.

## Risks and Assumptions

Known risks, dependencies, and assumptions:

- **Risk:** Local-partner license revocation in any single corridor could sever that corridor; mitigation is a two-partner-minimum per corridor target.
- **Risk:** FX market volatility during rate lock exposes Helix to slippage; mitigation is a sub-2-minute hold window and automated hedging.
- **Risk:** Regulatory divergence across launch corridors could slow onboarding; mitigation is a compliance-ops team sized to 5 FTEs at launch.
- **Assumption:** Mid-market treasurers will switch rails if predictable finality is demonstrated in a 60-day pilot.
- **Assumption:** Local partners will accept an SLA-backed volume commitment in exchange for exclusivity on a corridor.
- **Dependency:** Travel-rule vendor (TRP) — contracted, onboarding Q2-2026.

## Competitive Landscape

Competitive positioning synthesised from the upstream market research:

| Competitor | Positioning | Helix Differentiation |
|------------|-------------|-----------------------|
| Wise Business | Strong UX, consumer-derived brand, limited corridor depth for B2B | Helix offers all-in rate lock + audit-grade compliance packet per transaction |
| Airwallex | Strong APAC coverage, weaker LATAM, bundled multi-currency accounts | Helix corridors include LATAM priority; no account-holding requirement |
| Veem | SMB-focused, limited enterprise compliance features | Helix targets mid-market treasurers with SAP/NetSuite integration |
| SWIFT gpi | Incumbent rail, no rate-lock guarantee, slow finality | Helix eliminates correspondent chain for the top-12 corridors |

Helix competes on finality, rate transparency, and compliance depth — not lowest-price-per-transaction.

## Success Metrics

Measurable KPIs and success criteria for the first 18 months:

- **North-star KPI:** 95% of transactions settle within 4 hours across launch corridors.
- **Activation:** 30 paying customers with monthly volume ≥ $100k each by month 9.
- **Revenue:** $6M ARR run-rate by month 18 (60 bps average take rate on $120M/mo processed).
- **Reliability:** 99.95% API uptime; p99 latency < 800ms on initiate.
- **Compliance:** Zero missed sanctions-screening events; < 0.1% false-positive AML rate.
- **NPS:** Treasurer NPS ≥ 50 at month 12.

## Next Steps

- Primary: `/gaia-create-prd` — expand this brief into the full Product Requirements Document.
- Alternative: `/gaia-domain-research` — deepen regulatory context for the launch corridors.
