---
title: UX Design — E42-S7 Negative Fixture (missing Wireframes body)
date: 2026-04-24
product: "Helix Cross-Border Payments"
version: "0.1.0"
---

# UX Design: Helix Cross-Border Payments

## Personas

- Dana — AP Manager. Goals: hit vendor payroll cutoffs. Tech proficiency: high.
- Marco — Treasurer. Goals: rate-lock at initiation. Tech proficiency: medium.

## Information Architecture

Sitemap covers /dashboard, /payments, /exceptions, /settings.

## Wireframes

<!-- intentionally empty — VCP-CHK-14 anchor: Key screens described -->

## Interaction Patterns

- Forms: inline validation on blur.
- Error states: inline red copy beneath the field.
- Loading states: skeletons for lists, spinners for modal actions.

## Accessibility

- WCAG 2.1 AA target.
- Keyboard navigation: every control reachable via Tab.
- Screen reader support via ARIA live regions.

## Components

| Component | Variants |
|-----------|----------|
| Button | Primary, Secondary |
| Input | Text, Number |

## FR-to-Screen Mapping

| FR ID | Screen |
|-------|--------|
| FR-001 | Initiate Payment |
| FR-002 | Confirm Payment |
