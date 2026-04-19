---
name: gaia-test-review
description: Review test quality and identify flakiness. Use when "review tests" or /gaia-test-review.
argument-hint: "[story-key]"
context: fork
allowed-tools: [Read, Grep, Glob, Bash]
---

## Setup

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-test-review/scripts/setup.sh

## Mission

You are performing a test quality and flakiness review for a story. The story is resolved by `{story_key}` via the canonical glob `{story_key}-*.md` in `docs/implementation-artifacts/`. You assess test suite quality, identify flaky tests, evaluate test isolation, and produce a machine-readable verdict (PASSED or FAILED) written to the story's Review Gate "Test Review" row via `review-gate.sh`.

This skill is the native Claude Code conversion of the legacy `_gaia/lifecycle/workflows/4-implementation/test-review` workflow (brief Cluster 9, story E28-S70, ADR-042). It follows the canonical reviewer skill pattern established by E28-S66 (code-review).

**Fork context semantics (ADR-041, ADR-045):** This skill runs under `context: fork` with read-only tools (`Read Grep Glob Bash`). It CANNOT modify files -- the tool allowlist enforces NFR-048 (no-write isolation). Do NOT attempt to call Write or Edit.

**Subagent dispatch:** Test quality assessment is dispatched to the Vera QA subagent (E28-S21) for test coverage and quality analysis. Flakiness detection is dispatched to the Sable Test Architect subagent (E28-S21) for structural test analysis. The fork context invokes both subagents; their combined verdict is returned across the fork boundary.

## Critical Rules

- Knowledge fragments are bundled in this skill's `knowledge/` directory -- load them JIT when referenced by a step.
- A story key argument MUST be provided. If missing, fail fast with "usage: /gaia-test-review [story-key]".
- The story file MUST exist at `docs/implementation-artifacts/{story_key}-*.md`. Use the canonical glob to resolve regardless of title slug. If zero matches, fail with "story file not found for key {story_key}".
- The story MUST be in `review` status. If not, fail with "story must be in review status before test review".
- This skill is READ-ONLY. Do NOT attempt to call Write or Edit tools -- the fork context allowlist enforces this.
- Test quality assessment MUST be dispatched to the Vera QA subagent -- do NOT perform inline quality analysis in the fork context.
- Flakiness detection MUST be dispatched to the Sable Test Architect subagent -- do NOT perform inline flakiness analysis in the fork context.
- The verdict uses PASSED or FAILED (canonical Review Gate vocabulary, per CLAUDE.md).
- Call `review-gate.sh` to update the Review Gate row -- do NOT manually edit the story file.
- Sprint-status.yaml is NEVER written by this skill (Sprint-Status Write Safety rule).

## Steps

### Step 1 -- Resolve Story File

- If no story key was provided as an argument, fail with: "usage: /gaia-test-review [story-key]"
- Resolve the story file path using the canonical glob: `docs/implementation-artifacts/{story_key}-*.md`
- If zero matches: fail with "story file not found for key {story_key} -- searched docs/implementation-artifacts/{story_key}-*.md"
- If multiple matches: fail with "multiple story files matched key {story_key} -- resolve ambiguity"
- Read the resolved story file.

### Step 2 -- Status Gate

- Parse the story file YAML frontmatter and extract the `status` field.
- If status is not `review`, fail with: "story {story_key} is in '{status}' status -- must be in 'review' status for test review"
- Extract the list of acceptance criteria from the story file.
- Extract the list of files changed from the story file's "File List" section under "Dev Agent Record".

### Step 3 -- Test Quality Assessment

- Dispatch test quality assessment to the Vera QA subagent (E28-S21).
- Load knowledge fragment: `knowledge/test-isolation.md` for test doubles and isolation patterns
- Load knowledge fragment: `knowledge/deterministic-testing.md` for flakiness avoidance patterns
- Load knowledge fragment: `knowledge/selector-resilience.md` for UI selector resilience assessment
- Vera analyzes the story's test files for:
  - **Completeness:** Every acceptance criterion has corresponding test coverage
  - **Assertion quality:** Tests use meaningful assertions, not just existence checks
  - **Edge case coverage:** Boundary conditions, error paths, and negative cases tested
  - **Test isolation:** Tests do not depend on external state or execution order
  - **Naming conventions:** Test names clearly describe the behavior being verified
- The QA subagent returns: quality score, issues found (list), and recommendations.

### Step 4 -- Flakiness Analysis

- Dispatch flakiness detection to the Sable Test Architect subagent (E28-S21).
- Load knowledge fragment: `knowledge/visual-testing.md` for visual regression assessment patterns
- Load knowledge fragment: `knowledge/test-healing.md` for self-healing test and selector fallback patterns
- Sable analyzes the story's test files for:
  - **Non-determinism:** Tests depending on timing, random values, or system state
  - **Shared mutable state:** Global variables, singletons, or shared fixtures that leak between tests
  - **External dependencies:** Tests that hit network, filesystem, or databases without mocking
  - **Race conditions:** Async tests missing proper await/synchronization
  - **Order dependence:** Tests that pass only when run in a specific sequence
- The Test Architect subagent returns: flakiness risk rating, flagged tests (list), and mitigation suggestions.

### Step 5 -- Consolidated Verdict

- Combine results from Vera (quality) and Sable (flakiness):
  - If test quality is acceptable AND no critical flakiness risks: verdict is **PASSED**
  - If test quality has critical gaps OR critical flakiness risks detected: verdict is **FAILED** -- list all critical issues with reasons
- The verdict MUST appear as a machine-readable keyword in the report output.

### Step 6 -- Write Test Review Report

- Generate the test review report and print it to the conversation. The report must contain:
  - Story key and title
  - Test quality assessment from Vera QA subagent (Step 3 output)
  - Flakiness analysis from Sable Test Architect subagent (Step 4 output)
  - Consolidated findings organized by severity (Critical, Warning, Info)
  - Machine-readable verdict line: `**Verdict: PASSED**` or `**Verdict: FAILED**`
- Save the report to `docs/test-artifacts/{story_key}-test-review.md`.

### Step 7 -- Update Review Gate

- Map the verdict to the canonical Review Gate vocabulary:
  - PASSED maps to PASSED
  - FAILED maps to FAILED
- Invoke the shared `review-gate.sh` script to update the story's Review Gate table:
  ```bash
  ${CLAUDE_PLUGIN_ROOT}/../scripts/review-gate.sh update --story "{story_key}" --gate "Test Review" --verdict "{PASSED|FAILED}"
  ```
- Confirm the update succeeded (exit code 0).
- Report the final status to the user.
- Note: sprint-status.yaml may now be out of sync. Run `/gaia-sprint-status` to reconcile.

## Finalize

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-test-review/scripts/finalize.sh
