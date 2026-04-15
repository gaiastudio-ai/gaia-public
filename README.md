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

## License

AGPL-3.0 — see [LICENSE](./LICENSE).
