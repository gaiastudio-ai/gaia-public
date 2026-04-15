# GAIA Subagent Frontmatter Schema

**Status:** Canonical reference for E28-S19..S23 native conversion cluster.
**Owner:** GAIA Native Conversion Program (Epic E28).
**Pinned from:** E28-S1 Claude Code marketplace schema pin.

This document enumerates every YAML frontmatter field permitted on a GAIA
subagent file under `plugins/gaia/agents/`. Every agent file converted under
E28-S19..S23 MUST conform to this schema. New fields MAY NOT be introduced
without an ADR amending ADR-041.

## References

- **ADR-041 — Native Execution:**
  `docs/planning-artifacts/architecture.md#ADR-041 Native Execution`.
  ADR-041 establishes that GAIA subagents run as native Claude Code subagents,
  not under the legacy `_gaia/core/engine/workflow.xml` engine. This schema is
  the concrete frontmatter contract that makes native execution possible.
- **Feature Brief — GAIA Native Conversion:**
  `docs/creative-artifacts/gaia-native-conversion-feature-brief-2026-04-14.md`
  (specifically the Cluster 3 subagent pattern section, P3-S1). The feature
  brief defines the `name` / `model` / `description` / `context` / `allowed-tools`
  shape and the `## Memory` loader pattern that this schema enforces.

Both documents are load-bearing: any conflict between this schema and those
sources MUST be resolved by amending ADR-041 (the architecture decision record),
which then cascades back into this file.

## Required fields

| Field | Type | Required | Allowed values | Description |
|-------|------|----------|----------------|-------------|
| `name` | string | Yes | Lowercase kebab-case identifier matching the filename (sans `.md`). `_`-prefixed names are reserved for abstract/template files (e.g., `_base-dev`). | Canonical agent id. Used by Claude Code to address the subagent and by GAIA tooling (memory-loader, review-gate) as the key. |
| `model` | string | Yes | One of: `claude-opus-4-6`, `claude-sonnet-4-5`, `claude-haiku-4-5`, or `inherit`. | Model the subagent runs on. `inherit` defers to the parent session model. Dev and review agents typically pin `claude-opus-4-6`; lightweight helpers pin `claude-haiku-4-5`. |
| `description` | string | Yes | Non-empty single-line human description, max 240 characters. | Shown in orchestrator routing menus and used by the Claude Code marketplace. MUST begin with the agent's role, not a verb. |
| `context` | string | Yes | `main` or `fork`. | `main` = the subagent runs in the calling session's context (dev agents, orchestration helpers). `fork` = the subagent runs in an isolated forked context window (review gate agents, evaluators that must not pollute the main context). `_base-dev` and all stack dev agents MUST use `main`. `fork` is reserved for review gate agents converted in a later cluster. |
| `allowed-tools` | list[string] | Yes | Subset of the Claude Code tool set: `Read`, `Write`, `Edit`, `Bash`, `Grep`, `Glob`, `WebFetch`, `WebSearch`, `Task`. Ordering is not significant. | Whitelist of tools the subagent may call. MUST be the minimum set required. Dev agents get the full code-editing set; review agents get `Read, Grep, Glob` plus whatever is needed to emit a report. |

## Optional fields

| Field | Type | Required | Allowed values | Description |
|-------|------|----------|----------------|-------------|
| `abstract` | bool | No (default `false`) | `true` or `false` | Marks a template file that cannot be invoked directly (e.g., `_base-dev`). Abstract agents are skipped by `reload-plugins` discovery but MUST still pass this schema. |
| `aliases` | list[string] | No | List of lowercase kebab-case strings. | Alternate names the orchestrator accepts when routing. Used for persona names (e.g., `cleo` as an alias for `dev-typescript`). |
| `tags` | list[string] | No | Free-form lowercase tags. | Used by orchestrator search and marketplace categorization. |

## Forbidden fields

The following fields were used by the legacy `_gaia/` engine and MUST NOT appear
in any file under `plugins/gaia/agents/`:

- `template:` — legacy engine templating marker.
- `version:` on agent files — versioning is tracked by the plugin manifest, not per-agent.
- `used_by:` — legacy workflow engine routing hint.
- Any XML blocks (`<agent>`, `<memory-reads>`, `<shared-behavior>`, `<specification>`,
  `<rules>`, `<quality-gates>`, `<skill-registry>`) in the body. Native subagents
  use plain Markdown; XML is parsed by the legacy engine only.

## Body structure

Subagent bodies under native execution MUST follow this top-level section order:

1. `## Memory` — inline bash memory loader invocation (see below).
2. `## Mission` — one-paragraph mission statement.
3. `## Persona` — ported from legacy persona block.
4. `## Rules` — bulleted non-negotiables.
5. `## Skills` — JIT skill references (by skill id, resolved at runtime).
6. Any domain-specific sections (Scope, Authority, DoD, Constraints).

## Memory loader pattern

Every non-abstract subagent — and `_base-dev` as the shared template — MUST
include a `## Memory` section that invokes the memory loader as inline bash:

```markdown
## Memory

!${PLUGIN_DIR}/scripts/memory-loader.sh <agent-name> all
```

- `${PLUGIN_DIR}` is resolved by Claude Code at subagent spawn time to the
  plugin's installed directory.
- The first argument is the agent name (matching the `name:` field).
- The second argument is the memory scope: `all` | `recent` | `ground-truth`.
- `memory-loader.sh` is delivered by E28-S13 and lives at
  `plugins/gaia/scripts/memory-loader.sh`. Its CLI shape is considered stable
  once E28-S13 ships; this schema pins only the invocation pattern.

## Validation

Files under `plugins/gaia/agents/**/*.md` are linted by
`.github/scripts/lint-agent-frontmatter.sh` (the agent-frontmatter linter added
alongside this schema under E28-S19). The linter enforces:

- Presence of all required fields.
- Non-empty string values for string fields.
- `context` is one of `main` or `fork`.
- `allowed-tools` is a non-empty list.

See E28-S7 for the parallel SKILL.md frontmatter linter; the agent linter
mirrors its structure and error format.
