---
name: gaia-action-items
description: Process and resolve open action items before sprint planning. Use when "resolve action items" or /gaia-action-items. Loads action-items.yaml, auto-escalates aged items, routes each item by type (clarification → assignee agent, implementation → SM, process → user, automation → SM), records reasoning on every resolution, and optionally creates stories. Preserves the classification-confirmation gate before any /gaia-create-story handoff. Native Claude Code conversion of the legacy action-items workflow (E28-S111, Cluster 14).
argument-hint: "[action-id | status]"
allowed-tools: [Read, Write, Edit]
---

## Mission

You are processing open action items that accumulated since the last sprint — the pre-sprint triage pass. The tracker lives at `docs/implementation-artifacts/action-items.yaml` and is populated by `/gaia-retro`, `/gaia-triage-findings`, `/gaia-tech-debt-review`, and `/gaia-correct-course`. Your job is to walk through each open item, route it to the correct agent or ask the user directly, record the resolution with reasoning, and update the tracker.

This skill is the native Claude Code conversion of the legacy action-items workflow at `_gaia/lifecycle/workflows/4-implementation/action-items/instructions.xml` (brief Cluster 14, story E28-S111). The legacy 131-line XML body is preserved here as explicit prose per ADR-041. No workflow engine, no engine-specific XML step tags.

## Critical Rules

- **Action items are pre-sprint work — resolve BEFORE sprint planning, not during sprints.** If `/gaia-sprint-plan` is pending, run this skill first.
- **Route each item to the correct agent based on type.** `clarification` → assignee agent. `implementation` → Scrum Master (Nate). `process` → user. `automation` → Scrum Master. Do NOT make triage decisions unilaterally.
- **Every resolution must include reasoning — no silent closures.** Each updated `action-items.yaml` entry gets a `resolution:` field carrying the deciding agent's or user's reasoning. A closure with blank reasoning is invalid.
- **Items open for 3+ sprints auto-escalate from MEDIUM → HIGH.** Items open for 5+ sprints are flagged for mandatory user review.
- **NEVER silently hand off to /gaia-create-story (AC-EC7).** Triage-to-story handoff requires an explicit classification confirmation. Block the handoff and re-prompt until the bucket (backlog / story / NFR / out-of-scope) is confirmed.

## Inputs

1. **Action ID** — optional, via `$ARGUMENTS`. When provided (e.g., `A-001`), process only that single item.
2. **Status keyword** — optional, via `$ARGUMENTS`. When `status`, display the dashboard and exit without processing.
3. **Execution mode** — `normal` (per-item user prompts) or `yolo` (auto-apply agent recommendations; user confirmation still required for /gaia-create-story handoff per AC-EC7).

## Pipeline Overview

The skill runs four steps in strict order, mirroring the legacy `action-items/instructions.xml`:

1. **Load and Display** — read tracker, apply escalation, render dashboard or process list
2. **Process Each Item** — route by type, capture the decision
3. **Update Tracker** — persist status, resolution, resolved_date, related_stories
4. **Summary Report** — on-screen summary (no file artifact)

## Step 1 — Load and Display

- Read `docs/implementation-artifacts/action-items.yaml`. If the file does not exist, display `No action items tracked yet. Action items are created by /gaia-retro, /gaia-triage-findings, /gaia-tech-debt-review, and /gaia-correct-course.` and stop.
- Filter to `open` and `in-progress` items only (skip `done`, `invalid`, `deferred`).
- Apply escalation rules:
  - Items open for **3+ sprints** → auto-escalate priority MEDIUM → HIGH.
  - Items open for **5+ sprints** → flag for mandatory user review.
- If `$ARGUMENTS` matches an action_id (e.g., `A-001`): filter to that single item and continue.
- If `$ARGUMENTS == "status"`: render the dashboard and stop — do not process:

  ```
  Action Items Dashboard

  | Status       | Count |
  |--------------|-------|
  | Open         | {N}   |
  | In Progress  | {N}   |
  | Done         | {N}   |
  | Invalid      | {N}   |
  | Deferred     | {N}   |

  Open Items by Priority:
  | ID | Title | Type | Priority | Age (sprints) | Source | Assignee |

  Aged Items (2+ sprints):
  {list with escalation warnings}
  ```

- Otherwise, display all open items grouped by priority (HIGH first):

  ```
  Action Items: {N} open

  | # | ID | Title | Type | Priority | Age | Assignee |

  Processing {count} items...
  ```

## Step 2 — Process Each Item

For each open item (highest priority first, then oldest first):

1. Display a per-item header: `Item {id}: {title}`. Show type, priority, source, escalation_count, related_stories, and the original context from the source_ref.

2. Route based on the item's `type` field:

**clarification:**
- If the assignee is an agent (e.g., Theo, Derek, Zara, Val): invoke the assignee's agent skill (e.g., `/gaia-agent-architect`, `/gaia-agent-pm`, `/gaia-agent-security`, `/gaia-agent-validator`) with a context block:
  > You are {assignee}. An action item needs your decision:
  > Title: {title}
  > Context: {original context from source_ref}
  > Related stories: {related_stories}
  > This has been open for {escalation_count} sprints.
  > Make a decision: [resolve] with reasoning, [create-story] if implementation needed, or [defer] with justification.
- Wait for the agent to return with a decision.
- If no assignee is set, ask the user who should decide.

**implementation:**
- Invoke the SM skill (`/gaia-agent-sm`) with a context block:
  > You are Nate (Scrum Master). An action item needs implementation:
  > Title: {title}
  > Context: {original context}
  > Related stories: {related_stories}
  > Decide: [create-story] create a new story, [add-to-existing] add to an existing backlog story, or [already-done] if this was addressed by completed stories.
- Wait for the SM to return.
- If `create-story`: **classification gate (AC-EC7)** — confirm the bucket (backlog / story / NFR / out-of-scope) with the user before any `/gaia-create-story` invocation. Do NOT hand off silently. Then invoke `/gaia-create-story` with the context.
- If `add-to-existing`: update the target story's task list via the `Edit` tool.

**process:**
- Present to the user directly:
  > This action item recommends a process change: {title}
  > Context: {original context}
  > Options: [approve] implement the change, [dismiss] not needed, [defer] address later.
- Wait for the user's decision.

**automation:**
- Route to SM (same as `implementation` type) to create an implementation story.

**YOLO mode:** auto-apply agent and SM recommendations without user confirmation — EXCEPT for the `/gaia-create-story` handoff under `implementation` / `automation`, which always requires explicit classification confirmation (AC-EC7 is non-optional).

## Step 3 — Update Tracker

- For each processed item, update `docs/implementation-artifacts/action-items.yaml`:
  - `status`: `done` | `invalid` | `deferred` | `in-progress` (based on the decision)
  - `resolution`: reasoning from the deciding agent / user (blank is invalid)
  - `resolved_date`: current date (for `done` / `invalid`)
  - `related_stories`: append any newly created story keys
  - Update the `last_updated` timestamp at the top of the file
- Save the updated `action-items.yaml` via the `Edit` tool (surgical updates — do not regenerate the entire file).
- Save to Val memory (`_memory/validator-sidecar/decision-log.md`):

  ```
  ### [YYYY-MM-DD] Action Items Processed

  - **Agent:** validator
  - **Workflow:** action-items
  - **Status:** recorded

  Processed {count} action items.
  Resolved: {done_count}. Invalid: {invalid_count}. Deferred: {deferred_count}. In Progress: {in_progress_count}.
  {For each resolved item: "A-{NNN}: {title} → {status} — {brief resolution}"}
  ```

## Step 4 — Summary Report

Display on-screen (NOT as a file artifact):

```
Action Items Report

Processed: {processed_count}
Resolved: {done_count}
Invalid: {invalid_count}
Deferred: {deferred_count}
In Progress: {in_progress_count} (stories created, awaiting sprint)
Remaining: {open_count} (not yet processed)

| ID | Title | Decision | Reasoning |
```

If `in_progress_count > 0`:
- List the stories created from action items (keys + titles).
- Note: these will be available in the next `/gaia-sprint-plan`.

If `open_count > 0`:
- `{open_count} items remain open. Run /gaia-action-items to continue processing.`

If all resolved:
- `All action items resolved. Ready for /gaia-sprint-plan.`

## Edge Cases

- **AC-EC7 — classification confirmation gate:** never hand off to `/gaia-create-story` without explicit bucket confirmation. Re-prompt on unconfirmed classifications.
- **action-items.yaml missing:** stop with the "no action items tracked yet" message. Do NOT create the file.
- **Item references a non-existent story key:** log a WARNING; do not delete the item. The user can reconcile manually.

## References

- Legacy source: `_gaia/lifecycle/workflows/4-implementation/action-items/instructions.xml` (131 lines) — parity reference for NFR-053.
- Tracker: `docs/implementation-artifacts/action-items.yaml`.
- Triggers (populate the tracker): `/gaia-retro`, `/gaia-triage-findings`, `/gaia-tech-debt-review`, `/gaia-correct-course`.
- Downstream consumer: `/gaia-sprint-plan`.
- ADR-041 — Native Execution Model via Claude Code Skills + Subagents + Plugins + Hooks.
- ADR-042 — Scripts-over-LLM for Deterministic Operations.
- ADR-048 — Program-close deletion policy for legacy engine/workflows/tasks.
- FR-323 — Native Skill Format Compliance.
- NFR-053 — Functional parity with the legacy workflow.
- Reference implementation: `plugins/gaia/skills/gaia-fix-story/SKILL.md`.
