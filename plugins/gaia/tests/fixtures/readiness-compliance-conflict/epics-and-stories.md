# Epics and Stories — Compliance Conflict Fixture

> Fixture for VCP-RC-03 / VCP-RC-04. Used to drive the Step 7
> priority/schedule conflict detector. Contains a P0 GDPR story under
> a Post-MVP epic, a P1 HIPAA story under a Phase 3 epic, and a benign
> in-phase compliance story that MUST NOT be flagged.

## Epic E-CC-1 — MVP Foundation

- **Phase:** Phase 1 (MVP)
- **Description:** Core auth and onboarding for the MVP launch.

### Stories

- **CC-1-1** — User signup. Priority: P0. GDPR consent capture during onboarding.
- **CC-1-2** — Login. Priority: P1. No compliance tags.

## Epic E-CC-2 — Post-MVP Enhancements

- **Phase:** Post-MVP
- **Description:** Deferred polish work not blocking the MVP launch.

### Stories

- **CC-2-1** — Right-to-erasure GDPR data deletion endpoint. Priority: P0. GDPR.
- **CC-2-2** — UI tweaks. Priority: P2. No compliance.

## Epic E-CC-3 — Phase 3 Expansion

- **Phase:** Phase 3
- **Description:** Late-phase expansion into the regulated US health vertical.

### Stories

- **CC-3-1** — HIPAA-compliant patient record audit log. Priority: P1. HIPAA.
- **CC-3-2** — Reporting dashboard. Priority: P2. No compliance.
