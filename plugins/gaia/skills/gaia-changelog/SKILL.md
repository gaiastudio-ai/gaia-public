---
name: gaia-changelog
description: Generate a changelog entry from git history and sprint-status files. Groups commits by Keep a Changelog category (Added, Changed, Fixed, Deprecated, Removed, Security) and cross-references story keys from docs/implementation-artifacts/. Writes or appends to CHANGELOG.md. Use when "generate changelog" or /gaia-changelog.
argument-hint: "[version — optional, defaults to unreleased range since last tag]"
tools: Read, Write, Edit, Bash, Grep
---

## Mission

You are producing a **Keep a Changelog**-formatted changelog entry for this repository. You gather commits since the last release tag, group them by conventional-commit type, cross-reference story keys back to `docs/implementation-artifacts/`, and emit (or append to) `CHANGELOG.md` in the repository root.

This skill is the native Claude Code conversion of the legacy `_gaia/core/tasks/generate-changelog.xml` task (35 lines). Per **ADR-041** (Native Execution Model) and **ADR-042** (Scripts-over-LLM for Deterministic Operations), the legacy task-runner engine is retired and deterministic git operations are delegated to inline bash (not re-prosed by the LLM).

## Critical Rules

- **Follow Keep a Changelog format.** See https://keepachangelog.com/ — the six categories are canonical: Added, Changed, Fixed, Deprecated, Removed, Security.
- **Group every commit into exactly one category.** Map conventional-commit prefixes: `feat:` → Added, `fix:` → Fixed, `refactor:` / `chore:` / `perf:` / `docs:` / `style:` → Changed, `BREAKING CHANGE:` footer or `!` marker → Removed (breaking) section. Commits with no recognizable prefix go to an "Uncategorized" group rather than being silently dropped.
- **Include version number and date.** The entry header is `## [{version}] — {YYYY-MM-DD}` where `{version}` is either the argument supplied, the next semver tag, or `Unreleased` when no version is known.
- **Cross-reference story keys.** If a commit subject contains a match for `E\d+-S\d+`, link the entry back to the corresponding story file under `docs/implementation-artifacts/` so reviewers can open the full context.
- Do NOT invent version numbers or dates. If the argument is missing and no tag exists, use `Unreleased` as the version and today's ISO date as the date.
- Output path is `CHANGELOG.md` in the repository root. Append to an existing file rather than overwriting; new entries go above the previous top entry.

## Inputs

- `$ARGUMENTS`: optional version identifier (e.g., `1.127.2`). If omitted, use the range since the last tag (or the full history when no tag exists) and label the entry `Unreleased`.

## Instructions

### Step 1 — Gather Sources

Use inline bash for the deterministic git operations (ADR-042):

```bash
!git log $(git describe --tags --abbrev=0 2>/dev/null || echo "")..HEAD --oneline --no-merges
```

If the previous-tag command returns empty (no tags yet), fall back to `git log --oneline --no-merges` for the entire history.

Then read any sprint-status files in `docs/implementation-artifacts/` that name stories shipping in this release.

Identify the version number for this entry (argument, next tag, or `Unreleased`).

### Step 2 — Categorize Changes

Walk the commit list and bucket each commit into one of the Keep a Changelog categories:

- **Added** — `feat:` commits, new capabilities.
- **Changed** — `refactor:`, `perf:`, `style:`, `docs:`, `chore:` commits that alter existing capabilities without breaking them.
- **Fixed** — `fix:` commits.
- **Deprecated** — explicit deprecation notices in commit bodies.
- **Removed** — `BREAKING CHANGE:` footer, `!` marker after the type, or explicit removal notices.
- **Security** — commits that mention a CVE, a security fix, or start with `security:`.

Extract a meaningful one-line description from each commit subject (strip the conventional-commit prefix). For story-linked commits, append `— [{story_key}](docs/implementation-artifacts/{story_key}-*.md)` so reviewers can open the story file.

### Step 3 — Format

Render the entry as:

```
## [{version}] — {YYYY-MM-DD}

### Added
- {commit subject} — {story reference if any}

### Changed
- …

### Fixed
- …

### Deprecated
- … (omit section if empty)

### Removed
- … (omit section if empty)

### Security
- … (omit section if empty)
```

Sections with zero entries MUST be omitted (do not emit empty "### Added" blocks).

### Step 4 — Output

Write or append to `CHANGELOG.md` in the repository root. If the file exists, insert the new entry immediately below the top-level heading (`# Changelog`) and above the previous top entry. If the file does not exist, create it with the standard preamble:

```
# Changelog

All notable changes to this project are documented in this file. The format follows [Keep a Changelog](https://keepachangelog.com/), and this project adheres to [Semantic Versioning](https://semver.org/).

{new entry here}
```

If the commit range is empty (no commits since last tag), append a single-line note `_No changes since {previous tag}._` under the version header rather than writing an empty entry (AC-EC3: empty git range).

## References

- Source: `_gaia/core/tasks/generate-changelog.xml` (legacy 35-line task body — ported per ADR-041 + ADR-042).
- Keep a Changelog: https://keepachangelog.com/
- Semantic Versioning: https://semver.org/
- ADR-041: Native Execution Model via Claude Code Skills + Subagents + Plugins + Hooks.
- ADR-042: Scripts-over-LLM for Deterministic Operations.
- ADR-048: Engine Deletion as Program-Closing Action — legacy task coexists with this skill until program close.
- FR-323: Skill Conversion — slash-command identity preserved.
- NFR-053: Full v1.127.2-rc.1 Feature Parity.
