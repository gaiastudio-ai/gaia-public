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

### Step 3 -- Create Feature Branch

- Run `scripts/git-branch.sh {story_key} {slug}` to create a feature branch.
- The script handles collision detection and offers resume if branch exists.

### Step 4 -- Plan Implementation

- Load the playbook: read `playbook.md` for reasoning guidance.
- For FRESH mode: read architecture.md and ux-design.md for context. Generate a detailed implementation plan covering: context, implementation steps, files to modify, testing strategy, risks.
- For REWORK mode: read failed review reports. Focus plan on fixing review issues.
- For RESUME mode: continue from checkpoint state.
- Render the plan to the user.

<!-- E55-S1: planning gate begin -->
<!-- E55-S5: plan-structure validator hook (added by E55-S5) -->

After the plan is rendered, the planning gate halts the workflow. YOLO mode detection is the single source of truth that selects the branch -- never re-implement detection inline (per ADR-057, ADR-073).

Run `${CLAUDE_PLUGIN_ROOT}/scripts/yolo-mode.sh is_yolo` to detect YOLO mode. The exit status is the verdict (0 = YOLO active, non-zero = interactive).

If `is_yolo` returns non-zero (non-YOLO branch -- default):
  - The next tool invocation MUST be `AskUserQuestion`. Do NOT invoke any other tool first. In particular, do NOT issue any `Edit` or `Write` tool call to a test file or implementation file between the plan render and the user's response -- the plan the user sees is the plan that gets implemented.
  - The `AskUserQuestion` prompt body offers a single option for E55-S1: `approve` -> advance to Step 5 TDD Red.
  <!-- E55-S3: three-option prompt body (replaces single-approve in E55-S3) -->
  - Only an explicit `approve` response from the user advances to Step 5. Any other response (including silence) keeps the workflow halted.
  - Emit a single-line gate log to stderr (NFR-DSH-5): `step4_gate: yolo=false verdict=halted` on entry, then `step4_gate: yolo=false verdict=passed` once the user responds with approve.

If `is_yolo` returns zero (YOLO branch -- E55-S1 placeholder, full loop lands in E55-S2):
  <!-- E55-S2: YOLO Val auto-validation loop (added by E55-S2) -->
  - For E55-S1 this branch is a no-op pass-through to Step 5. The YOLO Val auto-validation loop semantics (`(critical|warning|info, max_iter=3)` per ADR-073) land in E55-S2.
  - Emit a single-line gate log to stderr (NFR-DSH-5): `step4_gate: yolo=true verdict=passed`.

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
