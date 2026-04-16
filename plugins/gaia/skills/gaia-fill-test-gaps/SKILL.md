---
name: gaia-fill-test-gaps
description: Read gap report, triage by severity and story, propose remediation actions. Use when "fill test gaps" or /gaia-fill-test-gaps.
argument-hint: "[--severity critical|high|medium|all]"
allowed-tools: Read Grep Glob Bash Write Edit
---

## Setup

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-fill-test-gaps/scripts/setup.sh

## Mission

You are performing gap remediation triage. You read the latest gap analysis report produced by `/gaia-test-gap-analysis`, filter gaps by severity, group them by story, propose remediation actions using the rule table from `scripts/lib/gap-triage-rules.js` (ADR-039 section 10.22.8.2), present a triage table for user approval, execute approved actions via bundled sub-workflow invocations, and emit a remediation report.

This skill is the native Claude Code conversion of the legacy `_gaia/testing/workflows/fill-test-gaps` workflow (Cluster 11, story E28-S84, ADR-042). It follows the canonical skill pattern established by E28-S66 (code-review).

**Write context:** This skill does NOT use `context: fork` because it needs to write the remediation report and invoke sub-workflows that modify project files. It uses `allowed-tools: Read Grep Glob Bash Write Edit` for full read-write access.

**Sub-workflow dispatch:** Approved remediation actions are dispatched to bundled sub-workflows (`/gaia-add-stories`, `/gaia-triage-findings`, `/gaia-test-automate`) via subagent invocations with `mode=yolo`. The ADR-037 return adapter (`scripts/lib/adr037-return-adapter.js`) normalizes sub-workflow returns.

## Critical Rules

- A gap analysis report MUST exist at `docs/test-artifacts/test-gap-analysis-*.md`. If none found, fail fast with "No gap analysis report found -- run `/gaia-test-gap-analysis` first" (AC-EC3).
- If gap report frontmatter contains malformed YAML, fail with a descriptive parse error message (AC-EC2).
- Action proposal rules MUST be applied from `scripts/lib/gap-triage-rules.js` -- the single source of truth for the ADR-039 section 10.22.8.2 rule table.
- Logs-and-continues error handling: a single sub-workflow failure MUST NOT halt the parent skill (FR-314).
- Retry-only-failed semantics: consult the most recent prior remediation report (within 24 hours) and skip rows that previously succeeded (AC6/AC7 from legacy workflow).
- Gap rows referencing story keys that no longer have story files are marked `skip` with reason `story_not_found` (AC-EC4).
- Sprint-status.yaml is NEVER written by this skill (Sprint-Status Write Safety rule).

## Steps

### Step 1 -- Load Gap Report

- Glob `docs/test-artifacts/test-gap-analysis-*.md` to find all gap analysis reports.
- Sort glob results deterministically (lexicographic on filename).
- For each matched file, parse the YAML frontmatter and extract the `date` field.
- If a file has missing or malformed frontmatter, HALT with error: "Parse error in {filepath} -- malformed or missing frontmatter. Fix the file or regenerate with /gaia-test-gap-analysis" (AC-EC2).
- Select the file with the most recent `date` value.
- If zero files match the glob, HALT with: "No gap analysis report found -- run `/gaia-test-gap-analysis` first" (AC-EC3).
- Parse the selected report's markdown body to extract gap table rows (story_key, gap_type, severity, description).

### Step 2 -- Severity Filter

- Default severity filter: `critical + high`.
- If `--severity` argument provided, apply the requested filter.
- Apply the filter to the gap list.
- If 0 gaps remain after filtering: continue with an empty list -- the triage table renders with "No gaps match the selected severity filter".
- If filtered gap count exceeds 50: record INFO note "Report size {N} exceeds 50-gap perf budget -- expect >30s runtime".

### Step 3 -- Group by Story Key

- Build a triage map from the filtered gap list, keyed by `story_key`.
- Each row: `story_key`, `gap_count`, `gap_types` (deduplicated), `proposed_action` (empty), `status` (pending).
- Sort deterministically by `story_key` (lexicographic ascending).
- **Retry-only-failed preload (AC6/AC7):** Import `loadPrior` from `scripts/lib/prior-remediation-loader.js`. Call `loadPrior` with the selected gap report path and test artifacts directory. If a non-null prior is returned, mark previously-succeeded rows as `skip_prior_success`.

### Step 4 -- Action Proposal

- For each triage row, resolve the story's current status from the story file frontmatter (source of truth). If story file not found, mark row as `skip` with reason `story_not_found` (AC-EC4).
- Import and invoke `proposeAction` from `scripts/lib/gap-triage-rules.js` for each gap.
- The rule table (ADR-039 section 10.22.8.2):
  - `uncovered-ac` + `backlog/ready-for-dev` -> action: `append_ac`, sub_workflow: `/gaia-add-stories`
  - `missing-test` + `done` -> action: `new_story`, sub_workflow: `/gaia-triage-findings`
  - `missing-edge-case` + `backlog/ready-for-dev` -> action: `append_edge_case`, sub_workflow: `/gaia-add-stories`
  - `unexecuted` + any status -> action: `expand_automation`, sub_workflow: `/gaia-test-automate`
  - any gap + `in-progress/review/blocked` -> action: `skip`, skip_reason: "story is {status} -- defer remediation"
  - unknown `gap_type` -> action: `skip`, skip_reason: `unknown_gap_type`

### Step 5 -- Triage Table Output

- Render the triage map as a markdown table: `story_key | gap_count | gap_types | proposed_action | sub_workflow | status | skip_reason`.
- Add header with: report source file, date, severity filter, total gaps, filtered gaps.
- Save to `docs/test-artifacts/fill-test-gaps-triage-{date}.md`.

### Step 6 -- Execute Approved Actions

- Import `normalizeReturn` from `scripts/lib/adr037-return-adapter.js`.
- For each approved triage row:
  - If `skip` or `skip_prior_success`: record as skipped and continue.
  - Resolve bundled ref (strip "/gaia-" prefix). Validate against allowed refs: `add-stories`, `triage-findings`, `test-automate`.
  - Invoke sub-workflow via subagent with `mode=yolo`.
  - Normalize return via `normalizeReturn`. Branch on status: `ok` -> succeeded, `error`/`halted`/`needs_user` -> failed (logs-and-continues).
- Log execution summary: "{succeeded} succeeded, {failed} failed, {skipped} skipped".

### Step 7 -- Emit Remediation Report

- Import `writeReport` from `scripts/lib/gap-remediation-report-writer.js`.
- Call `writeReport` with tracking map, source gap report path, output directory, and execution date.
- Output: `docs/test-artifacts/gap-remediation-report-{date}.md` with frontmatter (source_gap_report, execution_date, total_actions, succeeded, failed, skipped) and per-action detail table per architecture section 10.22.8.3.
- If `writeReport` throws, HALT with error -- the report must always be written for retry-only-failed semantics.

## Finalize

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-fill-test-gaps/scripts/finalize.sh
