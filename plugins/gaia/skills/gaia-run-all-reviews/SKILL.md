---
name: gaia-run-all-reviews
description: Run all 6 review workflows sequentially via subagents. Use when "run all reviews".
argument-hint: "[story-key]"
context: fork
allowed-tools: Read Grep Glob Bash
---

## Mission

You are running all 6 review workflows sequentially inline for a story. The story is resolved by `{story_key}` via the canonical glob `{story_key}-*.md` in `docs/implementation-artifacts/`. You orchestrate each review in deterministic order, update the Review Gate table after each, and report a summary of all verdicts.

This skill is the native Claude Code conversion of the legacy `_gaia/lifecycle/workflows/4-implementation/run-all-reviews` workflow (brief Cluster 9, story E28-S72, ADR-042, ADR-045). It is the conductor for the Cluster 9 reviewer skills landed under E28-S66..S71.

**Inline orchestration:** This skill runs all 6 reviews sequentially inline within a single context. It does NOT spawn nested subagents (to avoid nesting limitations). Each review is executed in-process by loading and following the relevant reviewer skill's instructions.

**Sequential-only contract (ADR-045):** The review gate is intentionally sequential. Parallel execution would create race conditions on the Review Gate table. The canonical order is never reordered.

## Critical Rules

- A story key argument MUST be provided. If missing, fail fast with "usage: /gaia-run-all-reviews [story-key]".
- The story file MUST exist at `docs/implementation-artifacts/{story_key}-*.md`. Use the canonical glob to resolve. If zero matches, fail with "story file not found for key {story_key}".
- The story MUST be in `review` status. If not, fail with "story must be in review status before running reviews".
- Reviews MUST run in this exact order — never reordered, never parallel:
  1. Code Review (gaia-code-review)
  2. Security Review (gaia-security-review)
  3. QA Tests (gaia-qa-tests)
  4. Test Automation (gaia-test-automate)
  5. Test Review (gaia-test-review)
  6. Performance Review (gaia-review-perf)
- **Never short-circuit on failure.** If a reviewer returns FAILED, record the verdict and continue to the next reviewer. The entire purpose is to surface ALL issues in one pass.
- After each reviewer completes, update the Review Gate table in the story file via `scripts/review-gate.sh update --story {story_key} --gate "{gate_name}" --verdict {PASSED|FAILED}`.
- If a reviewer crashes (unexpected error), record FAILED for that reviewer and continue.
- If `review-gate.sh` fails to update a row, log the failure and continue to the next reviewer.
- This skill does NOT transition story state. State transitions are owned by the state machine, not by the runner.

## Procedure

### Step 1: Validate Input

1. Parse the story key from the argument.
2. Resolve the story file via glob: `docs/implementation-artifacts/{story_key}-*.md`.
3. Read the story file frontmatter and verify `status: review`.
4. Read the current Review Gate table to confirm the section exists.

### Step 2: Execute Reviews Inline

For each reviewer in the canonical sequence, execute the review inline:

**Review 1 — Code Review:**
- Read the story file to identify all changed/created files listed in the File List section.
- For each file: read it and review for correctness, security, performance, readability, naming conventions, and test coverage.
- Produce a verdict: PASSED if no blocking issues, FAILED if blocking issues found.
- Update gate: `bash scripts/review-gate.sh update --story {story_key} --gate "Code Review" --verdict {verdict}`

**Review 2 — Security Review:**
- Read the story file and all implementation files.
- Review for OWASP Top 10 vulnerabilities, injection risks, authentication/authorization issues, secrets exposure, and input validation.
- Produce a verdict: PASSED if no security issues, FAILED if issues found.
- Update gate: `bash scripts/review-gate.sh update --story {story_key} --gate "Security Review" --verdict {verdict}`

**Review 3 — QA Tests:**
- Read the story's acceptance criteria and test files.
- Verify test coverage against each AC. Check for missing edge cases, boundary conditions, and error scenarios.
- Produce a verdict: PASSED if coverage is adequate, FAILED if gaps found.
- Update gate: `bash scripts/review-gate.sh update --story {story_key} --gate "QA Tests" --verdict {verdict}`

**Review 4 — Test Automation:**
- Read the test files and verify they are automated (can run via `npm test`, `bats`, or equivalent).
- Check test structure, assertions, mocking patterns, and CI integration.
- Produce a verdict: PASSED if automation is adequate, FAILED if gaps found.
- Update gate: `bash scripts/review-gate.sh update --story {story_key} --gate "Test Automation" --verdict {verdict}`

**Review 5 — Test Review:**
- Review test quality: check for flaky tests, proper assertions, test isolation, meaningful names, and arrange-act-assert structure.
- Produce a verdict: PASSED if test quality is adequate, FAILED if issues found.
- Update gate: `bash scripts/review-gate.sh update --story {story_key} --gate "Test Review" --verdict {verdict}`

**Review 6 — Performance Review:**
- Review implementation for performance concerns: unnecessary loops, missing memoization, unbounded operations, blocking I/O, and algorithmic complexity.
- Produce a verdict: PASSED if no performance issues, FAILED if concerns found.
- Update gate: `bash scripts/review-gate.sh update --story {story_key} --gate "Performance Review" --verdict {verdict}`

### Step 3: Generate Summary

After all 6 reviews complete:

1. Read the updated Review Gate table from the story file.
2. Count PASSED vs FAILED verdicts.
3. Report a summary:
   - If ALL 6 PASSED: "All 6 reviews PASSED. Story {story_key} is ready for done status."
   - If any FAILED: "{N} review(s) FAILED: {list}. Story should return to in-progress for rework."
4. Write `docs/implementation-artifacts/{story_key}-review-summary.md` with the full review results.
