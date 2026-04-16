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

### Step 2 — Capture Change Scope

Ask the user:

1. What new test cases are needed? Describe the feature or change requiring test coverage.
2. Which FR/NFR IDs need test coverage?

- Read relevant sections of `docs/planning-artifacts/prd.md` for requirement context (if available).
- Read relevant sections of `docs/planning-artifacts/architecture.md` for technical context (if available).
- Record: new_requirements, change_description, affected_test_areas.

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

### Step 4 — Update Test Plan

- Append new test cases to the appropriate test area sections.
- If new test area needed: create section header with description before adding test cases.
- Update test scope section to reflect expanded coverage.
- Update coverage summary if present (new requirements covered / total).
- Preserve all existing content exactly as-is — no reordering, no reformatting, no removal.

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

### Step 6 — Next Steps

- Report test cases added: list new IDs, their types, and requirements covered.
- If high-risk stories need acceptance tests: "Recommend running /gaia-atdd for stories: {story_keys}"
- If traceability update needed: "Recommend running /gaia-trace to update traceability matrix"

## Finalize

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-edit-test-plan/scripts/finalize.sh
