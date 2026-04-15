# gaia-public

GAIA Framework — Generative Agile Intelligence Architecture. Public Claude Code marketplace distributing the `gaia` plugin: 25 specialized agents, 62 workflows, and 8 shared skills.

## Install

```
/plugin marketplace add gaiastudio-ai/gaia-public
/plugin install gaia@gaiastudio-ai-gaia-public
/reload-plugins
```

The `/reload-plugins` step is required after install for the plugin's agents, skills, and commands to become available in the current Claude Code session.

### Recovery

If the initial `/plugin marketplace add` fails due to a cached broken clone, clear it and retry:

```
rm -rf ~/.claude/plugins/marketplaces/gaiastudio-ai-gaia-public/
/plugin marketplace add gaiastudio-ai/gaia-public
```

## License

AGPL-3.0 — see [LICENSE](./LICENSE).
