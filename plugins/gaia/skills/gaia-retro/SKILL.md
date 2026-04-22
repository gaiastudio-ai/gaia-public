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

### Step 5 --- Action Items (structured YAML write — FR-RIM-5)

For each improvement area identified in Step 4, propose a concrete action item with:
- Description of the action
- Owner (team member or role responsible)
- Target sprint for completion
- Priority (high for recurring issues, medium for new items)

Prompt the facilitator:

> Review the proposed action items. Add, remove, or modify items. Each action item needs an owner and target sprint.

Collect the facilitator's input and compile the final action items list, then persist each item to `${CLAUDE_PROJECT_ROOT}/docs/planning-artifacts/action-items.yaml` using the shared retro writer helper (ADR-052). The YAML schema is authoritative — see architecture §10.28.6.

Per-item payload (one YAML list element per action, FR-RIM-5):

```yaml
- id: AI-{auto-inc}
  sprint_id: "{sprint_id}"
  text: "{action text}"
  classification: clarification|implementation|process|automation
  status: open
  escalation_count: 0
  created_at: "{ISO 8601 timestamp}"
  theme_hash: "sha256:{hex of lowercase(trim(text))}"
```

Invoke the shared writer once per action item:

```bash
${CLAUDE_PLUGIN_ROOT}/../../scripts/retro-sidecar-write.sh \
  --root       "${CLAUDE_PROJECT_ROOT}" \
  --sprint-id  "${sprint_id}" \
  --target     "${CLAUDE_PROJECT_ROOT}/docs/planning-artifacts/action-items.yaml" \
  --payload    "$(emit_action_item_yaml)"
```

Failure posture:

- Missing `action-items.yaml` → writer seeds the file with the schema header from architecture §10.28.6 before appending (AC-EC3).
- Malformed existing YAML → writer HALTs with a line-pointer error; fix the YAML manually and re-run (AC-EC3).
- Dedup by stable `AI-{n}` ID when the prose retro already referenced an item — in-place `text` update rather than duplicate row (AC-EC8).
- `flock` on the YAML file serializes auto-increment across concurrent writers (AC-EC9).

The prose retrospective artifact written in Step 6 references each item by `AI-{n}` ID rather than duplicating text — `action-items.yaml` is the source of truth.

### Step 5c --- Agent Memory Updates (FR-RIM-3, ADR-016, ADR-052)

After Step 5 completes, persist the sprint's lessons to each of the six canonical agent memory sidecars so the next sprint's planning and dev agents carry the institutional memory forward. Writes go through the shared retro writer helper (ADR-052, architecture §10.28.2) which enforces the NFR-RIM-2 allowlist, NFR-RIM-3 idempotency, and atomic backup/verify.

Target sidecars (six fan-out, one entry per agent per sprint):

1. `${CLAUDE_PROJECT_ROOT}/_memory/architect-sidecar/decision-log.md` — architecture-level lessons.
2. `${CLAUDE_PROJECT_ROOT}/_memory/test-architect-sidecar/decision-log.md` — test strategy lessons.
3. `${CLAUDE_PROJECT_ROOT}/_memory/security-sidecar/decision-log.md` — security findings.
4. `${CLAUDE_PROJECT_ROOT}/_memory/devops-sidecar/decision-log.md` — deployment / pipeline lessons.
5. `${CLAUDE_PROJECT_ROOT}/_memory/sm-sidecar/decision-log.md` — process lessons.
6. `${CLAUDE_PROJECT_ROOT}/_memory/pm-sidecar/decision-log.md` — stakeholder / prioritization lessons.

For each sidecar, compose a payload in ADR-016 decision-log format tagged with the sprint ID, then invoke:

```bash
${CLAUDE_PLUGIN_ROOT}/../../scripts/retro-sidecar-write.sh \
  --root       "${CLAUDE_PROJECT_ROOT}" \
  --sprint-id  "${sprint_id}" \
  --target     "${CLAUDE_PROJECT_ROOT}/_memory/${agent}-sidecar/decision-log.md" \
  --payload    "$(emit_adr016_lesson ${agent})"
```

Failure posture:

- Missing sidecar file → writer creates the parent dir and seeds the canonical ADR-016 header before appending (AC-EC2).
- Re-run for the same sprint → composite dedup key (`sprint_id + sha256(payload)`) causes the writer to return `skipped_idempotent`; sidecar is byte-identical (AC2 / TC-RIM-4).
- Partial fan-out failure (e.g., one sidecar is read-only) → the failing sidecar is restored from `.bak`; already-successful sidecars keep their appended entry (they are valid organizational memory); retro halts before proceeding to Step 5d (AC-EC7).
- Symlink bypass attempt → writer resolves via `realpath` before the allowlist check and rejects with `status=unauthorized` (AC-EC5).

### Step 5d --- Velocity Data Persistence (FR-RIM-4, architecture §10.28.5)

Append a velocity row to `${CLAUDE_PROJECT_ROOT}/_memory/sm-sidecar/velocity-data.md`. This runs **unconditionally** on every retro invocation — it is the velocity mandate per architecture §10.28.5. Idempotency key is `sprint_id` alone (one row per sprint).

Payload schema (architecture §10.28.5):

```
| Planned points   | {planned}   |
| Completed points | {completed} |
| Story count (done)     | {done_count}     |
| Story count (rollover) | {rollover_count} |
| Velocity %             | {pct}            |
```

Invocation:

```bash
${CLAUDE_PLUGIN_ROOT}/../../scripts/retro-sidecar-write.sh \
  --root       "${CLAUDE_PROJECT_ROOT}" \
  --sprint-id  "${sprint_id}" \
  --target     "${CLAUDE_PROJECT_ROOT}/_memory/sm-sidecar/velocity-data.md" \
  --payload    "$(emit_velocity_row)"
```

Failure posture:

- Missing sprint ID → writer exits with `status=missing_sprint_id` and a non-zero code; prior Step 5c sidecar entries are NOT rolled back (they are valid memory), but the retro halts before Step 5 / Step 7 so no partial action-items / validator state lands (AC-EC4).
- Second retro invocation for the same sprint → writer sees the existing `### Sprint {id}` row and returns `skipped_idempotent`; velocity-data.md is byte-identical (AC2 / TC-RIM-4).
- Missing file → writer creates and seeds with the canonical "SM Velocity Data" header before appending (AC-EC2).

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

### Step 7 --- Val Memory Persistence (FR-RIM-8)

After the retro artifact is written, persist the retro's decisions and rolling context to the validator sidecar so Val can cross-reference retro outcomes in subsequent validations. This delegates to the Shared Val Sidecar Writer (architecture §10.10) — the shared retro writer helper is used as the transport (ADR-052, architecture §10.28.2 "Relationship to Shared Val Sidecar Writer") so the NFR-RIM-2 allowlist and NFR-RIM-3 idempotency apply uniformly.

Targets:

- `${CLAUDE_PROJECT_ROOT}/_memory/validator-sidecar/decision-log.md` — append one ADR-016-formatted entry per retro (sprint-ID tagged).
- `${CLAUDE_PROJECT_ROOT}/_memory/validator-sidecar/conversation-context.md` — refresh the rolling body with a one-line summary of the current retro per FR-VSP-2.

Invocation:

```bash
# decision-log append
${CLAUDE_PLUGIN_ROOT}/../../scripts/retro-sidecar-write.sh \
  --root       "${CLAUDE_PROJECT_ROOT}" \
  --sprint-id  "${sprint_id}" \
  --target     "${CLAUDE_PROJECT_ROOT}/_memory/validator-sidecar/decision-log.md" \
  --payload    "$(emit_val_retro_decision)"

# conversation-context refresh
${CLAUDE_PLUGIN_ROOT}/../../scripts/retro-sidecar-write.sh \
  --root       "${CLAUDE_PROJECT_ROOT}" \
  --sprint-id  "${sprint_id}" \
  --target     "${CLAUDE_PROJECT_ROOT}/_memory/validator-sidecar/conversation-context.md" \
  --payload    "$(emit_val_conversation_summary)"
```

Failure posture:

- Missing `_memory/validator-sidecar/` directory → the shared writer creates the directory and seeds both files with canonical ADR-016 headers before the first append (AC-EC10).
- Degraded-mode running: if Step 5c / 5d / 5 failed earlier, Step 7 still runs so the validator sidecar records the partial-success outcome — retro mandate per architecture §10.28.2.

## Finalize

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-retro/scripts/finalize.sh
