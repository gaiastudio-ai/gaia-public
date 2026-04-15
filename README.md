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

## License

AGPL-3.0 — see [LICENSE](./LICENSE).
