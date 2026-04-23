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

### Step 7 -- Approval Gate (E35-S2)

This step gates progression from Phase 1 to Phase 2. The user (or YOLO auto-approve) must approve the plan before Phase 2 can execute. The verdict is recorded via `review-gate.sh update --plan-id` and written to the plan file's `approval` block.

**Pre-conditions:**
- The plan file MUST exist at `docs/test-artifacts/test-automate-plan-{story_key}.md` (emitted by Step 6).
- The story file MUST exist at `docs/implementation-artifacts/{story_key}-*.md`.

**7.1 — Read and validate plan file:**
- Read the plan file emitted by Step 6. Parse YAML frontmatter to extract `plan_id`.
- If the plan file is missing or the story file is missing, HALT: "Cannot proceed with approval gate -- plan file or story file not found. Re-run Phase 1." Do NOT write any ledger record (AC-EC4).
- If the frontmatter is malformed (cannot extract `plan_id`), HALT: "plan_tamper_detected -- cannot parse plan_id from plan file frontmatter. Re-run Phase 1."

**7.2 — Present plan for approval:**
- Display the plan contents: narrative body and `proposed_tests[]` summary (test file paths, test case names, mapped acceptance criteria).
- Record the `plan_id` value at presentation time for tamper detection (AC-EC5, AC-EC8).

**7.3 — Collect verdict:**
- In **normal mode**: prompt the user:
  ```
  [a] Approve (PASSED) | [r] Reject (FAILED) | [x] Abort
  ```
- In **YOLO mode**: auto-approve path (AC5):
  1. Load tier-directory allowlist by invoking `test-env-allowlist.sh --test-env docs/test-artifacts/test-environment.yaml`.
  2. If `test-environment.yaml` is missing (AC-EC6): pause for explicit user approval. Log: "allowlist source absent -- cannot auto-approve."
  3. For each `proposed_tests[].test_file` path in the plan, check whether it falls within any allowlisted tier directory (prefix match after path normalization).
  4. If ALL proposed test paths are within the allowlist: auto-approve. Set verdict = PASSED.
  5. If ANY proposed test path is outside the allowlist: pause for explicit user approval even in YOLO. Log which path(s) are outside scope.

**7.4 — Tamper check (AC-EC5, AC-EC8):**
- Immediately before recording the verdict, re-read the plan file and extract the current on-disk `plan_id`.
- If the on-disk `plan_id` differs from the value recorded at presentation time (Step 7.2), HALT: "plan_tamper_detected -- plan_id changed between presentation and verdict. The on-disk plan was overwritten (possibly by a concurrent invocation). Re-run Phase 1."
- If the `plan_id` matches, proceed to record the verdict against the on-disk `plan_id`.

**7.5 — Record verdict:**
- On **PASSED** (user approves or YOLO auto-approves):
  1. Invoke: `review-gate.sh update --story {story_key} --gate test-automate-plan --verdict PASSED --plan-id {plan_id}`
  2. Patch the plan file's YAML frontmatter `approval` block:
     - Set `approval.verdict` to `"PASSED"`
     - Set `approval.verdict_plan_id` to `{plan_id}`
  3. Use atomic write (temp file + mv) for the plan file patch.
  4. Post-write verification: re-read the plan file and confirm `approval.verdict` = PASSED and `approval.verdict_plan_id` = `{plan_id}`. If divergence, HALT with message pointing at AC4.
  5. Report: "Plan approved. Verdict PASSED recorded for plan_id={plan_id}. Ready for Phase 2 execution (E35-S3)."
  6. Invoke the composite review-gate-check to show the overall story review status:
     ```bash
     ${CLAUDE_PLUGIN_ROOT}/scripts/review-gate.sh review-gate-check --story "{story_key}"
     ```
     Capture stdout and include the Review Gate table and summary line (`Review Gate: COMPLETE|PENDING|BLOCKED`) in the command's output. This check is informational only -- do not halt on non-zero exit codes. Exit codes 0/1/2 correspond to COMPLETE/BLOCKED/PENDING per ADR-054. Log the result and continue regardless of exit code.

- On **FAILED** (user rejects, AC-EC7):
  1. Invoke: `review-gate.sh update --story {story_key} --gate test-automate-plan --verdict FAILED --plan-id {plan_id}`
  2. Patch the plan file's `approval.verdict` to `"FAILED"`.
  3. Report: "Plan rejected. Verdict FAILED recorded. Phase 2 will NOT be invoked. Re-run /gaia-test-automate to generate a new plan."
  4. Exit cleanly. Do NOT invoke Phase 2.

- On **Abort**:
  1. Exit cleanly without recording any verdict. Do NOT invoke Phase 2.

**7.6 — Handoff to Phase 2:**
- Phase 2 execution is the responsibility of E35-S3. This step does NOT invoke Phase 2.
- Report: "Approval gate complete. Phase 2 execution is handled by E35-S3."
- Note: sprint-status.yaml may now be out of sync. Run `/gaia-sprint-status` to reconcile.

## Finalize

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-test-automate/scripts/finalize.sh
