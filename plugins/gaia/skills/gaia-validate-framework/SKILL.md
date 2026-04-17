---
name: gaia-validate-framework
description: Scan the GAIA framework tree for consistency, broken references, and missing components. Use when "validate framework" or /gaia-validate-framework. Walks _gaia/, compares against _gaia/_config/manifest.yaml, checks workflow integrity, agent integrity, command integrity, manifest integrity, config resolution, skill index integrity, and knowledge index integrity, then emits a severity-grouped findings report. Native Claude Code conversion of the legacy validate-framework task (E28-S111, Cluster 14).
argument-hint: "[--report-path]"
allowed-tools: [Read, Bash, Grep]
---

## Mission

You are running a framework self-validation scan. The skill walks `_gaia/`, compares the on-disk file inventory against `_gaia/_config/manifest.yaml`, and verifies that every workflow, agent, command, skill, and knowledge reference resolves. The output is a severity-grouped findings report written to `docs/implementation-artifacts/framework-validation-{date}.md` (or a user-provided path).

This skill is the native Claude Code conversion of the legacy validate-framework task at `_gaia/core/tasks/validate-framework.xml` (brief Cluster 14, story E28-S111). The legacy 66-line XML body is preserved here as explicit prose per ADR-041. No workflow engine, no engine-specific XML step tags.

## Critical Rules

- **Report ALL issues found — do not stop at first error.** Every step collects findings into an aggregated list. The skill emits the full report even when critical findings are present.
- **Check every path reference in every file.** Every `{installed_path}/...`, `{project-root}/...`, and `{project-path}/...` reference must resolve to an actual file. Dangling references are CRITICAL findings.
- **Verify config resolution works end-to-end.** Load `global.yaml` via `scripts/resolve-config.sh` (ADR-044) and confirm it parses. Under the native model there is no `.resolved/` pre-compilation step — config is resolved at skill-invocation time. Flag `global.yaml` parse failure as CRITICAL.
- **Report format preserves the legacy output shape.** Severity column, section column, finding column, suggested-fix column. Downstream tooling (CI checks, triage workflows) consume this shape — do NOT invent a new one.
- **Fail fast when manifest.yaml is missing (AC-EC3).** If `_gaia/_config/manifest.yaml` is absent, emit a CRITICAL finding `manifest.yaml missing — cannot validate framework` and exit non-zero. No partial report.
- **Use inline `!` bash for deterministic ops (ADR-042).** Manifest reads, directory listings, and `shasum` go through inline `!` bash. Do NOT re-implement manifest parsing in LLM prose.

## Inputs

1. **Report path** — optional, via `$ARGUMENTS`. Defaults to `docs/implementation-artifacts/framework-validation-{date}.md`.

## Pipeline Overview

The skill runs nine steps in strict order, mirroring the legacy `validate-framework.xml`:

1. **File Inventory** — scan `_gaia/`, count by type, compare against manifest.yaml
2. **Workflow Integrity** — verify every `workflow.yaml` has its companion files
3. **Agent Integrity** — verify every agent `.md` has well-formed XML and real menu links
4. **Command Integrity** — verify every `.claude/commands/gaia-*.md` references real framework files
5. **Manifest Integrity** — verify surviving `agent-manifest.csv` rows match on-disk agent files and vice versa (legacy workflow/task/skill manifests retired by ADR-048)
6. **Config Resolution** — verify `global.yaml` parses cleanly under the native resolution path (module `config.yaml` and `.resolved/` retired by ADR-044/ADR-048)
7. **Skill Index Integrity** — verify every entry in `_skill-index.yaml` has a real file and valid line ranges
8. **Knowledge Index Integrity** — verify every entry in knowledge `_index.csv` has a real fragment under 200 lines
9. **Report** — emit PASS/FAIL overall + itemized findings grouped by severity

## Step 1 — File Inventory

- **AC-EC3 — manifest.yaml missing:** check `_gaia/_config/manifest.yaml`. If absent, emit CRITICAL `manifest.yaml missing — cannot validate framework` and exit non-zero. No partial report.
- Scan the `_gaia/` directory tree via inline `!find _gaia -type f -name '*.md' -o -name '*.xml' -o -name '*.yaml' -o -name '*.csv'`. Count files by type.
- Compare counts against expected counts from `manifest.yaml` (version field and declared module counts).
- Flag any drift as INFO (counts off by small margin) or WARNING (counts off by a large margin).

## Step 2 — Workflow Integrity

- For each `workflow.yaml` under `_gaia/{core,lifecycle,dev,creative,testing}/workflows/`:
  - Verify the `instructions` file declared in the yaml exists on disk.
  - Verify the `validation` (checklist) file exists when declared.
  - Verify the `config_source` file exists.
  - Verify the `template` field, when declared, points to an existing template (respecting the `custom/templates/` override order).
- Scan each `workflow.yaml` and its `instructions` for unresolved `{variable}` references that were NOT expected (expected tokens: `{project-root}`, `{project-path}`, `{installed_path}`, `{date}`, `{memory_path}`, `{checkpoint_path}`, and any explicit workflow variables).
- Flag unresolved references as CRITICAL.

## Step 3 — Agent Integrity

- For each `.md` file under `_gaia/{core,lifecycle,dev,creative,testing}/agents/`:
  - Verify the `<agent>` XML block is well-formed (balanced tags, no orphan attributes).
  - Verify each menu item's `file=` attribute points to a real file.
  - Verify activation steps are numbered correctly (1..N with no gaps).
- Flag malformed XML as CRITICAL; missing menu targets as WARNING.

## Step 4 — Command Integrity

- For each `.claude/commands/gaia-*.md` (or equivalent slash-command definition file):
  - Verify it references a real framework workflow, agent, or skill file.
  - Cross-reference `gaia-help.csv` — every help entry should have a matching command definition.
- Flag missing references as CRITICAL; help-CSV drift as WARNING.

## Step 5 — Manifest Integrity

- Verify `agent-manifest.csv` has a row for every agent `.md` file found on disk, and vice versa.
- Flag any drift (manifest row without a file, or file without a manifest row) as WARNING.
- Note: `workflow-manifest.csv`, `task-manifest.csv`, and `skill-manifest.csv` were retired under ADR-048 (program-closing engine deletion). The native model discovers skills/subagents via Claude Code's auto-discovery, so these manifests are no longer authoritative and MUST NOT be checked here.

## Step 6 — Config Resolution

- Load `_gaia/_config/global.yaml` via the native resolution path (`scripts/resolve-config.sh`, per ADR-044) — verify it parses as valid YAML and the key project-root / project-path / memory-path fields resolve cleanly.
- Flag YAML parse errors as CRITICAL.
- Note: module `config.yaml` files and the `.resolved/` pre-compilation chain were retired under ADR-044 + ADR-048. The native model resolves config at skill-invocation time — there is no pre-compiled output to verify.

## Step 7 — Skill Index Integrity

- For each entry in `_gaia/dev/skills/_skill-index.yaml`:
  - Verify the referenced `.md` file exists.
  - Verify the declared `lines: [start, end]` range is valid (end > start; both within file bounds).
  - Verify the section content at the declared range starts with a matching `<!-- SECTION: xxx -->` marker.
- Flag missing files as CRITICAL; invalid line ranges as WARNING.

## Step 8 — Knowledge Index Integrity

- For each entry in knowledge `_index.csv` files (e.g., `_gaia/testing/knowledge/*/index.csv`):
  - Verify the fragment `.md` file exists on disk.
  - Verify each fragment is under 200 lines (per `<200-line` context-budget rule in the framework spec).
- Flag missing fragments as CRITICAL; oversize fragments as WARNING.

## Step 9 — Report

Generate the framework validation report at the configured output path.

Format:

```markdown
# GAIA Framework Validation Report — {YYYY-MM-DD}

**Overall Status:** PASS | FAIL

**Summary:**
- Critical findings: {N}
- Warning findings: {M}
- Info findings: {K}

## Findings

| Severity | Section | Finding | Suggested Fix |
|----------|---------|---------|---------------|
| CRITICAL | Workflow Integrity | workflow.yaml at ... references missing instructions file ... | Restore the instructions file or remove the workflow.yaml entry |
| WARNING  | Manifest Integrity | agent-manifest.csv has a row for ... but no file exists on disk | Remove the stale manifest row or restore the file |
| INFO     | File Inventory     | file count drift — expected 42 md files, found 43 | Run /gaia-build-configs and re-validate |
| ...      | ...                | ...                                             | ...           |
```

Grouping: CRITICAL first, then WARNING, then INFO. Within each severity, sort by section then alphabetical by finding text.

**Overall Status**: PASS when there are zero CRITICAL findings; FAIL otherwise. WARNING and INFO do not break the gate.

## Edge Cases

- **AC-EC3 — manifest.yaml missing:** exit with a single CRITICAL finding `manifest.yaml missing — cannot validate framework`. No partial report. Non-zero exit.
- **Empty `_gaia/` tree:** report each expected directory as WARNING; Overall Status FAIL.
- **Legacy `.resolved/` remnants present:** INFO — `.resolved/` was retired under ADR-044/ADR-048; surviving directories are stale artifacts from pre-native installs. Suggest running `plugins/gaia/scripts/gaia-cleanup-legacy-engine.sh`.

## References

- Legacy source: `_gaia/core/tasks/validate-framework.xml` (66 lines) — parity reference for NFR-053.
- `_gaia/_config/manifest.yaml` — authoritative file inventory source (read-only input for this skill).
- `_gaia/_config/global.yaml` — authoritative config source (read-only input for this skill).
- ADR-041 — Native Execution Model via Claude Code Skills + Subagents + Plugins + Hooks.
- ADR-042 — Scripts-over-LLM for Deterministic Operations (inline `!` bash for manifest reads, `find`, `shasum`).
- ADR-048 — Program-close deletion policy for legacy engine/workflows/tasks.
- FR-323 — Native Skill Format Compliance.
- NFR-053 — Functional parity with the legacy task.
- Reference implementation: `plugins/gaia/skills/gaia-fix-story/SKILL.md`.
