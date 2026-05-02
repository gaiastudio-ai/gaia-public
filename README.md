# gaia-public

GAIA Framework — Generative Agile Intelligence Architecture. Public Claude Code marketplace distributing the `gaia` plugin: 25 specialized agents, 62 workflows, and 8 shared skills.

## Pre-Release Notice (v1.127.x)

GAIA v2 (plugin-based) is currently in **early-adopter preview**. The v1 → v2 migration path (`/gaia-migrate apply`) is functional on a reference fixture but is still stabilizing on real v1 projects.

**If you are evaluating GAIA:** start a fresh project with the v2 plugin — do not migrate a production v1 project yet.

**If you must migrate a v1 project today:**

- Back up your `_gaia/`, `_memory/`, and `custom/` directories before running `/gaia-migrate apply`. The migrator creates its own backup under `.gaia-migrate-backup/`, but an independent copy is cheap insurance.
- After migration, run `plugins/gaia/scripts/audit-v2-migration.sh` (from the plugin install) against your project root and confirm zero failing skills before trusting any generated output.
- Some skills still reference legacy v1 paths (`_gaia/_config/*`) in their body prose and will fall back to a degraded-but-functional response on a freshly migrated project. Tracked under E28-S196 and the post-migration audit follow-ups.

We will remove this notice once the v2 migration regression gate is green and the remaining SKILL.md path references are closed out (tracked in E28-S195, E28-S196, and the B5 triage story).

## Install

```
/plugin marketplace add gaiastudio-ai/gaia-public
/plugin install gaia@gaiastudio-ai-gaia-public
/reload-plugins
```

The `/reload-plugins` step is **required** after `/plugin install` — without it, the plugin's agents, skills, and commands do not become available in the current Claude Code session. This is silent: no error is shown if you skip it, the components just never register. If you installed the plugin and your `/gaia` commands are missing, run `/reload-plugins` first before reporting a bug.

### Recovery from a polluted marketplace cache

If the initial `/plugin marketplace add` fails (for example, a transient network error or an earlier broken clone cached under `~/.claude/plugins/marketplaces/`), the failure can leave a polluted cache entry that causes every subsequent retry to fail with the same error. Clear the cache and retry:

```
rm -rf ~/.claude/plugins/marketplaces/gaiastudio-ai-gaia-public/
/plugin marketplace add gaiastudio-ai/gaia-public
```

The same pattern applies to the enterprise marketplace — replace `gaia-public` with `gaia-enterprise` in both the directory path and the `marketplace add` command.

This cache-pollution behaviour is tracked upstream at [anthropics/claude-code#48736](https://github.com/anthropics/claude-code/issues/48736) — we have requested that `/plugin marketplace add` either re-fetch on a failed parse or clean up the cache entry on clone failure so this recovery recipe becomes unnecessary. Until that lands, you can also run the automated helper `plugins/gaia/scripts/plugin-cache-recovery.sh --slug gaiastudio-ai-gaia-public` which encodes the same fix non-interactively.

### Private marketplace authentication

The enterprise marketplace lives in a private GitHub repo (`gaiastudio-ai/gaia-enterprise`). It works out of the box with your existing `gh auth` credentials — there is **no Claude Code-specific authentication layer** for private marketplaces and none is planned. If `gh auth status` shows you are logged in as a user with read access to `gaiastudio-ai/gaia-enterprise`, then `/plugin marketplace add gaiastudio-ai/gaia-enterprise` will succeed; if not, run `gh auth login` first. Distribution access is governed by GitHub repo ACLs. The only license enforcement that runs server-side is the CI `license-check` job in the enterprise repo's `plugin-ci.yml`, which gates publication on a valid `LICENSE` file, a populated `license` field in `plugin.json`, and SPDX headers on shipped markdown.

If you prefer a guarded, scriptable alternative to the raw `rm -rf`, the plugin ships `plugins/gaia/scripts/plugin-cache-recovery.sh`. It validates the slug, classifies the cache entry as `absent` / `healthy` / `polluted`, and refuses to remove a healthy clone unless `--force` is passed:

```
plugins/gaia/scripts/plugin-cache-recovery.sh --detect --slug gaiastudio-ai-gaia-public
plugins/gaia/scripts/plugin-cache-recovery.sh --slug gaiastudio-ai-gaia-public --dry-run
plugins/gaia/scripts/plugin-cache-recovery.sh --slug gaiastudio-ai-gaia-public
```

`--detect` exits `2` on a polluted entry so CI and workflow steps can branch on it without parsing text; `--dry-run` prints the intended target without touching the filesystem. See the script header for the full exit-code table and slug-validation rules.

## Migrate from GAIA v1

If your project already has a GAIA v1 install (the legacy `Gaia-framework` npm installer — presence of `_gaia/`, `_memory/`, `custom/` directories in the project root, plus `.claude/commands/gaia-*.md` stubs), the `gaia-migrate` skill automates the upgrade to the v2 plugin layout.

**Prerequisite:** the `gaia` plugin must be installed and loaded first (see the Install section above).

### Preview the migration (read-only)

```
/gaia:gaia-migrate --dry-run
```

The dry-run prints every planned operation — template conversions, sidecar rewrites, config file splits, legacy command stubs to delete, v1 directories to back up and remove, total backup size — without touching the filesystem. Safe to run as many times as you want.

### Apply the migration

```
/gaia:gaia-migrate apply
```

`apply` executes the plan. Each destructive step backs up before deleting, so a full restore to v1 state is always possible from the backup tree. In order:

1. Migrate templates from `_gaia/` into plugin skills.
2. Rewrite sidecar files under `_memory/`.
3. Split `_gaia/_config/global.yaml` into `config/project-config.yaml` (v2 shape).
4. Back up and delete legacy `.claude/commands/gaia-*.md` stubs (only files matching `gaia-*.md` — your own command files are untouched).
5. Back up and delete the v1 directories `_gaia/`, `_memory/`, `custom/`. This step requires `config/project-config.yaml` to be present and valid (safety gate) and prompts for an explicit `yes` confirmation. Pass `--yes` or `--force` to skip the prompt in CI / non-interactive contexts.
6. Print a rollback command so you can restore v1 state from the backup if anything went wrong.

### Smoke-test after apply

```
/gaia:gaia-help
```

The `gaia:` prefix is important — it resolves to the plugin's `gaia-help` skill unambiguously. After a successful migration there should be exactly one `/gaia:gaia-help` registration; the legacy `.claude/commands/gaia-help.md` stub has been removed by step 4 above.

If `/gaia:gaia-help` prints context-sensitive GAIA help, the migration succeeded. If it's unknown, re-run `/reload-plugins` and confirm the install (see "Install" above).

### Rollback

The apply command prints the exact rollback command at the end, of the form:

```
cp -a $BACKUP_ROOT/_gaia $BACKUP_ROOT/_memory $BACKUP_ROOT/custom .
cp -a $BACKUP_ROOT/.claude/commands/ .claude/
```

The backup tree is in the project root (timestamped directory like `.gaia-migrate-backup-<timestamp>/`). Delete the backup tree manually once you're satisfied with the v2 install.

### Idempotence

Re-running `/gaia:gaia-migrate apply` on a project that is already on v2 (no v1 markers, `config/project-config.yaml` present) is a no-op — it prints "Nothing to migrate — already on v2." and exits 0.

## Plugin component discovery rules

Claude Code auto-discovers plugin components at install time from conventional subdirectories under `plugins/gaia/`. The rules below are empirical (captured against Claude Code CLI `2.1.109` on 2026-04-15) and apply to any plugin authored in this marketplace, not just `gaia`. The full long-form writeup with source evidence lives in `docs/planning-artifacts/assessments/gaia-native-conversion-prereqs.md` §2.1.

**Scanned subdirectories (defaults, relative to the plugin root):**

| Subdir | What it registers | Notes |
|--------|-------------------|-------|
| `.claude-plugin/plugin.json` | Plugin manifest | Required. Plugin is ignored entirely if missing. Path is fixed. |
| `commands/*.md` | Slash commands | Flat scan only — nested dirs are **not** auto-recursed. Override with `"commands": [...]` in `plugin.json`. |
| `agents/*.md` | Subagents | Flat scan. Files whose basename starts with `_` (e.g. `_SCHEMA.md`, `_base-dev.md`) are treated as private payload and **not** registered as callable agents. |
| `skills/<slug>/SKILL.md` | Skills | One directory per skill. The entry file is **`SKILL.md`** (uppercase). Sibling `references/`, `examples/`, `scripts/` are payload. |
| `hooks/hooks.json` | Hook registrations | Single JSON file at a fixed path. Co-located scripts are payload — reach them via `${CLAUDE_PLUGIN_ROOT}/hooks/<file>`. Override with `"hooks": "./config/hooks.json"` or inline object. |
| `.mcp.json` | MCP servers | Single JSON file at plugin root, or inline `"mcpServers": { ... }`. |
| `scripts/`, `config/`, `test/` | — | **Not discovered.** Payload only. Reach them via `${CLAUDE_PLUGIN_ROOT}/<path>` from inside a command, hook, or skill body. |

**Case sensitivity:** subdirectory names are lowercase and strict (`commands/`, `agents/`, `skills/`, `hooks/`). `SKILL.md` is uppercase. macOS case-insensitive filesystems will mask casing bugs that surface only in Linux CI — treat casing as strict.

**Required frontmatter per component:**

- **Command** (`commands/<name>.md`): YAML frontmatter with `description` (required). Optional: `argument-hint`, `allowed-tools`.
- **Subagent** (`agents/<name>.md`): YAML frontmatter with `name` and `description` (both required). The `name` field **must** match the filename basename — a mismatch produces an unreachable agent.
- **Skill** (`skills/<slug>/SKILL.md`): YAML frontmatter with `name` and `description` (both required). The `name` field **must** match the parent directory name. The `description` is the trigger signature Claude Code matches against user intent — a weak description means the skill never fires.
- **Hook** (`hooks/hooks.json`): top-level `hooks` object keyed by event name (`PreToolUse`, `PostToolUse`, `UserPromptSubmit`, ...); each entry needs `type` and `command`. Optional: `matcher` (regex on tool name), `timeout`.

**Filename conventions:** kebab-case `.md` files for commands, agents, and skill directories. The plugin manifest `name` field must match `^[a-z][a-z0-9]*(-[a-z0-9]+)*$`. File extensions other than `.md` (for components) and `.json` (for hooks and MCP) are not scanned.

**Edge cases worth knowing:**

1. **Empty subdirectories install successfully.** The placeholder bootstrap pattern in E28-S4 / E28-S5 works because `/plugin install` never fails on an empty `skills/` or `hooks/` directory — the Plugin Details UI's `Will install: · Components will be discovered at installation` line is literal, not a preview.
2. **Nested command dirs are not auto-recursed.** `commands/ci/build.md` is invisible unless you list `"commands": ["./commands", "./commands/ci"]` in `plugin.json`.
3. **Malformed YAML frontmatter is silently skipped.** A subagent with an unquoted colon in its `description` will not appear in `/agents` and no error is shown during `/plugin install`. Debug by running `claude --debug` and grepping for the plugin load line, or by reducing the frontmatter to a minimal valid shape and adding fields back one at a time.
4. **Symlinks work on macOS/Linux but are a portability hazard.** `git archive` and the marketplace clone step do not always preserve symlink targets cleanly. This plugin deliberately avoids symlinks.
5. **Post-install `/reload-plugins` is mandatory** before newly installed components become callable in the current session. See the "Install" section above.

## CI regression gate: `audit-v2-migration`

Every pull request targeting `main` or `staging` runs the `audit-v2-migration` job in [.github/workflows/plugin-ci.yml](./.github/workflows/plugin-ci.yml). The job exercises every plugin skill's `setup.sh` and `finalize.sh` scripts through [scripts/audit-v2-migration.sh](./scripts/audit-v2-migration.sh) in `--fixture-mode enriched`, then gates the build on zero B1–B5 regressions:

- **Exit 0** — every skill lands in `OK` or `NO-SCRIPTS`; CI passes.
- **Exit 1** — one or more skills regressed (B1 path contract, B2 checkpoint target, B3 SKILL.md literal paths, B4 global.yaml overlay, B5 skill-contract). This is a **plugin regression** and the PR must be fixed before merge.
- **Exit 2** — the harness itself erred (misconfig, fixture prep failure). Diagnose the harness, not the plugin.

The machine-readable summary line `audit-v2-migration: result=<PASS|FAIL> total=<N> ok=<N> no_scripts=<N> failed=<N>` is written to stderr at end-of-run so you can grep for the outcome without parsing the CSV. The per-skill CSV is uploaded as the `audit-v2-migration-csv` workflow artifact on every run — download it from the Actions UI for failure diagnostics.

Contributors: your PR will be audited automatically. If the job fails, open the run page, download the `audit-v2-migration-csv` artifact, and inspect the bucket column to identify which regression class was hit.

## Updating

GAIA updates are delivered automatically. When Claude Code starts a new session, its background auto-update mechanism checks the marketplace for a newer `plugin.json` version. If one exists, Claude Code pulls the update silently. No user action is required in the normal case.

**Force refresh (if auto-update seems stuck):**

```
/plugin marketplace update gaiastudio-ai-gaia-public
```

Then restart Claude Code. After restart, `/plugin` should report the new version.

**Private-repo users:** set `GITHUB_TOKEN` in your shell environment before launching Claude Code. The marketplace clone step requires read access to the repository. If `gh auth status` shows you are authenticated with read access, updates work automatically.

## Documentation

For a discovery entry point into the GAIA artifact directories
(`planning-artifacts/`, `implementation-artifacts/`, `test-artifacts/`) and
the role of each, see [docs/INDEX.md](./docs/INDEX.md).

## License

AGPL-3.0 — see [LICENSE](./LICENSE).
