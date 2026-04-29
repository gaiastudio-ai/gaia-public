# gaia-dev-story

Implement a user story end-to-end: load story, plan, TDD (red/green/refactor), commit, push, PR, CI, merge.

## Hooks-in-Skill-Frontmatter Pattern

This skill is the canonical reference implementation of the PostToolUse hook pattern in GAIA skill frontmatter. The pattern works as follows:

### Why `context: fork`

Dev-story uses `context: fork` to run in an isolated subagent context. This scopes the PostToolUse hook's `Edit|Write` matcher to only this skill's execution — preventing the hook from firing on Edit/Write calls in other skills or the main conversation.

Without `context: fork`, the PostToolUse hook would fire globally for every Edit/Write in the session, creating unwanted checkpoint files from unrelated operations.

### How the PostToolUse Hook Works

```yaml
hooks:
  PostToolUse:
    - matcher: "Edit|Write"
      hooks:
        - type: command
          command: ${CLAUDE_SKILL_DIR}/scripts/checkpoint.sh write gaia-dev-story
```

1. Claude Code detects that a tool call matching `Edit|Write` just completed within this skill's fork context.
2. It invokes `scripts/checkpoint.sh write gaia-dev-story` as a post-tool-use hook.
3. The skill-local `checkpoint.sh` wrapper translates this into the shared foundation `checkpoint.sh`'s `--workflow gaia-dev-story --step 0` contract, where `--step 0` is a sentinel value for hook-triggered checkpoints.
4. The shared `checkpoint.sh` writes a YAML checkpoint file to `_memory/checkpoints/gaia-dev-story.yaml` with an atomic temp-file + rename operation.

### Adapting This Pattern

To add PostToolUse hooks to another skill:

1. Copy the `hooks:` block from `_reference-frontmatter.md` into your SKILL.md frontmatter.
2. Change the workflow name in the command to match your skill.
3. Add `context: fork` to isolate hook scope.
4. Ensure your `scripts/checkpoint.sh` wrapper delegates to the shared foundation script.

## Scripts

| Script | Purpose |
|--------|---------|
| `setup.sh` | Config resolution, gate validation, checkpoint load |
| `finalize.sh` | Terminal checkpoint write, lifecycle event |
| `load-story.sh` | Story file lookup via sprint-state.sh |
| `transition-story-status.sh` | Story status transitions (atomic four-surface writer) |
| `git-branch.sh` | Feature branch creation with collision detection |
| `checkpoint.sh` | PostToolUse hook target (wraps shared checkpoint.sh) |
| `sprint-state.sh` | Story state machine transitions |
| `pr-create.sh` | PR creation via gh CLI |
| `ci-wait.sh` | CI status polling with timeout |
| `merge.sh` | PR merge with conflict/protection handling |
