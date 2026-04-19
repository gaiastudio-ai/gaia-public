---
title: "E28-S190 — v2 plugin post-migration audit"
story_key: "E28-S190"
status: "complete"
date: "2026-04-18"
author: "dev-story / E28-S190"
owners: ["release-engineering"]
inputs:
  - "docs/implementation-artifacts/E28-S190-audit-v2-post-migration-functionality.md"
  - "gaia-public/scripts/audit-v2-migration.sh"
  - "docs/implementation-artifacts/E28-S190-audit-results.csv"
---

# v2 Plugin Post-Migration Audit

## TL;DR

- **`/gaia-migrate apply` bricks 66 of 115 installed plugin skills** — every
  skill that ships a `setup.sh` fails identically with
  `resolve-config: config file not found`.
- **Root cause is a two-bug chain, not one bug.** Fixing only the obvious
  `CLAUDE_SKILL_DIR` contract (B1) exposes a second latent bug (B4): even when
  `resolve-config.sh` finds `config/project-config.yaml`, that file does not
  contain the fields the resolver requires — they were all left behind in
  `_gaia/_config/global.yaml`, which the destructive step E28-S188 then deletes.
- **Recommendation: revert E28-S188 on `main`** (keep the backup, keep the config
  split, drop the destructive delete) and ship B1 + B4 fixes in a focused
  follow-up sprint before re-enabling the delete.

## Reproduction Harness (AC1)

- Script: `gaia-public/scripts/audit-v2-migration.sh`
- Run:

  ```bash
  gaia-public/scripts/audit-v2-migration.sh \
    --plugin-cache ~/.claude/plugins/cache/gaiastudio-ai-gaia-public/gaia/1.127.2/skills \
    --project-root /tmp/gaia-audit-fixture \
    --out /tmp/audit-v2-results.csv
  ```

- Fixture: `/tmp/gaia-audit-fixture/` with only `config/` (v2 post-migration
  state) and `gaia-public/` (project source). No `_gaia/`, `_memory/`,
  `custom/` — simulating exactly what `/gaia-migrate apply` leaves behind
  after E28-S188 runs.
- Output: `docs/implementation-artifacts/E28-S190-audit-results.csv` (116 rows:
  header + 115 skills). Schema: `skill_name,has_setup,setup_exit,setup_stderr_head,has_finalize,finalize_exit,finalize_stderr_head,bucket`.

## Skill Inventory (AC2)

| Metric | Count |
| --- | --- |
| Total skill directories in plugin cache | 115 |
| Skills with `setup.sh` (exercised) | 66 |
| Skills with no `setup.sh`/`finalize.sh` (LLM-only, e.g. `gaia-help`, `gaia-migrate`) | 49 |
| Failing skills (setup.sh or finalize.sh exit != 0) | 66 |
| Passing skills with scripts | 0 |

Every skill that has a `setup.sh` fails. Every skill that relies solely on
SKILL.md LLM prose (no scripts) is classified `NO-SCRIPTS`. These latter skills
"work" in the sense that the harness can't fail them, but they are not safe —
several of them still reference `_gaia/_config/*.csv` literal paths in their
SKILL.md body prose (see B3 below).

## Failure Classification (AC3)

### B1 — CLAUDE_SKILL_DIR path contract mismatch — 66 / 66 failures

**Evidence.** Every failing skill emits the identical stderr line:

```
<skill-name>/setup.sh: resolve-config.sh failed:
resolve-config: config file not found:
  /Users/jlouage/.claude/plugins/cache/.../skills/<skill-name>/config/project-config.yaml
```

`resolve-config.sh` (lines 236–242) computes the default shared config path as
`${CLAUDE_SKILL_DIR}/config/project-config.yaml`. Under Claude Code's plugin
harness `CLAUDE_SKILL_DIR` is set to the **skill's own directory inside the
plugin cache**, not the user's project root. `config/project-config.yaml`
does not exist under the plugin cache and never will — it lives at the
user's project root, which is where `/gaia-migrate apply` wrote it.

**Root-cause predicate:** the path contract assumed `CLAUDE_SKILL_DIR ==
project root`. Claude Code does not provide that. `CLAUDE_PROJECT_ROOT` (or the
setup-script `cwd`, which equals the invoking user's cwd) is the correct
anchor.

### B4 — Missing `global.yaml` overlay with required fields — latent cascade, confirmed

Independently reproduced by running `resolve-config.sh` directly with
`CLAUDE_SKILL_DIR` pointed at the project root (the B1 fix). Output:

```
$ CLAUDE_SKILL_DIR=/tmp/gaia-audit-fixture \
    bash .../resolve-config.sh
resolve-config: missing required field: checkpoint_path
```

`resolve-config.sh` (lines 340–346) requires `checkpoint_path`, `date`,
`framework_version`, `installed_path`, `memory_path`, `project_path`,
`project_root` as mandatory fields on the merged (shared + local) surface.
`gaia-migrate.sh` (lines 313–326) deliberately splits the v1 `global.yaml`
into:

- **local keys** (framework_version, project_root, project_path, memory_path,
  checkpoint_path, installed_path, config_path, user_name, etc.) → retained
  in `_gaia/_config/global.yaml` rewritten in place
- **shared keys** (ci_cd, val_integration, sizing_map, problem_solving, etc.)
  → new `config/project-config.yaml`

Then E28-S188 runs `rm -rf _gaia/`. After that the ONLY surviving config file
is `config/project-config.yaml` — which contains **zero** of the seven
required fields.

**This is not a secondary bug. It is the actual blocker.** Fixing B1 in
isolation turns the error message from "config file not found" into "missing
required field: checkpoint_path" but the skill still fails.

### B2 — Checkpoint write target deleted — 0 observed, because B1 short-circuits first

Checkpoint write failures (`checkpoint.sh write failed for <workflow>`) do
appear in 55 of the 66 `finalize.sh` stderr heads, but only because the
skills proceeded through `finalize.sh` despite `setup.sh` exiting 1. Once B1 +
B4 are fixed the checkpoint bug moves from "hidden under another failure" to
"first observable error." A checkpoint write under a deleted `_memory/`
directory will fail — `mkdir -p` inside the checkpoint script needs to be
audited too. Treat B2 as **latent, not-yet-reached**, and require fix stories
to explicitly cover it.

### B3 — SKILL.md body references to `_gaia/_config/*` literal paths — 15 skills

A grep of every installed `SKILL.md` for the pattern `_gaia/_config/[a-z-]+\.(csv|yaml|md)`:

```
gaia-brainstorm, gaia-bridge-disable, gaia-bridge-enable, gaia-bridge-toggle,
gaia-create-prd, gaia-edit-arch, gaia-edit-prd, gaia-edit-ux, gaia-help,
gaia-migrate, (5 more) — 15 total
```

These skills' LLM prose instructs "load `_gaia/_config/gaia-help.csv`" or
"read `_gaia/_config/workflow-manifest.csv`" as literal file paths. Claude
Code reads those paths relative to the project cwd. On the reporter's
workspace the legacy `Gaia-framework/_gaia/_config/` directory existed
outside the project root — enough for Claude to find `gaia-help.csv` via the
legacy fallback — but on a clean v1→v2 migration target the entire `_gaia/`
tree is gone and the Read tool returns "file not found."

gaia-help specifically has a graceful-missing-file contract in its own SKILL.md
(Step 1 — `workflow-manifest.csv missing → fall back to /gaia`), so it
degrades gracefully even when the file is missing. That is why the user
saw it "work" rather than fail hard. The other 14 are not known to degrade
gracefully.

### B5 — Other — none observed

The classifier reserves B5 for unknowns. No failing skill landed in B5.

## Minimal Fix Per Bucket (AC4, not implemented)

### B1 fix

**Target file:** `gaia-public/plugins/gaia/scripts/resolve-config.sh`
(also published to `~/.claude/plugins/cache/.../scripts/resolve-config.sh`).

**Change.** Lines 236–242 currently read:

```bash
if [ -z "$SHARED_PATH" ]; then
  if [ -n "${CLAUDE_SKILL_DIR:-}" ]; then
    SHARED_PATH="${CLAUDE_SKILL_DIR}/config/project-config.yaml"
  fi
fi
```

Replace with a lookup that prefers `CLAUDE_PROJECT_ROOT`, falls back to
`pwd`, and keeps `CLAUDE_SKILL_DIR` as a last-resort legacy alias:

```bash
if [ -z "$SHARED_PATH" ]; then
  if [ -n "${CLAUDE_PROJECT_ROOT:-}" ] && \
     [ -f "${CLAUDE_PROJECT_ROOT}/config/project-config.yaml" ]; then
    SHARED_PATH="${CLAUDE_PROJECT_ROOT}/config/project-config.yaml"
  elif [ -f "$PWD/config/project-config.yaml" ]; then
    SHARED_PATH="$PWD/config/project-config.yaml"
  elif [ -n "${CLAUDE_SKILL_DIR:-}" ] && \
       [ -f "${CLAUDE_SKILL_DIR}/config/project-config.yaml" ]; then
    SHARED_PATH="${CLAUDE_SKILL_DIR}/config/project-config.yaml"
  fi
fi
```

Needs a parallel update to the default `--local` lookup so the local
overlay can be discovered from the same anchor. Document the discovery
order in the file header and in
`gaia-public/plugins/gaia/config/MIGRATION-from-global-yaml.md`.

### B4 fix

Two independent options — the fix story must pick one and commit.

**Option A (recommended).** Teach `/gaia-migrate` to write a minimal
`config/global.yaml` (machine-local overlay) at the project root during
`_migrate_config_split`. Content: the seven required fields seeded from
the pre-split `_gaia/_config/global.yaml`. This is a one-file write, one
additional `resolve-config.sh` default path
(`CLAUDE_PROJECT_ROOT/config/global.yaml`), and no schema changes. Keeps
the split-file semantics intact.

**Option B.** Move the seven required fields into `config/project-config.yaml`
itself (team-shared). Violates the split premise (they are per-developer,
not team-shared) and breaks the current schema at
`gaia-public/plugins/gaia/config/project-config.schema.yaml`. Not recommended.

### B2 fix (latent)

**Target files:** `gaia-public/plugins/gaia/scripts/checkpoint.sh` and every
`<skill>/scripts/finalize.sh`. Before writing, ensure `checkpoint_path`
exists with `mkdir -p "$checkpoint_path"`. The path itself must come from
resolve-config output (already correct once B1 + B4 land).

### B3 fix

**Target files:** every `SKILL.md` body that grep found. Rewrite the literal
references to read from the plugin's bundled knowledge files
(`${CLAUDE_SKILL_DIR}/../../knowledge/` or equivalent) rather than
`_gaia/_config/`. For gaia-help specifically, ship `gaia-help.csv` and
`workflow-manifest.csv` inside the plugin cache (under `knowledge/`) and
update the SKILL.md to read them from the plugin-resolved path. Retire the
legacy-fallback code path in the SKILL.md body prose.

## Prioritized Fix-Story List (AC5)

| Story | Title | Bucket | Size | Unblocks | Owner |
| --- | --- | --- | --- | --- | --- |
| **E28-S191** | Fix `resolve-config.sh` path discovery (prefer `CLAUDE_PROJECT_ROOT`, fall back to `PWD`) | B1 | S (2 pts) | 66 skills' setup.sh | release-eng |
| **E28-S192** | Make `/gaia-migrate` preserve required local-config fields at project root | B4 | S (2 pts) | All 66 skills post-E28-S191 | release-eng |
| **E28-S193** | Ensure `checkpoint_path` exists before checkpoint write | B2 | XS (1 pt) | finalize.sh of all 66 skills | release-eng |
| **E28-S194** | Retire `_gaia/_config/*.csv` literal paths from 15 SKILL.md files; ship `gaia-help.csv` + `workflow-manifest.csv` inside plugin `knowledge/` | B3 | M (5 pts) | gaia-help and 14 related skills on a clean v1→v2 migration target | release-eng |
| **E28-S195** | Regression: extend `audit-v2-migration.sh` into a CI gate — run nightly on a synthetic fixture and fail the build if any `setup.sh` exits non-zero | tooling | M (5 pts) | Future migration changes | release-eng |

**Blast-radius ordering:** E28-S191 + E28-S192 together unblock every failing
skill. Ship as a pair. E28-S193 must ride along because its preconditions are
cleared by E28-S191/S192. E28-S194 is parallelizable (different files).
E28-S195 is the regression guard that prevents this exact class of bug from
recurring.

## Recommendation on E28-S188 Revert (AC6)

**Revert E28-S188 on `main` immediately.**

Rationale:

1. **E28-S188 deletes the only source of truth for required config fields.**
   The config split (E28-S131) moved local keys into `_gaia/_config/global.yaml`.
   E28-S188 then deletes that directory. No other file has those fields.
   `resolve-config.sh` cannot resolve without them.
2. **Fixing B1 alone is not sufficient.** Verified by direct invocation with
   `CLAUDE_SKILL_DIR` corrected — the resolver still fails at the required-field
   check. The user would see "progress" (different error message) but the
   plugin is still bricked.
3. **The config-split step (E28-S131) is valuable and should stay.** It cleanly
   separates team-shared from machine-local config. Reverting E28-S188 keeps the
   split, keeps the backup, keeps the `config/project-config.yaml` output —
   only the destructive `rm -rf _gaia/ _memory/ custom/` step is removed.
4. **Backup directory already exists.** `.gaia-migrate-backup/pre-delete-*/`
   demonstrates the backup machinery works. Reverting E28-S188 costs nothing
   — we just stop running the delete until B1 + B4 + B2 are fixed and
   validated against `audit-v2-migration.sh`.

Proposed PR body for the revert: "Revert E28-S188 destructive delete pending
E28-S191, E28-S192, E28-S193. The backup step and the config split (E28-S131)
are retained. The v1 directories stay in place until the path-resolution
fixes land and the audit harness comes back green against a clean fixture.
See `docs/implementation-artifacts/E28-S190-v2-post-migration-audit.md`."

## Appendix A — Full Bucket Table

See `docs/implementation-artifacts/E28-S190-audit-results.csv` for the complete
115-row table. Shape:

- 66 rows with `bucket=B1` (all failing skills).
- 49 rows with `bucket=NO-SCRIPTS` (LLM-only skills — no setup.sh/finalize.sh).
- 0 rows with `bucket=OK` (no skill's scripts currently pass under the
  post-migration contract).
- 0 rows with `bucket=B2`, `B3`, `B4`, `B5` — the classifier caught everything
  at B1 because B1 short-circuits before any downstream bug can be observed by
  the script. B3 was detected separately via SKILL.md grep (15 hits). B4 was
  detected separately via direct `resolve-config.sh` replay.

## Appendix B — How gaia-help appeared to "work"

On the reporter's workspace, `~/Dev/Gaia-framework/_gaia/_config/` still
existed as a sibling-tree from an older v1 checkout outside the GAIA-Framework
project root. When `/gaia:gaia-help` was invoked, the LLM's Read tool
resolved the literal `_gaia/_config/gaia-help.csv` against the cwd, walked
up, and found the legacy file — the skill ran. On a clean v1→v2 migration
target (no legacy tree outside the project root), the Read would return
"file not found" and gaia-help's documented graceful-fallback path would
kick in: emit "workflow-manifest.csv missing — falling back to /gaia" and
produce only `/gaia` as the suggestion. That is the B3 failure mode on a
clean host.

## Appendix C — Files Touched by This Story

| File | Change | Reason |
| --- | --- | --- |
| `gaia-public/scripts/audit-v2-migration.sh` | **new** | Reproducible audit harness (AC1). |
| `docs/implementation-artifacts/E28-S190-audit-results.csv` | **new** | Machine-readable full results table (AC3). |
| `docs/implementation-artifacts/E28-S190-v2-post-migration-audit.md` | **new** | This findings document (AC7). |
| `docs/implementation-artifacts/E28-S190-tdd-progress.md` | **new** | TDD adapted progress file (RED/GREEN/REFACTOR). |
| `docs/implementation-artifacts/E28-S190-audit-v2-post-migration-functionality.md` | **modified** | Story file — DoD checked, Findings table populated, status → review. |
