---
name: gaia-qa-tests
description: Generate QA test cases and review test coverage. Use when "generate QA tests" or /gaia-qa-tests.
argument-hint: "[story-key]"
context: fork
allowed-tools: Read Grep Glob Bash
---

## Setup

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-qa-tests/scripts/setup.sh

## Mission

You are performing a QA test generation review for a story. The story is resolved by `{story_key}` via the canonical glob `{story_key}-*.md` in `docs/implementation-artifacts/`. You review each acceptance criterion, document API and E2E test cases, run any existing tests, and produce a machine-readable verdict (PASSED or FAILED) written to the story's Review Gate row via `review-gate.sh`.

This skill is the native Claude Code conversion of the legacy `_gaia/lifecycle/workflows/4-implementation/qa-generate-tests` workflow (brief Cluster 9, story E28-S68, ADR-042). It follows the canonical reviewer skill pattern established by E28-S66.

**Fork context semantics (ADR-041, ADR-045):** This skill runs under `context: fork` with read-only tools (`Read Grep Glob Bash`). It CANNOT modify files — the tool allowlist enforces NFR-048 (no-write isolation). Do NOT attempt to call Write or Edit.

**Subagent dispatch:** QA test case generation is dispatched to the Vera QA subagent (E28-S21). The fork context invokes Vera for test analysis; Vera's verdict is returned across the fork boundary.

## Critical Rules

- A story key argument MUST be provided. If missing, fail fast with "usage: /gaia-qa-tests [story-key]".
- The story file MUST exist at `docs/implementation-artifacts/{story_key}-*.md`. Use the canonical glob to resolve regardless of title slug. If zero matches, fail with "story file not found for key {story_key}".
- The story MUST be in `review` status. If not, fail with "story must be in review status before QA tests".
- This skill is READ-ONLY. Do NOT attempt to call Write or Edit tools — the fork context allowlist enforces this.
- Do NOT write executable test files to the source tree (tests/, spec/, __tests__/, e2e/). Document test cases in the QA report only.
- QA analysis MUST be dispatched to the Vera QA subagent — do NOT perform inline analysis in the fork context.
- The verdict uses PASSED or FAILED (canonical Review Gate vocabulary, per CLAUDE.md).
- Call `review-gate.sh` to update the Review Gate row — do NOT manually edit the story file.
- Sprint-status.yaml is NEVER written by this skill (Sprint-Status Write Safety rule).

## Steps

### Step 1 -- Resolve Story File

- If no story key was provided as an argument, fail with: "usage: /gaia-qa-tests [story-key]"
- Resolve the story file path using the canonical glob: `docs/implementation-artifacts/{story_key}-*.md`
- If zero matches: fail with "story file not found for key {story_key} -- searched docs/implementation-artifacts/{story_key}-*.md"
- If multiple matches: fail with "multiple story files matched key {story_key} -- resolve ambiguity"
- Read the resolved story file.

### Step 2 -- Status Gate

- Parse the story file YAML frontmatter and extract the `status` field.
- If status is not `review`, fail with: "story {story_key} is in '{status}' status -- must be in 'review' status for QA tests"
- Extract the list of acceptance criteria from the story file.
- Extract the list of files changed from the story file's "File List" section under "Dev Agent Record".

### Step 3 -- API / Integration Test Case Documentation

- Document API/integration test cases for each acceptance criterion -- do NOT write executable test files.
- For each test case: describe the endpoint or function, method, input, expected response, and edge cases.
- Cover happy path, error cases, boundary conditions, and authorization scenarios.
- Use test case IDs in format TC-{story_key}-{NNN} (e.g., TC-E1-S1-001). Include fields: ID, AC reference, Preconditions, Steps, Expected Result.

### Step 4 -- E2E Test Case Documentation

- Document end-to-end test scenarios from user journeys -- do NOT write executable test files.
- For each scenario: describe preconditions, user actions, assertions, and cleanup.
- Continue TC-{story_key}-{NNN} numbering sequence from Step 3.

### Step 5 -- Test Execution

- If executable tests already exist in the source tree for this story: run them and report results.
- If no existing tests: run the application and manually verify key acceptance criteria through API calls or code inspection.
- Do NOT create new test files in the source tree -- test file creation is the responsibility of /gaia-test-automate.

### Step 6 -- Verdict

- If ALL acceptance criteria have corresponding test cases documented AND any existing tests pass: verdict is **PASSED**
- If ANY acceptance criterion lacks test coverage OR any existing test fails: verdict is **FAILED** -- list failing items with reasons.
- The verdict MUST appear as a machine-readable keyword in the report output.

### Step 7 -- Write QA Test Report

- Generate the QA test report and print it to the conversation. The report must contain:
  - Story key and title
  - Summary of acceptance criteria reviewed
  - API/integration test cases (Step 3 output)
  - E2E test cases (Step 4 output)
  - Test execution results (Step 5 output)
  - Machine-readable verdict line: `**Verdict: PASSED**` or `**Verdict: FAILED**`
- Save the report to `docs/test-artifacts/{story_key}-qa-tests.md`.

### Step 8 -- Update Review Gate

- Map the verdict to the canonical Review Gate vocabulary:
  - PASSED maps to PASSED
  - FAILED maps to FAILED
- Invoke the shared `review-gate.sh` script to update the story's Review Gate table:
  ```bash
  ${CLAUDE_PLUGIN_ROOT}/../scripts/review-gate.sh update --story "{story_key}" --gate "QA Tests" --verdict "{PASSED|FAILED}"
  ```
- Confirm the update succeeded (exit code 0).
- Report the final status to the user.
- Note: sprint-status.yaml may now be out of sync. Run `/gaia-sprint-status` to reconcile.

## Finalize

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-qa-tests/scripts/finalize.sh
