---
name: gaia-code-review
description: Pre-merge code review. Use when "run code review" or /gaia-code-review.
argument-hint: "[story-key]"
context: fork
allowed-tools: [Read, Grep, Glob, Bash]
---

## Setup

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-code-review/scripts/setup.sh

## Mission

You are performing a pre-merge code review for a story. The story is resolved by `{story_key}` via the canonical glob `{story_key}-*.md` in `docs/implementation-artifacts/`. You review each changed file for correctness, security, performance, readability, and test coverage. You produce a machine-readable verdict (APPROVE or REQUEST_CHANGES) in the report body and write PASSED or FAILED to the story's Review Gate row via `review-gate.sh`.

This skill is the native Claude Code conversion of the legacy `_gaia/lifecycle/workflows/4-implementation/code-review` workflow (brief Cluster 9, story E28-S66, ADR-042). This is the CANONICAL reference implementation of the reviewer skill pattern (no-write isolation) that E28-S67..S71 follow.

**Fork context semantics (ADR-041, ADR-045):** This skill runs under `context: fork` with read-only tools (`Read Grep Glob Bash`). It CANNOT modify files — the tool allowlist enforces NFR-048 (no-write isolation). Do NOT attempt to call Write or Edit.

## Critical Rules

- A story key argument MUST be provided. If missing, fail fast with "usage: /gaia-code-review [story-key]".
- The story file MUST exist at `docs/implementation-artifacts/{story_key}-*.md`. Use the canonical glob to resolve regardless of title slug. If zero matches, fail with "story file not found for key {story_key}".
- The story MUST be in `review` status. If not, fail with "story must be in review status before code review".
- This skill is READ-ONLY. Do NOT attempt to call Write or Edit tools — the fork context allowlist enforces this.
- The verdict in the report body uses APPROVE or REQUEST_CHANGES (internal vocabulary).
- The Review Gate row uses PASSED or FAILED (canonical vocabulary, per CLAUDE.md).
- Mapping: APPROVE maps to PASSED; REQUEST_CHANGES maps to FAILED.
- Call `review-gate.sh` to update the Review Gate row — do NOT manually edit the story file.
- Sprint-status.yaml is NEVER written by this skill (Sprint-Status Write Safety rule).

## Steps

### Step 1 -- Resolve Story File

- If no story key was provided as an argument, fail with: "usage: /gaia-code-review [story-key]"
- Resolve the story file path using the canonical glob: `docs/implementation-artifacts/{story_key}-*.md`
- If zero matches: fail with "story file not found for key {story_key} -- searched docs/implementation-artifacts/{story_key}-*.md"
- If multiple matches: fail with "multiple story files matched key {story_key} -- resolve ambiguity"
- Read the resolved story file.

### Step 2 -- Status Gate

- Parse the story file YAML frontmatter and extract the `status` field.
- If status is not `review`, fail with: "story {story_key} is in '{status}' status -- must be in 'review' status for code review"
- Extract the list of files changed from the story file's "File List" section under "Dev Agent Record".

### Step 3 -- Code Review

- For each changed file listed in the story, read the file and review for:
  - **Correctness:** Logic errors, edge cases, null/undefined handling, type safety
  - **Security:** Injection vulnerabilities, credential exposure, input validation, OWASP Top 10
  - **Performance:** Unnecessary loops, N+1 queries, missing indexes, memory leaks, large allocations
  - **Readability:** Naming conventions, function length, code duplication, comment quality
  - **Test Coverage:** Each acceptance criterion has at least one test, edge cases tested, mocking appropriate

### Step 4 -- Architecture Conformance

- Read `docs/planning-artifacts/architecture.md` and extract ADRs, component hierarchy, layer boundaries, and API patterns.
- For each changed file, verify:
  - Component placement follows the documented hierarchy
  - Dependencies flow in the correct direction per architecture
  - API patterns match the architecture specification
  - Referenced ADRs exist and have status Accepted
- Include an "Architecture Conformance" section in findings with PASS/FAIL per check.

### Step 5 -- Design Fidelity Check

- Read story file YAML frontmatter -- check if a `figma:` block exists.
- If a `figma:` block is present: compare design token references in changed code against `docs/planning-artifacts/design-system/design-tokens.json`, classify as matched/drifted/missing, and include fidelity results in findings.
- If no `figma:` block: skip fidelity check.

### Step 6 -- Generate Findings

- Categorize all issues found by severity:
  - **Critical:** Must be fixed before merge (security vulnerabilities, data loss risks, correctness bugs)
  - **Warning:** Should be fixed but not blocking (performance concerns, minor code quality issues)
  - **Suggestion:** Nice to have improvements (naming, style, documentation)

### Step 7 -- Decision

- If NO critical issues were found: verdict is **APPROVE**
- If ANY critical issues were found: verdict is **REQUEST_CHANGES**
- The verdict MUST appear as a machine-readable keyword in the report output.

### Step 8 -- Write Review Report

- Generate the review report and print it to the conversation. The report must contain:
  - Story key and title
  - Summary of files reviewed
  - Findings organized by severity (Critical, Warning, Suggestion)
  - Architecture Conformance results
  - Design Fidelity results (if applicable)
  - Machine-readable verdict line: `**Verdict: APPROVE**` or `**Verdict: REQUEST_CHANGES**`
- Save the report to `docs/implementation-artifacts/{story_key}-review.md`.

### Step 9 -- Update Review Gate

- Map the verdict to the canonical Review Gate vocabulary:
  - APPROVE maps to PASSED
  - REQUEST_CHANGES maps to FAILED
- Invoke the shared `review-gate.sh` script to update the story's Review Gate table:
  ```bash
  ${CLAUDE_PLUGIN_ROOT}/../scripts/review-gate.sh update --story "{story_key}" --gate "Code Review" --verdict "{PASSED|FAILED}"
  ```
- Confirm the update succeeded (exit code 0).
- Report the final status to the user.
- Note: sprint-status.yaml may now be out of sync. Run `/gaia-sprint-status` to reconcile.

## Finalize

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-code-review/scripts/finalize.sh
