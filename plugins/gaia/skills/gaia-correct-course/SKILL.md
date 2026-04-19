---
name: gaia-correct-course
description: "Manage mid-sprint scope changes by updating story files (source of truth) and reconciling sprint-status.yaml via sprint-state.sh. Supports scope changes, priority shifts, blocker resolution, resource changes, and story injection. GAIA-native replacement for the legacy correct-course XML engine workflow."
argument-hint: "[story-key] [change-type]"
allowed-tools: [Read, Edit, Bash]
version: "1.0.0"
---

## Setup

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-correct-course/scripts/setup.sh

## Mission

Manage mid-sprint course corrections by applying scope changes to story files and reconciling `sprint-status.yaml` via the canonical `sprint-state.sh` helper. The story file is always the source of truth -- this skill edits story files directly and delegates all sprint-status reconciliation to `sprint-state.sh`.

This skill is the native Claude Code conversion of the legacy `_gaia/lifecycle/workflows/4-implementation/correct-course/` XML engine workflow (brief Cluster 8, story E28-S63). Follows ADR-042 (scripts-over-LLM) for state transitions via `sprint-state.sh`.

## Critical Rules

- The story file is the source of truth per CLAUDE.md Sprint-Status Write Safety. All changes start in the story file.
- NEVER write to `sprint-status.yaml` directly. NEVER modify `sprint-status.yaml` by hand or via Edit/Write tools. All sprint-status reconciliation MUST go through `sprint-state.sh`.
- New stories injected into the sprint MUST already exist in `epics-and-stories.md`. If they do not, recommend running `/gaia-add-stories` first.
- Document the reason for every course correction in the sprint plan.
- Preserve existing story data -- only modify the fields relevant to the scope change.

## Steps

### Step 1 --- Load Sprint Context

Read the current sprint context:

1. Read `${CLAUDE_PROJECT_ROOT}/docs/implementation-artifacts/sprint-status.yaml` to understand current sprint state.
2. Read `${CLAUDE_PROJECT_ROOT}/docs/planning-artifacts/epics-and-stories.md` to identify stories not yet in any sprint (candidates for injection).
3. Scan `${CLAUDE_PROJECT_ROOT}/docs/implementation-artifacts/retro-*.md` files if available -- check if the current issue matches a known pattern from past retrospectives. If a match is found, note it: "This issue was flagged in retro-{sprint_id}: {finding}. Previous recommendation: {recommendation}."

### Step 2 --- Identify Change

Ask the user: "What needs to change and why?"

Classify the change into one of these types:
- **Scope change** -- adding, removing, or modifying story scope within the sprint
- **Priority shift** -- reordering story priorities without adding/removing stories
- **Blocker resolution** -- unblocking a story by resolving a dependency or impediment
- **Resource change** -- reassigning stories due to team capacity changes
- **Story injection** -- pulling a new story into the sprint from the backlog

Ask if this is linked to a change request (CR ID).

### Step 3 --- Impact Analysis

For each affected story:

1. Identify which stories are impacted by the change.
2. Assess dependency implications -- check `depends_on` and `blocks` fields in affected story files.
3. Estimate impact on sprint timeline and velocity.
4. If story injection: verify the story exists in `epics-and-stories.md`. If not, recommend `/gaia-add-stories` first.

### Step 4 --- Propose Adjustment

Present the proposed changes:

1. Re-scope sprint: list stories to add, remove, or reprioritize.
2. If injecting stories: show velocity impact -- what must be removed to fit within capacity.
3. Propose updated timeline.
4. Get user approval for changes.

### Step 5 --- Apply Changes

For each approved change, apply it to the story file (source of truth):

1. Edit the story file to update status, tasks, acceptance criteria, or priority as needed.
2. Invoke `sprint-state.sh` to reconcile `sprint-status.yaml`:

For stories **removed** from the sprint (moved back to backlog):
```bash
PROJECT_PATH="${CLAUDE_PROJECT_ROOT}" "${CLAUDE_PLUGIN_ROOT}/scripts/sprint-state.sh" transition --story {story_key} --to backlog
```

For stories **injected** into the sprint:
```bash
PROJECT_PATH="${CLAUDE_PROJECT_ROOT}" "${CLAUDE_PLUGIN_ROOT}/scripts/sprint-state.sh" transition --story {story_key} --to {target_status}
```

For stories that **changed status** but remain in the sprint:
```bash
PROJECT_PATH="${CLAUDE_PROJECT_ROOT}" "${CLAUDE_PLUGIN_ROOT}/scripts/sprint-state.sh" transition --story {story_key} --to {new_status}
```

### Step 6 --- Log Course Correction

Format the change summary with a standard header in the sprint plan:

```
## Course Correction -- {date}
Change Type: {type} | Stories Affected: {count} | Velocity Impact: {delta} points
Reason: {reason}
CR ID: {cr_id or N/A}
```

Log the correction reason, CR ID (if applicable), and all changes made.

### Step 7 --- Suggest Next Actions

Based on the changes applied:

- If stories were injected: suggest `/gaia-dev-story {story_key}` for newly injected stories.
- If stories were removed: note that removed stories return to backlog for future sprint planning.
- If a CR was referenced: suggest checking the change request status.

## Finalize

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-correct-course/scripts/finalize.sh
