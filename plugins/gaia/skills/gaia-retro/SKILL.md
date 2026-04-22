---
name: gaia-retro
description: "Facilitate a post-sprint retrospective capturing went-well, didn't-go-well, and action-items sections. Writes a retro artifact to docs/implementation-artifacts/. GAIA-native replacement for the legacy retrospective XML engine workflow."
argument-hint: "[sprint-id?]"
allowed-tools: [Read, Write, Bash]
version: "1.0.0"
---

## Setup

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-retro/scripts/setup.sh

## Mission

Facilitate a structured post-sprint retrospective by collecting team feedback across three sections (went well, what could improve, action items) and writing the resulting retro artifact to `docs/implementation-artifacts/`. When an optional sprint-id argument is provided (e.g., `sprint-42`), use that sprint. Otherwise, resolve the current sprint from `docs/implementation-artifacts/sprint-status.yaml`.

This skill is the native Claude Code conversion of the legacy `_gaia/lifecycle/workflows/4-implementation/retrospective/` XML engine workflow (brief Cluster 8, story E28-S64). Follows ADR-041 and the canonical SKILL.md shape from E28-S19 and E28-S53.

## Critical Rules

- NEVER overwrite an existing retro artifact. If `retrospective-{sprint_id}-{date}.md` already exists, suffix a timestamp (e.g., `retrospective-{sprint_id}-{date}-{HHMM}.md`) rather than clobber.
- Retro artifacts are write-once per sprint. Once written, they are immutable records of the team discussion.
- The skill is conversational: prompt the facilitator for each section rather than auto-generating content from sprint state. Sprint data is used to seed the discussion, not replace it.
- Read sprint-status.yaml and story files as read-only context. NEVER modify sprint-status.yaml or story files during a retro.
- Action items MUST be concrete and actionable with assigned ownership — no vague aspirations.

## Steps

### Step 1 --- Resolve Sprint ID

If a sprint-id argument was provided, use it directly.

Otherwise, read `${CLAUDE_PROJECT_ROOT}/docs/implementation-artifacts/sprint-status.yaml` and extract the current `sprint_id` from the top-level metadata.

If sprint-status.yaml is missing or unreadable, ask the user for the sprint ID.

### Step 1b --- Review Report Extraction (FR-RIM-2)

Extract verdicts and key findings from review artifacts for the resolved sprint. This produces a "data-driven findings" block that seeds Steps 3 and 4.

Invoke:

```bash
${CLAUDE_PLUGIN_ROOT}/skills/gaia-retro/scripts/review-extract.sh \
  --impl-dir "${CLAUDE_PROJECT_ROOT}/docs/implementation-artifacts" \
  --sprint-id "${sprint_id}"
```

The scanner globs `code-review-*.md`, `security-review-*.md`, `qa-tests-*.md`, and `performance-review-*.md`, filters to artifacts whose YAML frontmatter `sprint_id` matches the resolved sprint, and parses the `**Verdict:**` line from each. Malformed or truncated artifacts yield a `UNKNOWN` verdict with a `parse-warning` note (AC-EC4). When no artifacts match the current sprint, the scanner emits an explicit `no review artifacts for sprint {id}` note (AC-EC5) so prior-sprint review files do not leak into the current retro's findings.

Hold the scanner output in session memory — do NOT copy it verbatim into the final retro artifact. Surface it as context to the facilitator during Steps 3 and 4.

### Step 2 --- Load Sprint Data

Read `${CLAUDE_PROJECT_ROOT}/docs/implementation-artifacts/sprint-status.yaml` to extract:
- All story keys for the resolved sprint
- Planned points and completed points
- Story statuses (done, in-progress, review, blocked, carried over)

For each story in the sprint, read its story file from `${CLAUDE_PROJECT_ROOT}/docs/implementation-artifacts/` to extract:
- Review Gate results (PASSED/FAILED/UNVERIFIED)
- Findings table entries
- Definition of Done status

Compute sprint metrics:
- Completion rate: done / total stories
- Velocity: delivered vs planned points
- First-pass review rate: stories that passed all reviews without rework
- Blocked stories count and list
- Carryover stories list

Present the sprint data summary to the facilitator as context before starting the discussion.

### Step 3 --- What Went Well

Present data-driven positive findings from the sprint metrics:
- Stories that passed all 6 reviews on first try
- Velocity met or exceeded plan
- Stories with no review rework
- Good dependency management (no blocks or blocks resolved quickly)

Then prompt the facilitator:

> Based on the data above, what else went well this sprint? Add items, confirm the data-driven findings, or modify them.

Collect the facilitator's input and compile the final went-well list.

### Step 4 --- What Could Improve

Present data-driven improvement areas from the sprint metrics:
- Stories that failed reviews and cycled back
- Untriaged findings still in story files
- Blocked stories and their duration
- Carryover stories not completed
- Common code review feedback patterns

Then prompt the facilitator:

> Based on the data above, what else could improve? Add items, confirm the data-driven findings, or modify them.

Collect the facilitator's input and compile the final improvements list.

### Step 5 --- Action Items

For each improvement area identified in Step 4, propose a concrete action item with:
- Description of the action
- Owner (team member or role responsible)
- Target sprint for completion
- Priority (high for recurring issues, medium for new items)

Prompt the facilitator:

> Review the proposed action items. Add, remove, or modify items. Each action item needs an owner and target sprint.

Collect the facilitator's input and compile the final action items list.

### Step 5b --- Cross-Retro Pattern Detection (FR-RIM-1)

After action items are drafted in Step 5, scan prior retrospective files for recurring themes. Themes appearing in 2+ distinct sprints are flagged systemic, and their parent `action-items.yaml` entry receives an `escalation_count` increment.

Invoke:

```bash
${CLAUDE_PLUGIN_ROOT}/skills/gaia-retro/scripts/cross-retro-detect.sh \
  --retros-dir     "${CLAUDE_PROJECT_ROOT}/docs/implementation-artifacts" \
  --action-items   "${CLAUDE_PROJECT_ROOT}/docs/implementation-artifacts/action-items.yaml" \
  --current-sprint "${sprint_id}"
```

The scanner:

1. Globs `retrospective-*.md` under the retros dir.
2. Extracts action-item lines under `## Action Items` sections (or resolves `AI-{n}` references in `action-items.yaml`).
3. Normalizes each line (`lowercase(trim(text))`) and computes `SHA-256(norm)`.
4. Flags themes seen in 2+ distinct sprint IDs as systemic.
5. For each systemic theme, delegates to `action-items-increment.sh` using `(current_sprint, theme_hash)` as the idempotency key so re-running the same retro never double-increments (NFR-RIM-3).

All edge paths are non-blocking (per the story's "Failure posture"):

- No prior retros → success, zero escalations (AC3 / AC-EC9).
- Missing or unreadable `action-items.yaml` → warn on stderr, continue (AC-EC2).
- Orphan `AI-{n}` reference → log orphan, skip that item, continue (AC-EC6).
- Empty / zero-byte retro file → contributes zero themes (AC-EC9).
- Mixed-case or whitespace variants → normalize to the same hash (AC-EC10).
- 100+ prior retros → bounded per-file read (`MAX_BYTES=65536`) caps token usage (NFR-RIM-1).

> **Note (E36-S2 coupling):** the increment writer is an inline, byte-compatible stand-in for the ADR-052 shared retro writer helper delivered by E36-S2. When E36-S2 lands, replace the body of `action-items-increment.sh` with a delegation to the helper — the CLI contract stays stable, so callers in this skill do not need to change.

### Step 6 --- Write Retro Artifact

Compose the retrospective artifact with the following sections:
- Sprint metadata (sprint_id, date, velocity, completion rate)
- What Went Well (from Step 3)
- What Could Improve (from Step 4)
- Action Items (from Step 5)

Determine the output file path:
- Default: `${CLAUDE_PROJECT_ROOT}/docs/implementation-artifacts/retrospective-{sprint_id}-{YYYY-MM-DD}.md`
- If that file already exists: use `retrospective-{sprint_id}-{YYYY-MM-DD}-{HHMM}.md` to avoid clobbering

Write the artifact to the determined path.

Report the output path to the facilitator.

## Finalize

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-retro/scripts/finalize.sh
