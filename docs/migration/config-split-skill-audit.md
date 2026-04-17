# E28-S144 — Config-Split Skill Audit

> **Authoritative scope artifact** for the skill-level migration that removes direct `global.yaml` / `config/project-config.yaml` reads from SKILL.md bodies in favor of `!scripts/resolve-config.sh {key}` (ADR-044 §10.26.3).
>
> **Story:** E28-S144
> **Date:** 2026-04-17
> **Author:** Auto-generated via `scripts/audit-skill-config-reads.sh`, annotated with migration decisions.
>
> **Rerun:**
> ```bash
> plugins/gaia/scripts/audit-skill-config-reads.sh plugins/gaia/skills
> ```

## Audit Method

1. Ran `grep -rnE "global\.yaml|project-config\.yaml"` against every `plugins/gaia/skills/*/SKILL.md` file (Task 1).
2. For each match: captured `file:line:text`, then classified by intent — is this a **read** of a config value, a **write** to the config file, a **meta-validation** of the config schema, or an **explanatory prose** reference?
3. Read-side references were migrated to `!scripts/resolve-config.sh {key}`. Write-side / meta-validator references were added to the allowlist in `verify-no-direct-config-reads.sh` with rationale comments. Explanatory prose mentioning the filenames was wrapped in HTML comments so the refined scan tolerates it (AC3).

## Scope Classification

| # | Skill | Lines | Intent | Action |
|---|-------|-------|--------|--------|
| 1 | `gaia-sprint-plan` | 23, 45 | Reads `sizing_map` | **Migrate** → `!scripts/resolve-config.sh sizing_map` |
| 2 | `gaia-rollback-plan` | 35, 43 | Reads `ci_cd.promotion_chain` context | **Migrate** → `!scripts/resolve-config.sh --format shell` + prose indirection note |
| 3 | `gaia-deploy-checklist` | 33 | Reads `ci_cd.promotion_chain` config key | **Migrate** → `!scripts/resolve-config.sh ci_cd.promotion_chain` |
| 4 | `gaia-val-validate-plan` | 70 | Names `framework_version` source file | **Migrate** → `!scripts/resolve-config.sh framework_version` |
| 5 | `gaia-validation-patterns` | 88 | Documents `{project-path}` provenance | **Migrate** → `!scripts/resolve-config.sh project_path` |
| 6 | `gaia-bridge-toggle` | 3, 10, 20, 35, 43, 52, 59, 60, 95 | **Writes** `test_execution_bridge.bridge_enabled` in-place | **Allowlist** — config editor (cannot route through a read-only resolver) |
| 7 | `gaia-bridge-enable` | 3, 24 | **Writes** (thin wrapper over bridge-toggle) | **Allowlist** — config editor |
| 8 | `gaia-bridge-disable` | 3, 24 | **Writes** (thin wrapper over bridge-toggle) | **Allowlist** — config editor |
| 9 | `gaia-ci-setup` | 18, 28, 43, 48 | **Writes** `ci_cd.promotion_chain` in-place | **Allowlist** — config editor |
| 10 | `gaia-ci-edit` | 3, 14, 18, 22, 29, 33, 41, 92, 95 | **Writes** `ci_cd.promotion_chain` in-place (CRUD UI) | **Allowlist** — config editor |
| 11 | `gaia-validate-framework` | 18, 36, 83, 143 | **Meta-validates** that `global.yaml` parses end-to-end | **Allowlist** — meta-validator (its job is to parse the file directly) |

## Rationale for Allowlist

Three skill families legitimately reference the filenames directly and **cannot** route through `resolve-config.sh`:

1. **Config editors** (`gaia-bridge-toggle` and its two wrappers, `gaia-ci-setup`, `gaia-ci-edit`) — they **write to** `global.yaml` in place, preserving comments and field ordering. `resolve-config.sh` is read-only and emits flattened `KEY='VALUE'` output, which cannot round-trip YAML with comments. Using a write-side indirection script would increase complexity without benefit — they must edit the file directly.
2. **Meta-validator** (`gaia-validate-framework`) — its explicit mandate is to verify that `global.yaml` and each module `config.yaml` parse as valid YAML and that the inheritance chain resolves correctly. Routing this through `resolve-config.sh` would defeat the purpose (the resolver already assumes the files parse).

Both categories are captured in the allowlist inside `scripts/verify-no-direct-config-reads.sh` with inline comments explaining the exemption. Adding a new skill to the allowlist MUST include a rationale comment in that file — CI review enforces the invariant.

## Behavioral Parity (AC4)

| Skill | Pre-migration read | Post-migration read | Value diff |
|-------|--------------------|---------------------|------------|
| `gaia-sprint-plan` | `yq '.sizing_map' _gaia/_config/global.yaml` | `!scripts/resolve-config.sh sizing_map` (merged shared + local) | None — `sizing_map` lives in the shared layer per E28-S141; local never overrides. |
| `gaia-rollback-plan` | `cat _gaia/_config/global.yaml` + parse `ci_cd` | `!scripts/resolve-config.sh --format shell` | None — `ci_cd.promotion_chain` resolves identically; local layer passes through when absent. |
| `gaia-deploy-checklist` | Inline check against `ci_cd.promotion_chain` in `global.yaml` | `!scripts/resolve-config.sh ci_cd.promotion_chain` | None — promotion chain presence semantics unchanged. |
| `gaia-val-validate-plan` | Direct file path "`global.yaml: framework_version field`" | `!scripts/resolve-config.sh framework_version` | None — same key, same value, just via indirection. |
| `gaia-validation-patterns` | Documentation-only mention of `global.yaml` | Same, but resolver indirection called out | None — prose-only change. |

Zero behavioral drift expected. The refined scan (`verify-no-direct-config-reads.sh`) provides a continuous check that the invariant is preserved going forward.

## Scripts

Two helper scripts are checked in under `plugins/gaia/scripts/`:

- `audit-skill-config-reads.sh` — rerunnable audit. Scans every `SKILL.md`, emits `file:line:text` per match. Exit 0 on successful scan regardless of match count. Used by this audit doc and any future sprint that touches skills.
- `verify-no-direct-config-reads.sh` — CI guard. Same scan but skips allowlisted skills and strips HTML comments before grepping. Exits 1 on any non-allowlisted, non-comment direct read. Wire into CI to enforce AC3.

Both scripts default to resolving the skills directory via `${CLAUDE_PLUGIN_ROOT}/skills` at runtime; for local CI runs pass the directory as `$1`.
