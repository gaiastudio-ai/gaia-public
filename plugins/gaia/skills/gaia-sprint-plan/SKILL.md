---
name: gaia-sprint-plan
description: "Plan a sprint by selecting stories from the backlog, applying sizing and priority rules via the sm subagent (Nate), and committing the sprint atomically to sprint-status.yaml via sprint-state.sh. GAIA-native replacement for the legacy _gaia/lifecycle/workflows/sprint-planning/ XML engine workflow."
argument-hint: "[sprint-scope]"
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Skill]
---

## Setup

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-sprint-plan/scripts/setup.sh

## Mission

You are planning a sprint using the Nate (Scrum Master) persona. This skill reads the backlog from `docs/planning-artifacts/epics-and-stories.md`, classifies stories by readiness, applies sizing and priority rules, and commits the finalized sprint atomically to `sprint-status.yaml` via `sprint-state.sh` (E28-S11). The skill MUST NOT write to `sprint-status.yaml` directly -- all state mutations go through `sprint-state.sh`.

This skill is the native Claude Code conversion of the legacy `_gaia/lifecycle/workflows/sprint-planning/` XML engine workflow (brief Cluster 8, story E28-S60). It delegates planning reasoning to the `sm` subagent and uses `sprint-state.sh` for atomic state updates per ADR-042.

## Critical Rules

- NEVER write to `sprint-status.yaml` directly. All writes MUST go through `sprint-state.sh` (E28-S11). This is the ADR-042 contract.
- Only stories with status `ready-for-dev` and an existing individual story file are selectable for a sprint.
- Dependency blocking: a story whose `depends_on` list contains any story NOT in `done` status CANNOT be included.
- Sprint commitments respect the velocity estimate from the `sizing_map` config key, resolved via `!scripts/resolve-config.sh sizing_map` (ADR-044 §10.26.3).
- Use the sm subagent (Nate) persona for planning reasoning -- do not re-implement planning logic inline.

## Steps

### Step 1 -- Load Epics, Stories, and Previous Retro

- Read `docs/planning-artifacts/epics-and-stories.md`.
- Parse all stories with their priorities, sizes, and dependencies.
- Scan `docs/implementation-artifacts/` for individual story files matching `{story_key}-*.md`. For each file found, read its frontmatter `status` field.
- Classify stories into selectable and non-selectable:
  - **SELECTABLE:** stories with individual files AND `status: ready-for-dev`
  - **NOT SELECTABLE (no file):** "Story {key} has no individual file -- run `/gaia-create-story {key}` first."
  - **NOT SELECTABLE (wrong status):** "Story {key} is in '{status}' status -- must be `ready-for-dev` to be selectable."
- Display the classification: selectable stories table (`Key | Title | Priority | Size | Risk | Status`) and non-selectable stories with reasons.
- Load most recent `retro-{sprint_id}.md` from `docs/implementation-artifacts/` if available. If retro found: extract open action items and present them as sprint constraints.

### Step 2 -- Sprint Scoping

- Ask: Sprint duration (1 week / 2 weeks / custom)?
- Ask: Team velocity estimate (story points)?
- Ask: Sprint number (for multi-sprint tracking)?
- Resolve the `sizing_map` key via `!scripts/resolve-config.sh sizing_map` (ADR-044 §10.26.3 — the resolver transparently merges the team-shared and machine-local layers, applying the "local overrides shared" precedence). Display the canonical point values (S/M/L/XL) before selection. <!-- Shared layer: config/project-config.yaml. Local layer: global.yaml. -->

### Step 3 -- Story Selection

- Select stories for this sprint based on priority ordering (P0 > P1 > P2) and dependency topology -- only from stories classified as SELECTABLE in Step 1.
- Ensure total size fits within velocity estimate using `sizing_map` point values.
- **Dependency blocking:** for each candidate, check its `depends_on` list. If any dependency is NOT `done`, the story CANNOT be included. Display: "BLOCKED: Story {key} depends on {dep_key} (status: {dep_status})."
- **Priority surfacing:** after selection, check for P0 stories that are `ready-for-dev` but NOT selected. If any found, warn: "WARNING: P0 stories ready but not selected:" and ask user to confirm the exclusion.
- If `docs/test-artifacts/test-plan.md` exists: apply risk levels -- buffer 20% for high-risk stories.
- **ATDD check (high-risk only):** for each high-risk story, check if `docs/test-artifacts/atdd-{story_key}.md` exists. If missing: "HIGH-RISK story {key} has no ATDD file -- run `/gaia-atdd {key}` before development."
- Present the candidate sprint to the user and capture confirmation.

### Step 4 -- Update Story Files

- For each selected story with an individual file: update the `sprint_id` field to `sprint-{N}`.
- Stories remain `ready-for-dev` -- do NOT change their status. `/gaia-dev-story` transitions them to `in-progress` when work begins.

### Step 5 -- Sprint Plan Generation

- Create the sprint plan with story assignments and execution order, ordered by dependency resolution + priority.
- Generate a Sprint Burndown Estimate table: `Day | Points Remaining | Stories Completing`.
- Include: sprint goals, selected stories (ordered), velocity target, risk assessment, and a Testing Readiness section listing ONLY high-risk stories with their ATDD file status.

### Step 6 -- Commit Sprint via sprint-state.sh

- Generate `sprint-status.yaml` content with the standardized schema:
  ```yaml
  sprint_id: "sprint-{N}"
  duration: "{duration}"
  velocity_capacity: {velocity}
  total_points: {sum}
  started: "{date}"
  end_date: "{end_date}"
  stories:
    - key: "{story-key}"
      title: "{title}"
      status: "ready-for-dev"
      points: {points}
      risk_level: "{risk}"
      assignee: null
      blocked_by: null
      updated: "{date}"
  ```
- Write `sprint-status.yaml` to `docs/implementation-artifacts/sprint-status.yaml` EXCLUSIVELY via `sprint-state.sh`:
  ```bash
  ${CLAUDE_PLUGIN_ROOT}/../scripts/sprint-state.sh transition \
    --story "{story_key}" --to "ready-for-dev"
  ```
  Invoke once per selected story to register it in the sprint. If `sprint-state.sh` exits non-zero, abort cleanly and surface the error to the user. Do NOT fall back to direct YAML writes.

### Step 7 -- Save Sprint Plan Document

- Write the sprint plan document to `docs/implementation-artifacts/{sprint_id}-plan.md`.
- The document includes all sections from Step 5.

### Step 8 -- Val Validation (optional)

- If the Val subagent is available: invoke Val to validate the sprint plan. Val verifies:
  - All selected story keys exist as story files with status `ready-for-dev`
  - Dependency ordering is correct
  - Points math is correct (total <= velocity)
  - No duplicate story keys
- If Val returns findings: auto-fix and re-validate.
- If Val fails or is unavailable: log warning and continue -- validation is non-blocking for sprint planning.

### Step 9 -- NFR-048 Token Footprint Measurement

- Record the skill's token footprint for NFR-048 tracking. This measurement becomes input to the aggregate reporting under E28-S65.
- Log: skill name, step count, approximate token usage vs. the legacy XML engine invocation.

### Step 10 -- Report

- Display the finalized sprint summary: sprint ID, duration, velocity, stories selected, total points, capacity utilization.
- Suggest next step: `/gaia-dev-story {first_story_key}` to begin the first story.

## Finalize

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-sprint-plan/scripts/finalize.sh
