# Reference Frontmatter — gaia-dev-story

This is the canonical reference for the hooks-in-skill-frontmatter pattern,
copied verbatim from the GAIA Native Conversion feature brief (P7-S2).
Future skill conversions that need PostToolUse hooks should copy from this file.

```yaml
---
name: gaia-dev-story
description: Implement a user story end-to-end -- validate, dev, test, PR. Use when "dev this story" or /gaia-dev-story.
argument-hint: [story-key]
context: fork
allowed-tools: Read Write Edit Grep Glob Bash
hooks:
  PostToolUse:
    - matcher: "Edit|Write"
      hooks:
        - type: command
          command: ${CLAUDE_SKILL_DIR}/scripts/checkpoint.sh write gaia-dev-story
---
```

## Pattern Notes

- `context: fork` ensures the skill runs in an isolated subagent context so the PostToolUse hook's tool-matching is scoped to this skill's execution only.
- `allowed-tools` lists the canonical minimum for a dev workflow. The frontmatter linter should reject additions or removals without documented rationale.
- The `PostToolUse` hook fires `checkpoint.sh` after every `Edit` or `Write` tool invocation, providing automatic checkpointing of file mutations.
- `${CLAUDE_SKILL_DIR}` is resolved by Claude Code at runtime to the skill's directory path.
- `checkpoint.sh` must be idempotent and use atomic writes (temp file + rename) to survive rapid Edit sequences.
