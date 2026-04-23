---
name: gaia-create-story
description: Create a detailed story file from epics-and-stories.md with full frontmatter, acceptance criteria, and sprint-state registration. Cluster 7 architecture skill.
argument-hint: [story-key]
allowed-tools: [Read, Write, Edit, Bash]
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
- Step 6 (Validation) MUST implement the shared Val + SM Fix-Loop dispatch pattern defined in ADR-050. The SM fix is INLINE — this skill uses its own `Edit` and `Write` tools to apply fixes. Nested subagent spawning for the fix is forbidden (preserves NFR-046 single-spawn-level constraint). The existing `allowed-tools: [Read, Write, Edit, Bash]` frontmatter already supports inline SM fix — no allowlist expansion is required.
- The 3-attempt cap in Step 6 is a hard constraint. YOLO mode MUST NOT bypass the cap or the terminal FAILED verdict (FR-340).
- Terminal verdicts from Step 6 are recorded via `review-gate.sh` using the `story-validation` ledger-keyed gate (`--plan-id <id>`). This path does NOT touch the six canonical Review Gate table rows — those belong to the six downstream review commands.

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
- If `origin` and `origin_ref` were passed by the invoking command (e.g., `/gaia-correct-course` or `/gaia-triage-findings` via Skill-to-Skill Delegation, FR-FITP-2): set `origin: "{origin_value}"` and `origin_ref: "{origin_ref_value}"` in frontmatter. These record provenance for traceability (NFR-FITP-1). If not passed, leave as `origin: null` and `origin_ref: null`.
- Write acceptance criteria in Given/When/Then format.
- Write tasks/subtasks breakdown.
- Write test scenarios table.
- Write the story file to `docs/implementation-artifacts/{story_key}-{slug}.md`.

### Step 5 -- Register in Sprint Status

- Call `scripts/update-story-status.sh {story_key} backlog` to register the story in `sprint-status.yaml`.
- This MUST happen AFTER the story file write has succeeded (story file is source of truth).

### Step 6 -- Validation (ADR-050 Shared Val + SM Fix-Loop Dispatch Pattern)

This step implements the six-component dispatch pattern from ADR-050. It replaces the legacy inline checks (15-field frontmatter presence, Given/When/Then AC format, canonical filename) with a full 8-part Val validation, an inline SM fix loop (3-attempt cap), status-sync after every attempt, and a terminal verdict recorded via `review-gate.sh`. E33-S1 is the reference implementation; E33-S2 (`/gaia-validate-story`) reuses the same pattern.

**IMPORTANT — NFR-046 single-spawn-level constraint:** the SM fix runs INLINE using this skill's own `Edit` and `Write` tools. Do NOT spawn a nested SM subagent via the `Agent` or `Task` tool during the fix apply — a Val subagent spawning an SM subagent would be two levels deep and violate NFR-046. Inline SM fix is the canonical pattern.

**Component 1 — Val dispatch.** Invoke the Val (validator) subagent with:
- `context: fork` (isolated validation context)
- read-only tool allowlist: `[Read, Grep, Glob, Bash]`
- `artifact_path`: the story file path written in Step 4
- `source_workflow`: `gaia-create-story`

Val returns a structured 8-part response. The eight parts are: `frontmatter`, `completeness`, `clarity`, `semantics`, `dependencies`, `factual`, `origin`, `review_gate_vocabulary`. Each part carries a `findings` array (possibly empty); each finding carries a severity classification (`CRITICAL`, `WARNING`, or `INFO`) and the structured fields needed to locate and fix it.

**Malformed 8-part response (AC-EC1):** if Val returns a response missing one of the 8 named parts, log a WARNING, treat the missing part as UNVERIFIED, and proceed deterministically — never silently pass. If more than one part is missing, HALT with guidance to re-invoke Val once; if the re-invocation is also malformed, record the terminal verdict as UNVERIFIED via `review-gate.sh`.

**Component 2 — Finding classification.** Partition findings by severity.
- Zero CRITICAL and zero WARNING: verdict PASSED, skip the fix loop entirely. Proceed to Component 6 terminal write.
- Any CRITICAL or WARNING: enter the fix loop.
- INFO findings (FR-339, AC-EC7) are always logged to the story's Dev Agent Record but NEVER trigger the loop. The severity classifier MUST filter INFO out of the loop trigger condition — INFO does not extend the loop lifespan.

**Component 3 — Inline SM fix (attempt N of 3).** Apply fixes using this skill's own `Edit` and `Write` tools. The SM auto-fix vocabulary covers:
- frontmatter field additions (missing required fields from the 15-field schema)
- AC format corrections (converting free-form ACs to Given/When/Then)
- dependency / trace / origin field updates
- canonical filename renames

Scope is restricted to the single story file path and (for Component 6) the `review-gate.sh` ledger output. No other files may be edited during the fix apply.

**Component 4 — Re-validation.** After each fix attempt, re-invoke Val as a FRESH `context: fork` subagent. Each attempt is a new dispatch — not a continuation of the prior Val session. Use the same parameters as Component 1.

**Component 5 — Status-sync after every attempt (FR-338, NFR-056).** After the fix applies (Component 3), write the frontmatter `status` field to the story file, then invoke the skill-scoped wrapper:

```bash
${CLAUDE_PLUGIN_ROOT}/skills/gaia-create-story/scripts/update-story-status.sh {story_key} {new_status}
```

That wrapper delegates to the shared `${CLAUDE_PLUGIN_ROOT}/scripts/sprint-state.sh` foundation script, which ensures `sprint-status.yaml` is byte-identically in sync with the story frontmatter `status` (VLR-04).

**AC-EC3 — self-transition rejection is benign.** If the fix attempt produced no net change to the frontmatter `status` field, `sprint-state.sh` will reject the self-transition. Treat this as benign (non-blocking) — log it and proceed to re-validation. Do NOT HALT.

**Component 6 — Attempt cap and terminal verdict.** The hard cap is 3 attempts (FR-337). Track the attempt counter; new findings introduced by an SM fix (AC-EC5) do NOT reset the counter. Identical finding IDs across two consecutive attempts (oscillation / non-convergence, AC-EC4) must be logged to Dev Agent Record as a stall signal, but the loop MUST NOT short-circuit — the cap still runs to 3.

Terminal verdict write (ledger-keyed, does NOT overwrite the six-row Review Gate table):

```bash
# On zero CRITICAL/WARNING within 3 attempts:
${CLAUDE_PLUGIN_ROOT}/scripts/review-gate.sh update \
  --story "{story_key}" \
  --gate "story-validation" \
  --verdict PASSED \
  --plan-id "create-story-val-{timestamp}"

# On exhaustion with CRITICAL/WARNING findings remaining after 3 attempts:
${CLAUDE_PLUGIN_ROOT}/scripts/review-gate.sh update \
  --story "{story_key}" \
  --gate "story-validation" \
  --verdict FAILED \
  --plan-id "create-story-val-{timestamp}"
```

Query shape for downstream consumers (VLR-06 Tier 1 assertion):

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/review-gate.sh status \
  --story "{story_key}" \
  --gate "story-validation" \
  --plan-id "create-story-val-{timestamp}"
# returns the exact canonical string PASSED, FAILED, or UNVERIFIED.
```

Canonical vocabulary is strict: exactly `PASSED`, `FAILED`, or `UNVERIFIED`. No other variant (lowercase, "failed", "ERROR") is accepted — enforced by `review-gate.sh`.

**AC-EC2 — missing review-gate.sh.** If `review-gate.sh` is not present or not executable at Component 6, HALT with an actionable error that references the expected path. Do NOT silently skip the terminal verdict write.

**AC-EC6 — Val timeout / model unavailable.** If Val's `context: fork` invocation times out, crashes, or returns no response, HALT with the canonical message "Val validation could not complete: {reason}" and record the terminal verdict as UNVERIFIED via `review-gate.sh`. Never silently PASSED.

**AC-EC8 / FR-340 — YOLO does not bypass the cap.** YOLO-mode invocations run the same 3-attempt loop with the same terminal verdict rules. YOLO MUST NOT override the cap and MUST NOT override a terminal FAILED verdict. On a YOLO-mode FAILED, HALT with guidance pointing to `/gaia-fix-story {story_key}`.

**Token budget (NFR-055).** Log per-attempt Val token usage to Dev Agent Record. Total loop overhead MUST NOT exceed 3x a single-pass Val budget.

### Step 7 — Persist to Val Sidecar (E34-S2)

Final step. Delegates Val-decision persistence to the shared Val sidecar writer helper (`val-sidecar-write.sh`, E34-S1, architecture §10.10). This step MUST be the final action of the skill — placing it last guarantees AC3 atomicity: any upstream failure short-circuits before the helper runs, so no partial sidecar entry can appear.

Build the decision payload as `{verdict, findings[], artifact_path}` using the terminal verdict recorded by Step 6 (via `review-gate.sh`). If Step 6 was skipped (no validation ran), use `verdict: "skipped"` and an empty findings list so the command invocation is still recorded.

Invoke the helper:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/val-sidecar-write.sh \
  --command-name "/gaia-create-story" \
  --input-id     "${story_key}" \
  --sprint-id    "${sprint_id:-N/A}" \
  --decision-payload "$(jq -cn \
    --arg verdict       "${verdict}" \
    --arg artifact_path "${story_file_path}" \
    --argjson findings  "${findings_json:-[]}" \
    '{verdict: $verdict, findings: $findings, artifact_path: $artifact_path}')"
```

The helper enforces the two-file allowlist (NFR-VSP-2) and idempotency by composite `(command_name, input_id, decision_hash)` key (FR-VSP-2) — re-runs with identical payload yield `status=skipped_duplicate` and must be treated as success.

Failure posture: if the helper rejects or errors, log a warning and continue — memory persistence is best-effort and MUST NOT fail the skill.

## Finalize

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-create-story/scripts/finalize.sh
