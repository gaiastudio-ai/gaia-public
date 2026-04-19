---
name: gaia-sprint-status
description: "Display the current sprint status dashboard. Delegates rendering to the sprint-status-dashboard.sh formatter script, which reads sprint-status.yaml and produces a deterministic plain-text dashboard. GAIA-native replacement for the legacy sprint-status XML engine workflow."
allowed-tools: [Bash, Read]
version: "1.0.0"
---

## Setup

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-sprint-status/scripts/setup.sh

## Mission

Display the current sprint status by invoking the deterministic `sprint-status-dashboard.sh` formatter script. This skill is read-only with respect to `sprint-status.yaml` — it NEVER writes to or modifies the sprint status file under any code path, per CLAUDE.md Sprint-Status Write Safety.

This skill is the native Claude Code conversion of the legacy `_gaia/lifecycle/workflows/4-implementation/sprint-status/` XML engine workflow (brief Cluster 8, story E28-S61). Nearly all work is delegated to the bash formatter script per ADR-042 (scripts-over-LLM).

## Critical Rules

- NEVER write to `sprint-status.yaml`. This skill is strictly read-only with respect to sprint state.
- All dashboard rendering is performed by `sprint-status-dashboard.sh` — do NOT implement formatting logic in the LLM layer.
- If the formatter script exits non-zero, surface the error message to the user and stop. Do NOT attempt to render the dashboard manually.

## Steps

### Step 1 — Run Dashboard Formatter

Run the sprint-status-dashboard.sh formatter script:

```bash
PROJECT_PATH="${CLAUDE_PROJECT_ROOT}" "${CLAUDE_PLUGIN_ROOT}/scripts/sprint-status-dashboard.sh"
```

If the script exits 0, present its stdout output to the user verbatim — do not reformat, filter, or enhance the dashboard output. The script produces the canonical dashboard rendering.

If the script exits non-zero, display the error output and inform the user:
- Exit 1 with "not found": `sprint-status.yaml` does not exist. Suggest running `/gaia-sprint-plan` first.
- Exit 1 with "malformed": the YAML file is corrupt. Suggest running `/gaia-sprint-status` after fixing the file.

### Step 2 — Suggest Next Actions

Based on the dashboard output, suggest relevant next actions:

- If stories are in `ready-for-dev`: suggest `/gaia-dev-story {story_key}` for the highest-priority story.
- If stories are in `review`: suggest `/gaia-run-all-reviews {story_key}` for stories awaiting review.
- If stories are `blocked`: note the blocking dependency.
- If all stories are `done`: suggest `/gaia-retro` for a sprint retrospective.

## Finalize

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-sprint-status/scripts/finalize.sh
