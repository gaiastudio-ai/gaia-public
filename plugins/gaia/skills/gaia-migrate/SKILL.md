---
name: gaia-migrate
description: Automate the upgrade from GAIA v1 (workflow.xml engine) to v2 (Claude Code native plugin) — backup, migrate templates/memory/config, validate. Use after the v2 plugins have been installed via /plugin marketplace add.
when_to_use: When a user has an existing GAIA v1 installation (presence of _gaia/, _memory/, custom/) and wants to migrate to the v2 plugin layout. Run with `dry-run` first to see the planned operations. After `/gaia-migrate apply` completes, manually run `/gaia-help` to smoke-test the post-migration install — filesystem-only validation cannot exercise skill invocation, so a live `/gaia-help` run is the only way to confirm slash-command routing, plugin discovery, and skill loading are wired up end-to-end.
allowed-tools: [Read, Bash]
---

## Mission

Automate the v1 → v2 migration documented in `gaia-public/docs/migration-guide-v2.md`. Per ADR-042 (scripts-over-LLM), filesystem operations delegate to `plugins/gaia/scripts/gaia-migrate.sh`. This SKILL.md drives the user-facing flow: confirm the user wants to migrate, run dry-run first, then apply, then surface the script's structured summary.

## When to use

- The user has run `/plugin marketplace add gaia-public` (and `gaia-enterprise` if licensed) and confirmed `/plugin list` shows them.
- The user's project root contains v1 markers: `_gaia/`, `_memory/`, `custom/`, and `_gaia/_config/global.yaml`.
- The user has read `gaia-public/docs/migration-guide-v2.md` (or wants the automated path).

If the user has NOT installed the v2 plugins yet, point them to §1 Prerequisites of the migration guide first — `/gaia-migrate` cannot install plugins.

## Steps

1. **Confirm intent.** Ask the user: "Run dry-run first to preview, or apply directly?" Default to dry-run.

2. **Run dry-run.** Invoke:
   ```bash
   plugins/gaia/scripts/gaia-migrate.sh dry-run --project-root .
   ```
   Surface the printed plan to the user. Highlight the backup destination, migration steps, and any HALT conditions.

3. **If user approves, run apply.** Invoke:
   ```bash
   plugins/gaia/scripts/gaia-migrate.sh apply --project-root .
   ```
   The script handles backup → migration → validation → summary. Stream the output.

4. **Surface the SUCCESS / FAILED banner.** On `SUCCESS`, confirm the migration is complete and remind the user the backup is at `.gaia-migrate-backup/{ts}/`. On `FAILED`, surface the printed restore command verbatim and instruct the user to inspect the backup before retrying.

5. **Manual follow-up items.** If the script printed any `manual follow-up:` lines, list them to the user with §-references back to the migration guide.

6. **Manual post-migration smoke-test.** Instruct the user to run `/gaia-help` in the migrated project and confirm it returns the context-sensitive help menu. This is the canonical post-migration smoke-test: the script's filesystem-only validation cannot exercise skill invocation, so only a live `/gaia-help` run proves slash-command routing, plugin discovery, and skill loading survived the migration. If `/gaia-help` does not respond, direct the user to §Troubleshooting of the migration guide.

## Authoritative source

The mechanical migration steps are documented in `gaia-public/docs/migration-guide-v2.md` (E28-S130). This skill automates that walkthrough; the guide remains the human-readable reference. If the script detects a state the guide doesn't cover (e.g., a corrupt v1 file), surface it as a `manual follow-up:` line and direct the user to the guide.

## Safety

- **Backup before any write.** The script's `_safe_write()` helper gates every `cp`, `mv`, `rm` behind the dry-run flag and runs the backup step BEFORE any migration step writes (AC2).
- **Dry-run is idempotent.** Running dry-run twice produces identical plans (AC5).
- **Restore command is always printed.** Both `SUCCESS` and `FAILED` summaries echo the exact `cp -a "{backup}" "{project-root}"` command for manual rollback (AC-EC8).
- **Script does NOT auto-restore on failure.** Explicit user action is required (per §safety doctrine — automatic restoration could mask real issues).

## References

- Migration guide (authoritative manual-steps source): `gaia-public/docs/migration-guide-v2.md` (E28-S130)
- Backing script: `plugins/gaia/scripts/gaia-migrate.sh`
- Manual integration-test plan (edge cases AC-EC2/3/5/7): `docs/test-artifacts/E28-S170-gaia-migrate-edge-cases-test-plan.md` (E28-S170) — reproducible steps, expected behavior, and environment setup for edge cases that are not bats-testable without dedicated scaffolding (tmpfs size caps, corrupt-byte fixtures, signal-interrupt timing)
- ADR-042: Scripts-over-LLM for Deterministic Operations
- ADR-048: Engine Deletion as Program-Closing Action
- FR-326: Config Split (drives subtask 4.3 partition rules)
- FR-328: Engine Deletion (program-closing motivation for the migration)
