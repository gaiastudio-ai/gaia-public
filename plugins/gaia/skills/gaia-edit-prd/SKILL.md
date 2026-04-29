---
name: gaia-edit-prd
description: Edit an existing Product Requirements Document with cascade-aware downstream artifact detection, delegating PRD-authoring reasoning to the pm subagent (Derek) — Cluster 5 planning skill. Use when the user wants to modify sections of an existing PRD while preserving consistency with architecture, epics, stories, and test plans.
context: fork
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Agent]
---

## Setup

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-edit-prd/scripts/setup.sh

## Memory

!${CLAUDE_PLUGIN_ROOT}/scripts/memory-loader.sh pm all

## Mission

This skill orchestrates edits to an existing Product Requirements Document (PRD). PRD authoring and reasoning is delegated to the **pm** subagent (Derek), who evaluates change impact, validates consistency, and produces the updated artifact. The skill loads the current PRD, coordinates the multi-step edit flow, detects cascade impacts on downstream artifacts, and writes the output to `docs/planning-artifacts/prd.md`.

This skill is the native Claude Code conversion of the legacy `_gaia/lifecycle/workflows/2-planning/edit-prd` workflow (brief Cluster 5, story P5-S2 / E28-S41). The step ordering, cascade-aware semantics, and output path are preserved verbatim from the legacy `instructions.xml` — do not restructure, re-prompt, or reorder.

## Critical Rules

- A PRD MUST already exist at `docs/planning-artifacts/prd.md` before starting. If missing, fail fast with "No PRD found at docs/planning-artifacts/prd.md — run /gaia-create-prd first."
- Preserve existing content not being changed — edits are surgical, not wholesale rewrites.
- Add a version note documenting what changed and why after every edit session.
- Update "Review Findings Incorporated" section after adversarial review (if triggered).
- PRD edit reasoning is delegated to the `pm` subagent (Derek) via native Claude Code subagent invocation — do NOT inline Derek's persona into this skill body. If the pm subagent (E28-S21) is not available, fail with "pm subagent not available — install E28-S21" error.
- Cascade impact assessment on downstream artifacts (architecture.md, epics-and-stories.md, test-plan.md) is MANDATORY after every edit — this is the key semantic preserved from the legacy workflow.

## Val Dispatch Contract

> Any Val invocation triggered by this skill (directly or via `/gaia-val-validate` delegation as part of cascade follow-ups) is dispatched with `model: claude-opus-4-7` and `effort: high` per ADR-074 contract C2 (Val opus pin). Validation rigor is the framework-wide contract; the harness MUST NOT downgrade Val to a cheaper default model. **Non-opus mismatch guard (AC3):** if a test fixture or downstream override forces a non-opus model into the dispatch context, this skill MUST emit the canonical WARNING `Val dispatch on non-opus model — forcing opus per ADR-074 contract C2` and force `model: claude-opus-4-7` before invoking Val. Silent degradation is forbidden.

## Steps

### Step 1 — Load PRD

- Read the current PRD at `docs/planning-artifacts/prd.md`.
- If the file does not exist, fail fast: "No PRD found at docs/planning-artifacts/prd.md — run /gaia-create-prd first."
- Display the current structure summary to the user: list all section headers, requirement count (FR-### and NFR-### IDs), and last version note date.

### Step 2 — Identify Changes

Delegate to the **pm** subagent (Derek) via `agents/pm` to evaluate the requested changes.

Ask the user:

1. What sections need to change?
2. Why are these changes needed?
3. Is this linked to a change request? If so, provide the CR ID.

Confirm scope of changes before proceeding. The pm subagent evaluates whether the requested changes are consistent with the existing PRD structure and flags any potential conflicts.

### Step 3 — Apply Edits

Delegate to the **pm** subagent (Derek) via `agents/pm` to apply the edits:

- Make requested changes while preserving unchanged content.
- Validate consistency with remaining sections — ensure cross-references between FRs, NFRs, user journeys, and data requirements remain valid.
- Add version note at top of the PRD: date, changes made, reason, CR ID (if applicable).

### Step 4 — Save Updated PRD

Write the updated PRD to `docs/planning-artifacts/prd.md` with the version note prepended.

### Step 5 — Adversarial Review

- Read `${CLAUDE_PLUGIN_ROOT}/knowledge/adversarial-triggers.yaml` to evaluate trigger rules. (This policy table ships inside the plugin under ADR-041's `knowledge/` convention; the legacy v1 location `_gaia/_config/adversarial-triggers.yaml` is retired and no longer used.) Determine the current `change_type`: if invoked with a change_type context (e.g., from add-feature triage), use that value. If no context is available, infer from the change scope: minor edits map to "low-risk-enhancement", significant feature additions map to "feature".
- Look up the trigger rule for `change_type` + artifact "prd". If adversarial is false for this combination: skip adversarial review — mark "Review Findings Incorporated" as "Adversarial review not triggered — change type: {change_type} per adversarial-triggers.yaml". Proceed to Step 7.
- If adversarial is true: spawn a subagent to run the adversarial review task against `docs/planning-artifacts/prd.md`.
- When subagent returns: verify `adversarial-review-prd-*.md` exists in `docs/planning-artifacts/`.

### Step 6 — Incorporate Review Findings

- Read `docs/planning-artifacts/adversarial-review-prd-*.md` — extract critical and high severity findings.
- For each critical/high finding: add or refine requirement in the PRD.
- Update the "## Review Findings Incorporated" section — append new entries with amendment date.
- Write the updated PRD to `docs/planning-artifacts/prd.md`.

### Step 7 — Architecture Cascade Check

This is the cascade-aware behavior preserved from the legacy edit-prd workflow — the key semantic that distinguishes editing from creation.

- Read `docs/planning-artifacts/architecture.md` section headers.
- Compare PRD changes against architecture scope.
- Classify cascade impact:
  - **NONE:** Requirements-only changes — architecture unaffected.
  - **MINOR:** Architecture needs a section update — recommend `/gaia-edit-arch`.
  - **SIGNIFICANT:** New component/API/data model — recommend `/gaia-edit-arch` with adversarial review, then `/gaia-add-stories`.
- Report cascade assessment to user with recommended next command(s).

## Finalize

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-edit-prd/scripts/finalize.sh

## Next Steps

- If cascade NONE: no further action required.
- If cascade MINOR: `/gaia-edit-arch` — Update architecture to match PRD changes.
- If cascade SIGNIFICANT: `/gaia-edit-arch` — Update architecture, then `/gaia-add-stories` to create new stories for added scope.
