---
name: gaia-validate-story
description: Full story validation with factual verification via Val subagent. Invokes the validator in an isolated forked context and records the outcome via review-gate.sh using canonical PASSED/FAILED/UNVERIFIED vocabulary.
argument-hint: "[story-key]"
context: fork
allowed-tools: [Read, Grep, Glob, Bash]
---

## Setup

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-validate-story/scripts/setup.sh

## Mission

You are validating a story file against the codebase and ground truth using the Val (validator) subagent. The story file is resolved by `{story_key}` via the canonical glob `{story_key}-*.md` in `docs/implementation-artifacts/`. The validation runs in an isolated (forked) context so the parent session state does not contaminate the validator's findings.

This skill is the native Claude Code conversion of the legacy validate-story workflow (brief Cluster 7, story E28-S54). It invokes Val as a subagent with `context: fork` for isolated validation and records the outcome via `review-gate.sh` (E28-S14).

## Critical Rules

- A story key argument MUST be provided. If missing, fail fast with "usage: /gaia-validate-story [story-key]".
- The story file MUST exist at `docs/implementation-artifacts/{story_key}-*.md`. Use the canonical glob to resolve regardless of title slug. If zero matches, fail before invoking Val with "story file not found for key {story_key}".
- The Val (validator) subagent definition MUST be available. If the subagent cannot start, record `UNVERIFIED` via `review-gate.sh` and exit non-zero with a clear error.
- Validation outcome MUST be recorded via `review-gate.sh` (E28-S14) — NEVER write to the Review Gate table directly.
- Only canonical verdict values are permitted: `PASSED`, `FAILED`, or `UNVERIFIED`. No other values.
- The subagent invocation MUST use `context: fork` for isolated validation context.

## Steps

### Step 1 -- Resolve Story File

- If no story key was provided as an argument, fail with: "usage: /gaia-validate-story [story-key]"
- Resolve the story file path using the canonical glob: `docs/implementation-artifacts/{story_key}-*.md`
- If zero matches: fail with "story file not found for key {story_key} -- searched docs/implementation-artifacts/{story_key}-*.md"
- If multiple matches: fail with "multiple story files matched key {story_key} -- resolve ambiguity"
- Read the resolved story file and confirm it has a `## Review Gate` section.

### Step 2 -- Invoke Val Subagent

- Invoke the Val (validator) subagent with the following parameters:
  - `artifact_path`: the resolved story file path from Step 1
  - `source_workflow`: `gaia-validate-story`
- The subagent runs under `context: fork` so the parent conversation state is not leaked into the validator.
- If the subagent fails to start (definition missing, timeout, or crash): set verdict to `UNVERIFIED`, log the error, and proceed to Step 3.
- Parse the subagent's structured response:
  - Extract the findings list (CRITICAL, WARNING, INFO)
  - Extract the overall verdict (pass/fail)
  - Map the verdict: zero CRITICAL/WARNING findings = `PASSED`, any CRITICAL/WARNING = `FAILED`, subagent error = `UNVERIFIED`

### Step 3 -- Record Outcome via review-gate.sh

- Call `review-gate.sh` to update the Review Gate table in the story file:
  ```bash
  ${CLAUDE_PLUGIN_ROOT}/scripts/review-gate.sh update \
    --story "{story_key}" \
    --gate "Code Review" \
    --verdict "{verdict}"
  ```
  Note: The gate name used depends on which review this skill maps to. For story validation, this is invoked by the review orchestrator which specifies the appropriate gate.
- The `review-gate.sh` script enforces canonical vocabulary (`PASSED`/`FAILED`/`UNVERIFIED`) and handles atomic file writes.
- Verify the written value by running:
  ```bash
  ${CLAUDE_PLUGIN_ROOT}/scripts/review-gate.sh status --story "{story_key}"
  ```

### Step 4 -- Report Results

- If verdict is `PASSED`: report "Story {story_key} validation PASSED -- no critical or warning findings."
- If verdict is `FAILED`: report "Story {story_key} validation FAILED" and list each CRITICAL/WARNING finding with its description and location.
- If verdict is `UNVERIFIED`: report "Story {story_key} validation UNVERIFIED -- Val subagent was unavailable: {reason}."
- Exit with code 0 for PASSED, non-zero for FAILED or UNVERIFIED.

## Finalize

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-validate-story/scripts/finalize.sh
