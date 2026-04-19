---
name: gaia-edit-arch
description: Edit an existing architecture document with cascade-aware downstream artifact detection, delegating architecture-authoring reasoning to the architect subagent (Theo) — Cluster 6 architecture skill. Use when the user wants to modify sections of an existing architecture while preserving consistency with epics, stories, test plans, and infrastructure design.
context: fork
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Agent]
---

## Setup

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-edit-arch/scripts/setup.sh

## Mission

This skill orchestrates edits to an existing System Architecture document. Architecture authoring and reasoning is delegated to the **architect** subagent (Theo), who evaluates change impact, validates consistency, records ADRs, and produces the updated artifact. The skill loads the current architecture, coordinates the multi-step edit flow, detects cascade impacts on downstream artifacts, and writes the output to `docs/planning-artifacts/architecture.md`.

This skill is the native Claude Code conversion of the legacy `_gaia/lifecycle/workflows/3-solutioning/edit-architecture` workflow (brief Cluster 6, story P6-S2 / E28-S46). The step ordering, cascade-aware semantics, and output path are preserved verbatim from the legacy `instructions.xml` — do not restructure, re-prompt, or reorder.

## Critical Rules

- An architecture document MUST already exist at `docs/planning-artifacts/architecture.md` before starting. If missing, fail fast with "No architecture document found at docs/planning-artifacts/architecture.md — run /gaia-create-arch first."
- Preserve existing content not being changed — edits are surgical, not wholesale rewrites. No silent drops, reorders, or modifications to unchanged sections.
- Record every significant decision as a new ADR with auto-incremented ID in the architecture document's Decision Log table.
- Add a version note documenting what changed, why, and the CR/reference after every edit session.
- Update "Review Findings Incorporated" section after adversarial review (if triggered).
- Architecture edit reasoning is delegated to the `architect` subagent (Theo) via native Claude Code subagent invocation — do NOT inline Theo's persona into this skill body. If the architect subagent (E28-S21) is not available, fail with "architect subagent not available — install E28-S21" error.
- Cascade impact assessment on downstream artifacts (epics-and-stories.md, test-plan.md, infrastructure-design.md, traceability-matrix.md) is MANDATORY after every edit — this is the key semantic preserved from the legacy workflow.

## Steps

### Step 1 — Load Existing Architecture

- Read the current architecture document at `docs/planning-artifacts/architecture.md`.
- If the file does not exist, fail fast: "No architecture document found at docs/planning-artifacts/architecture.md — run /gaia-create-arch first."
- Count existing ADRs in Section 2 (Architecture Decisions) — note highest ADR ID for auto-increment.
- Identify existing Version History entries — note last version number for auto-increment.
- Display current structure summary to user: section headers, ADR count, current version.

### Step 2 — Capture Change Scope

Delegate to the **architect** subagent (Theo) via `agents/architect` to evaluate the requested changes.

- If triggered by a change request: inherit CR ID, technical_impact, and change_description from the triggering workflow context. Skip user questions — proceed directly to scope confirmation.
- If triggered by adversarial review: load adversarial review findings as the change scope. Set driver = "adversarial-review". Skip user questions — proceed directly to scope confirmation.
- Otherwise, ask the user:
  1. What sections need to change? (List affected architecture sections)
  2. What is the change? (Describe the modification)
  3. Why is this change needed? (Driver: change request / technical discovery / adversarial finding / PRD edit cascade)
  4. Is this linked to a change request or other reference? If so, provide the CR ID or reference.

Record: sections_affected, change_description, driver, cr_id.

Classify change scope: MINOR (section update, config change) / SIGNIFICANT (new component, API change, data model change) / BREAKING (architectural shift, tech stack change).

Confirm scope of changes with user before proceeding. The architect subagent evaluates whether the requested changes are consistent with the existing architecture and flags any potential conflicts.

### Step 3 — Apply Targeted Edits

Delegate to the **architect** subagent (Theo) via `agents/architect` to apply the edits:

- For each affected section: present current content, propose edits, wait for user confirmation or modification.
- Preserve all unchanged sections exactly as-is — no reordering, no reformatting, no content loss.
- Validate consistency between edited sections and remaining unchanged sections.
- If edits affect component-to-requirement traceability: verify Addresses fields remain accurate.

### Step 4 — Record ADRs

Delegate to the **architect** subagent (Theo) via `agents/architect` to record architecture decision records:

- For each significant decision in the edit: create a new ADR entry.
- Auto-increment ADR ID from highest existing (e.g., if ADR-5 exists, new ADR is ADR-6).
- ADR template:
  ```
  ### ADR-{id}: {Decision Title}
  - **Status:** Active
  - **Context:** {Why this decision was needed}
  - **Decision:** {What was decided}
  - **Consequences:** {Trade-offs and implications}
  - **Addresses:** {FR-* / NFR-* IDs this decision addresses}
  ```
- If superseding an existing ADR: set old ADR status to "Superseded by ADR-{new_id}" and add "Supersedes: ADR-{old_id}" to the new entry.
- Auto-increment architecture version: minor bump (e.g., v1.0 -> v1.1, v1.3 -> v1.4).

### Step 5 — Add Version Note

- Append a new row to the Version History table:
  `| {date} | {change summary} | {driver} | {CR ID or reference} |`
- If no Version History section exists, create one:
  ```
  ## Version History
  | Date | Change | Reason | CR/Reference |
  |------|--------|--------|-------------|
  | {date} | {change summary} | {driver} | {CR ID or reference} |
  ```

### Step 6 — Save and Review Gate

- Generate a diff summary showing exactly what changed (sections modified, ADRs added/superseded, version bump).
- Write updated architecture document to `docs/planning-artifacts/architecture.md` with all edits applied, new ADRs appended, version incremented, and version note added.
- Read `_gaia/_config/adversarial-triggers.yaml` to evaluate trigger rules. Determine the current `change_type`: if this workflow was invoked with a change_type context (e.g., from add-feature triage), use that value. If no context is available, infer from the change scope and driver: adversarial-finding or technical-discovery maps to "feature", change-request depends on the CR classification.
- Look up the trigger rule for `change_type` + artifact "architecture". If adversarial is false for this combination: skip adversarial review — mark "Review Findings Incorporated" as "Adversarial review not triggered — change type: {change_type} per adversarial-triggers.yaml". Proceed to Step 7.
- If adversarial is true and magnitude meets or exceeds threshold: spawn a subagent to run the adversarial review task against `docs/planning-artifacts/architecture.md`, focused on changed sections.
- When subagent returns: verify `adversarial-review-architecture-*.md` exists in `docs/planning-artifacts/`.
- Read findings — extract critical and high severity items.
- For each critical/high finding: incorporate into architecture document.
- Update "Review Findings Incorporated" section — append new entries with amendment date.
- Write the final architecture document.

### Step 7 — Cascade Impact Analysis

This is the cascade-aware behavior preserved from the legacy edit-architecture workflow — the key semantic that distinguishes editing from creation.

- Classify cascade impact on downstream artifacts:

  | Downstream Artifact    | Impact | Recommended Action |
  |------------------------|--------|--------------------|
  | Epics and Stories       | {NONE/MINOR/SIGNIFICANT} | {/gaia-add-stories or manual update} |
  | Test Plan               | {NONE/MINOR/SIGNIFICANT} | {/gaia-test-design} |
  | Infrastructure Design   | {NONE/MINOR/SIGNIFICANT} | {/gaia-infra-design or manual update} |
  | Traceability Matrix     | {NONE/MINOR/SIGNIFICANT} | {/gaia-trace} |

- For each artifact with impact > NONE: recommend the appropriate update workflow.
- Report cascade assessment to user with recommended next command(s).
- Record all architecture changes and new ADRs in Theo's memory sidecar.

## Finalize

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-edit-arch/scripts/finalize.sh

## Next Steps

- If cascade NONE: no further action required.
- If cascade MINOR: update affected artifacts with targeted edits.
- If cascade SIGNIFICANT: `/gaia-add-stories` to create new stories for added scope, `/gaia-test-design` to update test coverage, `/gaia-trace` to refresh traceability matrix.
