---
name: gaia-resume
description: "Resume from the last checkpoint after context loss or a session break. Lists active checkpoints from _memory/checkpoints/, reads the selected one via checkpoint.sh read, validates it via checkpoint.sh validate, and surfaces a Proceed / Start fresh / Review prompt if validation detects drift or missing files. Use when 'resume' or /gaia-resume."
allowed-tools: [Bash, Read, Glob]
---

## Mission

You are the **GAIA resume system**. Your job is to reconnect a user with an interrupted workflow after context loss or a session break — without re-running completed steps. You do that by (1) listing checkpoint files under `_memory/checkpoints/`, (2) having the user pick one (or auto-picking when only one is active), (3) invoking `checkpoint.sh read` to load the recorded workflow state, (4) invoking `checkpoint.sh validate` to confirm the `files_touched` integrity, and (5) on any validation failure, surfacing a **Proceed / Start fresh / Review** prompt so the user decides how to recover.

This skill is the native Claude Code `/gaia-resume` entry point. Per **ADR-042** (Scripts-over-LLM for Deterministic Operations), all deterministic checkpoint work — listing, reading, sha256 integrity checks — is delegated to `plugins/gaia/scripts/checkpoint.sh`. The skill body only orchestrates the conversation: prompt the user, invoke the script, interpret exit codes, and hand off to the resumed workflow.

## When to Use

Invoke `/gaia-resume` when:
- You have just returned from **context loss** or a **session break** and need to pick up the last workflow where it left off.
- Claude Code was interrupted mid-workflow (e.g., `/gaia-dev-story` crashed, `/gaia-create-story` was paused) and a checkpoint file exists under `_memory/checkpoints/`.
- You want to inspect which workflows have an active checkpoint before deciding to resume, restart, or discard them.

Do NOT invoke `/gaia-resume` when:
- You want to start a fresh workflow from the beginning — use the specific slash command (e.g., `/gaia-dev-story`) directly.
- No checkpoint exists in `_memory/checkpoints/` — this skill will report "no active workflows to resume" and exit.

## Critical Rules

- **Delegate all checkpoint I/O to scripts.** For V1 YAML checkpoints, use `checkpoint.sh read` / `checkpoint.sh validate` (E28-S136). For V2 JSON per-skill checkpoints (ADR-059, E43 cluster), delegate discovery, temp-file filtering, and corruption classification to `resume-discovery.sh` (E43-S7). Do NOT parse checkpoint YAML/JSON, compute sha256 checksums, filter orphan temp files, or re-implement drift / corruption detection in the LLM layer — the scripts are the single source of truth (ADR-042).
- **Never silently resume past a validation failure.** If `checkpoint.sh validate` returns a non-zero exit code, the user MUST be prompted with Proceed / Start fresh / Review. Auto-resuming past drift or missing files is a protocol violation.
- **Never silently resume past a corruption failure.** If `resume-discovery.sh` exits 3 (corrupted checkpoint), the user MUST see the classified `corrupted checkpoint: {path} — {reason}. Suggestion: re-run /gaia-{skill} from scratch, or select a different checkpoint from {dir}.` message and be offered a re-run or fallback path. Never auto-retry past a corrupted checkpoint.
- **Exclude the `completed/` subdirectory when listing active checkpoints.** Archived checkpoints under `_memory/checkpoints/completed/` represent finished workflows and are not resumable. Only live checkpoint files directly under `_memory/checkpoints/` are candidates.
- **Filter orphan temp files and non-canonical filenames during discovery.** The V2 checkpoint writer (`write-checkpoint.sh`) uses an atomic write pattern (`{FINAL}.tmp.$$` renamed to `{FINAL}`). If a crash leaves an orphan temp file behind, the discovery logic (`resume-discovery.sh`) MUST ignore it during resume routing and surface it to the user as cleanup guidance — never attempt to parse a temp file or non-canonical filename as a valid checkpoint.
- **Read-only with respect to checkpoint files.** This skill does NOT write, delete, or modify any checkpoint file. It invokes read/validate/discovery subcommands only; any resumption that proceeds past this skill re-enters the owning workflow, which is responsible for its own checkpoint writes.
- **Never invent a checkpoint or workflow name.** If the user's input does not match a real checkpoint file under `_memory/checkpoints/`, report the mismatch and re-prompt — do not fabricate a resume target.

## Inputs

- `$ARGUMENTS`: optional workflow name (the stem of the checkpoint file, e.g., `dev-story-E28-S173`). If supplied, skip the interactive list and jump directly to Step 3 with that workflow name. If omitted, run Step 1 and Step 2.

## Steps

### Step 1 — List Active Checkpoints

Use the **Glob** tool to discover checkpoint files:

- Pattern: `_memory/checkpoints/*.yaml`
- Exclude: any path containing `_memory/checkpoints/completed/` (archived, not resumable).

If the glob returns zero matches, print `No active workflows to resume.` and suggest `/gaia` as the next step. Exit the skill — do not proceed to Step 2.

If the glob returns one or more matches, render a numbered list showing each checkpoint's filename stem (the workflow name) and, if the **Read** tool is available, the `workflow`, `step`, and `timestamp` fields from the YAML header of each file:

```
Active checkpoints:

1. dev-story-E28-S173 — step 7 (green_complete) at 2026-04-17T13:45:22Z
2. create-story-E28-S180 — step 4 at 2026-04-17T09:12:05Z
```

### Step 2 — Select a Checkpoint

- If exactly one checkpoint exists: confirm with the user "Resume `{name}`? [y/n]". On `y`, proceed to Step 3 with that name. On `n`, exit with "Resume cancelled."
- If multiple checkpoints exist: ask the user to pick by number or workflow name. If the input is ambiguous or does not match, re-prompt — do not guess.
- If `$ARGUMENTS` was supplied, skip this step and use that value as the selected workflow name.

### Step 3 — Read the Checkpoint

Invoke the checkpoint reader to load the recorded workflow state:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/checkpoint.sh" read --workflow "{selected_name}"
```

On exit 0, the script prints the checkpoint YAML to stdout. Capture `workflow`, `step`, `timestamp`, `variables`, and `files_touched` for use in Step 5.

On exit 2 ("checkpoint not found"), report the missing file path to the user and return to Step 1. Do NOT fabricate a checkpoint.

On exit 1 (usage error), surface the stderr message verbatim and exit the skill.

### Step 4 — Validate File Integrity

Invoke the checkpoint validator to verify that every file recorded in `files_touched` still exists and still has the same sha256 checksum:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/checkpoint.sh" validate --workflow "{selected_name}"
```

Interpret the exit codes:

- **exit 0 — clean.** All recorded files exist and every sha256 matches. Report `All files unchanged since checkpoint — safe to resume.` and proceed directly to Step 6.
- **exit 1 — drift.** One or more files have changed (different sha256) since the checkpoint was written. The script prints `drift: <path>` lines on stderr for each changed file. Proceed to Step 5 with the drift list.
- **exit 2 — missing file.** One or more recorded files have been deleted since the checkpoint was written. The script prints `missing file: <path>` lines on stderr. Proceed to Step 5 with the missing list.

Never silently resume past a non-zero exit — always branch into Step 5 so the user sees the mismatch and chooses the recovery path.

### Step 5 — Proceed / Start Fresh / Review

When validation returns exit 1 (drift) or exit 2 (missing file), render the list of affected files and present the three-option prompt:

```
Validation detected {N} changed file(s) since the checkpoint was written:

- {path} — DRIFT (sha256 does not match)
- {path} — DELETED (file no longer exists)

Choose how to recover:

[Proceed]      Resume anyway — the workflow re-enters at the recorded step.
               The changed files will be re-processed by the workflow.

[Start fresh]  Discard this checkpoint and re-run the workflow from the
               beginning. The checkpoint file is left in place; the workflow
               will overwrite it on the next write.

[Review]       Show `git diff HEAD -- {paths}` for each changed file so you
               can inspect the delta, then re-prompt with these three options.
```

Wait for the user to pick exactly one of **Proceed**, **Start fresh**, or **Review**.

- **Proceed:** continue to Step 6.
- **Start fresh:** exit the skill and suggest re-running the owning slash command (e.g., `/gaia-dev-story`) from its normal entry point.
- **Review:** for each changed file, run `git diff HEAD -- {path}` (if the project is a git repo) or show a summary of the checksum mismatch (if not), then loop back to the Proceed / Start fresh / Review prompt.

### Step 6 — Hand Off to the Owning Workflow

Once validation is clean (Step 4 exit 0) or the user chose **Proceed** in Step 5:

- Announce: `Resuming {workflow} at step {step}.`
- Instruct the user to re-invoke the owning slash command (derived from the checkpoint's `workflow` field — for example, `dev-story-E28-S173` → `/gaia-dev-story E28-S173`). The owning workflow is responsible for reading its own checkpoint via `checkpoint.sh read` on re-entry and skipping to the recorded step.
- This skill exits after the handoff. It does NOT execute workflow steps itself.

## V2 Checkpoint Discovery (E43, per-skill JSON checkpoints)

The V2 checkpoint infrastructure introduced by E43 writes per-skill JSON checkpoints under `_memory/checkpoints/{skill_name}/{ISO8601-microseconds-Z}-step-{N}.json`. When the user requests resume for a V2 skill (any of the 24 Phase 1–3 skills wired in E43-S2..S5), delegate discovery, temp-file filtering, and corruption classification to `resume-discovery.sh`:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/resume-discovery.sh" "{skill_name}"
```

### Reserved exit codes for V2 resume

- **0 — success.** The path of the latest valid checkpoint is printed to stdout; any cleanup guidance (orphan temp files, non-canonical filenames) is emitted BEFORE the path so the user can clean up their workspace.
- **1 — usage / invalid argument.** Generic failure exit.
- **2 — no checkpoint found for skill** (after filtering). The user has never run this skill or all files in the skill directory were filtered as temp / non-canonical. Suggest `/gaia-{skill_name}` to start fresh.
- **3 — corrupted checkpoint.** The latest candidate failed to parse as JSON. The script emits a classified message of shape `corrupted checkpoint: {path} — {reason}. Suggestion: re-run /gaia-{skill_name} from scratch, or select a different checkpoint from {dir}.` along with any additional corrupted checkpoint paths and a count of uncorrupted earlier checkpoints (user may resume from an earlier step rather than re-run from scratch).

### Temp-file and non-canonical filtering

`resume-discovery.sh` filters out any file matching these patterns from the candidate list and reports them as cleanup guidance:

- `{canonical}.tmp.{pid}` — the atomic-write temp produced by `write-checkpoint.sh` and renamed on successful write; surviving tmp files indicate a crash mid-write.
- `.tmp-*.json` — leading-dot alternate convention (defensive).
- `*.partial` — alternate convention (defensive).
- Any filename not matching the canonical pattern `{ISO8601-microseconds-Z}-step-{N}.json` — reported under cleanup guidance but never parsed as a checkpoint.

Cleanup guidance is informational only — `/gaia-resume` proceeds with the filtered candidate list without blocking on leftover files.

### Corruption-detection control flow

```text
candidates = list_checkpoints(skill_dir)
    # filter out temp-file patterns and non-canonical filenames;
    # report them as cleanup guidance before any resume action.
latest = candidates.sort_by_timestamp.last
if latest is None:
    emit "no checkpoint found for {skill}"; exit 2
try:
    checkpoint = json.load(latest)
except JSONDecodeError as reason:
    emit "corrupted checkpoint: {latest} — {reason}. Suggestion: re-run /gaia-{skill} from scratch."
    # also report earlier corrupted checkpoints and count of uncorrupted ones
    exit 3
# continue with checksum verification (E43-S6) …
```

No code path emits an unhandled parse error, stack trace, or bare `command not found` to the user — every error is caught, classified, and reported with an actionable message. This is the corruption-handling contract operationalized by E43-S7 (ADR-059 resilience clause).

## References

- `plugins/gaia/scripts/checkpoint.sh` — the deterministic V1 YAML checkpoint primitive (write / read / validate) from E28-S136.
- `plugins/gaia/scripts/write-checkpoint.sh` — the deterministic V2 JSON per-skill checkpoint writer (atomic temp-file rename) from E43-S1.
- `plugins/gaia/scripts/resume-discovery.sh` — the V2 discovery + corruption classifier (temp-file filtering, non-canonical filtering, JSON parse guard, cleanup guidance) from E43-S7.
- `_memory/checkpoints/` — active checkpoint files; `_memory/checkpoints/completed/` — archived, non-resumable.
- `${CLAUDE_PLUGIN_ROOT}/knowledge/gaia-help.csv` — registers `/gaia-resume` so `/gaia-help` can discover it.
- ADR-041: Native Execution Model via Claude Code Skills + Subagents + Plugins + Hooks.
- ADR-042: Scripts-over-LLM for Deterministic Operations.
- ADR-048: Engine Deletion as Program-Closing Action — legacy command coexists with this skill until program close.
- E28-S136: V1 checkpoint primitive foundation (write / read / validate, sha256 integrity).
- E43-S1: V2 checkpoint schema v1 + atomic `write-checkpoint.sh` helper.
- E43-S7: V2 checkpoint failure-mode handling (corruption, partial writes, orphan temp filtering) — this skill's delegation to `resume-discovery.sh`.
- FR-323: Skill Conversion — slash-command identity preserved.
- FR-342: Per-skill checkpoint/resume contract.
- ADR-059: V2 checkpoint schema + atomic write + resume contract.
- NFR-VCP-1: Checkpoint schema consistency across skills.
