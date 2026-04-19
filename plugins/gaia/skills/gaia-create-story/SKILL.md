---
name: gaia-create-story
description: Create a detailed story file from epics-and-stories.md with full frontmatter, acceptance criteria, and sprint-state registration. Cluster 7 architecture skill.
argument-hint: [story-key]
tools: Read, Write, Edit, Bash
---

## Setup

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-create-story/scripts/setup.sh

## Mission

You are creating a detailed story file for the specified story key. The story definition is extracted from `docs/planning-artifacts/epics-and-stories.md` and elaborated with architecture context, acceptance criteria in Given/When/Then format, tasks/subtasks, test scenarios, and dependencies. The story file is written to `docs/implementation-artifacts/{story_key}-{slug}.md` using the canonical filename convention.

This skill is the native Claude Code conversion of the legacy create-story workflow (brief Cluster 7, story E28-S52). The step ordering, prompts, and output path are preserved from the legacy instructions.

## Critical Rules

- An epics-and-stories document MUST exist at `docs/planning-artifacts/epics-and-stories.md` before starting. If missing, fail fast with "epics-and-stories.md not found at docs/planning-artifacts/epics-and-stories.md -- run /gaia-create-epics first."
- Story files MUST include complete YAML frontmatter with ALL 15 required fields: key, title, epic, status, priority, size, points, risk, sprint_id, depends_on, blocks, traces_to, date, author, priority_flag. Optional fields: origin, origin_ref, figma.
- All acceptance criteria MUST use Given/When/Then format: "Given {context}, when {action}, then {expected result}".
- The story file MUST be written to `docs/implementation-artifacts/{story_key}-{slug}.md` using the canonical `{story_key}-{story_title_slug}.md` filename convention.
- Slug generation: lowercase the title, replace non-alphanumeric characters with hyphens, collapse consecutive hyphens, trim leading/trailing hyphens.
- The story template is bundled at `${CLAUDE_PLUGIN_ROOT}/skills/gaia-create-story/story-template.md`. Do NOT take a runtime dependency on the `_gaia/` framework tree.
- After writing the story file, call `scripts/update-story-status.sh` to register the story with `status=backlog` in `sprint-status.yaml`.
- The `sprint-status.yaml` MUST be re-read immediately before writing (Sprint-Status Write Safety rule).
- If a story file already exists for this key with status other than `backlog`, HALT with guidance to use /gaia-fix-story.
- The priority_flag field accepts only `null` (default) or `"next-sprint"` as valid values.

## Steps

### Step 1 -- Select Story

- If a story key was provided as an argument (e.g., `/gaia-create-story E1-S2`), use it directly.
- Read `docs/planning-artifacts/epics-and-stories.md` and locate the story by key.
- Scan `docs/implementation-artifacts/` for existing story files matching `{story_key}-*.md`.
- If a story file already exists:
  - Read its YAML frontmatter status field.
  - If status is `backlog`: warn "Story file exists with status backlog. Proceeding will regenerate it." Allow continue.
  - If status is anything else: HALT -- "Story {key} is in '{status}' status. Use /gaia-fix-story {key} to edit."
- If no story key was provided: display a prioritized list of stories without files and ask the user to select.

### Step 2 -- Load Context

- Read story summary from `docs/planning-artifacts/epics-and-stories.md`.
- Read `docs/planning-artifacts/architecture.md` for technical context (ADRs live inline in the Decision Log table).
- Read `docs/planning-artifacts/ux-design.md` if available for UI context.

### Step 3 -- Elaborate Story

- Present a brief summary of what was loaded.
- Ask the user how to elaborate (manual answers or auto-delegation to PM/Architect subagents).
- Gather edge cases, implementation preferences, constraints, and additional context.

### Step 4 -- Generate Story File

- Load the bundled story template from `${CLAUDE_PLUGIN_ROOT}/skills/gaia-create-story/story-template.md`.
- Generate the slug from the story title: lowercase, replace non-alphanumeric with hyphens, collapse consecutive hyphens, trim edges.
- Populate ALL 15 required frontmatter fields from the epics-and-stories source data.
- Set `status: backlog` in frontmatter.
- Write acceptance criteria in Given/When/Then format.
- Write tasks/subtasks breakdown.
- Write test scenarios table.
- Write the story file to `docs/implementation-artifacts/{story_key}-{slug}.md`.

### Step 5 -- Register in Sprint Status

- Call `scripts/update-story-status.sh {story_key} backlog` to register the story in `sprint-status.yaml`.
- This MUST happen AFTER the story file write has succeeded (story file is source of truth).

### Step 6 -- Validation

- Verify the written story file has all 15 required frontmatter fields.
- Verify all acceptance criteria use Given/When/Then format.
- Verify the filename matches the canonical `{story_key}-{slug}.md` pattern.

## Finalize

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-create-story/scripts/finalize.sh
