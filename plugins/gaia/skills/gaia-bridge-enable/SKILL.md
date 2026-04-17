---
name: gaia-bridge-enable
description: Enable the Test Execution Bridge by delegating to gaia-bridge-toggle with mode=enable. Thin wrapper that preserves the user-visible /gaia-bridge-enable slash command (AC11, FR-323). Edits test_execution_bridge.bridge_enabled = true in _gaia/_config/global.yaml and re-runs /gaia-build-configs. Idempotent — no write when already enabled.
allowed-tools: [Read, Edit, Bash]
---

## Mission

You are the `/gaia-bridge-enable` wrapper. This skill preserves the existing user-visible slash command while delegating the full toggle semantics to `gaia-bridge-toggle`.

This skill is part of the native Claude Code conversion under E28-S111 (Cluster 14). The legacy `bridge-toggle` workflow is converted to `gaia-bridge-toggle/SKILL.md`; this wrapper keeps the enable-specific alias working per ADR-041 and AC11 of E28-S111.

## Critical Rules

- **Delegate to `gaia-bridge-toggle` with mode=enable.** Do NOT duplicate the toggle logic here.
- **Hard-code mode=enable.** This wrapper is enable-only. Ignore any `$ARGUMENTS` that attempt to override the mode.
- **Preserve the user-visible slash command.** `/gaia-bridge-enable` must continue to resolve for OSS users with zero behavioral change (AC11).

## Delegation

Follow the full `gaia-bridge-toggle` skill body with `mode = enable`:

1. Read `_gaia/_config/global.yaml` and extract `test_execution_bridge.bridge_enabled`.
2. If the section is missing, fail fast with `test_execution_bridge block missing — run /gaia-ci-setup first`.
3. If already `true`, report `Bridge already enabled` and exit without writing.
4. Otherwise, perform the regex-based in-place edit to flip `bridge_enabled: false` → `bridge_enabled: true`, preserving all comments and formatting.
5. Run the Post-Flip Checks (enable-only — stat `docs/test-artifacts/test-environment.yaml`; for absent in YOLO, auto-skip with a warning).
6. Emit the summary, ending with the mandatory next-step suggestion: `Run /gaia-build-configs to regenerate the resolved configs so the bridge_enabled change takes effect.`

The full step-by-step procedure is documented in `plugins/gaia/skills/gaia-bridge-toggle/SKILL.md`. This wrapper inherits all behavior from that skill.

## References

- Delegate: `plugins/gaia/skills/gaia-bridge-toggle/SKILL.md` (full five-step procedure).
- Legacy source: `_gaia/core/workflows/bridge-toggle/instructions.xml` (69 lines) — parity reference for NFR-053.
- ADR-041 — Native Execution Model via Claude Code Skills + Subagents + Plugins + Hooks.
- FR-323 — Native Skill Format Compliance (slash-command continuity).
- E28-S111 AC11 — wrapper pattern for one-to-many slash-command mappings.
