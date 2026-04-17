---
name: figma-integration
description: OSS stub for the premium figma-integration skill. The full Figma MCP integration (design token extraction, component spec generation, frame authoring, asset export, import flow, and fidelity gate) ships in the enterprise plugin behind the figma-premium feature flag. This OSS entry point is intentionally minimal — it documents the boundary and points users to the enterprise activation path.
version: '1.0'
license: enterprise
feature_flag: figma-premium
allowed-tools: [Read]
---

# Figma Integration — OSS Stub

> **This is the OSS stub.** The full `figma-integration` skill — design-tool MCP detection, design-token extraction, component spec generation, frame authoring, asset export, Figma import mode, and the design-to-implementation fidelity gate — is a premium capability and ships in the enterprise plugin (Cluster 17 / E28-S122). No premium extraction logic lives in this file by design — it is held in the enterprise plugin source tree and is activated only when the matching license and feature flag are present.
>
> **Premium upgrade available.** Install `gaia-enterprise` alongside this plugin and ensure the `figma-premium` feature flag is enabled on your license to activate the full capability set: `/plugin marketplace add gaiastudio-ai/gaia-enterprise && /plugin install gaia-enterprise`.

**Traces to:** FR-332 (enterprise license gate), FR-323 (native skill conversion), NFR-048 (OSS/enterprise separation), NFR-053 (feature parity), ADR-041 (native execution model), ADR-043 (OSS/enterprise split).

## License Gate

This skill is gated behind the enterprise license flag. Two frontmatter fields declare the gate:

| Field | Value | Meaning |
|---|---|---|
| `license` | `enterprise` | The callable skill body is reserved for enterprise-licensed workspaces. |
| `feature_flag` | `figma-premium` | Runtime activation requires this feature flag. Without it, invocation resolves to a friendly "enterprise required" message and the consuming workflow degrades gracefully to markdown-only operation. |

Per ADR-043, an OSS stub is always *loadable* — the linter and JIT loader both resolve this file without error — but invoking the skill body without the matching feature flag produces a non-blocking redirect rather than executing premium logic. The stub never contains the premium source at rest in the OSS git history.

## Enterprise Activation

The premium `figma-integration` skill ships in the enterprise GAIA plugin. To enable Figma-aware workflows (create-ux, edit-ux, dev-story figma hook, code-review fidelity gate):

1. Install the enterprise plugin alongside the OSS plugin. The enterprise plugin provides the full skill body under its own `plugins/gaia-enterprise/skills/figma-integration/` tree — see **E28-S122** for the delivery story and Cluster 17 for the surrounding enterprise bundle.
2. Ensure your workspace has the `figma-premium` feature flag enabled. License validation is performed by the enterprise plugin's SessionStart hook; the OSS plugin does not ship license-check code.
3. Once activated, the enterprise skill replaces this stub at load time — consuming workflows call the same skill name (`figma-integration`) and receive the full capability set.

If the enterprise plugin is not installed, consuming workflows continue in markdown-only mode (the behavior mandated by the OSS path — see the legacy skill's "Zero-change path" and FR-143 graceful-fallback requirement).

## Capability Summary (Enterprise Only)

The following capabilities are provided by the enterprise plugin and are NOT present in this OSS stub. They are listed here purely as pointers so OSS readers know what is gated:

- **Design tool detection** — probe for MCP server availability with graceful fallback.
- **Design token extraction** — map published styles into a standardised design-token format for downstream consumers.
- **Component specification extraction** — pull components, variants, and props into a tech-agnostic YAML spec.
- **Frame authoring** — generate UI-kit frames across mobile, tablet, and desktop viewports.
- **Asset export** — export icons as SVG and images at 1x / 2x / 3x densities.
- **Import mode** — reverse flow that reads existing designs INTO ux-design.md.
- **Per-stack token resolution** — generate stack-native token code for each supported dev agent.
- **Design-to-implementation fidelity gate** — post-implementation drift detection consumed by code review.

None of the above is implemented in this stub. Reading this file MUST NOT provide an OSS reader with enough detail to reconstruct the premium pipeline — refer to the enterprise plugin.

## Consumer Contract

Workflows that previously JIT-loaded `_gaia/dev/skills/figma-integration.md` now resolve this skill name via the native plugin registry. Resolution order:

1. If the enterprise plugin is installed and the `figma-premium` flag is enabled, the enterprise `figma-integration` SKILL.md is loaded — the full premium capability set becomes available.
2. Otherwise, this OSS stub is loaded. Consuming workflows MUST detect the stub (presence of `license: enterprise` in the loaded frontmatter or an explicit capability probe) and degrade to markdown-only behavior. No MCP calls are attempted, no design-system artifacts are produced, no fidelity gate is enforced.

## Traceability

- **FR-323** — Skill Conversion (native plugin layout for skills).
- **FR-332** — Enterprise license gate declared via frontmatter.
- **NFR-048** — OSS plugin MUST NOT ship premium logic.
- **NFR-053** — Feature parity preserved across OSS + enterprise split.
- **ADR-041** — Native execution model under Claude Code Skills + Subagents + Plugins + Hooks.
- **ADR-043** — OSS / enterprise split mechanism and feature-flag gating.
- **E28-S122** — Enterprise `figma-integration` delivery story (Cluster 17).
- Legacy source: `_gaia/dev/skills/figma-integration.md` — retained in the running framework tree per CLAUDE.md (framework vs product separation).
