---
name: gaia-create-ux
description: Create UX design specifications through collaborative discovery with the ux-designer subagent (Christy) — Cluster 5 planning skill. Use when the user wants to produce a validated UX design document from an existing PRD, covering personas, information architecture, wireframes, interaction patterns, accessibility, and Figma integration.
context: fork
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Agent]
---

## Setup

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-create-ux/scripts/setup.sh

## Memory

!${CLAUDE_PLUGIN_ROOT}/scripts/memory-loader.sh ux-designer decision-log

## Mission

You are orchestrating the creation of a UX Design document. The UX design authoring is delegated to the **ux-designer** subagent (Christy), who conducts user research, designs information architecture, creates wireframes, and produces the final artifact. You load the PRD, validate inputs, coordinate the multi-step flow, and write the output to `docs/planning-artifacts/ux-design.md` using the carried `ux-design-assessment-template.md` for brownfield assessments.

This skill is the native Claude Code conversion of the legacy `_gaia/lifecycle/workflows/2-planning/create-ux-design` workflow (brief Cluster 5, story P5-S4 / E28-S43). The step ordering, prompts, and output path are preserved verbatim from the legacy `instructions.xml` — do not restructure, re-prompt, or reorder.

## Critical Rules

- A PRD MUST exist at `docs/planning-artifacts/prd.md` before starting. If missing, fail fast with "PRD not found at docs/planning-artifacts/prd.md — run /gaia-create-prd first."
- Every design decision must trace to a user need from the PRD.
- UX design authoring is delegated to the `ux-designer` subagent (Christy) via native Claude Code subagent invocation — do NOT inline Christy's persona into this skill body. If the ux-designer subagent (E28-S21) is not available, fail with "ux-designer subagent not available — install E28-S21" error.
- If `docs/planning-artifacts/ux-design.md` already exists, warn the user: "An existing UX design was found. Continuing will overwrite it. Confirm to proceed or abort." Do not silently overwrite.
- Template resolution: load `ux-design-assessment-template.md` from this skill directory for brownfield UX assessments. If `custom/templates/ux-design-assessment-template.md` exists and is non-empty, use the custom template instead — the custom template takes full precedence over the framework default (ADR-020 / FR-101).

## Steps

### Step 1 — Load PRD

- Read the PRD at `docs/planning-artifacts/prd.md`.
- If the file does not exist, fail fast: "PRD not found at docs/planning-artifacts/prd.md — run /gaia-create-prd first."
- Extract: user personas, user journeys, and functional requirements.
- If `docs/planning-artifacts/ux-design.md` already exists: warn "An existing UX design was found at docs/planning-artifacts/ux-design.md. Continuing will overwrite it. Confirm with user before proceeding."

> `!scripts/write-checkpoint.sh gaia-create-ux 1 project_name="$PROJECT_NAME" ux_slug="$UX_SLUG" prd_path="$PRD_PATH"`

### Step 2 — User Personas

Delegate to the **ux-designer** subagent (Christy) via `agents/ux-designer` to refine persona definitions.

- Refine persona definitions from PRD.
- Add: scenarios, goals, tech proficiency, accessibility needs.

> `!scripts/write-checkpoint.sh gaia-create-ux 2 project_name="$PROJECT_NAME" ux_slug="$UX_SLUG" prd_path="$PRD_PATH"`

### Step 3 — Information Architecture

Delegate to the **ux-designer** subagent (Christy) via `agents/ux-designer` to design information architecture.

- Design sitemap and navigation structure.
- Define content hierarchy and page relationships.
- Map each page or section to the FR IDs it serves — every page must trace to at least one FR. Flag any user-facing FR from the PRD that has no corresponding page in the sitemap.

> `!scripts/write-checkpoint.sh gaia-create-ux 3 project_name="$PROJECT_NAME" ux_slug="$UX_SLUG" prd_path="$PRD_PATH"`

### Step 4 — Wireframes

Delegate to the **ux-designer** subagent (Christy) via `agents/ux-designer` to create wireframes.

- Create text-based wireframe descriptions for key screens.
- Define layout, component placement, interaction patterns.
- Annotate each wireframe with the FR IDs it addresses. Flag any FR with user-facing behavior that has no wireframe representation.

> `!scripts/write-checkpoint.sh gaia-create-ux 4 project_name="$PROJECT_NAME" ux_slug="$UX_SLUG" prd_path="$PRD_PATH"`

### Step 5 — Interaction Patterns

Delegate to the **ux-designer** subagent (Christy) via `agents/ux-designer` to define interaction patterns.

- Define common UI patterns used across the application.
- Specify component library or design system choices.
- Document form behaviors, validation, error states.
- Map each interaction flow to the corresponding user journey from the PRD. Every PRD user journey must have a defined interaction pattern.

> `!scripts/write-checkpoint.sh gaia-create-ux 5 project_name="$PROJECT_NAME" ux_slug="$UX_SLUG" prd_path="$PRD_PATH"`

### Step 6 — Accessibility

- Define WCAG compliance targets (A, AA, AAA).
- Plan keyboard navigation, screen reader support.
- Define color contrast and text sizing standards.

> `!scripts/write-checkpoint.sh gaia-create-ux 6 project_name="$PROJECT_NAME" ux_slug="$UX_SLUG" prd_path="$PRD_PATH"`

### Step 7 — Figma MCP Detection and Mode Selection

- Probe for available Figma MCP server.
- If Figma MCP available: present mode selection — [Generate] Create Figma frames alongside ux-design.md | [Import] Import existing Figma designs (read-only) | [Skip] Text-only UX spec, no Figma integration.
- If not available: skip Figma integration — proceed with text-only UX design output. Log: "No Figma MCP server detected. Generating markdown-only ux-design.md."

> `!scripts/write-checkpoint.sh gaia-create-ux 7 project_name="$PROJECT_NAME" ux_slug="$UX_SLUG" prd_path="$PRD_PATH"`

### Step 8 — Generate Mode (if selected)

- Create UI Kit page in Figma, extract design tokens, create styles and components.
- Generate per-screen frames at 6 viewports: 280px, 375px, 600px, 768px, 1024px, 1280px.
- Set up prototype flows and asset export configuration.
- Record Figma node IDs and enhance ux-design.md with Figma metadata.

> `!scripts/write-checkpoint.sh gaia-create-ux 8 project_name="$PROJECT_NAME" ux_slug="$UX_SLUG" prd_path="$PRD_PATH"`

### Step 9 — Import Mode (if selected)

- Validate Figma file key, discover pages and frames.
- Extract design tokens in W3C DTCG format.
- Build screen inventory and component specs.
- Generate ux-design.md content from imported Figma data.

> `!scripts/write-checkpoint.sh gaia-create-ux 9 project_name="$PROJECT_NAME" ux_slug="$UX_SLUG" prd_path="$PRD_PATH"`

### Step 10 — Generate Output

Write the UX design document to `docs/planning-artifacts/ux-design.md` with: personas, information architecture, wireframe descriptions, interaction patterns, component specifications, accessibility plan, FR-to-Screen Mapping table. Include Figma metadata sections if Generate or Import mode was active.

The `ux-design-assessment-template.md` carried in this skill directory is available for brownfield UX assessments — reference it at `${CLAUDE_PLUGIN_ROOT}/skills/gaia-create-ux/ux-design-assessment-template.md`.

> `!scripts/write-checkpoint.sh gaia-create-ux 10 project_name="$PROJECT_NAME" ux_slug="$UX_SLUG" prd_path="$PRD_PATH" --paths docs/planning-artifacts/ux-design.md`

### Step 11 — Optional: Accessibility Review

- Ask if the user wants to review the UX design for WCAG 2.1 accessibility compliance.
- If yes: spawn a subagent to run the accessibility review.
- If skip: accessibility review can be run anytime later with `/gaia-review-a11y`.

> `!scripts/write-checkpoint.sh gaia-create-ux 11 project_name="$PROJECT_NAME" ux_slug="$UX_SLUG" prd_path="$PRD_PATH"`

## Finalize

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-create-ux/scripts/finalize.sh

## Next Steps

- `/gaia-review-a11y` — Review UX design for WCAG 2.1 accessibility compliance.
- `/gaia-create-arch` — If accessibility review will be done later, proceed to architecture design.
