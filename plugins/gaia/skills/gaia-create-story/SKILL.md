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
- After writing the story file, call `scripts/transition-story-status.sh {story_key} --to backlog` to register the story atomically with `status=backlog` across the four canonical surfaces (story-file frontmatter, `sprint-status.yaml`, `epics-and-stories.md`, `story-index.yaml`).
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

> **YOLO hard guard (E54-S1, AC3, FR-340):** The existing-story-status HALT above runs unconditionally — including in YOLO mode. YOLO MUST NOT bypass the HALT gate. Order of evaluation: existing-story-status HALT first, YOLO branch (Step 3) second. A `status: in-progress` story HALTs before any subagent spawn even with `yolo`/`--yolo` set.

### Step 2 -- Load Context

- Read story summary from `docs/planning-artifacts/epics-and-stories.md`.
- Read `docs/planning-artifacts/architecture.md` for technical context (ADRs live inline in the Decision Log table).
- Read `docs/planning-artifacts/ux-design.md` if available for UI context.

### Step 3 -- Elaborate Story

#### YOLO branch (E54-S1, FR-340)

Read `YOLO_MODE` from the setup script's stdout (the `gaia-create-story/setup.sh: yolo_mode={true|false}` line).

When `YOLO_MODE=true`:

- **Skip the routing prompt entirely.** Do NOT display the `[u]/[a]` menu; do NOT wait for user input. Auto-select the `[a]` Auto-delegate path and proceed directly to subagent spawn.
- **Auto-continue any post-subagent or template-output review prompts.** YOLO mode replaces every `[c]/[e]/[a]` or `[c]/[e]/[v]` interactive review prompt with an automatic continue — there must be zero user prompts between Step 4 (file write) and Step 6 (Val dispatch) (AC6).
- **YOLO MUST NOT bypass the Step 1 existing-story-status HALT gate (AC3) nor the Step 6 3-attempt cap or terminal FAILED verdict (AC2, FR-340).** The HALT gate in Step 1 fires before the YOLO branch ever evaluates; the cap and verdict in Step 6 are unconditional.

When `YOLO_MODE=false` (interactive default), proceed to the prompt below.

#### Non-YOLO routing prompt

Present a brief summary of what was loaded, then offer the user how to elaborate. The canonical prompt is (text below is part of the AC4 contract — do not paraphrase):

```
How would you like to elaborate this story?
[u] I'll answer the elaboration questions myself
[a] Auto-delegate to PM (Derek), Architect (Theo){UX_CLAUSE}    -- recommended
```

The `{UX_CLAUSE}` token is replaced based on the **four-rule UX detection** below:

- When any rule matches: `, and UX Designer (Christy)`
- When no rule matches: `` (empty string — the `[a]` line **omits** the "and UX Designer" clause)

Concrete examples:

- UX match → `[a] Auto-delegate to PM (Derek), Architect (Theo), and UX Designer (Christy)`
- No UX match → `[a] Auto-delegate to PM (Derek) and Architect (Theo)`

#### Four-rule UX detection

Run all four rules. Any rule matching → spawn UX Designer. No rule matching → omit UX Designer (backend-only path).

**Rule #1 — `figma:` frontmatter block (definitive signal).** Parse the story frontmatter and check for a top-level `figma:` key. Presence is a hard match.

**Rule #2 — UI/UX terms in description or AC text.** Case-insensitive substring match against the UI_TERMS list:

```
screen | page | modal | form | button | navigation | wizard | flow |
interaction | accessibility | responsive | mobile view | design
```

Treat `flow` carefully: prefer word-boundary regex and exclude `data flow` / `control flow` to avoid false positives in backend stories.

**Rule #3 — Epic UX classification.** The epic this story belongs to has a UX-tagged classification in `epics-and-stories.md` (look for an explicit `tags:` or `classification:` line on the epic).

**Rule #4 — `ux-design.md` references the epic.** `docs/planning-artifacts/ux-design.md` exists AND the story's epic key is referenced inside that file. If the file is missing (the common case for early-stage projects), rule #4 must **skip cleanly** — no error, no halt — and rules 1-3 still evaluate. Use a file-exists guard (`[ -f "$UX_DESIGN_MD" ]`).

**Detection pseudocode** (telemetry-friendly; runs all rules for observability):

```
ux_match = false
rule_fired = []
if frontmatter has 'figma:' key:                       ux_match=true; rule_fired += "rule1"
if description or any AC contains UI_TERMS (case-insensitive): ux_match=true; rule_fired += "rule2"
if epic in epics-and-stories.md has UX classification: ux_match=true; rule_fired += "rule3"
if file_exists(ux-design.md) and grep -q "$EPIC_KEY" ux-design.md: ux_match=true; rule_fired += "rule4"
log "ux_detection: match=${ux_match} rules=${rule_fired[*]}"
```

A story matching multiple rules still results in **a single UX Designer spawn** — priority order matters for telemetry only. Always log which rule(s) fired.

#### Subagent contracts

When the user picks `[a]`, dispatch the selected subagents with the contracts below.

**PM (Derek) — `gaia:pm`.** Always spawned on `[a]`.
- Loads: `docs/planning-artifacts/epics-and-stories.md`, `docs/planning-artifacts/prd.md`, `docs/planning-artifacts/ux-design.md` (when present).
- Answers 3 questions: (Q1) edge cases from a product/stakeholder lens; (Q2) AC prioritization (must-have vs nice-to-have); (Q3) stakeholder notes / cross-team callouts.

**Architect (Theo) — `gaia:architect`.** Always spawned on `[a]`.
- Loads: `docs/planning-artifacts/architecture.md`, `docs/planning-artifacts/test-plan.md`, `docs/planning-artifacts/epics-and-stories.md`.
- Answers 2 questions: (Q1) implementation constraints (ADRs, patterns, tech choices); (Q2) technical dependencies (other modules, services, libraries).

**UX Designer (Christy) — `gaia:ux-designer`.** Spawned on `[a]` ONLY when the four-rule UX detection matches. NOT spawned for backend-only stories.
- Loads: `docs/planning-artifacts/ux-design.md` (when present), `docs/planning-artifacts/epics-and-stories.md`, the story frontmatter (including any `figma:` block).
- Answers exactly 3 questions: (Q1) UX edge cases — empty, loading, error, no-data, offline states; (Q2) accessibility — keyboard navigation, screen-reader support, color contrast, ARIA semantics; (Q3) interaction patterns — which design-system components/patterns to reuse vs build custom.

PM still loads `ux-design.md` even when UX Designer is also spawned — this is intentional. PM brings stakeholder context; UX Designer brings design-system expertise. The question scopes do not overlap.

#### Parallel spawn protocol — single message, multiple Agent calls

```
+-----------------------------------------------------------+
| HARD CONSTRAINT                                            |
| All selected subagents MUST be spawned in a SINGLE message |
| containing multiple Agent tool calls — true parallel,      |
| NOT sequential. This is the canonical Claude Code parallel |
| pattern. Do NOT spawn one, await its return, then spawn    |
| the next — that is sequential and violates AC6.            |
+-----------------------------------------------------------+
```

Concretely, when `[a]` is selected:

- Backend-only story (no UX match): emit ONE assistant message containing TWO Agent tool calls — PM and Architect — invoked in parallel.
- UX-scoped story (any rule matches): emit ONE assistant message containing THREE Agent tool calls — PM, Architect, and UX Designer — invoked in parallel.

Sequential dispatch (spawn → await → spawn) is forbidden. The single-message multi-Agent-call pattern is the canonical Claude Code parallel mechanism — not a custom invention.

#### `[u]` Manual elaboration path (4-question flow, AC5)

When the user selects `[u]`, ask exactly 4 questions in this canonical order. No additional questions, no reordering, no merging:

1. **Edge cases.** "What edge cases should this story handle? (empty/loading/error states, boundary inputs, failure modes)"
2. **Implementation preferences.** "Any implementation preferences or constraints? (libraries, patterns, ADRs to honor, anti-patterns to avoid)"
3. **AC splits.** "Should any acceptance criterion be split into smaller ACs for clarity or test isolation?"
4. **Additional context.** "Any additional context — stakeholders, integrations, or cross-team callouts — to include?"

The 4 questions are exactly 4 — sized to mirror V1's `[u]` UX. Do NOT inflate the count by walking the PM/Architect/UX scopes from the `[a]` path.

Gather edge cases, implementation preferences, AC splits, and additional context returned by the `[u]` flow (or by the subagents on the `[a]` path) and pass them forward to Step 4.

### Step 3b -- Edge Case Analysis (V1 pipeline restoration, E54-S4)

This step JIT-invokes the `edge-cases` skill to enumerate boundary, error, timing, concurrency, integration, security, data, and environment scenarios for the story's acceptance criteria. It restores the V1 R1 parity pipeline that was dropped in V2. Steps 3b/3c/3d run **non-interactively** — they MUST NOT introduce any new user prompts and behave identically in YOLO mode (AC6).

**Traces to:** FR-227 (edge-case enumeration mandatory for M+ stories), FR-229 (AC append), NFR-042 (8K token budget).

**Size gate (AC4).** If the story `size` is `S`, skip Step 3b entirely:

```
if [ "${SIZE}" = "S" ]; then
  log "edge_case_skip: size=S"
  edge_case_results=[]
  # proceed to Step 3c with empty results — Step 3c becomes a no-op
fi
```

For sizes M, L, or XL, proceed with the JIT skill invocation below.

**JIT skill invocation.** Invoke the `edge-cases` skill (canonical name; namespaced form `gaia:edge-cases` resolves equivalently) via the Skill tool. Pass the input context:

```yaml
story_key:           "{STORY_KEY}"
story_title:         "{TITLE}"
story_description:   "{DESCRIPTION}"
acceptance_criteria: ["{AC1}", "{AC2}", ...]   # primary ACs from Step 3 elaboration
size:                "{SIZE}"                  # M | L | XL
architecture_excerpt: "{relevant ADR/architecture section, optional}"
```

The skill returns a structured `edge_case_results` list with the canonical schema:

```yaml
edge_case_results:
  - id:       "EC-1"          # sequential EC-{N}
    scenario: "..."            # one-line description
    input:    "..."            # triggering input/precondition
    expected: "..."            # expected behavior
    category: "boundary"       # one of: boundary | error | timing | concurrency | integration | security | data | environment
    severity: "high"           # optional: critical | high | medium | low (used by Step 3d row format)
```

**Token budget cap (NFR-042, AC5).** The combined input context plus skill output MUST stay under **8K tokens** total. The edge-cases skill self-truncates its output when over budget; this skill (the consumer) enforces the **truncation order** when post-processing results that still exceed budget after the skill returns:

1. **Keep first:** `boundary`, `error`, `security` (highest-priority categories).
2. **Keep next:** `concurrency`, `timing`.
3. **Keep last (drop from tail when over budget):** `data`, `integration`, `environment`.

Implement the order as a category priority array. Drop results from the lowest-priority category first until the total fits inside 8K. Final result MUST be `<= 8K`.

**Telemetry (AC5).** After each invocation, log the token usage:

```
log "edge_case_token_usage=${tokens}"
```

When usage exceeds 80% of the 8K budget, also log a `Dev Notes` entry (per the edge-cases skill's NFR-042 contract).

**Failure handling (AC1).** The skill is **non-blocking**. On any error — skill not found, timeout (>30s wall clock), malformed output, exception — the consumer MUST:

```
edge_case_results = []
log "edge_case_pipeline: failed reason=${reason}"
log "warning: edge-cases skill failed — continuing without edge cases"
# proceed to Step 3c (do not halt, do not re-raise)
```

Under no circumstance should an edge-case skill failure block story creation.

**YOLO compatibility (AC6).** Step 3b is fully non-interactive — it issues no prompts and produces the same `edge_case_results` for the same inputs regardless of `YOLO_MODE`.

### Step 3c -- Append Edge Cases to Acceptance Criteria (V1 pipeline restoration, E54-S4)

This step appends edge-case-derived acceptance criteria rows to the story's AC list. It enforces a SHA-256 hash-based immutability check on every primary AC line that aborts the append (and atomically reverts the file) if any primary AC line drifts during the operation.

**Traces to:** FR-229 (V1 ACs append), ADR-074 contract C2 (AC immutability hash check), ADR-042 (Scripts-over-LLM), AF-2026-04-28-7 Work Items 4 + 6.7 (script migration).

**Format (FR-229).** For each entry in `edge_case_results`, emit one AC row using:

```
- [ ] AC-EC{N}: Given {input}, when {scenario}, then {expected}
```

`{N}` is sequential (EC1, EC2, ...) per story.

**Append position.** Append edge-case ACs **after the last primary AC**. Primary ACs (those produced in Step 3 by elaboration) are **immutable** — Step 3c MUST NOT modify, reorder, or delete any primary AC. Edge-case ACs always trail the primary block.

**Primary AC immutability hash check (ADR-074 C2).** The append is delegated to `append-edge-case-acs.sh` (E63-S7), which computes a SHA-256 over every primary AC line BEFORE the append, performs the append, recomputes the hashes, and compares element-wise. Any mismatch — a single mutated character in any primary AC line — triggers an atomic revert (the file is restored byte-identical to its pre-append state via a `mktemp` snapshot) and a non-zero exit. This is the strictest possible immutability check and replaces the V2 count-drift check (which only detected count changes, missing in-place mutations).

Invoke the script — do NOT perform the append in prose:

```
!scripts/append-edge-case-acs.sh \
  --file <story-file> \
  --edge-cases '<json-array-of-edge-case-results>'
```

Where `<json-array-of-edge-case-results>` is the `edge_case_results` list from Step 3b serialized as JSON (each entry: `{id, scenario, input, expected, category, severity?}`).

The script is idempotent: re-runs with overlapping `scenario` strings dedupe by exact `scenario` substring match against existing AC-EC entries, so a second invocation with the same input is a no-op (stdout reports `0` new entries appended).

The script's stdout (on success) is the integer count of AC-EC entries appended (post-dedup). Capture this as `edge_case_ac_appended_count` for the Step 3c gate log. On non-zero exit, the file has already been reverted; treat as `edge_case_ac_appended = false` and proceed to Step 3d with the unchanged primary ACs (story creation MUST NOT halt — edge-case append is best-effort per the V1 contract).

If the target file does not exist, the script writes a WARNING to stderr and exits 0 (non-blocking, mirrors Step 3d's missing-test-plan posture).

Rationale: primary ACs are contractual user/PM/Architect output. Drift — whether from a parsing bug, a regex misfire, or any other corruption — indicates the appender misbehaved, and the safest action is to revert atomically rather than leave the AC list half-mutated. Moving the algorithm from prose to a deterministic bash script (per ADR-042) eliminates LLM-side drift and reclaims ~400 tokens of Step 3c budget for E63-S11.

**YOLO compatibility (AC6).** Step 3c is fully non-interactive.

### Step 3d -- Append Edge Cases to Test Plan (V1 pipeline restoration, E54-S4)

This step appends one test-plan row per edge case to the story's section in `docs/planning-artifacts/test-plan.md`. Re-runs are idempotent — duplicate rows are deduplicated by `(story_key, scenario)` pair.

**Traces to:** FR-230 (V1 test-plan append).

**Target file.** `docs/planning-artifacts/test-plan.md`. If the file does not exist, this step is **non-blocking**:

```
if [ ! -f "docs/planning-artifacts/test-plan.md" ]; then
  log "warning: test-plan.md missing — skipping Step 3d test-plan append (non-blocking)"
  return
fi
```

**Locate the story's test-plan section.** Search for a heading match of the form `## {story_key}` or `### {story_key}` (e.g., `## E54-S4` or `### E54-S4`). If the section is missing, append a new section with that heading at the end of the file.

**Compute next TC ID.** For the located story section, find the maximum existing `TC-{N}` numeric suffix scoped to that section and compute `next_tc_id = max(existing TC-{N} for this story) + 1`. TC IDs may be re-allocated on re-run — they are NOT used for dedup (see below).

**Dedup by `(story_key, scenario)` pair (AC3).** Build the set of existing `(story_key, scenario)` pairs for the story's section by parsing existing rows. For each `ec` in `edge_case_results`:

```
if (story_key, ec.scenario) in existing_pairs:
  skip   # already present — idempotent re-run, no duplicate row
else:
  append row, increment next_tc_id, add (story_key, ec.scenario) to existing_pairs
```

This makes Step 3d idempotent on re-run: the same `(story_key, scenario)` pair never inflates the test plan with duplicates, even when TC IDs shift.

**Row format (FR-230).** Each appended row uses the canonical pipe-delimited table format:

```
| TC-{N} | {scenario} | edge-case | {severity} | {story_key} |
```

Columns: `TC ID | Scenario | Type | Severity | Story Key`. The literal `edge-case` token in the Type column distinguishes these rows from primary test cases (which use `unit`, `integration`, `e2e`, etc.). The `{severity}` is taken from `ec.severity` if provided by the edge-cases skill, otherwise default to `medium`.

**YOLO compatibility (AC6).** Step 3d is fully non-interactive.

### Step 4 -- Generate Story File

- Load the bundled story template from `${CLAUDE_PLUGIN_ROOT}/skills/gaia-create-story/story-template.md`.
- Generate the slug from the story title: lowercase, replace non-alphanumeric with hyphens, collapse consecutive hyphens, trim edges.
- Populate ALL 15 required frontmatter fields from the epics-and-stories source data.
- **Derive `points` from `size` via the resolved `sizing_map`.** Resolve the `sizing_map` key via `!scripts/resolve-config.sh sizing_map` once per skill run (cache the result in a shell variable for the remainder of Step 4). The resolver merges the team-shared `config/project-config.yaml` over the framework defaults per ADR-044 §10.26.3, applying the project-over-global precedence contract from ADR-074 contract C1 (E61-S1 added the `sizing_map:` block to the project-config.yaml schema). Look up `points` by the story's `size` (S/M/L/XL) — `points` is derived from `size` via the resolved mapping, **not** from a hardcoded `S=2 / M=5 / L=8 / XL=13` constant. Mirrors the pattern in `gaia-sprint-plan/SKILL.md` Step 2 — both skills consume the identical resolver key.
- **HALT on resolver failure (no silent fallback).** If `!scripts/resolve-config.sh sizing_map` exits non-zero or returns a malformed map (missing one of the four canonical sizes), HALT with an actionable error naming the resolver and exit code. The skill MUST NOT silently fall back to a hardcoded `sizing_map` — that would defeat the project-overridable contract from ADR-074 contract C1 and contradict ADR-044's project-over-global precedence rule.
- Set `status: backlog` in frontmatter.
- If `origin` and `origin_ref` were passed by the invoking command (e.g., `/gaia-correct-course` or `/gaia-triage-findings` via Skill-to-Skill Delegation, FR-FITP-2): set `origin: "{origin_value}"` and `origin_ref: "{origin_ref_value}"` in frontmatter. These record provenance for traceability (NFR-FITP-1). If not passed, leave as `origin: null` and `origin_ref: null`.
- Write acceptance criteria in Given/When/Then format.
- Write tasks/subtasks breakdown.
- Write test scenarios table.
- Write the story file to `docs/implementation-artifacts/{story_key}-{slug}.md`.

> After artifact write: run open-question detection snippet
> `!${CLAUDE_PLUGIN_ROOT}/scripts/detect-open-questions.sh docs/implementation-artifacts/${STORY_KEY}-${SLUG}.md`

### Step 5 -- Register in Sprint Status

- Call `${CLAUDE_PLUGIN_ROOT}/scripts/transition-story-status.sh {story_key} --to backlog` to register the story atomically across the four canonical status surfaces (story-file frontmatter, sprint-status.yaml, epics-and-stories.md, story-index.yaml). This is the unified atomic writer introduced by E54-S3.
- This MUST happen AFTER the story file write has succeeded (story file is source of truth).
- New code MUST call `scripts/transition-story-status.sh {story_key} --to backlog` directly. The legacy deprecation wrapper introduced in E54-S3 still forwards old call sites with a WARNING to stderr, but it is scheduled for removal — do not introduce new dependencies on it.

### Step 6 -- Validation (ADR-050 Shared Val + SM Fix-Loop Dispatch Pattern)

This step implements the six-component dispatch pattern from ADR-050. It replaces the legacy inline checks (15-field frontmatter presence, Given/When/Then AC format, canonical filename) with a full 8-part Val validation, an inline SM fix loop (3-attempt cap), status-sync after every attempt, and a terminal verdict recorded via `review-gate.sh`. E33-S1 is the reference implementation; E33-S2 (`/gaia-validate-story`) reuses the same pattern.

**IMPORTANT — NFR-046 single-spawn-level constraint:** the SM fix runs INLINE using this skill's own `Edit` and `Write` tools. Do NOT spawn a nested SM subagent via the `Agent` or `Task` tool during the fix apply — a Val subagent spawning an SM subagent would be two levels deep and violate NFR-046. Inline SM fix is the canonical pattern.

**Component 1 — Val dispatch.** Invoke the Val (validator) subagent with:
- `context: fork` (isolated validation context)
- `model: claude-opus-4-7` (ADR-074 contract C2 — Val opus pin)
- `effort: high` (ADR-074 contract C2 — Val opus pin)
- read-only tool allowlist: `[Read, Grep, Glob, Bash]`
- `artifact_path`: the story file path written in Step 4
- `source_workflow`: `gaia-create-story`

**Non-opus mismatch guard (ADR-074 contract C2, AC3).** If a test fixture or downstream override forces a non-opus model into the dispatch context, the skill MUST emit the canonical WARNING `Val dispatch on non-opus model — forcing opus per ADR-074 contract C2` and force `model: claude-opus-4-7` before invoking Val. Silent degradation is forbidden — validation rigor is the contract.

[Val opus-pin contract — see plugins/gaia/agents/validator.md §Val Operations]

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

**Component 5 — Status-sync after every attempt (FR-338, NFR-056).** After the fix applies (Component 3), invoke the unified atomic transition script:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/transition-story-status.sh {story_key} --to {new_status}
```

`transition-story-status.sh` (E54-S3) atomically updates ALL FOUR locations the status lives in — the story-file frontmatter, sprint-status.yaml, epics-and-stories.md per-story status indicator, and story-index.yaml — under a shared flock with rollback on partial failure (FR-338, NFR-056). It is the canonical status writer; a legacy deprecation wrapper still forwards old call sites with a stderr warning but is scheduled for removal.

**AC-EC3 — self-transition is benign.** `transition-story-status.sh` treats a self-transition (current status equal to `--to` value) as a no-op: it logs the no-op, performs no writes, and exits 0. Step 6 callers MUST treat this as benign (non-blocking) and proceed to re-validation. Do NOT HALT.

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

**Component 6b — Status transition on terminal verdict (E54-S3 / FR-338).** After the terminal verdict is recorded via `review-gate.sh`, transition the story status via the unified atomic writer. The canonical Step 6 ordering is:

1. `review-gate.sh update --verdict <PASSED|FAILED|UNVERIFIED>` (terminal ledger write)
2. `transition-story-status.sh {story_key} --to <target_status>` (four-file atomic status update)
3. (Step 7) `val-sidecar-write.sh` (memory persistence)

The target status per verdict:

```bash
# PASSED — flip to ready-for-dev (the story is ready for development).
${CLAUDE_PLUGIN_ROOT}/scripts/transition-story-status.sh {story_key} --to ready-for-dev

# FAILED — keep at validating (the story is parked pending /gaia-fix-story).
${CLAUDE_PLUGIN_ROOT}/scripts/transition-story-status.sh {story_key} --to validating

# UNVERIFIED — same as FAILED: keep at validating until validation can complete.
${CLAUDE_PLUGIN_ROOT}/scripts/transition-story-status.sh {story_key} --to validating
```

`transition-story-status.sh` is idempotent (self-transitions are no-ops, see AC-EC3 above), so calling `--to validating` when the story is already at `validating` is harmless.

The ordering is load-bearing: review-gate.sh records the verdict that downstream consumers query; transition-story-status.sh reflects that verdict in the canonical status; val-sidecar-write.sh (Step 7) persists the decision payload referencing both. Reversing any pair leaves a window where queryable state disagrees.

**AC-EC2 — missing review-gate.sh.** If `review-gate.sh` is not present or not executable at Component 6, HALT with an actionable error that references the expected path. Do NOT silently skip the terminal verdict write.

**AC-EC6 — Val timeout / model unavailable.** If Val's `context: fork` invocation times out, crashes, or returns no response, HALT with the canonical message "Val validation could not complete: {reason}" and record the terminal verdict as UNVERIFIED via `review-gate.sh`. Never silently PASSED.

**AC-EC8 / FR-340 — YOLO does not bypass the cap.** YOLO-mode invocations run the same 3-attempt loop with the same terminal verdict rules. YOLO MUST NOT override the cap and MUST NOT override a terminal FAILED verdict. On a YOLO-mode FAILED, HALT with guidance pointing to `/gaia-fix-story {story_key}`.

**E54-S1 / AC6 — YOLO auto-triggers Val dispatch.** When `YOLO_MODE=true`, Step 6 dispatches Val (Component 1 above) immediately after Step 4 file write — no user prompt, no confirmation. The auto-continue applies to the dispatch trigger only; the 3-attempt cap, severity classification, terminal verdict, and HALT-on-FAILED rules are unchanged. There must be zero user prompts between Step 4 (file write) and Step 6 Val dispatch in YOLO mode.

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
