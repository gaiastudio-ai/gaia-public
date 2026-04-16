---
name: gaia-atdd
description: Generate failing acceptance tests using TDD methodology from a story's acceptance criteria. Converts each AC into a Given/When/Then test skeleton following the red phase of TDD.
argument-hint: [story-key]
allowed-tools: [Read, Write, Edit, Bash]
---

## Setup

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-atdd/scripts/setup.sh

## Mission

You are generating Acceptance Test-Driven Development (ATDD) artifacts for the specified story key. Each acceptance criterion from the story file is transformed into a failing test skeleton using Given/When/Then format. The output is saved to `docs/test-artifacts/atdd-{story_key}.md`.

This skill is the native Claude Code conversion of the legacy `_gaia/testing/workflows/atdd/` workflow (brief Cluster 4, story E28-S83). The step ordering, output path convention, and AC-to-test mapping are preserved from the legacy instructions.

## Critical Rules

- Knowledge fragments are bundled in this skill's `knowledge/` directory -- load them JIT when referenced by a step.
- The `story-key` argument is **required**. If missing or malformed (empty string, missing epic prefix like "S83" without "E{n}-" prefix), exit with a clear validation error message naming the invalid argument. Valid format: `E{number}-S{number}` (e.g., `E1-S1`, `E28-S83`).
- A story file MUST exist at `docs/implementation-artifacts/{story_key}-*.md` before proceeding. If the story file is not found for the given key, exit with error: "Story file not found for {story_key}".
- The story file MUST contain an `## Acceptance Criteria` section with at least one AC entry. If no acceptance criteria are found or the section is empty, exit gracefully with the message: "No acceptance criteria found for {story_key}" and write no ATDD artifact.
- Each acceptance criterion maps to exactly one failing test skeleton — maintain a strict 1:1 AC-to-test mapping.
- All generated tests MUST use **Given/When/Then** format for behavior specification.
- Tests are in the **red phase of TDD** — they describe expected behavior and must fail because the implementation does not exist yet. Do NOT write implementation code.
- Output MUST be written to `docs/test-artifacts/atdd-{story_key}.md`. If the file already exists from a prior run, overwrite it idempotently — no duplicate content or stale remnants should remain.
- If the generated ATDD output exceeds 10KB (e.g., a story with 20+ ACs), log a warning: "ATDD output exceeds 10KB ({size}KB) — review for completeness." Output must remain complete with no truncation regardless of size.
- Only high-risk stories typically require ATDD. If the story risk level is not "high", proceed anyway but note in the output header that ATDD was invoked explicitly.

## Steps

### Step 1 -- Validate Input

- If a story key was provided as an argument (e.g., `/gaia-atdd E1-S1`), use it directly.
- Validate story key format: must match `E{number}-S{number}` pattern. If malformed, exit with error: "Invalid story key format: {story_key}. Expected format: E{n}-S{n}".
- If no story key was provided, exit with error: "story-key argument is required".

### Step 2 -- Load Story File

- Search `docs/implementation-artifacts/` for a file matching `{story_key}-*.md`.
- If no story file is found, exit with error: "Story file not found for {story_key}".
- Read the story file and extract:
  - Story title from frontmatter
  - Risk level from frontmatter (default: "low" if absent)
  - Acceptance criteria from the `## Acceptance Criteria` section
- If the Acceptance Criteria section is missing or contains no AC entries, exit with: "No acceptance criteria found for {story_key}".

### Step 3 -- Generate AC-to-Test Mapping

- Load knowledge fragment: `knowledge/api-testing-patterns.md` for schema validation and contract test patterns relevant to AC-to-test transformation
- For each acceptance criterion (AC1, AC2, AC-EC1, etc.):
  - Extract the AC identifier and description
  - Transform the AC into a Given/When/Then test skeleton
  - Name the test descriptively to reflect the AC being validated
- Build a traceability table mapping each AC to its corresponding test

### Step 4 -- Write ATDD Artifact

- Generate the ATDD document with the following structure:
  - Header: story key, title, risk level, generation date
  - AC-to-test mapping table (AC ID, AC description, test name)
  - Test skeletons in Given/When/Then format for each AC
  - Summary: total ACs, total tests, confirmation all tests are in failing/red state
- Write the artifact to `docs/test-artifacts/atdd-{story_key}.md`
- If the file already exists, overwrite it completely (idempotent operation)
- After writing, check file size. If output exceeds 10KB, display warning: "ATDD output exceeds 10KB — review for completeness"

### Step 5 -- Validation

- Verify every AC from the story has exactly one corresponding test in the output
- Verify no test references an AC that does not exist in the story
- Verify all tests use Given/When/Then format
- Verify the output file was written successfully

## Finalize

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-atdd/scripts/finalize.sh
