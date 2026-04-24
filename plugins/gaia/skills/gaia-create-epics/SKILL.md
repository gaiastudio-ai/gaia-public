---
name: gaia-create-epics
description: Break requirements into epics and user stories through collaborative discovery with the architect (Theo) and pm (Derek) subagents — Cluster 6 architecture skill. Use when the user wants to decompose a PRD and architecture into implementation-ready epics and stories with dependency topology, risk levels from the test plan, and priority ordering.
context: fork
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Agent]
---

## Setup

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-create-epics/scripts/setup.sh

## Memory

!${CLAUDE_PLUGIN_ROOT}/scripts/memory-loader.sh architect all
!${CLAUDE_PLUGIN_ROOT}/scripts/memory-loader.sh pm all

## Mission

You are orchestrating the creation of an Epics and Stories document. The epic definition and story breakdown are delegated to the **architect** subagent (Theo) for technical decomposition and the **pm** subagent (Derek) for business prioritization and user story authoring. You load the PRD, architecture, test plan, and optional UX design, validate inputs, coordinate the multi-step flow, and write the output to `docs/planning-artifacts/epics-and-stories.md`.

This skill is the native Claude Code conversion of the legacy `_gaia/lifecycle/workflows/3-solutioning/create-epics-stories` workflow (brief Cluster 6, story P6-S3 / E28-S47). The step ordering, prompts, and output path are preserved verbatim from the legacy `instructions.xml` — do not restructure, re-prompt, or reorder.

## Critical Rules

- A PRD MUST exist at `docs/planning-artifacts/prd.md` before starting. If missing, fail fast with "PRD not found at docs/planning-artifacts/prd.md — run /gaia-create-prd first."
- An architecture document MUST exist at `docs/planning-artifacts/architecture.md` before starting. If missing, fail fast with "Architecture not found at docs/planning-artifacts/architecture.md — run /gaia-create-arch first."
- The architecture document MUST contain a "## Review Findings Incorporated" section. If missing, fail fast with "Architecture review findings not found — run /gaia-create-arch first to complete adversarial review and architecture refinement."
- A test plan MUST exist at `docs/test-artifacts/test-plan.md` before starting. This is an **enforced** quality gate (ADR-042), not advisory. The gate is checked by `scripts/setup.sh` via `validate-gate.sh test_plan_exists`. If missing, HALT with "test-plan.md not found — run /gaia-test-design first." The file must be non-empty — a zero-byte file is treated as missing.
- Epic definition and technical decomposition are delegated to the `architect` subagent (Theo) via native Claude Code subagent invocation — do NOT inline Theo's persona into this skill body. If the architect subagent (E28-S21) is not available, fail with "architect subagent not available — install E28-S21" error.
- Story authoring and business prioritization are delegated to the `pm` subagent (Derek) via native Claude Code subagent invocation — do NOT inline Derek's persona into this skill body. If the pm subagent (E28-S21) is not available, fail with "pm subagent not available — install E28-S21" error.
- If either the `architect` or `pm` subagent is not registered, surface a clear subagent-missing error rather than silently falling back to inline persona content.
- If `docs/planning-artifacts/epics-and-stories.md` already exists, warn the user: "An existing epics-and-stories document was found. Continuing will overwrite it. Confirm to proceed or abort." Do not silently overwrite.
- Every story must have `depends_on` and `blocks` declarations — no circular dependencies.
- Stories must be ordered by dependency topology first, then business priority.

## Steps

### Step 1 — Load Upstream Artifacts

- Read `docs/planning-artifacts/prd.md` — extract functional requirements.
- GATE: verify prd.md exists. If missing, HALT — run /gaia-create-prd first.
- Read `docs/planning-artifacts/architecture.md` — extract technical components.
- GATE: verify architecture.md contains a "## Review Findings Incorporated" section. If missing, HALT — run /gaia-create-arch first to complete adversarial review and architecture refinement.
- Read `docs/test-artifacts/test-plan.md` — extract risk assessment (high-risk areas: revenue-critical, security-sensitive, complex logic). This file was already validated by `scripts/setup.sh` via the enforced quality gate.
- Read `docs/planning-artifacts/ux-design.md` if available — extract UI flows, component hierarchy, interaction patterns, and accessibility requirements. Set `has_ux_design` flag.

> `!scripts/write-checkpoint.sh gaia-create-epics 1 project_name="$PROJECT_NAME" prd_version="$PRD_VERSION" architecture_version="$ARCHITECTURE_VERSION"`

### Step 2 — Detect Mode

- Check `docs/planning-artifacts/prd.md` header for "Mode: Brownfield".
- If brownfield mode detected: set mode to brownfield. Stories must cover gap requirements ONLY — do NOT create stories for existing implemented features.
- If no brownfield header: set mode to greenfield. Create stories for all features from the PRD.

> `!scripts/write-checkpoint.sh gaia-create-epics 2 project_name="$PROJECT_NAME" prd_version="$PRD_VERSION" epics_mode="$EPICS_MODE"`

### Step 3 — Define Epics

Delegate to the **architect** subagent (Theo) via `agents/architect` to define epics.

- Group related features into logical epics.
- Each epic: name, description, goal, success criteria.
- Brownfield: epics should focus on gap closure — not existing functionality.

> `!scripts/write-checkpoint.sh gaia-create-epics 3 project_name="$PROJECT_NAME" prd_version="$PRD_VERSION" epic_count="$EPIC_COUNT"`

### Step 4 — Break Into Stories

Delegate to the **pm** subagent (Derek) via `agents/pm` to author user stories.

- For each epic, create user stories.
- Each story needs: title, description, acceptance criteria, size estimate (S/M/L/XL).
- Use format: "As a [user], I want to [action] so that [benefit]".
- Brownfield: stories must trace to PRD gap requirement IDs. Do NOT create stories for existing implemented features.
- If `has_ux_design`: frontend stories MUST reference specific UX flows, components, and interaction patterns from ux-design.md. Include relevant screen names, navigation paths, and accessibility requirements in acceptance criteria.

> `!scripts/write-checkpoint.sh gaia-create-epics 4 project_name="$PROJECT_NAME" prd_version="$PRD_VERSION" epic_count="$EPIC_COUNT" story_count="$STORY_COUNT"`

### Step 5 — Apply Test-Plan Risk Levels

- Read risk assessment from the test plan loaded in Step 1.
- For each story: if it touches a high-risk component, set risk_level: high. Otherwise medium or low.
- High-risk stories: add to Dev Notes: "Risk: HIGH — run /gaia-atdd before /gaia-dev-story".

> `!scripts/write-checkpoint.sh gaia-create-epics 5 project_name="$PROJECT_NAME" prd_version="$PRD_VERSION" story_count="$STORY_COUNT" high_risk_count="$HIGH_RISK_COUNT"`

### Step 6 — Declare Dependencies

Delegate to the **architect** subagent (Theo) via `agents/architect` to determine dependency topology.

- For each story, declare depends_on: [story-ids] and blocks: [story-ids].
- Ensure no circular dependencies.

> `!scripts/write-checkpoint.sh gaia-create-epics 6 project_name="$PROJECT_NAME" prd_version="$PRD_VERSION" story_count="$STORY_COUNT" deps_declared="$DEPS_DECLARED"`

### Step 7 — Priority Ordering

Delegate to the **pm** subagent (Derek) via `agents/pm` to set business priority.

- Sort stories by: dependency topology first, then business priority.
- Assign priority: P0 (must-have), P1 (should-have), P2 (nice-to-have).

> `!scripts/write-checkpoint.sh gaia-create-epics 7 project_name="$PROJECT_NAME" prd_version="$PRD_VERSION" story_count="$STORY_COUNT" priority_assigned="$PRIORITY_ASSIGNED"`

### Step 8 — Generate Output

Write the epics and stories document to `docs/planning-artifacts/epics-and-stories.md`. Each story formatted as:

```
### Story {epic-N}-{story-N}: {Title}
- Epic: {epic name}
- Priority: {P0/P1/P2}
- Size: {S/M/L/XL}
- Risk: {high/medium/low}
- Depends on: [{story-ids}]
- Blocks: [{story-ids}]
- Acceptance Criteria:
  - AC1: {criteria}
```

> `!scripts/write-checkpoint.sh gaia-create-epics 8 project_name="$PROJECT_NAME" prd_version="$PRD_VERSION" epic_count="$EPIC_COUNT" story_count="$STORY_COUNT" --paths docs/planning-artifacts/epics-and-stories.md`

### Step 9 — Brownfield: Generate Onboarding Knowledge Base (optional)

Skip this step if mode is greenfield.

- Generate onboarding doc as a knowledge base index linking to ALL artifacts.
- Write to `docs/planning-artifacts/brownfield-onboarding.md`.

> `!scripts/write-checkpoint.sh gaia-create-epics 9 project_name="$PROJECT_NAME" prd_version="$PRD_VERSION" epics_mode=brownfield brownfield_onboarding_written="$BROWNFIELD_ONBOARDING_WRITTEN"`

### Step 10 — Edge Case Analysis (optional)

- Ask: "Would you like to hunt for edge cases in the stories? Recommended to catch gaps before sprint planning. (yes / skip)"
- If yes: spawn edge case analysis subagent.
- If skip: edge case analysis can be run anytime later with /gaia-edge-cases.

> `!scripts/write-checkpoint.sh gaia-create-epics 10 project_name="$PROJECT_NAME" prd_version="$PRD_VERSION" edge_cases_run="$EDGE_CASES_RUN"`

### Step 11 — Adversarial Review (optional)

- Ask: "Would you like to run an adversarial review on the epics and stories? Recommended before sprint planning. (yes / skip)"
- If yes: spawn adversarial review subagent.
- If skip: adversarial review can be run anytime later with /gaia-adversarial.

> `!scripts/write-checkpoint.sh gaia-create-epics 11 project_name="$PROJECT_NAME" prd_version="$PRD_VERSION" adversarial_run="$ADVERSARIAL_RUN"`

## Finalize

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-create-epics/scripts/finalize.sh
