---
name: gaia-test-automate
description: Expand automated test coverage for a story. Use when "automate tests" or /gaia-test-automate.
argument-hint: "[story-key]"
context: fork
allowed-tools: [Read, Grep, Glob, Bash]
---

## Setup

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-test-automate/scripts/setup.sh

## Mission

You are performing an automated test coverage expansion review for a story. The story is resolved by `{story_key}` via the canonical glob `{story_key}-*.md` in `docs/implementation-artifacts/`. You analyze test gaps, delegate to the qa subagent (Vera) for test generation, and produce a machine-readable verdict (PASSED or FAILED) written to the story's Review Gate "Test Automation" row via `review-gate.sh`.

This skill is the native Claude Code conversion of the legacy `_gaia/lifecycle/workflows/4-implementation/test-automation` workflow (brief Cluster 9, story E28-S69, ADR-042). It follows the canonical reviewer skill pattern established by E28-S66 (code-review).

**Fork context semantics (ADR-041, ADR-045):** This skill runs under `context: fork` with read-only tools (`Read Grep Glob Bash`). It CANNOT modify files -- the tool allowlist enforces NFR-048 (no-write isolation). Do NOT attempt to call Write or Edit.

**Subagent dispatch:** Automated test coverage expansion is dispatched to the Vera QA subagent (E28-S21). The fork context invokes Vera for test generation analysis; Vera's verdict is returned across the fork boundary.

## Critical Rules

- Knowledge fragments are bundled in this skill's `knowledge/` directory -- load them JIT when referenced by a step.
- A story key argument MUST be provided. If missing, fail fast with "usage: /gaia-test-automate [story-key]".
- The story file MUST exist at `docs/implementation-artifacts/{story_key}-*.md`. Use the canonical glob to resolve regardless of title slug. If zero matches, fail with "story file not found for key {story_key}".
- The story MUST be in `review` status. If not, fail with "story must be in review status before test automation".
- This skill is READ-ONLY. Do NOT attempt to call Write or Edit tools -- the fork context allowlist enforces this.
- Test coverage expansion analysis MUST be dispatched to the Vera QA subagent -- do NOT perform inline test generation in the fork context.
- The verdict uses PASSED or FAILED (canonical Review Gate vocabulary, per CLAUDE.md).
- Call `review-gate.sh` to update the Review Gate row -- do NOT manually edit the story file.
- Sprint-status.yaml is NEVER written by this skill (Sprint-Status Write Safety rule).

## Steps

### Step 1 -- Resolve Story File

- If no story key was provided as an argument, fail with: "usage: /gaia-test-automate [story-key]"
- Resolve the story file path using the canonical glob: `docs/implementation-artifacts/{story_key}-*.md`
- If zero matches: fail with "story file not found for key {story_key} -- searched docs/implementation-artifacts/{story_key}-*.md"
- If multiple matches: fail with "multiple story files matched key {story_key} -- resolve ambiguity"
- Read the resolved story file.

### Step 2 -- Status Gate

- Parse the story file YAML frontmatter and extract the `status` field.
- If status is not `review`, fail with: "story {story_key} is in '{status}' status -- must be in 'review' status for test automation"
- Extract the list of acceptance criteria from the story file.
- Extract the list of files changed from the story file's "File List" section under "Dev Agent Record".

### Step 3 -- Test Coverage Analysis

- Load knowledge fragments as needed for analysis context:
  - Load knowledge fragment: `knowledge/fixture-architecture.md` for fixture and factory patterns
  - Load knowledge fragment: `knowledge/deterministic-testing.md` for flakiness avoidance patterns
  - Load knowledge fragment: `knowledge/api-testing-patterns.md` for API test coverage patterns
  - Load knowledge fragment: `knowledge/data-factories.md` for test data generation patterns
  - Load knowledge fragment: `knowledge/selector-resilience.md` for UI selector resilience patterns
  - Load knowledge fragment: `knowledge/visual-testing.md` for visual regression patterns
- Load stack-specific unit testing patterns as needed:
  - Load knowledge fragment: `knowledge/jest-vitest-patterns.md` for JS/TS projects
  - Load knowledge fragment: `knowledge/pytest-patterns.md` for Python projects
  - Load knowledge fragment: `knowledge/junit5-patterns.md` for Java projects
- Analyze the existing test suite to identify coverage gaps for this story's acceptance criteria.
- For each acceptance criterion, determine whether automated tests exist that verify the criterion.
- Identify untested edge cases, boundary conditions, and error paths.
- Categorize gaps by severity: critical (AC without any test coverage), warning (partial coverage), info (minor edge case).

### Step 4 -- Automated Test Expansion

- Dispatch test coverage expansion to the Vera QA subagent (E28-S21).
- Vera analyzes the story's implementation files and acceptance criteria, then generates or documents test cases to fill identified gaps.
- The subagent returns: test cases generated (count), acceptance criteria now covered (list), remaining gaps (list).
- Do NOT write executable test files to the source tree from this fork context -- document the test expansion plan in the report.

### Step 5 -- Verdict

- If ALL acceptance criteria have automated test coverage (existing or newly documented) AND no critical gaps remain: verdict is **PASSED**
- If ANY acceptance criterion lacks automated test coverage OR critical gaps remain unaddressed: verdict is **FAILED** -- list uncovered criteria and remaining gaps.
- The verdict MUST appear as a machine-readable keyword in the report output.

### Step 6 -- Write Test Automation Report

- Generate the test automation report and print it to the conversation. The report must contain:
  - Story key and title
  - Summary of test coverage analysis (Step 3 output)
  - Test expansion results from Vera subagent (Step 4 output)
  - Coverage gap summary: critical/warning/info counts
  - Machine-readable verdict line: `**Verdict: PASSED**` or `**Verdict: FAILED**`
- Save the report to `docs/test-artifacts/{story_key}-test-automation.md`.

### Step 7 -- Update Review Gate

- Map the verdict to the canonical Review Gate vocabulary:
  - PASSED maps to PASSED
  - FAILED maps to FAILED
- Invoke the shared `review-gate.sh` script to update the story's Review Gate table:
  ```bash
  ${CLAUDE_PLUGIN_ROOT}/../scripts/review-gate.sh update --story "{story_key}" --gate "Test Automation" --verdict "{PASSED|FAILED}"
  ```
- Confirm the update succeeded (exit code 0).
- Report the final status to the user.
- Note: sprint-status.yaml may now be out of sync. Run `/gaia-sprint-status` to reconcile.

## Finalize

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-test-automate/scripts/finalize.sh
