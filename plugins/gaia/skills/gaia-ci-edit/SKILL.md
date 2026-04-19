---
name: gaia-ci-edit
description: Edit the ci_cd.promotion_chain in global.yaml — add, remove, edit, or reorder environments. Use when "edit CI config" or /gaia-ci-edit.
argument-hint: "[--add|--remove|--edit|--order] [env-id]"
tools: Read, Grep, Glob, Bash, Write, Edit
---

## Setup

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-ci-edit/scripts/setup.sh

## Mission

You are editing the `ci_cd.promotion_chain` array in `global.yaml`. You read the current chain, present a CRUD menu (add, remove, edit, reorder), validate changes against the E20-S1 schema, write back preserving the canonical field order (id, name, branch, ci_provider, merge_strategy, ci_checks), and cascade updates to dependent files.

This skill is the native Claude Code conversion of the legacy `_gaia/testing/workflows/ci-edit` workflow (Cluster 11, story E28-S86, ADR-042). It follows the canonical skill pattern established by E28-S66 (code-review).

**Write context:** This skill uses `allowed-tools: Read Grep Glob Bash Write Edit` because it modifies `global.yaml` and cascades changes to CI config files and test-environment.yaml.

**Foundation script integration (ADR-042):** This skill invokes `validate-gate.sh` from `plugins/gaia/scripts/` for post-edit CI gate verification. Deterministic operations (config resolution, gate verification, YAML manipulation) belong in bash scripts, not LLM prompts.

**Schema reference (ADR-033):** The promotion chain uses the multi-environment format defined in `global.yaml`. Each entry has: id, name, branch, ci_provider, merge_strategy, ci_checks. The canonical field order MUST be preserved on every write-back operation to ensure round-trip fidelity through YAML parsers.

## Critical Rules

- The `id` field of every entry is immutable (ADR-033). Edits that attempt to change `id` MUST be rejected.
- Every CRUD operation MUST be followed by full chain re-validation. Partial updates are not permitted.
- An operation that would leave zero entries in the chain is ALWAYS blocked. The chain must contain at least 1 environment at all times (AC-EC6).
- When `promotion_chain` is an empty array in `global.yaml`, the skill MUST handle gracefully and allow adding the first environment without error (AC-EC2).
- If the `ci_cd` section contains malformed YAML, the skill MUST detect the parse failure, report the malformed section, and refuse to write changes (AC-EC4).
- The `validate-gate.sh` foundation script (E28-S15) MUST be present and executable. If missing or not executable, HALT with: "validate-gate.sh not found or not executable -- dependency E28-S15 must be installed first" (AC-EC3, AC-EC5).
- Remove and Edit operations MUST run the safety scan first (checkpoints, stories, test-environment.yaml) and require explicit user confirmation when references are found.
- Only the `ci_cd.promotion_chain` block in `global.yaml` may be modified -- all other fields and comments MUST be preserved exactly.
- Sprint-status.yaml is NEVER written by this skill (Sprint-Status Write Safety rule).
- The canonical field order (id, name, branch, ci_provider, merge_strategy, ci_checks) MUST be preserved on write-back (AC4).

## Steps

### Step 1 -- Load Current Promotion Chain

- Read `global.yaml` in full. Preserve all fields and comments.
- Check whether `ci_cd` block exists and contains a `promotion_chain` array.
- If `ci_cd` block absent or `promotion_chain` field missing: display "No promotion chain configured. Run `/gaia-ci-setup` first." and HALT.
- If `promotion_chain` is an empty array: allow adding the first environment (AC-EC2).
- If YAML parsing fails on the `ci_cd` section: report the malformed section and refuse to proceed (AC-EC4).
- Render the current chain as a formatted table: position, id, branch, environment, merge_strategy, ci_provider.

### Step 2 -- Present Operation Menu

- Present the CRUD operation menu:
  - `[a]` add -- insert a new environment into the chain
  - `[r]` remove -- delete an existing environment (with safety scan)
  - `[e]` edit -- modify fields of an existing environment (id is immutable)
  - `[o]` order -- reorder the chain (warns on position 0 change)
  - `[v]` view -- re-render the current chain table
  - `[x]` exit -- close without writing

### Step 3 -- Add Operation

- Prompt for each required field in canonical order: id (slug format), name, branch, ci_provider (enum), merge_strategy (enum), ci_checks (optional array).
- Ask for insertion position (0-based index, or append).
- Reject duplicate id or branch values.
- Proceed to validation step.

### Step 4 -- Remove Operation

- Prompt for the id of the environment to remove.
- If chain length is 1: HALT -- "Cannot remove the last environment. The promotion chain must have at least 1 environment. Add a replacement first, or use `/gaia-ci-setup` to reset the chain." (AC-EC6)
- Run safety scan (checkpoints, stories, test-environment.yaml).
- If references found: require explicit user confirmation before proceeding.
- Proceed to validation step.

### Step 5 -- Edit Operation

- Prompt for the id of the environment to edit. Display current field values.
- Allow modification of: branch, name, test_tiers, merge_strategy, auto_merge, approval_required, ci_provider, ci_checks.
- If user attempts to edit `id`: reject with "Field 'id' is immutable (ADR-033). To rename, remove this entry and add a new one."
- Run safety scan before applying if branch is being changed.
- Proceed to validation step.

### Step 6 -- Reorder Operation

- Render the current chain as a numbered list.
- Prompt for the new order as a comma-separated list of ids.
- If reorder changes position 0: warn that this changes the PR target for all feature branches and require explicit confirmation.
- Proceed to validation step.

### Step 7 -- Validate, Write, and Cascade

- Validate the modified chain: minimum 1 entry, unique ids, unique branches, required fields, valid enums, id slug pattern.
- If validation fails: display violations and return to the operation menu without writing.
- Write the updated chain back to `global.yaml`. Only `ci_cd.promotion_chain` may be modified.
- Preserve the canonical field order on write-back (AC4): id, name, branch, ci_provider, merge_strategy, ci_checks.
- Cascade updates: update CI workflow triggers if branch names changed, update test-environment.yaml tier mappings, regenerate ci-setup.md.
- On cascade failure: report the specific error, do NOT rollback `global.yaml` silently.

### Step 8 -- Summary

- Display: operation performed, entries affected, position 0 changes, cascade results, warnings.
- Remind user to commit updated files on a feature branch.

## Finalize

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-ci-edit/scripts/finalize.sh
