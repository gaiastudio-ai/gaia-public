---
title: Domain Research — E42-S3 Positive Fixture
date: 2026-04-24
domain: Regulated Fintech Payments
---

# Domain Research: Regulated Fintech Payments

## Domain Overview

This domain research maps the regulated fintech payments domain, covering the key players, regulatory landscape, trends, terminology, and domain-specific risks relevant to teams building cross-border payment infrastructure. Focus areas are payment rails, KYC/AML compliance, and issuer/acquirer relationships.

- Domain: regulated fintech payments (cross-border).
- Focus areas: payment rails, KYC/AML compliance, issuer/acquirer relationships.

## Key Players

- **Stripe** — acquirer/issuer platform with developer-first APIs; role: payments infrastructure.
- **Adyen** — enterprise-focused unified commerce platform; role: global acquirer.
- **PayPal** — consumer and merchant payments; role: two-sided payments network.
- **Visa** and **Mastercard** — card network operators; role: scheme rails.
- **Plaid** — bank data aggregation; role: account connectivity.
- **Wise** — low-fee international transfers; role: cross-border settlement.
- **Revolut** — neobank; role: retail fintech.

## Regulatory Landscape

- **PSD2 (EU)** — strong customer authentication and open banking obligations.
- **PCI-DSS** — card data handling standard; mandatory for any platform touching PANs.
- **GDPR** — EU personal data protection; affects KYC data retention and cross-border transfers.
- **AML/KYC** — Bank Secrecy Act (US), 6AMLD (EU); identity verification and sanctions screening requirements.
- **Open Banking (UK CMA)** — account information and payment initiation service providers.
- **US state money transmitter licensing** — per-state MTL requirements for cross-border flows.

## Trends

- Real-time payments (RTP, FedNow, SEPA Instant) becoming table-stakes for B2B/B2C flows.
- Account-to-account (A2A) payments displacing card rails in the UK and EU.
- Embedded finance — non-fintechs adding payment rails via BaaS providers.
- Stablecoin settlement pilots (USDC, EURC) for cross-border corridors.
- Increasing scrutiny on BaaS banks (US consent orders, FCA interventions 2024-2026).

## Terminology Glossary

- **PSP** — Payment Service Provider; licensed entity that moves funds between parties.
- **Acquirer** — bank/processor that accepts card transactions on behalf of merchants.
- **Issuer** — bank that issues cards to cardholders.
- **Interchange** — fee paid by acquirer to issuer per transaction.
- **Scheme** — card network (Visa, Mastercard, Amex, Discover).
- **KYC** — Know Your Customer; identity verification obligation.
- **AML** — Anti-Money Laundering; transaction monitoring obligation.
- **MTL** — Money Transmitter License; US state-level license.
- **SCA** — Strong Customer Authentication; PSD2 two-factor requirement.
- **PAN** — Primary Account Number; the 16-digit card number.
- **Tokenization** — replacing PANs with non-sensitive tokens.
- **Chargeback** — cardholder-initiated transaction reversal.

## Risk Assessment

### Regulatory and Compliance Risks

- PSD2 SCA non-compliance can block EU traffic — evidence: FCA fined multiple PSPs 2024-2026 for SCA gaps.
- PCI-DSS scope creep can multiply audit cost 3-5x if PAN data leaks outside the tokenized boundary.
- US MTL patchwork — a single missed state license can block corridor launches (NY, CA, TX particularly strict).
- GDPR cross-border transfer risk after Schrems II — standard contractual clauses and DPA reviews required.

### Technical Risks

- Card scheme rate limits — Visa/Mastercard BIN-sponsor throughput caps bottleneck growth.
- Fraud model drift — card-not-present fraud patterns change seasonally; static models degrade fast.
- Key rotation and HSM dependency — lost or delayed rotation can halt settlement.
- Settlement mismatch between RTP rails and legacy T+2 batch — reconciliation complexity.
- Third-party BaaS dependency — consent orders in 2024-2026 forced multiple BaaS-reliant fintechs to pause.

### Market and Competitive Risks

- Incumbent PSPs (Stripe, Adyen) have pricing scale advantages small players cannot match without volume.
- Scheme fee inflation (interchange++ pricing) erodes low-margin corridors.
- Fintech winter — funding contraction 2023-2025 reduces appetite for long-duration compliance investments.
- Stablecoin displacement risk — card rails may lose share in some corridors to on-chain settlement.

## Web Access

Web access was available during this session — live regulatory and player research was incorporated.

## Recommendations

- Prioritize PCI-DSS scope minimization via tokenization from day one.
- Secure at least one BIN sponsor and one alternative BaaS partner to avoid single-vendor risk.
- Build SCA compliance into the core auth flow before EU launch.
- Monitor stablecoin settlement pilots as an optionality play rather than a core rail.
- Engage state MTL counsel early — the licensing lead time is 9-18 months per state.
