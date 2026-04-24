---
name: gaia-edit-test-plan
description: Edit an existing test plan by adding new test cases while preserving all existing content. Use when "edit the test plan" or /gaia-edit-test-plan.
context: fork
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash]
---

## Setup

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-edit-test-plan/scripts/setup.sh

## Mission

Edit an existing test plan (`docs/test-artifacts/test-plan.md`) by adding new test cases, updating coverage, and appending a version note — while preserving all existing content unchanged. The updated test plan is written back to `docs/test-artifacts/test-plan.md`.

This skill is the native Claude Code conversion of the legacy `_gaia/testing/workflows/edit-test-plan` workflow (E28-S87, Cluster 11). The step ordering, prompts, and output path are preserved verbatim from the legacy `instructions.xml` — do not restructure, re-prompt, or reorder.

## Critical Rules

- A test plan MUST already exist at `docs/test-artifacts/test-plan.md` before starting. If the file is missing, halt with: "test-plan.md not found at docs/test-artifacts/test-plan.md — run /gaia-test-design first."
- Preserve all existing test plan content — test strategy, environments, entry/exit criteria, existing test cases.
- New test cases must follow the same format as existing ones.
- Test case IDs must auto-increment from the highest existing ID.
- Never remove or modify existing test cases — edits are additive only.
- This is a single-prompt operation — no subagent invocation needed.
- Output to `docs/test-artifacts/test-plan.md`.

## Steps

### Step 1 — Load Existing Test Plan

- Read `docs/test-artifacts/test-plan.md` in full.
- GATE: verify test-plan.md exists. If missing, halt and recommend /gaia-test-design.
- Identify existing test case count and highest test case ID (for auto-increment).
- Identify existing test areas/categories (e.g., unit, integration, E2E, performance, security).
- Display current test plan structure summary to the user: section count, test case count, coverage areas.

> `!scripts/write-checkpoint.sh gaia-edit-test-plan 1 test_plan_path="docs/test-artifacts/test-plan.md" edit_mode=load stage=test-plan-loaded`

### Step 2 — Capture Change Scope

Ask the user:

1. What new test cases are needed? Describe the feature or change requiring test coverage.
2. Which FR/NFR IDs need test coverage?

- Read relevant sections of `docs/planning-artifacts/prd.md` for requirement context (if available).
- Read relevant sections of `docs/planning-artifacts/architecture.md` for technical context (if available).
- Record: new_requirements, change_description, affected_test_areas.

> `!scripts/write-checkpoint.sh gaia-edit-test-plan 2 test_plan_path="docs/test-artifacts/test-plan.md" edit_mode=scope stage=change-scope-captured`

### Step 3 — Define New Test Cases

For each new requirement, define test cases with:
- Test case ID (auto-incremented from highest existing)
- Title and description
- Test type (unit, integration, E2E, performance, security, accessibility)
- Pre-conditions and test steps
- Expected results
- Priority (critical/high/medium/low)
- Validates: FR-*/NFR-* IDs this test case validates

Determine if new test areas/categories are needed or if cases fit existing categories.

> `!scripts/write-checkpoint.sh gaia-edit-test-plan 3 test_plan_path="docs/test-artifacts/test-plan.md" edit_mode=add stage=new-cases-defined`

### Step 4 — Update Test Plan

- Append new test cases to the appropriate test area sections.
- If new test area needed: create section header with description before adding test cases.
- Update test scope section to reflect expanded coverage.
- Update coverage summary if present (new requirements covered / total).
- Preserve all existing content exactly as-is — no reordering, no reformatting, no removal.

> `!scripts/write-checkpoint.sh gaia-edit-test-plan 4 test_plan_path="docs/test-artifacts/test-plan.md" edit_mode=update stage=plan-updated`

### Step 5 — Add Version Note and Save

Append version note to test plan:

```
## Version History
| Date | Change | New Test Cases | FR/NFR IDs Covered |
|------|--------|---------------|-------------------|
| {date} | {change summary} | {new test case IDs} | {FR/NFR IDs} |
```

If no Version History section exists, create one.

Write the updated test plan to `docs/test-artifacts/test-plan.md`.

> `!scripts/write-checkpoint.sh gaia-edit-test-plan 5 test_plan_path="docs/test-artifacts/test-plan.md" edit_mode=save stage=saved --paths docs/test-artifacts/test-plan.md`

### Step 6 — Next Steps

- Report test cases added: list new IDs, their types, and requirements covered.
- If high-risk stories need acceptance tests: "Recommend running /gaia-atdd for stories: {story_keys}"
- If traceability update needed: "Recommend running /gaia-trace to update traceability matrix"

> `!scripts/write-checkpoint.sh gaia-edit-test-plan 6 test_plan_path="docs/test-artifacts/test-plan.md" edit_mode=next-steps stage=next-steps-reported`

## Validation

<!--
  E42-S14 — V1→V2 21-item checklist port (FR-341, FR-359, VCP-CHK-29, VCP-CHK-30).
  Classification (21 items total):
    - Script-verifiable:  7 (SV-01..SV-07) — enforced by finalize.sh.
    - LLM-checkable:     14 (LLM-01..LLM-14) — evaluated by the host LLM
      against the test-plan.md artifact at finalize time.
  Exit code 0 when all 7 script-verifiable items PASS; non-zero otherwise.

  V1 source reconciliation:
    - _gaia/testing/workflows/edit-test-plan/checklist.md ships 11
      explicit bullets under five V1 H2 sections (Edit Quality, New
      Test Cases, Coverage, Version History, Output Verification).
    - The story 21-item count is authoritative per
      docs/v1-v2-command-gap-analysis.md §6 and the epic design note.
    - The remaining 10 items are reconciled from V1 instructions.xml
      step outputs (Step 1 plan load + ID harvest + test-area survey,
      Step 2 scope capture + PRD/architecture context load, Step 3
      test case authoring with required fields, Step 4 area-header
      creation, Step 5 Version History creation, Step 6 next-steps
      block).
    - Every V1 checklist bullet maps 1:1 to a V2 validation entry. No
      item is dropped, renamed, or merged.

  Because the V1 edit-test-plan checklist is dominated by
  preservation-semantics checks ("existing test cases preserved
  exactly", "existing test strategy unchanged", "test cases follow same
  format as existing"), LLM-checkable is the dominant classification
  here (14 / 21). Script-verifiable items cover the output-file shape,
  Version History presence, test-area headers, test-case-ID
  convention, and the Validates-field regex.

  V1 category coverage mapping (21 items):
    Edit Quality          — LLM-01, LLM-02, LLM-03                       (3)
    New Test Cases        — LLM-04, LLM-05, LLM-06, SV-05, SV-06, SV-07  (6)
    Coverage              — LLM-07, LLM-08                               (2)
    Version History       — SV-03, SV-04                                 (2)
    Output Verification   — SV-01, SV-02                                 (2)
    Reconciled (V1 instr) — LLM-09..LLM-14                               (6)
    Total                                                                 21

  Invoked by `finalize.sh` at post-complete (per architecture §10.31.1).
  Validation runs BEFORE the checkpoint and lifecycle-event writes
  (observability is never suppressed by checklist outcome — story AC5).

  See docs/implementation-artifacts/E42-S14-port-gaia-edit-test-plan-and-gaia-test-design-checklists-to-v2.md.
-->

- [script-verifiable] SV-01 — Output file saved to docs/test-artifacts/test-plan.md
- [script-verifiable] SV-02 — Output artifact is non-empty
- [script-verifiable] SV-03 — Version History section present (## Version History heading)
- [script-verifiable] SV-04 — Version History row with date, change summary, new test case IDs, FR/NFR anchors
- [script-verifiable] SV-05 — Test area section headers present (unit / integration / e2e / performance / security keyword)
- [script-verifiable] SV-06 — Test case ID convention followed (TC-NN / TP-NN anchors present)
- [script-verifiable] SV-07 — Validates field maps to FR/NFR IDs (FR-* or NFR-* anchor present)
- [LLM-checkable] LLM-01 — Existing test cases preserved exactly
- [LLM-checkable] LLM-02 — Existing test strategy and environments unchanged
- [LLM-checkable] LLM-03 — New test cases follow same format as existing
- [LLM-checkable] LLM-04 — Test case IDs auto-incremented from highest existing (no collisions)
- [LLM-checkable] LLM-05 — Each new test case has type, steps, expected results, priority
- [LLM-checkable] LLM-06 — Test cases assigned to correct test area/category (semantic fit)
- [LLM-checkable] LLM-07 — Test scope section updated to reflect expanded coverage
- [LLM-checkable] LLM-08 — Coverage summary updated (if present)
- [LLM-checkable] LLM-09 — Existing test plan loaded from docs/test-artifacts/test-plan.md (Step 1 output)
- [LLM-checkable] LLM-10 — Highest existing test case ID identified for auto-increment (Step 1)
- [LLM-checkable] LLM-11 — Existing test areas/categories identified before editing (Step 1)
- [LLM-checkable] LLM-12 — Change scope captured: feature description and FR/NFR IDs recorded (Step 2)
- [LLM-checkable] LLM-13 — PRD and architecture context consulted where available (Step 2)
- [LLM-checkable] LLM-14 — Next-steps block populated (traceability / ATDD recommendations) (Step 6)

## Finalize

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-edit-test-plan/scripts/finalize.sh
