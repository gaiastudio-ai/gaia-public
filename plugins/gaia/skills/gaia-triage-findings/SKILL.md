---
name: gaia-triage-findings
description: "Scan in-progress and completed story files for development findings and triage each into a new backlog story, an existing story, or dismiss. Produces new story files with complete frontmatter (15 required fields, status: backlog, sprint_id: null). Source story findings tables stay intact for idempotent re-triage. Done-story guard (FR-FITP-1) blocks ADD TO EXISTING mutations against status: done targets with an explicit override path recorded for retrospective review. GAIA-native replacement for the legacy triage-findings XML engine workflow."
argument-hint: "[story-key?] [--override-done-story --user <u> --date <d> --finding <fid> --reason <r>]"
allowed-tools: [Read, Write, Bash]
version: "1.1.0"
---

## Setup

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-triage-findings/scripts/setup.sh

## Mission

Scan story files in `docs/implementation-artifacts/` for populated Findings tables and triage each finding into actionable backlog stories. New story files are created with complete frontmatter (all 15 required fields populated, `status: backlog`, `sprint_id: null`). The source story's findings table stays intact so re-triage is idempotent-friendly (dedup by source story key + finding text if re-run).

This skill is the native Claude Code conversion of the legacy `_gaia/lifecycle/workflows/4-implementation/triage-findings/` XML engine workflow (brief Cluster 8, story E28-S63). Follows ADR-042 (scripts-over-LLM) where applicable.

## Critical Rules

- Every finding MUST be triaged -- none may be left unprocessed.
- New stories created from findings MUST have `status: backlog` and `sprint_id: null`.
- The source story findings table MUST never be mutated or deleted. Triage markers (`[TRIAGED]`, `[DISMISSED]`) are appended to the finding text -- the original finding row stays intact.
- Do not modify the source story file beyond appending triage markers to the Findings table.
- New story keys MUST use the next sequential number in the epic -- scan existing stories to determine the last key. NEVER reuse an existing key.
- New triaged stories MUST NOT be added to `sprint-status.yaml` -- they are backlog items assigned to sprints via `/gaia-sprint-plan` or injected via `/gaia-correct-course`.
- New stories MUST be appended to `epics-and-stories.md` under the correct epic.
- New backlog story files MUST use the canonical filename format `{story_key}-{story_title_slug}.md`.
- All 15 required frontmatter fields must be populated: `template`, `version`, `used_by`, `key`, `title`, `epic`, `status`, `priority`, `size`, `points`, `risk`, `sprint_id`, `date`, `author`, and at minimum one of `depends_on`/`blocks`/`traces_to` (can be empty arrays).
- **Done-Story Immutability Guard (FR-FITP-1):** Before any ADD TO EXISTING mutation, MUST invoke `scripts/triage-guard.sh check <target_story>`. If the target story has `status: done`, the guard halts with guidance to route through `/gaia-create-story` (new story) or `/gaia-add-feature` (change request) — zero writes to the done story. An explicit override path exists (`--override-done-story` with user, date, finding ID, reason) that records the override in the triage report with `retro_flag: true` so `/gaia-retro` surfaces it. Done stories are immutable institutional artifacts; silent mutation merges retro-blind regressions back into closed work.

## Steps

### Step 1 --- Scan for Findings

Scan story files in `${CLAUDE_PROJECT_ROOT}/docs/implementation-artifacts/` for non-empty Findings tables.

1. Read all `.md` files matching `E*-S*-*.md` in the implementation artifacts directory.
2. For each file, look for the `## Findings` section and parse the markdown table.
3. Skip findings already marked as `[TRIAGED]` or `[DISMISSED]`.
4. If an optional `story-key` argument was provided, scan only that story file.
5. If no untriaged findings are found: inform user "No findings to triage" and stop.

Collect all findings from ALL story files regardless of status -- scan every `.md` file that has a non-empty Findings table. This ensures triage catches findings from stories in any status.

### Step 2 --- Present Findings

Group findings by severity (critical first, then high, medium, low).

For each finding, show:
- Source story key
- Type (bug, tech-debt, enhancement, missing-setup, documentation)
- Severity (critical, high, medium, low)
- Description
- Suggested action

### Step 3 --- Triage Each Finding

For each finding, generate a triage recommendation based on:

- **Severity:** CRITICAL or HIGH findings -> recommend CREATE STORY
- **Type:** `bug` and `tech-debt` -> recommend CREATE STORY; `enhancement` -> consider ADD TO EXISTING
- **Scope:** If the finding is closely related to an existing backlog story -> recommend ADD TO EXISTING
- **Relevance:** If the finding is no longer applicable -> recommend DISMISS

For each CREATE STORY recommendation, also recommend timing:
- **CRITICAL** -> **NOW**: Inject into current sprint via `/gaia-correct-course`
- **HIGH** -> **NEXT SPRINT**: Flag as P0 for `/gaia-sprint-plan`
- **MEDIUM** -> **BACKLOG**: Standard priority P1
- **LOW** -> **BACKLOG**: Standard priority P2

Present recommendations and let the user confirm or override each decision:
- **CREATE STORY** -- generate a new backlog story file
- **ADD TO EXISTING** -- append finding to an existing story's tasks
- **DISMISS** -- finding is not actionable or already resolved

### Step 3b --- Done-Story Guard (ADD TO EXISTING only, FR-FITP-1)

For every finding classified as **ADD TO EXISTING**, BEFORE any mutation of the target story, invoke the done-story guard:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/triage-guard.sh check "${target_story_file}"
```

Interpret the exit code:

- **Exit 0** — target status is `in-progress`, `review`, `ready-for-dev`, `validating`, or `backlog`. Proceed with the ADD TO EXISTING mutation (append finding to the target story's tasks).
- **Exit 2** — target is `status: done`. The guard emits halt guidance on stdout (story key, sprint ID, retrospective linkage, sanctioned redirects). Present the guidance to the user. Do NOT mutate the target story. Two sanctioned paths:
  - **Recommended:** re-classify the finding as CREATE STORY (routes through `/gaia-create-story` with `origin: triage-findings`).
  - **Change request:** open `/gaia-add-feature` if the finding implies a spec-level amendment.
- **Exit 1** — error reading the target story file. Surface the stderr and halt the classification pathway for that finding.

**Override path (rare, audited):** If the user explicitly requests the override, re-invoke the guard with all override arguments:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/triage-guard.sh check \
  --override \
  --user "${USER}" \
  --date "$(date -u +%Y-%m-%d)" \
  --finding "${finding_id}" \
  --reason "${user_supplied_reason}" \
  --report "${CLAUDE_PROJECT_ROOT}/docs/implementation-artifacts/triage-report.md" \
  "${target_story_file}"
```

The guard exits 0 and appends an override record to the triage report under a `## Done-Story Guard Overrides` section:

```yaml
- user: "<user>"
  date: "<YYYY-MM-DD>"
  finding_id: "<finding_id>"
  target_story_key: "<E*-S*>"
  reason: "<free-text>"
  retro_flag: true
```

`retro_flag: true` ensures `/gaia-retro` surfaces the override for retrospective review. Proceed with the ADD TO EXISTING mutation only after the guard exits 0.

**Non-mutation invariant:** on the guard-fired path (no override), zero writes to the target story file, zero writes to `sprint-status.yaml`, zero writes to `action-items.yaml` (action-items writes land in E39-S3).

### Step 4 --- Create Backlog Stories

For each CREATE STORY decision:

1. Determine the correct epic from the source story's `epic` field.
2. Scan `${CLAUDE_PROJECT_ROOT}/docs/planning-artifacts/epics-and-stories.md` and `${CLAUDE_PROJECT_ROOT}/docs/implementation-artifacts/` for all existing stories in that epic.
3. Find the highest story number and assign the next sequential key.
4. Update `epics-and-stories.md` with the new story entry under the correct epic.
5. Create the new story file at `${CLAUDE_PROJECT_ROOT}/docs/implementation-artifacts/{story_key}-{slug}.md` with complete frontmatter:

```yaml
template: 'story'
version: 1.4.0
used_by: ['create-story']
key: "{new_story_key}"
title: "{title_from_finding}"
epic: "{source_epic}"
status: backlog
priority: "{P0|P1|P2}"
size: "{estimated_size}"
points: {estimated_points}
risk: "{risk_level}"
sprint_id: null
date: "{today}"
author: "Triage"
depends_on: []
blocks: []
traces_to: []
```

Set `origin: triage` and `origin_ref` to the source story file path for traceability.

### Step 5 --- Mark Findings as Triaged

In each source story's Findings table, append triage markers to processed findings:

- CREATE STORY: append `[TRIAGED -> {new_story_key}]` to the Finding column
- ADD TO EXISTING: append `[TRIAGED -> {existing_story_key}]` to the Finding column
- DISMISS: append `[DISMISSED]` to the Finding column

### Step 6 --- Summary and Recommendations

Present the triage summary:
- Total findings processed
- Stories created (with keys and priorities)
- Items added to existing stories
- Items dismissed

Confirm: "epics-and-stories.md updated with {N} new stories under their respective epics."

If any stories were marked as NOW (inject into current sprint):
- Suggest running `/gaia-correct-course` to inject them.

If any stories were marked as NEXT SPRINT (P0):
- Note they will be prioritized in `/gaia-sprint-plan`.

## Finalize

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-triage-findings/scripts/finalize.sh
