---
title: Domain Research — E42-S3 Negative Fixture
date: 2026-04-24
domain: Regulated Fintech Payments
---

# Domain Research: Regulated Fintech Payments

> Negative fixture for VCP-CHK-06: the `## Terminology Glossary` section is intentionally omitted so the glossary-presence / terminology items fail under finalize.sh.

## Domain Overview

This domain research maps the regulated fintech payments domain, covering the key players, regulatory landscape, trends, and domain-specific risks relevant to teams building cross-border payment infrastructure. Focus areas are payment rails, KYC/AML compliance, and issuer/acquirer relationships.

- Domain: regulated fintech payments (cross-border).
- Focus areas: payment rails, KYC/AML compliance, issuer/acquirer relationships.

## Key Players

- **Stripe** — acquirer/issuer platform with developer-first APIs; role: payments infrastructure.
- **Adyen** — enterprise-focused unified commerce platform; role: global acquirer.
- **PayPal** — consumer and merchant payments; role: two-sided payments network.
- **Visa** and **Mastercard** — card network operators; role: scheme rails.
- **Plaid** — bank data aggregation; role: account connectivity.

## Regulatory Landscape

- **PSD2 (EU)** — strong customer authentication and open banking obligations.
- **PCI-DSS** — card data handling standard; mandatory for any platform touching PANs.
- **GDPR** — EU personal data protection; affects KYC data retention and cross-border transfers.
- **AML/KYC** — Bank Secrecy Act (US), 6AMLD (EU); identity verification and sanctions screening requirements.
- **US state money transmitter licensing** — per-state MTL requirements for cross-border flows.

## Trends

- Real-time payments (RTP, FedNow, SEPA Instant) becoming table-stakes for B2B/B2C flows.
- Account-to-account (A2A) payments displacing card rails in the UK and EU.
- Embedded finance — non-fintechs adding payment rails via BaaS providers.
- Stablecoin settlement pilots (USDC, EURC) for cross-border corridors.

## Risk Assessment

### Regulatory and Compliance Risks

- PSD2 SCA non-compliance can block EU traffic.
- PCI-DSS scope creep can multiply audit cost 3-5x.
- US MTL patchwork — a single missed state license can block corridor launches.

### Technical Risks

- Card scheme rate limits — BIN-sponsor throughput caps bottleneck growth.
- Fraud model drift — card-not-present fraud patterns change seasonally.
- Third-party BaaS dependency — consent orders forced multiple fintechs to pause.

### Market and Competitive Risks

- Incumbent PSPs have pricing scale advantages small players cannot match.
- Scheme fee inflation erodes low-margin corridors.
- Stablecoin displacement risk in some corridors.

## Web Access

Web access was available during this session — live regulatory and player research was incorporated.

## Recommendations

- Prioritize PCI-DSS scope minimization via tokenization from day one.
- Secure at least one BIN sponsor and one alternative BaaS partner to avoid single-vendor risk.
- Build SCA compliance into the core auth flow before EU launch.
- Engage state MTL counsel early.
