# E28-S190 — TDD Progress

Investigation story — TDD adapted as described in the story context:

- **RED** = harness written and reproduces the observed failure.
- **GREEN** = harness + findings document produced cleanly.
- **REFACTOR** = findings doc reviewed and fix-story list finalized.

## RED Phase

**Harness:** `gaia-public/scripts/audit-v2-migration.sh`

Takes a post-migration fixture (v2 `config/` present, v1 `_gaia/`, `_memory/`,
`custom/` deleted) and walks every skill under
`~/.claude/plugins/cache/gaiastudio-ai-gaia-public/gaia/<ver>/skills/*/`,
invoking `setup.sh` and `finalize.sh` with `CLAUDE_SKILL_DIR` set to the
skill directory (mirroring Claude Code's plugin harness convention) and
`CLAUDE_PROJECT_ROOT` set to the project root. Captures exit codes and
stderr heads into a CSV, auto-classifies each failure into bucket B1/B2/B3/B4/B5.

**Fixture:** `/tmp/gaia-audit-fixture-<pid>/` — `config/` copied from
`/Users/jlouage/Dev/GAIA-Framework/config/` and `gaia-public/` copied as
project source. No `_gaia/`, no `_memory/`, no `custom/`.

**First run (RED):**

```
=== audit-v2-migration summary ===
total_skills: 115
failed_skills: 66
bucket_B1_path_contract: 66
bucket_B2_checkpoint_deleted: 0
bucket_B3_skill_md_literal_paths: 0
bucket_B4_global_yaml_overlay: 0
bucket_B5_other: 0
```

Every single failing skill produces exactly this stderr:

```
<skill-name>/setup.sh: resolve-config.sh failed:
resolve-config: config file not found:
  /Users/jlouage/.claude/plugins/cache/.../skills/<skill-name>/config/project-config.yaml
```

Matches the user's originally observed failure verbatim — the harness is valid.

## GREEN Phase

Findings document written to
`docs/implementation-artifacts/E28-S190-v2-post-migration-audit.md` with:

- full bucket breakdown (B1 = 66 failures, B4 = latent cascade confirmed
  by direct invocation with CLAUDE_SKILL_DIR corrected);
- minimal-fix description per bucket (no code changed — this is an audit);
- prioritized fix-story list (E28-S191, S192, S193) with estimates;
- recommendation on E28-S188 revert question.

Raw CSV preserved at `docs/implementation-artifacts/E28-S190-audit-results.csv`.

## REFACTOR Phase

Findings cross-checked:

- every B1 row in the CSV matches the `resolve-config: config file not found`
  signature, no false classification;
- the CLAUDE_SKILL_DIR-fixed replay (executed manually during authoring)
  demonstrates that even with the path contract corrected, every skill
  still fails with `resolve-config: missing required field: checkpoint_path`
  — proving B4 is a real latent cascade and the fix cannot stop at B1;
- the B1 + B4 chain explains 100% of the observed failures without
  invoking B2, B3, or B5.

No test suite to run (docs-only story). All 8 DoD items verified in the
story file's Definition of Done section.
