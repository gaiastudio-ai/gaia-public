---
name: gaia-add-feature
description: Triage and route a fix, enhancement, or feature through only the affected artifacts. Classifies as patch/enhancement/feature and cascades accordingly -- updating PRD, architecture, epics, test plan, threat model, and traceability as needed (FR-323).
context: fork
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Agent]
---

## Setup

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-add-feature/scripts/setup.sh

## Memory

!${CLAUDE_PLUGIN_ROOT}/scripts/memory-loader.sh pm decision-log

## Mission

You are the orchestrator for adding a new feature, enhancement, or patch to the project. You classify the change scope and cascade updates through exactly the set of affected artifacts. This skill delegates to sub-workflows via subagents -- it does not perform direct edits to downstream artifacts.

This skill is the native Claude Code conversion of the legacy add-feature workflow (E28-S57, FR-323). The classification vocabulary (patch / enhancement / feature), cascade matrix, and delegation model are preserved verbatim from the legacy workflow.

## Critical Rules

- This is an orchestrator -- delegate to sub-workflows via subagents, do not perform edits directly.
- Context flows forward: PRD diff feeds architecture edit, which feeds test plan edit, which feeds story creation.
- Intelligently skip steps when not needed -- do not force all sub-workflows on every change.
- The classification vocabulary is EXACTLY: `patch`, `enhancement`, `feature`. Do NOT rename, alias, or refactor these terms -- downstream triage tooling and historical change requests depend on those exact strings.
- The cascade matrix (which artifacts are updated per classification) MUST match the definitions below exactly.

## Classification Vocabulary

Changes are classified into exactly one of three categories:

| Classification | Scope | Description |
|----------------|-------|-------------|
| **patch** | Minimal | A one-line typo fix, copy change, or trivial correction. Touches only the directly affected doc. Does NOT cascade to PRD, architecture, epics, test plan, threat model, or traceability. |
| **enhancement** | Moderate | A story-level change such as a new acceptance criterion on an existing story. Cascades to epics + test plan + traceability. Leaves PRD, architecture, and threat model untouched unless impact is explicitly flagged. |
| **feature** | Full | A net-new user-visible capability. Full cascade across PRD, architecture, epics, test plan, threat model, and traceability. |

## Cascade Matrix

The cascade matrix defines which artifacts are updated for each classification:

| Artifact | patch | enhancement | feature |
|----------|-------|-------------|---------|
| PRD (`docs/planning-artifacts/prd.md`) | -- | -- | YES |
| Architecture (`docs/planning-artifacts/architecture.md`) | -- | -- | YES |
| Epics & Stories (`docs/planning-artifacts/epics-and-stories.md`) | -- | YES | YES |
| Test Plan (`docs/test-artifacts/test-plan.md`) | -- | YES | YES |
| Threat Model (`docs/planning-artifacts/threat-model.md`) | -- | -- | YES |
| Traceability (`docs/test-artifacts/traceability-matrix.md`) | -- | YES | YES |

"--" means the artifact is NOT touched for that classification. "YES" means the artifact IS updated via the appropriate sub-workflow.

## Steps

### Step 1 -- Capture Feature Scope

- Ask: Describe the new feature, enhancement, or fix you want to add.
- Ask: What is the business driver? (customer request / market opportunity / technical improvement / regulatory)
- Ask: Is this linked to a change request? If so, provide the CR ID.
- If CR exists: read `docs/planning-artifacts/change-request-{cr_id}.md` for context (impact analysis, approval status).
- Classify the change as **patch**, **enhancement**, or **feature** based on scope analysis.
- Present scope summary to user for confirmation before proceeding:
  - Change: {description}
  - Classification: {patch / enhancement / feature}
  - Driver: {driver}
  - CR: {cr_id or "none"}
  - Expected cascade: {list of artifacts that will be updated per the cascade matrix}

### Step 2 -- Execute Cascade (patch)

- If classification is `patch`:
  - Apply the fix directly to the affected document.
  - No cascade -- no downstream artifacts are touched.
  - Skip to Step 8 (Summary).

### Step 3 -- Edit PRD (feature only)

- If classification is `feature`:
  - Delegate to the edit-prd sub-workflow via subagent: add new functional and non-functional requirements.
  - Capture the PRD diff -- identify NEW requirement IDs (FR-*, NFR-*) added.
  - Capture the cascade classification from edit-prd (architecture impact: NONE/MINOR/SIGNIFICANT).
  - Store: prd_diff, cascade_to_arch.
- If classification is `enhancement` or `patch`: skip this step.

### Step 4 -- Edit Architecture (feature only, if needed)

- If classification is `feature` AND cascade_to_arch != NONE:
  - Delegate to the edit-architecture sub-workflow via subagent.
  - Capture the architecture diff -- new ADRs, changed sections.
  - Store: arch_diff.
- If cascade_to_arch == NONE: inform user "No architecture changes needed" and skip.
- If classification is `enhancement` or `patch`: skip this step.

### Step 5 -- Edit Test Plan (enhancement and feature)

- If classification is `enhancement` or `feature`:
  - Check if `docs/test-artifacts/test-plan.md` exists. If not, recommend running /gaia-test-design.
  - If test plan exists: delegate to the edit-test-plan sub-workflow via subagent.
  - Capture test plan additions (new test case IDs).
  - Store: test_diff.
- If classification is `patch`: skip this step.

### Step 6 -- Edit Threat Model (feature only)

- If classification is `feature`:
  - Check if `docs/planning-artifacts/threat-model.md` exists.
  - If it exists: update the threat model to account for new attack surfaces introduced by the feature.
  - Store: threat_model_diff.
- If classification is `enhancement` or `patch`: skip this step.

### Step 7 -- Add Feature Stories (enhancement and feature)

- If classification is `enhancement` or `feature`:
  - Delegate to the add-stories sub-workflow via subagent, passing feature_description, prd_diff, arch_diff, and cr_id.
  - Capture new story keys and epic assignments.
  - Store: new_stories.
  - Priority flag integration: if the driver is high-urgency (P0, business-critical, or regulatory), set priority_flag: "next-sprint" in each created story's frontmatter.
- If classification is `patch`: skip this step.

### Step 7b -- Update Traceability (enhancement and feature)

- If classification is `enhancement` or `feature`:
  - Delegate to the traceability sub-workflow via subagent to regenerate the traceability matrix.
  - Verify new FR/NFR IDs, test cases, and stories are linked.
- If classification is `patch`: skip this step.

### Step 8 -- Summary

- Present final summary:

  **Change Addition Complete: {description}**

  | Artifact | Status | Details |
  |----------|--------|---------|
  | Classification | {patch/enhancement/feature} | {scope rationale} |
  | PRD | {Updated/Skipped} | {new FR/NFR IDs or "N/A"} |
  | Architecture | {Updated/Skipped} | {new ADRs or "N/A"} |
  | Test Plan | {Updated/Skipped/Not found} | {new test case IDs or reason} |
  | Threat Model | {Updated/Skipped} | {changes or "N/A"} |
  | Stories | {Created/Skipped} | {new story keys or "N/A"} |
  | Traceability | {Regenerated/Skipped} | {linkage status} |

  **Next steps:**
  - For each new story: run `/gaia-create-story {story_key}` to elaborate
  - To start development: run `/gaia-sprint-plan` or `/gaia-correct-course`

## Finalize

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-add-feature/scripts/finalize.sh
