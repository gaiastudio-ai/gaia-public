---
name: gaia-dev-story
description: Implement a user story end-to-end -- validate, dev, test, PR. Use when "dev this story" or /gaia-dev-story.
argument-hint: [story-key]
context: fork
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash]
hooks:
  PostToolUse:
    - matcher: "Edit|Write"
      hooks:
        - type: command
          command: ${CLAUDE_SKILL_DIR}/scripts/checkpoint.sh write gaia-dev-story
---

## Setup

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-dev-story/scripts/setup.sh

## Mission

You are implementing a user story end-to-end: loading the story spec, planning the implementation, writing tests (TDD red), implementing code (TDD green), refactoring, verifying the Definition of Done, committing, pushing, creating a PR, waiting for CI, and merging. This is the most comprehensive dev workflow in GAIA.

This skill is the native Claude Code conversion of the legacy dev-story workflow (brief Cluster 7, story E28-S53). The playbook contains all LLM reasoning guidance. The scripts directory contains all mechanical operations. The PostToolUse hook automatically writes a checkpoint after every Edit or Write tool invocation.

## Critical Rules

- A story file MUST exist at `docs/implementation-artifacts/{story_key}-*.md` before starting. If missing, fail fast with "Story file not found -- run /gaia-create-story first."
- Story status MUST be `ready-for-dev` or `in-progress`. Any other status is a HALT condition.
- Follow TDD cycle strictly: Red (failing tests) -> Green (minimal implementation) -> Refactor. Each phase is a separate step -- NEVER combine them.
- Do NOT write implementation code during the Red phase.
- Do NOT skip the Refactor phase even if Green code looks acceptable.
- All tests MUST pass before marking complete.
- Definition of Done checklist MUST be verified -- every item checked before moving to review.
- When reading or running application source code, use the project path as the base directory.
- All mechanical operations (git, checkpoint, sprint-state, sha256, PR, CI, merge) are handled by scripts -- do NOT inline shell commands in the conversation.
- The PostToolUse hook fires `checkpoint.sh` automatically after every Edit/Write -- you do not need to manually checkpoint file mutations.

## Steps

### Step 1 -- Load Story

- Parse the story key from the argument (e.g., `/gaia-dev-story E1-S2`).
- Run `scripts/load-story.sh {story_key}` to locate and validate the story file.
- Read the story file: extract key, status, acceptance criteria, subtasks, dependencies, risk level.
- Detect execution mode:
  - Status `ready-for-dev` -> FRESH (new implementation)
  - Status `in-progress` with FAILED reviews -> REWORK (fix review issues)
  - Status `in-progress` otherwise -> RESUME (continue from checkpoint)

### Step 2 -- Update Status

- For FRESH mode: run `scripts/update-story-status.sh {story_key} in-progress`.
- For REWORK/RESUME: skip -- story is already in-progress.

<!-- E55-S5: step 2b atdd gate begin -->
### Step 2b -- ATDD Gate (high-risk stories only)

- Run `${CLAUDE_PLUGIN_ROOT}/skills/gaia-dev-story/scripts/atdd-gate.sh {story_key}`.
- The script reads the story's `risk` frontmatter field (canonical) — `risk_level` is a PRD/ADR longhand alias for the same semantic field. If `risk: high`, the script requires at least one ATDD scenarios file matching `atdd-{epic_key}*.md` OR `atdd-{story_key}*.md` under `docs/test-artifacts/`. For `medium`, `low`, or unset risk it exits 0 unconditionally.
- On non-zero exit (high-risk story, no ATDD file): HALT with the script's stderr message naming the expected paths under `docs/test-artifacts/`. Direct the user to `/gaia-atdd {story_key}` to generate the scenarios file before re-running `/gaia-dev-story`.
- On exit 0: proceed to Step 3.
- **Sequencing trade-off:** Step 2b sits AFTER Step 2 (status is already `in-progress`) but BEFORE Step 3 (no feature branch yet). Halting at 2b leaves the story status updated but no branch created — the user reverts status manually (or re-runs /gaia-dev-story after producing the ATDD file) to recover.
<!-- E55-S5: step 2b atdd gate end -->

### Step 3 -- Create Feature Branch

- Run `scripts/git-branch.sh {story_key} {slug}` to create a feature branch.
- The script handles collision detection and offers resume if branch exists.

### Step 4 -- Plan Implementation

- Load the playbook: read `playbook.md` for reasoning guidance.
- For FRESH mode: read architecture.md and ux-design.md for context. Generate a detailed implementation plan covering: context, implementation steps, files to modify, testing strategy, risks.
- For REWORK mode: read failed review reports. Focus plan on fixing review issues.
- For RESUME mode: continue from checkpoint state.
- Render the plan to the user.

<!-- E55-S5: figma graceful-degrade begin -->
**Figma graceful-degrade (FR-DSH-8):** Before rendering the plan, if the story frontmatter has a `figma:` block, probe the Figma MCP server (e.g., `mcp__claude_ai_Figma__whoami`). If the probe fails (server unavailable, auth error, timeout, or the server is not listed):

- Log a single-line warning to stderr: `figma_mcp_unavailable: server={name} fallback=text-only` (NFR-DSH-5 single-line gate-log convention).
- Proceed with text-only context — DO NOT halt, no exception. Plan rendering continues with whatever non-Figma context is available.

Stories without a `figma:` frontmatter block proceed unchanged — this region only fires when Figma context was requested.
<!-- E55-S5: figma graceful-degrade end -->

<!-- E55-S1: planning gate begin -->
<!-- E55-S5: plan-structure validator hook (added by E55-S5) -->

**Plan-structure validator (FR-DSH-4):** BEFORE the planning gate halt fires (E55-S1) and BEFORE the YOLO auto-validation loop (E55-S2), run `${CLAUDE_PLUGIN_ROOT}/skills/gaia-dev-story/scripts/validate-plan-structure.sh` against the rendered plan. Pass `--rework` when the execution mode is REWORK so the `Root Cause` section is required; otherwise the script enforces 8 sections (REWORK-only `Root Cause` skipped).

- The validator reports the FIRST missing canonical section on stderr and exits non-zero. Do NOT advance to the gate halt or the YOLO branch until the validator passes (TC-DSH-10).
- On non-zero exit: log the missing section, instruct the agent to regenerate the plan with the missing section included, then re-run the validator.
- Cap the regenerate loop at 5 attempts to avoid infinite agent loops on a structurally broken plan template. On cap exhaustion, HALT with the last validator stderr and the attempt count so the user can intervene before the gate fires.
- T-38 mitigation: the validator uses `grep -F` with literal ASCII section names — Cyrillic homoglyphs (e.g., `Сontext` U+0421) are correctly treated as MISSING.

After the plan is rendered, the planning gate halts the workflow. YOLO mode detection is the single source of truth that selects the branch -- never re-implement detection inline (per ADR-057, ADR-073).

Run `${CLAUDE_PLUGIN_ROOT}/scripts/yolo-mode.sh is_yolo` to detect YOLO mode. The exit status is the verdict (0 = YOLO active, non-zero = interactive).

If `is_yolo` returns non-zero (non-YOLO branch -- default):
  - The next tool invocation MUST be `AskUserQuestion`. Do NOT invoke any other tool first. In particular, do NOT issue any `Edit` or `Write` tool call to a test file or implementation file between the plan render and the user's response -- the plan the user sees is the plan that gets implemented.
  <!-- E55-S3: three-option prompt body (labels: approve, revise, validate) -->
  - The `AskUserQuestion` prompt body offers exactly three labeled options -- `approve`, `revise`, `validate` -- lowercase, no punctuation, no synonyms. Match TC-DSH-02 expectations exactly. Do NOT add a fourth option (no `skip`, `verify`, `cancel`, etc.).
  - On `approve`: advance to Step 5 TDD Red. Only an explicit `approve` response advances; any other response (including silence) keeps the workflow halted (preserves E55-S1 behavior).
  - On `revise`: ask the user for free-form feedback text via a follow-up `AskUserQuestion` (or harness-equivalent). Pass the feedback to the plan regenerator and regenerate the plan reflecting the feedback. Then re-ask the same three-option question. The `revise` loop is user-driven and unbounded -- there is NO iteration cap; the user decides when to `approve` (TC-DSH-03).
  - On `validate`: route the rendered plan to the `gaia-val-validate` skill via Skill-to-Skill delegation with `context: fork`. Render Val's findings inline, grouped into CRITICAL / WARNING / INFO buckets. Then re-ask the same three-option question. The `validate` loop is user-driven and unbounded -- there is NO iteration cap; the user decides when to `approve` or `revise` (TC-DSH-04). This is intentionally distinct from the YOLO branch's 3-iteration auto-fix cap (E55-S2 / FR-340).
  - Emit a single-line gate log to stderr (NFR-DSH-5): `step4_gate: yolo=false verdict=halted` on entry, then `step4_gate: yolo=false verdict=passed` once the user responds with `approve`. Emit `step4_gate: yolo=false verdict=revise` and `step4_gate: yolo=false verdict=validate` per loop iteration on the corresponding branch.

If `is_yolo` returns zero (YOLO branch):
  <!-- E55-S2: YOLO Val auto-validation loop (added by E55-S2) -->
  - The rendered plan auto-routes to Val for up to 3 iterations of CRITICAL+WARNING auto-fix per ADR-073. The YOLO branch MUST NOT issue any user-prompt tool call; the next tool invocation MUST be the `gaia-val-validate` skill on the rendered plan with `context: fork`. Auto-fix is inline using this skill's own `Edit`/`Write` tools (NFR-046 single-spawn-level) — no nested subagent spawn inside the loop.
  - **T-37 path-traversal mitigation (AC5):** BEFORE constructing the audit-file path, validate `story_key` against the regex `^E[0-9]+-S[0-9]+$`. On mismatch, abort the YOLO branch with a clear error and emit no writes — never sanitize-and-continue. Reference shell idiom: `printf '%s\n' "$story_key" | grep -Eq '^E[0-9]+-S[0-9]+$'`.
  - **Audit file (AC2):** persist findings to `_memory/checkpoints/{story_key}-yolo-plan-findings.md` on every iteration. Append per iteration — never overwrite, never truncate. Two consecutive YOLO runs on the same story append a fresh set of `## Iteration {N} — {timestamp}` sections under the existing ones; entries from prior runs MUST be preserved verbatim. Each section body is the structured findings JSON or YAML returned by Val.
  - **Checkpoint persistence (AC4):** record the YOLO flag, the current iteration count, and the `last-findings-hash` (sha256 of the latest findings JSON) via `${CLAUDE_PLUGIN_ROOT}/scripts/append-val-iteration.sh` (which delegates to `write-checkpoint.sh`). Comparing `last-findings-hash` across iterations identifies oscillation; log stalls to the Dev Agent Record but DO NOT short-circuit the loop — the 3-iteration cap is the hard backstop.
  - **ADR-073 canonical pseudocode (DoD documentation requirement):**

```
iteration = 0
while iteration < 3:
  findings = val.validate(plan)            # gaia-val-validate, severity in {CRITICAL, WARNING, INFO}
  critical = filter(findings, severity="CRITICAL")
  warning  = filter(findings, severity="WARNING")
  audit_append(iteration, findings)        # _memory/checkpoints/{story_key}-yolo-plan-findings.md
  checkpoint_record(yolo=true, iteration, sha256(findings))
  if not critical and not warning:         # INFO-only or empty -> break (AC3)
    break
  apply_fixes(critical + warning)          # inline Edit/Write — no subagent spawn
  iteration += 1
if iteration == 3 and (critical or warning):
  HALT with remaining findings + audit-file path -> /gaia-fix-story  # AC2 cap (FR-340)
else:
  proceed to Step 5
```

  - **Halt-on-exhaust behavior (AC2):** if the loop exhausts the 3-iteration cap with remaining CRITICAL or WARNING findings, HALT with an actionable message that names the remaining findings and points to `_memory/checkpoints/{story_key}-yolo-plan-findings.md`. Direct the user to `/gaia-fix-story` or to re-run with the audit file as context. YOLO MUST NOT bypass the cap (FR-340).
  - **INFO-only break (AC3):** if Val returns INFO-only findings (or no findings) on any iteration, break the loop and proceed to Step 5 immediately — INFO findings are advisory and never gating.
  - **Resume semantics (AC4):** when `/gaia-resume` re-enters this branch, read the checkpoint to recover yolo flag + iteration count + last-findings-hash, then re-enter the loop at the recorded iteration. If the next iteration's findings hash matches the recorded one, log the stall and continue.
  - **No inline YOLO detection (AC6):** YOLO detection has already happened at the gate dispatch above. This branch body MUST NOT redefine or re-implement YOLO detection — single-source-of-truth per ADR-057 / ADR-073. The branch is selected by the surrounding gate; the body simply consumes the verdict.
  - **Soft dependency on E41-S5 (`yolo_steps:` wiring):** if E41-S5 has landed, the per-step YOLO list selects this branch via the wired entry point; if not, this branch is reached via the script-call fallback at the gate dispatch above — never inline.
  - Emit a single-line gate log to stderr per iteration (NFR-DSH-5): `step4_gate: yolo=true iteration={N} outcome={clean|info_only|findings_present}` (the `outcome` enum mirrors `append-val-iteration.sh --revalidation-outcome`). On loop exit emit a terminal verdict: `step4_gate: yolo=true verdict=passed` when the loop broke on clean / info_only, or `step4_gate: yolo=true verdict=halted` when the 3-iteration cap was reached with remaining CRITICAL or WARNING findings.

Backward-compatibility note (NFR-DSH-3): a resumed in-progress story with no Step 4 gate-clearance record on the checkpoint is treated as "halt not yet presented" and re-issues the halt -- it does NOT silently advance to Step 5.

<!-- E55-S1: planning gate end -->

### Step 5 -- TDD Red Phase (Write Failing Tests)

- Follow the playbook's test strategy reasoning.
- For each subtask: write failing test(s) that define expected behavior.
- Run the test suite -- verify all new tests FAIL.
- Tests MUST fail because implementation does not exist yet. If a test passes without implementation, it is vacuous and must be rewritten.

### Step 6 -- TDD Green Phase (Implement to Pass)

- Follow the playbook's design approach reasoning.
- For each subtask: implement minimum code to make failing tests pass.
- Run the test suite -- verify all tests PASS.
- Mark each completed subtask in the story file.

### Step 7 -- TDD Refactor Phase

- Improve code quality while keeping all tests green.
- Extract shared utilities, decompose large functions, improve naming, remove duplication.
- Run the test suite -- verify all tests STILL PASS.

### Step 8 -- Capture Findings

- Review any out-of-scope issues discovered during implementation.
- Add findings to the story file's Findings table.

### Step 9 -- Definition of Done

- Verify all DoD items: code compiles, tests pass, ACs met, no lint errors, conventions followed, no secrets, subtasks complete, docs updated.
- Auto-fix failing items up to 3 iterations.

### Step 10 -- Commit and Push

- Run `scripts/git-branch.sh` to verify branch state.
- Stage and commit with conventional commit format.
- Run `scripts/update-story-status.sh {story_key} review` after all gates pass.

### Step 11 -- Create PR

- Run `scripts/pr-create.sh {story_key} {title}` to create a pull request.
- The script targets the first promotion chain environment.

### Step 12 -- Wait for CI

- Run `scripts/ci-wait.sh {pr_number}` to poll CI status.
- The script handles timeout, transient errors, and failure reporting.

### Step 13 -- Merge PR

- Run `scripts/merge.sh {pr_number} {story_key}` to merge the PR.
- The script handles conflict detection, branch protection, and strategy selection.

### Step 14 -- Post-Completion Gate

- After the dev-story subagent returns `status=done`, the orchestrator verifies that a merge commit containing the story key actually exists on the target branch before accepting the done transition.
- Run `scripts/verify-pr-merged.sh {story_key} {target_branch}` where `{target_branch}` is derived from `ci_cd.promotion_chain[0].branch` in global.yaml.
- If no promotion chain is configured, pass `--no-chain` instead of a branch name. The script exits 3 (skip) and the gate passes silently for backward compatibility.
- **Exit code 0 (pass):** Merge commit found on target branch. Proceed to Step 15.
- **Exit code 2 (fail):** No merge commit found. The orchestrator re-runs Steps 10-13 (commit, push, create PR, wait for CI, merge) in the main orchestrator context before advancing the story to done. This handles the case where the subagent completed implementation but failed to push or merge.
- **Word-boundary matching:** The script uses `\b{story_key}\b` grep patterns to avoid false positives on partial key matches (e.g., E20-S1 must not match E20-S19). Matching is case-insensitive to handle squash-merge message rewrites.
- **Historical failure modes that motivated this gate:**
  - **E17-S1 (sprint-17):** Dev-story subagent completed implementation but never pushed commits. Orchestrator accepted `status=done` at face value. Sprint closed with unmerged code.
  - **E28-S213 (sprint-25):** Dev-story subagent completed all reviews but skipped push/PR/merge steps. Same outcome -- orchestrator trusted the status and sprint closed without the code landing.

### Step 15 -- Update Review Gate

- Initialize the Review Gate table in the story file: all 6 rows set to UNVERIFIED.
- Update story status to `review`.

## Finalize

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-dev-story/scripts/finalize.sh
