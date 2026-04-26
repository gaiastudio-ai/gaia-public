# Fixture: create-arch-tech-stack-pause

Story: **E46-S6** — `/gaia-create-arch` tech-stack confirmation pause + ADR sidecar write (FR-354 / AF-2026-04-24-1).

This fixture is the minimal project scaffolding required to drive `/gaia-create-arch` through Step 3 (Theo tech-stack recommendation) and into Step 3.5 (Tech-Stack Confirmation Pause) in a local Claude Code validation session. It is the runner anchor for:

- **VCP-ARCH-01** — Tech-stack confirmation pause fires after Step 3. _LLM-checkable._
- **VCP-ARCH-02** — User selects `[m]odify`; downstream Steps 4+ consume the modified stack via the `confirmed_tech_stack` runtime variable. _LLM-checkable._
- **VCP-ARCH-03** — ADR sidecar write end-to-end; `_memory/architect-sidecar/architecture-decisions.md` matches `docs/planning-artifacts/architecture.md § Decision Log` after the workflow ends. _Integration._

## Contents

| File | Purpose |
|------|---------|
| `prd.md` | Minimal Product Requirements Document with FR/NFR rows + the mandatory `## Review Findings Incorporated` section. Required by Step 1 of `/gaia-create-arch` (PRD existence + review findings GATE). |
| `README.md` | This file. |

## What this fixture deliberately does NOT include

- **No `architecture.md`.** Step 1 must find an absent architecture file so Step 9 can write a fresh one. If a stale `architecture.md` is present, the skill prompts to overwrite — fine for VCP-ARCH-01/02 but noisy for VCP-ARCH-03 sidecar diffing.
- **No pre-existing `_memory/architect-sidecar/architecture-decisions.md`.** VCP-ARCH-03 verifies the create-from-scratch path (canonical header write). The idempotency-on-rerun path (Test Scenario 7 in the story) is exercised by re-running the skill against this fixture twice and asserting append-only behavior.
- **No `custom/templates/architecture-template.md` override.** The framework default template is intended (ADR-020 / FR-101).
- **No threat model.** Step 7 cross-references `threat-model.md` when present; absence keeps the fixture minimal.

## How to use

1. Copy this fixture to a scratch directory (do not run against the GAIA-Framework working tree).
2. Place a minimal `_gaia/` runtime alongside `prd.md` (or symlink the project's `_gaia/`).
3. Run `/gaia-create-arch` from inside the scratch directory in a Claude Code session.
4. Observe Step 3.5 firing — the recommendation block + `[a]ccept / [m]odify / [r]eject` prompt MUST appear before Step 4 begins.
5. For VCP-ARCH-02: choose `[m]odify`, replace one library, and verify that Steps 4+ produce architecture content referencing the modified stack (not Theo's original).
6. For VCP-ARCH-03: let the workflow run to completion, then `diff` the inline `§ Decision Log` against `_memory/architect-sidecar/architecture-decisions.md` — every ADR row MUST appear in the sidecar with matching ADR ID, Decision, Rationale, Status, Source.

## Cross-references

- Story: `docs/implementation-artifacts/E46-S6-gaia-create-arch-tech-stack-confirmation-pause-adr-sidecar-write.md`
- Test plan rows: `docs/test-artifacts/test-plan.md § 11.46.14`
- Traceability: `docs/test-artifacts/traceability-matrix.md` FR-354 row
- ADR-016 entry format: `_gaia/lifecycle/skills/memory-management.md § decision-formatting`
- Sidecar location convention: `docs/planning-artifacts/architecture.md § 10.10`
