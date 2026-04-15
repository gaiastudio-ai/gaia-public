# gaia-public

GAIA Framework — Generative Agile Intelligence Architecture. Public Claude Code marketplace distributing the `gaia` plugin: 25 specialized agents, 62 workflows, and 8 shared skills.

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

### Private marketplace authentication

The enterprise marketplace lives in a private GitHub repo (`gaiastudio-ai/gaia-enterprise`). It works out of the box with your existing `gh auth` credentials — there is **no Claude Code-specific authentication layer** for private marketplaces and none is planned. If `gh auth status` shows you are logged in as a user with read access to `gaiastudio-ai/gaia-enterprise`, then `/plugin marketplace add gaiastudio-ai/gaia-enterprise` will succeed; if not, run `gh auth login` first. Distribution access is governed by GitHub repo ACLs. The only license enforcement that runs server-side is the CI `license-check` job in the enterprise repo's `plugin-ci.yml`, which gates publication on a valid `LICENSE` file, a populated `license` field in `plugin.json`, and SPDX headers on shipped markdown.

If you prefer a guarded, scriptable alternative to the raw `rm -rf`, the plugin ships `plugins/gaia/scripts/plugin-cache-recovery.sh`. It validates the slug, classifies the cache entry as `absent` / `healthy` / `polluted`, and refuses to remove a healthy clone unless `--force` is passed:

```
plugins/gaia/scripts/plugin-cache-recovery.sh --detect --slug gaiastudio-ai-gaia-public
plugins/gaia/scripts/plugin-cache-recovery.sh --slug gaiastudio-ai-gaia-public --dry-run
plugins/gaia/scripts/plugin-cache-recovery.sh --slug gaiastudio-ai-gaia-public
```

`--detect` exits `2` on a polluted entry so CI and workflow steps can branch on it without parsing text; `--dry-run` prints the intended target without touching the filesystem. See the script header for the full exit-code table and slug-validation rules.

## Plugin component discovery rules

Claude Code auto-discovers plugin components at install time from conventional subdirectories under `plugins/gaia/`. The rules below are empirical (captured against Claude Code CLI `2.1.109` on 2026-04-15) and apply to any plugin authored in this marketplace, not just `gaia`. The full long-form writeup with source evidence lives in `docs/planning-artifacts/gaia-native-conversion-prereqs.md` §2.1.

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

## License

AGPL-3.0 — see [LICENSE](./LICENSE).
