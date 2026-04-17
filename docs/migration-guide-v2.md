<!-- COORDINATION NOTE (E28-S126 → E28-S130):
     This file was created by E28-S126 with only the "Legacy engine cleanup" subsection
     populated (under a placeholder ## Verify heading). E28-S130 fills in the remaining
     top-level sections (Prerequisites, Backup, Install, Migrate Templates, Migrate Memory,
     Update CLAUDE.md, Verify, Rollback, Reviewer Orientation). S130 MUST preserve the
     "Legacy engine cleanup" subsection verbatim — it is the reference cutover runbook
     tied to the gaia-cleanup-legacy-engine.sh script shipped in this same PR.
     See: docs/implementation-artifacts/E28-S126-plan.md §Step 6 coordination note.
-->

# GAIA v1 → v2 Migration Guide

> **Status:** stub — E28-S130 expands this into the full v1→v2 migration guide.
> The "Legacy engine cleanup" subsection under §Verify is the reference cutover
> runbook for `plugins/gaia/scripts/gaia-cleanup-legacy-engine.sh`. It was
> created by E28-S126 and MUST be preserved when E28-S130 fills out the
> remaining sections.

## Table of Contents

<!-- TOC placeholder — populated by E28-S130 with section anchors for:
     Prerequisites, Backup, Install, Migrate Templates, Migrate Memory,
     Update CLAUDE.md, Verify, Rollback, Reviewer Orientation. -->

1. Prerequisites — _(pending E28-S130)_
2. Backup — _(pending E28-S130)_
3. Install — _(pending E28-S130)_
4. Migrate Templates — _(pending E28-S130)_
5. Migrate Memory — _(pending E28-S130)_
6. Update CLAUDE.md — _(pending E28-S130)_
7. **Verify**
   - [Legacy engine cleanup (manual cutover)](#legacy-engine-cleanup-manual-cutover)
8. Rollback — _(pending E28-S130)_
9. Reviewer Orientation — _(pending E28-S130)_

## Verify

_Sections above the "Legacy engine cleanup" subsection are filled in by E28-S130._

### Legacy engine cleanup (manual cutover)

After confirming the native-plugin installation boots and your workflows run
end-to-end, run the cleanup script to remove the retired `workflow.xml` engine,
engine protocols, the four retired `_config/` manifests, the five module
`config.yaml` files, and every nested `.resolved/` directory from your local
`_gaia/` runtime tree.

**When to run**

Only **after** you have:

- Installed the new `gaia-public` (and, if applicable, `gaia-enterprise`) plugin
  via `/plugin marketplace add` (see [Install](#install)).
- Verified at least one representative workflow (`/gaia-dev-story`, `/gaia-create-prd`,
  `/gaia-sprint-plan`) completes successfully against the native plugin.
- Completed any other migration steps above (template/memory/CLAUDE.md migrations).

If you run this script **before** the native plugin is installed and working,
every `/gaia-*` slash command on your machine will stop working until you
restore from backup.

**Command**

```bash
# From the project root (where `_gaia/` and the git repo sit alongside each other):
plugins/gaia/scripts/gaia-cleanup-legacy-engine.sh --project-root .

# Preview without making changes:
plugins/gaia/scripts/gaia-cleanup-legacy-engine.sh --project-root . --dry-run

# Bypass the clean-working-tree guard (use with care):
plugins/gaia/scripts/gaia-cleanup-legacy-engine.sh --project-root . --force-dirty
```

**What it removes**

- `_gaia/core/engine/` (`workflow.xml`, `error-recovery.xml`, `task-runner.xml`)
- `_gaia/core/protocols/` (discover-inputs.xml, preflight-check.xml, handoff.xml,
  review-gate-check.xml, status-sync.xml)
- `_gaia/_config/lifecycle-sequence.yaml`, `workflow-manifest.csv`,
  `task-manifest.csv`, `skill-manifest.csv`
- `_gaia/{core,lifecycle,dev,creative,testing}/config.yaml` (five module configs)
- Every `_gaia/**/.resolved/` directory (recursive)

**What survives** (preserved intentionally)

- `_gaia/_config/global.yaml` (authoritative local config — native plugin reads this directly)
- `_gaia/_config/agent-manifest.csv`, `files-manifest.csv`, `gaia-help.csv`
- `_memory/` (all agent sidecars, checkpoints, archives)
- `custom/` (user-authored template overrides)

**Pre-flight guards**

The script refuses to run if any of the following is true:

1. Uncommitted changes exist under `_gaia/` (unless `--force-dirty` is passed).
2. An in-flight checkpoint under `_memory/checkpoints/` references the legacy
   engine — resolve the checkpoint with `/gaia-resume` or move it to
   `_memory/checkpoints/completed/` first.
3. Any of the 12 cluster-gate stories (E28-S76, S81, S95, S99, S118, S133–S139)
   is not `done` + 6× `PASSED` — this guard is the program-closing pre-start
   gate from ADR-048.

**Recovery**

If the cleanup leaves you in an inconsistent state, the native plugin can be
reinstalled from the Claude Code marketplace cache per ADR-046 Hybrid Memory
Loading. Your `_memory/` and `custom/` trees are untouched by the cleanup — they
are not in the deletion manifest.

**Exit codes**

| Code | Meaning |
|---|---|
| 0 | Success — deletion complete, or already clean |
| 1 | Pre-flight gate failed (dirty tree / in-flight checkpoint / cluster gate) |
| 3 | Filesystem error during deletion (permission denied, locked path) |
| 64 | Usage error |

**References**

- ADR-048 — Engine Deletion as Program-Closing Action (`docs/planning-artifacts/architecture.md:103`)
- NFR-050 — Zero XML Engine Files (`docs/planning-artifacts/prd.md:1708`)
- FR-328 — Engine Deletion (`docs/planning-artifacts/prd.md:1637`)
- Story: E28-S126 — Delete workflow.xml engine, protocols, and `.resolved` config files
