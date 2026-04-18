<!-- Authored by E28-S126 (stub, "Legacy engine cleanup" subsection only) and
     expanded by E28-S130 (full guide). The "Legacy engine cleanup" subsection
     under §Verify is preserved verbatim from E28-S126.
-->

# GAIA v1 → v2 Migration Guide

This guide walks an existing GAIA v1 user through upgrading to v2 (Claude Code native plugin) without losing custom templates, agent memory, project configuration, or in-flight work.

**Audience:** developers running GAIA v1.127.x with the legacy `workflow.xml` engine. **Target:** GAIA v2 — published as Claude Code plugins (`gaia-public` + optional `gaia-enterprise`).

**Scope of this guide:** end-user cutover after the v2 plugins have been published to the Claude Code marketplace. This guide is NOT used during the conversion program itself (per ADR-048).

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Backup](#2-backup)
3. [Install](#3-install)
4. [Migrate Templates](#4-migrate-templates)
5. [Migrate Memory](#5-migrate-memory)
6. [Update CLAUDE.md](#6-update-claudemd)
7. [Verify](#7-verify)
8. [Rollback](#8-rollback)
9. [Reviewer Orientation](#9-reviewer-orientation)

Step IDs are globally numbered (S1.1, S2.3, etc.) so support conversations can reference exact locations.

---

## 1. Prerequisites

Before you migrate, satisfy every check below. The migration is safe ONLY when all four pass.

### S1.1 — Confirm the v2 plugins are published

The migration target is Claude Code's native plugin system. Run:

```
$ /plugin marketplace list
```

The output MUST include `gaia-public`. If you have an enterprise license, it should also include `gaia-enterprise`. If neither appears, **STOP** — the v2 plugins are not yet published to your marketplace and migration cannot proceed (AC-EC10).

### S1.2 — Verify version compatibility

`gaia-public` and `gaia-enterprise` MUST match at the minor version (both on `2.x.y`). Run:

```
$ /plugin marketplace info gaia-public
$ /plugin marketplace info gaia-enterprise   # if licensed
```

Confirm the major.minor versions match. Mismatched pairs cause degraded enterprise features (AC-EC8).

### S1.3 — Drain or discard in-flight checkpoints

v2 cannot resume v1 checkpoints. Inspect:

```
$ ls _memory/checkpoints/
```

For each `.yaml` file in this directory (excluding `_memory/checkpoints/completed/`):

- **Option A — drain:** complete the in-flight workflow under v1 first using the existing `/gaia-resume` flow. Once the workflow finishes, its checkpoint moves to `completed/`.
- **Option B — discard:** if you can't drain (e.g., the workflow is irrelevant), move the checkpoint manually:

  ```
  $ mkdir -p _memory/checkpoints/completed
  $ mv _memory/checkpoints/{stale-checkpoint}.yaml _memory/checkpoints/completed/
  ```

**Do not start migration with active checkpoints in `_memory/checkpoints/` (top level).** v2 will not be able to resume them and the user-experience is poor (AC-EC3).

### S1.4 — Back up `.claude/settings.json`

If you have customizations in `.claude/settings.json` (hooks, permissions, env vars), back it up explicitly:

```
$ cp .claude/settings.json .claude/settings.json.v1.bak
```

The migration does NOT overwrite this file automatically. You will re-apply v2-compatible permissions after install (AC-EC6).

---

## 2. Backup

Take a full backup of every directory the migration touches. The backup is your single rollback target — keep it safe and verifiable.

### S2.1 — Create a backup root

```
$ BACKUP_ROOT="$HOME/gaia-v1-backup-$(date +%Y%m%d-%H%M%S)"
$ mkdir -p "$BACKUP_ROOT"
$ echo "Backup root: $BACKUP_ROOT"
```

### S2.2 — Copy every relevant directory

```
$ cp -r _gaia/        "$BACKUP_ROOT/"
$ cp -r _memory/      "$BACKUP_ROOT/"
$ cp -r custom/       "$BACKUP_ROOT/"   # if exists
$ cp -r docs/         "$BACKUP_ROOT/"
$ cp -r .claude/      "$BACKUP_ROOT/"
$ cp    global.yaml   "$BACKUP_ROOT/"   # if at project root
$ cp    CLAUDE.md     "$BACKUP_ROOT/"
```

**Note:** `custom/` only exists if you've authored template overrides. Skip if absent.

### S2.3 — Generate a manifest with checksums

```
$ ( cd "$BACKUP_ROOT" && find . -type f -exec shasum -a 256 {} \; > manifest.sha256 )
$ wc -l "$BACKUP_ROOT/manifest.sha256"
```

The manifest serves two purposes: (1) post-migration `diff` evidence that custom templates and memory survived byte-identical (AC-EC1, AC-EC4); (2) rollback-restoration verification.

### S2.4 — Confirm backup is non-empty and readable

```
$ du -sh "$BACKUP_ROOT"
$ tail -3 "$BACKUP_ROOT/manifest.sha256"
```

Both commands should produce output. If either fails, **STOP** and resolve the disk/permissions issue before continuing.

---

## 3. Install

### S3.1 — Choose your project_path track

Open `_gaia/_config/global.yaml` (or the project root `global.yaml` if that's where it lives). Look for the `project_path` field.

- If `project_path: "."` → follow **Track A** below
- If `project_path: "{some-subdirectory}"` → follow **Track B** below

Each track has its own numbered steps so you don't have to mentally branch. Run only the steps under your track.

### Track A — `project_path: "."` (single-tree layout)

In this layout, application code and the GAIA framework share the project root. The migration installs the plugin into the same root.

```
$ /plugin marketplace add gaia-public
$ /plugin marketplace add gaia-enterprise   # if licensed
```

After install, verify:

```
$ /plugin list
```

Both plugins should be listed and active.

### Track B — `project_path: "{subdirectory}"` (split-tree layout)

In this layout, application source lives in a subdirectory (e.g., `gaia-public/`, `my-app/`) while GAIA framework lives at the project root. The plugin install command is the same; the difference is where you'll later sync templates and memory back.

```
$ /plugin marketplace add gaia-public
$ /plugin marketplace add gaia-enterprise   # if licensed
$ /plugin list
```

Note the value of `project_path` in your `global.yaml` — you'll need it for §4 and §5 to copy files into the correct subdirectory.

### S3.2 — Network failure handling (AC-EC7)

If `/plugin marketplace add` fails mid-download (network outage, marketplace unavailable):

1. Wait 30s, then retry the same command. The marketplace install is idempotent — a partial install gets cleaned up automatically.
2. If retry also fails, run `/plugin marketplace status` to see whether anything was partially installed.
3. If status reports a partial install, run `/plugin uninstall {plugin-name}` to clean up, then retry the add.
4. If the marketplace is fully unreachable, halt the migration. **The rollback at this stage is a no-op** because the install never completed; you can resume migration once the marketplace is reachable.

---

## 4. Migrate Templates

If you authored custom template overrides under `custom/templates/`, preserve them byte-for-byte.

### S4.1 — Copy custom/templates/ to its v2 location

The v2 plugin honors `custom/templates/` at the project root in both layouts (Track A and Track B). For most users this means: do nothing — `custom/templates/` is already where the v2 plugin expects it.

### S4.2 — Verify byte-identical preservation (AC-EC1)

```
$ diff -r "$BACKUP_ROOT/custom/templates" custom/templates
```

The output MUST be empty (no diff). If any line is reported, the templates have drifted — investigate and restore from the backup before continuing.

---

## 5. Migrate Memory

Agent memory sidecars contain decision history, ground truth, and conversation context that MUST survive migration (AC-EC4).

### S5.1 — Confirm sidecars survive in place

```
$ ls _memory/   # list every sidecar directory (validator-sidecar, devops-sidecar, etc.)
```

These directories already live under `_memory/` and the v2 plugin reads from the same location. No copy is required — confirm:

```
$ diff -r "$BACKUP_ROOT/_memory" _memory
```

The output should show only `_memory/checkpoints/` differences (which are expected — we drained those in §1.3) and any new sidecars created since the backup. The three canonical sidecar files MUST be unchanged for every Tier 1 / Tier 2 agent:

- `decision-log.md`
- `ground-truth.md` (Tier 1 only — validator, architect, pm, sm)
- `conversation-context.md`

### S5.2 — Verify checksums

```
$ ( cd _memory && find . -type f -name '*.md' -not -path './*/archive/*' -exec shasum -a 256 {} \; ) > /tmp/_memory.now.sha256
$ ( cd "$BACKUP_ROOT/_memory" && find . -type f -name '*.md' -not -path './*/archive/*' -exec shasum -a 256 {} \; ) > /tmp/_memory.backup.sha256
$ diff /tmp/_memory.now.sha256 /tmp/_memory.backup.sha256
```

Empty output = checksums match = sidecars are byte-identical.

---

## 6. Update CLAUDE.md

The v2 `CLAUDE.md` is ≤50 lines (per NFR-049) and contains only environment + hard rules + plugin pointers. Your v1 `CLAUDE.md` likely runs ~220 lines with engine-execution narrative.

### S6.1 — Replace your CLAUDE.md with the v2 template

The plugin ships a reference v2 CLAUDE.md at `gaia-public/CLAUDE.md`. Use it as the starting template:

```
$ cp .claude/plugins/gaia-public/CLAUDE.md CLAUDE.md
```

The path above assumes the marketplace install location; adjust if your install is elsewhere (e.g., system-wide). Confirm:

```
$ wc -l CLAUDE.md
```

Should be 30–50 lines.

### S6.2 — Re-apply project-specific customizations

If your v1 CLAUDE.md had project-specific environment values (e.g., custom `project_path`, custom artifact paths), re-apply them to the slim v2 template. Keep the file under 50 lines.

### S6.3 — Confirm version heading is preserved

```
$ head -1 CLAUDE.md
```

Must match `# GAIA Framework v{x.x.x}`. The version-bump script regex relies on this exact format.

---

## 7. Verify

After install + template/memory/CLAUDE.md migration, run a smoke test before declaring victory.

### S7.1 — Smoke-test three representative skills

```
$ /gaia
$ /gaia-help
$ /gaia-dev-story
```

Each command should resolve through the v2 plugin's SKILL.md and either show the orchestrator menu (`/gaia`), context-sensitive help (`/gaia-help`), or prompt for a story key (`/gaia-dev-story`). No "command not found" errors.

### S7.2 — Confirm `/gaia-validate-framework` passes

```
$ /gaia-validate-framework
```

The skill verifies file inventory, manifest integrity, and config resolution. Expect `Overall Status: PASS` with no CRITICAL findings.

### Legacy engine cleanup (manual cutover)

After confirming the native-plugin installation boots and your workflows run
end-to-end, run the cleanup script to remove the retired `workflow.xml` engine,
engine protocols, the four retired `_config/` manifests, the five module
`config.yaml` files, and every nested `.resolved/` directory from your local
`_gaia/` runtime tree.

**When to run**

Only **after** you have:

- Installed the new `gaia-public` (and, if applicable, `gaia-enterprise`) plugin
  via `/plugin marketplace add` (see §3 Install).
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

---

## 8. Rollback

If anything goes wrong during migration, **STOP** and follow this section instead of attempting forward fixes.

**S8.1 — STOP. Do not run further migration steps.** Forward attempts after a partial migration produce inconsistent state that's harder to recover from than a clean rollback.

**S8.2 — Uninstall the v2 plugins:**

```
$ /plugin uninstall gaia-enterprise   # if installed
$ /plugin uninstall gaia-public
```

This is safe whether you're at step 3.1 or step 7.2 — uninstalling plugins is reversible.

**S8.3 — Restore directories from backup** (idempotent — safe to run multiple times):

```
$ rm -rf _gaia/ _memory/ docs/ .claude/
$ cp -r "$BACKUP_ROOT/_gaia/"   ./
$ cp -r "$BACKUP_ROOT/_memory/" ./
$ cp -r "$BACKUP_ROOT/docs/"    ./
$ cp -r "$BACKUP_ROOT/.claude/" ./
$ cp    "$BACKUP_ROOT/CLAUDE.md" ./
$ cp    "$BACKUP_ROOT/global.yaml" ./   # if backed up at project root
$ cp -r "$BACKUP_ROOT/custom/" ./       # if backed up
```

**S8.4 — Verify restoration with the manifest:**

```
$ ( find . -type f \( -path './_gaia/*' -o -path './_memory/*' -o -path './docs/*' -o -path './.claude/*' -o -name 'CLAUDE.md' -o -name 'global.yaml' \) -exec shasum -a 256 {} \; | sort ) > /tmp/restored.sha256
$ ( cd "$BACKUP_ROOT" && find . -type f \( -path './_gaia/*' -o -path './_memory/*' -o -path './docs/*' -o -path './.claude/*' -o -name 'CLAUDE.md' -o -name 'global.yaml' \) -exec shasum -a 256 {} \; | sort ) > /tmp/backup.sha256
$ diff /tmp/restored.sha256 /tmp/backup.sha256
```

Empty diff = restoration is byte-identical to backup.

**S8.5 — Confirm v1 is functional:**

```
$ /gaia
```

If the v1 orchestrator launches normally, rollback succeeded. You can re-attempt migration later after addressing whatever caused the original failure (network, version skew, etc.). The backup remains valid for future attempts.

---

## 9. Reviewer Orientation

This appendix gives an external reviewer (someone who did not work on the GAIA Native Conversion Program / E28) the minimum context to verify this guide.

### 5-minute conceptual overview

GAIA v1 ran on a custom `workflow.xml` engine (~258 lines) that orchestrated 81 workflow YAML+XML bundles, 28 agent persona files, ~120 pre-compiled `.resolved/` configs, and 4 engine protocols. Every `/gaia-*` slash command loaded `workflow.xml` to interpret its workflow.

GAIA v2 replaces this entire stack with Claude Code's native primitives:

- 81 workflows → 81 `SKILL.md` files (auto-discovered)
- 28 agents → 28 `.claude/agents/{name}.md` subagents
- 4 protocols → inline bash scripts (`scripts/resolve-config.sh`, `scripts/checkpoint.sh`, etc.)
- ~120 `.resolved/` configs → resolved at skill-invocation time via `scripts/resolve-config.sh` (no pre-compilation step)

The v2 system runs entirely on Claude Code primitives, with no custom engine. Token usage drops 40–55% on mechanical workflows (per NFR-048). Feature parity with v1.127.2-rc.1 is preserved (per NFR-053).

### Legacy script names — redirection note

Early revisions of the architecture spec and several sprint-era story artifacts referenced three separate scripts for the checkpoint surface. During native conversion (E28-S10) those three were consolidated into a single `plugins/gaia/scripts/checkpoint.sh` dispatcher with `write` / `read` / `validate` subcommands. If you encounter any of the legacy names in older docs, stories, or custom hooks, map them as follows:

| Legacy name | Consolidated replacement |
|-------------|--------------------------|
| `checkpoint-write.sh` | `checkpoint.sh write` |
| `checkpoint-verify.sh` | `checkpoint.sh validate` |
| `sha256-verify.sh` | Absorbed by `checkpoint.sh` — the `write` subcommand stamps `files_touched` sha256 checksums and the `validate` subcommand re-checks them. There is no standalone `sha256-verify.sh` in the shipped product. |

Only the consolidated `checkpoint.sh` ships under `plugins/gaia/scripts/`. The legacy names are retained in historical story artifacts (E28-S10, E28-S83, E28-S105, E28-S136) for traceability; no live skill, hook, or script references them.

The migration this guide describes is the **end-user cutover** that retires the v1 engine on a single user's machine after the v2 plugins are published. It is NOT used during the conversion program itself.

### Key references

- **PRD §4.27** (`docs/planning-artifacts/prd.md`) — GAIA Native Conversion Program definition
- **ADR-041** (`docs/planning-artifacts/architecture.md` §Decision Log) — Native execution model via Claude Code Skills + Subagents + Plugins + Hooks
- **ADR-048** (`docs/planning-artifacts/architecture.md` §Decision Log) — Engine deletion as program-closing action
- **NFR-049** (`prd.md`) — `CLAUDE.md` ≤50 lines after migration
- **NFR-050** (`prd.md`) — Zero XML engine files in `gaia-public/plugins/gaia/` after migration

### What to verify in this guide

1. Every section (1–9) is present and ordered correctly.
2. Track A and Track B are clearly separated for users with different `project_path` values.
3. Rollback section starts with **STOP** and uses idempotent commands.
4. The "Legacy engine cleanup" subsection under §Verify (preserved verbatim from E28-S126) names the cleanup script's exact path, flags, and exit codes.
5. Prerequisites blocks the migration with `marketplace list` checks.

If all five items check out, the guide is mechanically correct. Substantive accuracy (e.g., "does this command actually work?") requires running through the steps in a sandbox — out of scope for a doc review.

---

## 10. Automated migration via `/gaia-migrate`

The 9 sections above describe the **manual** migration. After the v2 plugins are installed (§3), the `/gaia-migrate` skill (E28-S131) automates §1.3 (drain checkpoints — manual still required), §2 (Backup), §4 (Migrate Templates), §5 (Migrate Memory), and §6 (Update CLAUDE.md, partial), plus the §7 Verify validation step. The §1.1 / §1.2 prerequisite checks and §3 Install are still manual (they require user judgement and the marketplace UI).

### Recommended flow

1. Complete §1 Prerequisites manually (§1.1 marketplace check, §1.2 version compatibility, §1.3 checkpoint drain, §1.4 settings.json backup).
2. Install the v2 plugins per §3.
3. Run `/gaia-migrate` with dry-run first:

```
$ /gaia-migrate dry-run
```

The skill prints the planned operations (backup destination, migration steps, validation checks) without writing anything.

4. If the plan looks right, apply:

```
$ /gaia-migrate apply
```

The skill creates `.gaia-migrate-backup/{timestamp}/` BEFORE any migration write, runs the 3 migration subtasks, validates, and prints a `SUCCESS` or `FAILED` banner with the backup path and the exact restore command.

### Equivalence to manual steps

| Manual section | Automated by `/gaia-migrate`? |
|---|---|
| §1.1 marketplace plugin check | ❌ — manual (user must run `/plugin marketplace list`) |
| §1.2 version compatibility | ❌ — manual |
| §1.3 in-flight checkpoint drain | ❌ — manual (user judgement on drain vs discard) |
| §1.4 settings.json backup | ✅ — covered by §2 backup step (the entire `.claude/` is backed up) |
| §2 Backup (all directories + manifest) | ✅ — `.gaia-migrate-backup/{timestamp}/` with sha256 manifest |
| §3 Install | ❌ — manual (marketplace UI) |
| §4 Migrate Templates | ✅ — `_migrate_templates()` (verify-only when v2 path matches v1) |
| §5 Migrate Memory | ✅ — `_migrate_sidecars()` (verify-only when layouts match) |
| §6 Update CLAUDE.md | ⚠️ — partial (skill backs up CLAUDE.md but does not auto-rewrite — user does §6.1/§6.2 manually) |
| §7 Verify | ✅ — `_run_validate()` (plugin discovery + YAML parse + structural check) |
| §8 Rollback | ✅ — restore command printed in both SUCCESS and FAILED summaries |

### Rollback after `/gaia-migrate`

The skill never auto-restores. On `FAILED` (or if you want to roll back a successful migration), run the printed `cp -a` command verbatim:

```
$ cp -a "$HOME/path/to/.gaia-migrate-backup/{ts}/." "$HOME/path/to/project/"
```

Then uninstall the v2 plugins per §8.2.

### When to use the manual flow instead

- You need fine-grained control over which subdirectories migrate (the skill is all-or-nothing per subtask).
- The skill's `HALT: ...` diagnostic shows your install is partial or already migrated — read §1 Prerequisites and decide whether to repair, force, or stop.
- You're migrating a non-standard layout (e.g., `_memory/` lives outside `{project-root}/_memory/`). The skill assumes the canonical paths.

