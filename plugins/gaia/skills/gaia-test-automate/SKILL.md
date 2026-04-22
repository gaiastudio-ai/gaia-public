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

You are performing Phase 1 (fork-isolated analysis) of the two-phase test-automate pattern (ADR-051, architecture §10.27). The story is resolved by `{story_key}` via the canonical glob `{story_key}-*.md` in `docs/implementation-artifacts/`. You analyze test gaps, compute source-file SHA-256 entries, and emit a structured test-generation plan file at `docs/test-artifacts/test-automate-plan-{story_key}.md` (schema v1, §10.27.3). You do NOT write test files or finalize a Review Gate verdict -- those are Phase 2 responsibilities (E35-S2, E35-S3).

This skill is the native Claude Code conversion of the legacy `_gaia/lifecycle/workflows/4-implementation/test-automation` workflow (brief Cluster 9, story E28-S69, ADR-042). It follows the canonical reviewer skill pattern established by E28-S66 (code-review), extended with the two-phase fork-context architecture per ADR-051.

**Fork context semantics (ADR-041, ADR-045, ADR-051):** This skill runs under `context: fork` with read-only tools (`Read Grep Glob Bash`). It CANNOT modify files -- the tool allowlist enforces NFR-048 (no-write isolation). Do NOT attempt to call Write or Edit. The fork-isolation unit is the untrusted-analysis phase of the review command (§10.27.5).

**Two-phase architecture (ADR-051):** Phase 1 (this skill) produces the plan file. Phase 2 (E35-S3, main-context) executes the plan after user approval via the approval gate (E35-S2). Phase 1 does NOT invoke `review-gate.sh` and does NOT finalize any verdict.

**Subagent dispatch:** Automated test coverage expansion analysis is dispatched to the Vera QA subagent (E28-S21). The fork context invokes Vera for test generation analysis; Vera's analysis feeds the plan file's `proposed_tests[]` entries.

## Critical Rules

- Knowledge fragments are bundled in this skill's `knowledge/` directory -- load them JIT when referenced by a step.
- A story key argument MUST be provided. If missing, fail fast with "usage: /gaia-test-automate [story-key]".
- The story file MUST exist at `docs/implementation-artifacts/{story_key}-*.md`. Use the canonical glob to resolve regardless of title slug. If zero matches, fail with "story file not found for key {story_key}".
- The story MUST be in `review` status. If not, fail with "story must be in review status before test automation".
- This skill is READ-ONLY. Do NOT attempt to call Write or Edit tools -- the fork context allowlist enforces this.
- Test coverage expansion analysis MUST be dispatched to the Vera QA subagent -- do NOT perform inline test generation in the fork context.
- The plan file output path is `docs/test-artifacts/test-automate-plan-{story_key}.md` (architecture §10.27.3).
- Phase 1 does NOT invoke `review-gate.sh` -- the approval gate is wired by E35-S2.
- Phase 1 does NOT finalize a Review Gate verdict -- that is a Phase 2 responsibility (E35-S3).
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

### Step 3 -- Test Coverage Analysis (Phase 1 analysis)

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
- Compute SHA-256 for every source file read during analysis using `shasum -a 256 <path>`. Parse the leading hex field and prefix with `sha256:` (ADR-050 idempotency scheme format: `sha256:{hex}`). Record each file's `path`, `sha256`, and `last_modified` (ISO 8601) for the `analyzed_sources[]` array in the plan file.
- Handle edge cases during SHA-256 computation:
  - File deleted between read and SHA-256 (AC-EC2): log warning, omit from `analyzed_sources[]`, continue.
  - Non-UTF-8 / binary content (AC-EC5): `shasum` operates on raw bytes -- no special handling needed.
  - Large files (AC-EC4): `shasum` streams I/O regardless of file size -- no timeout concern.

### Step 4 -- Test Expansion Analysis (Phase 1 analysis)

- Dispatch test coverage expansion analysis to the Vera QA subagent (E28-S21).
- Vera analyzes the story's implementation files and acceptance criteria, then documents proposed test cases to fill identified gaps.
- The subagent returns: test cases proposed (count), acceptance criteria now covered (list), remaining gaps (list).
- Do NOT write executable test files to the source tree from this fork context -- all proposed tests are recorded as entries in the plan file's `proposed_tests[]` array (schema v1, §10.27.3).
- Each `proposed_tests[]` entry contains: `target` (source file), `test_file` (proposed test path), `tier`, `test_cases[]` with `name`, `assertion_intent`, and `maps_to_ac` fields.

### Step 5 -- Narrative Body (Phase 1 analysis)

- Compose a human-readable narrative describing the coverage gap analysis and test-design rationale.
- Include: which acceptance criteria lack coverage, which edge cases were identified, what test strategy is recommended.
- This narrative is written below the YAML frontmatter in the plan file (Step 6).

### Step 6 -- Emit Plan File (Phase 1 output)

- Invoke the `emit-plan-file.sh` helper to produce the Phase 1 plan file:
  ```bash
  ${CLAUDE_PLUGIN_ROOT}/skills/gaia-test-automate/scripts/emit-plan-file.sh \
    --story-key "{story_key}" \
    --output "docs/test-artifacts/test-automate-plan-{story_key}.md" \
    --sources '{analyzed_sources_json}' \
    --tests '{proposed_tests_json}' \
    --narrative "{narrative_body}"
  ```
- The plan file is written atomically (temp file + mv) to `docs/test-artifacts/test-automate-plan-{story_key}.md`.
- Each invocation generates a fresh `plan_id` (AC3). Re-invocations overwrite the file with a new plan_id; prior plans are discarded.
- Print the plan file contents to the conversation for user review.
- Phase 1 is now complete. The plan file awaits user approval via the approval gate (E35-S2, non-goal for this story).

### Step 7 -- Handoff to Approval Gate (non-goal guard)

- Phase 1 does NOT finalize a Review Gate verdict. The approval gate is wired by E35-S2.
- Phase 1 does NOT invoke `review-gate.sh`. Verdict recording happens after Phase 2 execution (E35-S3).
- Report to the user: "Phase 1 analysis complete. Plan file emitted at docs/test-artifacts/test-automate-plan-{story_key}.md. Approval gate and Phase 2 execution are wired by E35-S2 and E35-S3 respectively."
- Note: sprint-status.yaml may now be out of sync. Run `/gaia-sprint-status` to reconcile.

## Finalize

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-test-automate/scripts/finalize.sh
