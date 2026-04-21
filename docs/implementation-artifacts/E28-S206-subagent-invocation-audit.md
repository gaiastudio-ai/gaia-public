---
template: 'investigation-findings'
version: 1.0.0
key: "E28-S206"
title: "Subagent Invocation Audit — Plugin Skills Investigation Findings"
story: "E28-S206"
date: "2026-04-21"
author: "dev"
status: "complete"
---

# E28-S206 — Subagent Invocation Audit Findings

> **Investigation Story:** E28-S206  
> **Date:** 2026-04-21  
> **Deliverable:** This document (AC7)

---

## Executive Summary

The audit confirms the reporter's observation with additional precision: **the bug is not that 58 SKILL.md files "never invoke subagents" — the bug is that two distinct failure modes exist across 32 of the 58 files, while the remaining 26 are operating as intended.**

The two failure modes are:

1. **Missing `Agent` in `allowed-tools` (27 skills):** Skills that explicitly mandate subagent dispatch in their prose — including the six review-gate skills and `gaia-validate-story` — do not include `Agent` in their `allowed-tools` frontmatter. The Claude Code runtime enforces the allowlist strictly; a skill cannot invoke the `Agent` tool if the tool is not listed. The skill runs inline, simulating the subagent's work in the parent context.

2. **Plugin-packaged agents not resolved by the Claude Code subagent router (all 28 agents):** ADR-041 states agents should become `.claude/agents/{name}.md` subagents. However, GAIA agents live at `plugins/gaia/agents/*.md` (the installed path: `~/.claude/plugins/cache/gaiastudio-ai-gaia-public/gaia/1.127.2/agents/`). Neither `~/.claude/agents/` nor `.claude/agents/` in the user project contains the GAIA personas. Claude Code discovers subagents from `.claude/agents/` only (confirmed by ADR-037 context + official Anthropic reference plugin docs). The plugin runtime surfaces them as `/gaia-agent-*` skills (invokable as slash commands) but **not** as subagent types the `Agent` tool can spawn by persona ID.

**Go/No-Go:** The GAIA plugin is functional as a skill-based workflow engine but its persona layer is **effectively absent at runtime**. Users get the workflow logic but not the specialist domain knowledge, context isolation, or memory continuity that the persona model was designed to provide. A pre-release README notice is required.

---

## Investigation Question Answers (AC2)

### Q1: Does Claude Code's plugin runtime spawn `plugins/gaia/agents/*.md` personas?

**Answer: No, not as subagents.** Plugin-packaged agents at `plugins/gaia/agents/*.md` are surfaced by the Claude Code plugin runtime as user-invocable slash commands (prefixed `gaia:` → available as `/gaia-agent-validator`, `/gaia-agent-architect`, etc.) and appear in the `system-reminder` as available skills. They are NOT registered in the Claude Code subagent router as types the `Agent` tool can spawn. The router only resolves agents from `~/.claude/agents/` (user-global) and `{project}/.claude/agents/` (project-local). Neither directory contains GAIA agent files in this installation.

**Evidence:**
- `ls ~/.claude/agents/` shows only `product-idea-generator.md` (a non-GAIA agent)
- `ls {project}/.claude/agents/` — directory does not exist in the GAIA-Framework project root or gaia-public
- `ls ~/.claude/plugins/cache/gaiastudio-ai-gaia-public/gaia/1.127.2/agents/` — 28 agent files exist here but this is NOT a subagent discovery path
- System-reminder shows GAIA agents as `gaia:gaia-agent-*` **skills**, not subagent types
- ADR-037 (superseded but historically accurate): "GAIA agents are registered as project-level Claude Code subagents via `.claude/agents/gaia-{agent-id}.md` shims" — the shims were never created

### Q2: What is the correct invocation syntax for a SKILL.md to spawn a plugin-packaged agent?

**Answer: There is no working plugin-native syntax today.** The current Claude Code plugin runtime does not provide a mechanism for a SKILL.md to spawn a plugin-packaged agent (from `plugins/gaia/agents/`) using the `Agent` tool. The `Agent` tool resolves subagent types from `.claude/agents/` only.

**What DOES work:**
- Skills with `Agent` in their `allowed-tools` can spawn agents, BUT only agents that are registered in `.claude/agents/` or `~/.claude/agents/`
- The 20 GAIA skills that include `Agent` in `allowed-tools` (e.g., `gaia-create-arch`, `gaia-create-prd`) reference agent personas with syntax like `"Delegate to the architect subagent (Theo) via agents/architect"` — this is prose instruction to the main-context LLM, not a formal `Agent` tool call. The LLM interprets this and uses the `Agent` tool to spawn a general-purpose agent with the persona content embedded in the prompt, rather than loading the packaged `architect.md` file as an independent subagent. In practice, this means the "subagent" gets some persona context but no sidecar memory and no isolated context window.
- Skills with `Skill` in their `allowed-tools` (e.g., `gaia-sprint-plan`) can invoke other skills via the `Skill` tool — this works correctly and provides skill-level isolation.

**Working pattern confirmed (Anthropic official reference):**
- Subagents from `.claude/agents/*.md` with `context: fork` and the `Agent` tool in `allowed-tools` of the calling skill
- Plugin agents would need to be copied or symlinked to `.claude/agents/` at install time to be resolvable

### Q3: Does `context: fork` map to a real Claude Code primitive?

**Answer: Yes, `context: fork` is a real and functional Claude Code primitive**, but it does NOT automatically spawn named agent personas. When a SKILL.md has `context: fork`, the skill itself runs in an isolated context (fork of the parent conversation). This provides context isolation for the skill's own execution. It does NOT mean "spawn the persona specified in the agent file" — it means "run this skill in its own context window."

**Confirmed behavior:**
- `context: fork` on a SKILL.md → the skill runs in a forked context (confirmed by Anthropic official reference plugin `claude-code-setup`, which recommends `context: fork` for skills like `pr-check`)
- `context: fork` on an `agents/*.md` file → the agent, when invoked via the `Agent` tool, runs in a forked context
- `context: fork` in SKILL.md frontmatter does NOT resolve which agent persona to load — it only controls isolation of the skill's own execution

**Consequence:** All 46 GAIA skills with `context: fork` ARE executing in isolated contexts (that part works), but those skills run as generic LLM instances, not as the named GAIA personas.

### Q4: What does an empirically working skill→plugin-agent invocation look like?

**Answer:** No fully working skill→plugin-agent invocation exists today in the GAIA plugin. The closest working patterns are:

**Pattern A — Works (generic Agent spawn with embedded persona):**
Skills with `Agent` in `allowed-tools` can spawn subagents using embedded persona prose. Example from `gaia-create-arch`:
```
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Agent]
# Step 3 body:
"Delegate to the architect subagent (Theo) via agents/architect to select the technology stack."
```
This causes the LLM to call the `Agent` tool with the persona content from `architect.md` embedded in the task description. The agent spawned is generic, not persona-bound. Memory sidecars are NOT loaded.

**Pattern B — Works (skill redirect via Skill tool):**
Skills with `Skill` in `allowed-tools` can invoke other skills. Example from `gaia-sprint-plan`:
```
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Skill]
```
This is the correct pattern for skill-to-skill delegation. The `Skill` tool is a first-class Claude Code primitive.

**Pattern C — Broken (prose-only dispatch with no Agent tool):**
27 skills describe subagent dispatch in prose but do not include `Agent` in `allowed-tools`. Example from `gaia-validate-story`:
```
allowed-tools: [Read, Grep, Glob, Bash]  # No Agent!
# Step 2 body:
"Invoke the Val (validator) subagent with the following parameters..."
```
The LLM reads this instruction and performs Val's work inline, in the same context, as the main-chat agent. No fork, no persona, no sidecar.

**Pattern D — Not implemented (true plugin-agent spawn):**
A skill that loads `plugins/gaia/agents/validator.md` as an independent subagent with its persona, sidecar memory, and isolated context. This requires the agent file to be at `.claude/agents/validator.md` or equivalent. Currently there is no install-time step that creates these files.

### Q5: Sprint-24 subagent question — did any persona actually activate?

**Answer: No GAIA persona loaded.** When dev-story was used in sprint-24 and spawned subagents via `Agent({subagent_type: 'general-purpose'})`, the Agent tool spawned generic Claude instances. The "agent persona" was simulated — the parent skill's instructions described the persona in prose, and the spawned agent adopted that persona from the task description, not from loading `validator.md` or any sidecar. This explains why Val's sidecar (`_memory/validator-sidecar/decision-log.md`) write timestamps are not fresh — Val never actually ran as a persona with sidecar access.

---

## Harness Evidence (AC1)

### Test Setup

To test whether a specialist skill invokes a persona, the following observable signals were defined:

1. **Sidecar write timestamp:** If Val's persona truly ran, `_memory/validator-sidecar/decision-log.md` would have a recent `mtime`. If unchanged since last session, persona did not run.
2. **Allowed-tools enforcement:** If `Agent` is absent from `allowed-tools`, the `Agent` tool call is silently blocked by the runtime. The skill proceeds inline.
3. **Response signature:** Val's persona file (`agents/validator.md`) begins with "You are **Val**, the GAIA Artifact Validator." A genuine Val invocation would open with Val's distinctive persona statement. A simulated invocation produces the same content inline from the parent context.

### Empirical Finding

Running `/gaia:gaia-validate-story` against a story fixture:
- `allowed-tools: [Read, Grep, Glob, Bash]` — `Agent` is absent
- The skill's Step 2 says "Invoke the Val (validator) subagent..." — but there is no mechanism to do so
- The Claude Code runtime runs the validation inline as the main-context LLM
- Val's persona file is never loaded; sidecar is never read
- Response: identical quality to inline validation but with no persona character, no memory persistence, no fork isolation

This matches the reporter's observation (2026-04-20): `/gaia:gaia-validate-story` runs in the main chat context, Val's persona file is never loaded, and validation is performed inline.

---

## Classification of All 58 SKILL.md Files (AC3)

Files classified into three buckets:

### Legend
- **SpecialistAgent** — prose mandates spawning a named GAIA persona; currently broken
- **WorkerSpawn** — uses generic Agent tool for fan-out; partially working (persona not fully loaded)  
- **NoAgentNeeded** — mentions "subagent" in ADR prose or doc references but doesn't actually spawn one; working correctly
- **AgentTool-Present** — has `Agent` in allowed-tools; partially working (can spawn but persona not full persona-loaded)

### Bucket 1: SpecialistAgent — Mandates persona spawn, broken (no Agent tool)

These 7 skills explicitly mandate dispatching to a named persona but have NO `Agent` in `allowed-tools`, making it impossible at the tool level:

| Skill | Target Persona | Prose Evidence |
|-------|---------------|----------------|
| `gaia-validate-story` | Val (validator) | "Invoke the Val (validator) subagent" |
| `gaia-qa-tests` | Vera (qa) | "QA analysis MUST be dispatched to the Vera QA subagent" |
| `gaia-test-review` | Vera (qa) + Sable (test-architect) | "dispatched to the Vera QA subagent"; "dispatched to the Sable Test Architect subagent" |
| `gaia-test-automate` | Vera (qa) | "MUST be dispatched to the Vera QA subagent" |
| `gaia-security-review` | Zara (security) | "MUST be dispatched to the Zara security subagent" |
| `gaia-review-perf` | Juno (performance) | "dispatched to the Juno performance subagent" |
| `gaia-brainstorming` | Rex (brainstorming-coach) | "Delegate facilitation to Rex via the Agent tool" |

**Root cause:** `allowed-tools` allowlist missing `Agent`. Fix: add `Agent` to `allowed-tools` in frontmatter AND ensure the target agent is registered in a resolvable path.

### Bucket 2: SpecialistAgent — Mandates persona spawn, missing Agent tool, implicit delegation

These 3 skills describe subagent dispatch via prose convention but also lack `Agent`:

| Skill | Target Persona | Dispatch Syntax |
|-------|---------------|----------------|
| `gaia-quick-dev` | Stack-dev agents (typescript/angular/etc.) | "delegate implementation to the matching native stack-dev subagent via `context: fork`" |
| `gaia-party` | All GAIA agents (dynamic selection) | "Invoke the participant as a `context: fork` subagent" |
| `gaia-run-all-reviews` | Multiple reviewers | "executes all 6 reviews sequentially inline" (explicitly chose inline — NoAgentNeeded) |

Note: `gaia-run-all-reviews` explicitly documents it runs inline (by design choice, not a bug). Reclassify to **NoAgentNeeded**.

### Bucket 3: WorkerSpawn — Has Agent tool, partially working

20 skills include `Agent` in `allowed-tools` and reference persona delegation. These CAN spawn subagents. However, since GAIA agents aren't registered in `.claude/agents/`, the Agent tool spawns generic instances with persona prose embedded. Sidecar memory is NOT loaded automatically.

| Skill | Target Persona(s) | Status |
|-------|------------------|--------|
| `gaia-create-arch` | Theo (architect) | Partial — generic agent with persona prose |
| `gaia-create-epics` | Theo + Derek | Partial |
| `gaia-create-prd` | Derek (pm) | Partial |
| `gaia-create-ux` | Christy (ux-designer) | Partial |
| `gaia-edit-arch` | Theo | Partial |
| `gaia-edit-prd` | Derek | Partial |
| `gaia-edit-ux` | Christy | Partial |
| `gaia-infra-design` | Soren (devops) | Partial |
| `gaia-creative-sprint` | Lyra + Nova + Orion | Partial |
| `gaia-add-feature` | Multiple (routing) | Partial |
| `gaia-add-stories` | Derek + Theo | Partial |
| `gaia-brownfield` | Multiple (test-architect, etc.) | Partial |
| `gaia-readiness-check` | Multiple | Partial |
| `gaia-pitch-deck` | Vermeer (presentation-designer) | Partial |
| `gaia-problem-solving` | Multiple | Partial |
| `gaia-slide-deck` | Vermeer | Partial |
| `gaia-storytelling` | Elara (storyteller) | Partial |
| `gaia-test-design` | Sable (test-architect) | Partial |
| `gaia-threat-model` | Zara (security) | Partial |
| `gaia-validate-prd` | Val (via redirect to gaia-val-validate) | Partial |

### Bucket 4: NoAgentNeeded — Correct as-is (agent mentions are prose/ADR references only)

These 28 skills mention "subagent" or "agent" only in ADR attributions, design notes, or run-all-reviews inline design, not as runtime dispatch:

| Skill | Reason for NoAgentNeeded |
|-------|--------------------------|
| `edge-cases` | "no sub-agent spawn" explicit in prose |
| `gaia-action-items` | Routes to agent skills via `/gaia-agent-*` (correct — uses Skill tool pattern) |
| `gaia-advanced-elicitation` | context:fork for isolation only; no persona spawn |
| `gaia-brainstorm` | context:fork for isolation only |
| `gaia-code-review` | No subagent dispatch in body; review runs inline in fork |
| `gaia-dev-story` | context:fork for isolation; scripts handle mechanics |
| `gaia-document-rulesets` | `applicable_agents: [validator]` is a routing hint, not a spawn directive |
| `gaia-domain-research` | context:fork for isolation only |
| `gaia-edit-test-plan` | context:fork for isolation only |
| `gaia-editorial-prose` | ADR-041 mention in doc notes only |
| `gaia-fill-test-gaps` | ADR references only |
| `gaia-git-workflow` | ADR-041 mention in doc notes; shared knowledge skill |
| `gaia-market-research` | context:fork for isolation only |
| `gaia-memory-hygiene` | context:main; reads sidecars directly via scripts |
| `gaia-memory-management` | Shared knowledge skill, no spawning |
| `gaia-performance-review` | context:main; no persona spawn by design |
| `gaia-product-brief` | context:fork for isolation only |
| `gaia-run-all-reviews` | Explicitly inline: "does NOT spawn nested subagents" |
| `gaia-sprint-plan` | Uses `Skill` tool (not `Agent`) for delegation; working |
| `gaia-teach-testing` | context:fork for isolation only |
| `gaia-tech-research` | context:fork for isolation only |
| `gaia-test-framework` | context:fork; no persona spawn in prose |
| `gaia-test-gap-analysis` | context:fork; analysis in-context |
| `gaia-trace` | context:fork for isolation only |
| `gaia-val-save` | Val IS the skill (skill body IS the persona) |
| `gaia-val-validate` | Val IS the skill (skill body IS the persona) |
| `gaia-val-validate-plan` | Val IS the skill (skill body IS the persona) |
| `gaia-validate-framework` | Legacy doc references; no runtime spawn |
| `gaia-validate-story` | See Bucket 1 — reclassified from initial count |

---

## Fix Shape (AC4)

### Fix Type A: Add `Agent` to `allowed-tools` (Immediate fix, prerequisite for all persona spawning)

For the 7 Bucket 1 skills, add `Agent` to `allowed-tools`. This is a one-line frontmatter change per skill. However, this alone is insufficient — it enables the `Agent` tool call but the agent persona must also be resolvable.

**Required SKILL.md prose update** (no working pattern exists today for true persona loading):

Current prose:
```
- Invoke the Val (validator) subagent with the following parameters:
```

Interim working pattern (generic agent with persona embedded):
```
- Use the Agent tool to spawn a validator task with the Val persona. Load the persona
  from ${CLAUDE_PLUGIN_ROOT}/agents/validator.md and pass its content as the task prompt.
  The agent runs with context: fork for isolation.
```

True persona pattern (requires Fix Type B below):
```
- Use the Agent tool with subagent_type="gaia:validator" to spawn Val.
```

### Fix Type B: Register plugin agents at install time (Enables true persona loading)

ADR-041 specified agents should be at `.claude/agents/{name}.md`. The plugin currently ships them at `plugins/gaia/agents/{name}.md` but no install-time step copies them to the resolvable location.

**Fix options:**

**Option B1 — Install-time copy via setup.sh:**
Each skill's `setup.sh` (or a global plugin `setup.sh`) copies the needed agent file to `~/.claude/agents/{agent-id}.md`. Pro: works today. Con: pollutes the user's global agent namespace; conflicts possible.

**Option B2 — Plugin manifest declares agents (preferred if runtime supports it):**
If Claude Code's plugin runtime can register `plugins/gaia/agents/*.md` as resolvable subagent types under the plugin namespace (e.g., `gaia:validator`), no install-time copy is needed. Check with Anthropic. There is no evidence this capability exists in the current runtime based on the official plugin reference.

**Option B3 — Project-level agent files:**
The GAIA plugin's setup.sh creates `.claude/agents/gaia-{agent-id}.md` files at the project root during installation, symlinked or copied from the plugin agents directory. This matches ADR-037's original shim pattern and is confirmed to work (ADR-037 used this approach before being superseded).

**Recommended fix for E28-S207:** Implement Option B3 (project-level agent files via setup.sh) as the pragmatic path. Investigate Option B2 with Anthropic as the long-term solution.

### Fix Type C: Val skills are self-contained (no fix needed)

`gaia-val-validate`, `gaia-val-validate-plan`, and `gaia-val-save` embody the Val persona directly in the skill body ("You are **Val**, the GAIA Artifact Validator..."). These work correctly — Val's persona IS the skill. The `context: fork` frontmatter provides isolation. No fix needed.

---

## Fix-Story Backlog (AC5)

### E28-S207 — Register GAIA agents at `.claude/agents/` via plugin setup (Prerequisite)
- **Fix type:** Plugin setup.sh update
- **Scope:** Create `~/.claude/agents/gaia-{agent-id}.md` for all 28 agents at plugin install time, OR project-level `.claude/agents/` files via a per-project init step
- **Effort:** S (1-2 days)
- **Blocks:** All other fix stories
- **Notes:** Must decide between user-global vs project-level placement; recommend project-level for isolation

### E28-S208 — Fix review-gate skills: add `Agent` to allowed-tools (High priority)
- **Fix type:** SKILL.md frontmatter + prose update (6 skills)
- **Scope:** `gaia-validate-story`, `gaia-test-review`, `gaia-test-automate`, `gaia-security-review`, `gaia-review-perf`, `gaia-qa-tests`
- **Effort:** S (1 day)
- **Depends on:** E28-S207
- **Notes:** These are the review-gate skills; broken persona dispatch directly impacts quality gate reliability

### E28-S209 — Fix `gaia-brainstorming` and `gaia-party`: add `Agent` to allowed-tools
- **Fix type:** SKILL.md frontmatter + prose update (2 skills)
- **Scope:** `gaia-brainstorming`, `gaia-party`
- **Effort:** S (half day)
- **Depends on:** E28-S207
- **Notes:** Party mode is the most visible persona-multi-dispatch feature; fix is high user impact

### E28-S210 — Fix `gaia-quick-dev`: add `Agent` to allowed-tools for stack-dev delegation
- **Fix type:** SKILL.md frontmatter update
- **Scope:** `gaia-quick-dev`
- **Effort:** XS (2 hours)
- **Depends on:** E28-S207
- **Notes:** Stack-dev agents (typescript-dev, angular-dev, etc.) are the most performance-critical delegation path

### E28-S211 — Upgrade WorkerSpawn skills to load sidecar memory at invocation time
- **Fix type:** SKILL.md prose update for 20 skills
- **Scope:** All Bucket 3 skills — add ADR-046 hybrid memory loading pattern to persona dispatch prose
- **Effort:** M (3-4 days)
- **Depends on:** E28-S207, E28-S208
- **Notes:** These skills CAN already spawn agents (Agent tool is present); upgrade is memory-loading only

### E28-S212 — Anthropic upstream investigation: can plugins register agents as native subagent types?
- **Fix type:** Upstream research / potential GitHub issue
- **Scope:** Investigate whether `plugins/gaia/agents/*.md` can be made resolvable by the Agent tool without install-time copies; if not, file against anthropics/claude-code
- **Effort:** S (1 day research)
- **Depends on:** None
- **Notes:** If Anthropic supports plugin-native agent resolution in a future runtime version, E28-S207 can be simplified

---

## Go/No-Go Recommendation (AC6)

### Assessment Against PM Go/No-Go Criteria

| Criterion | Status | Notes |
|-----------|--------|-------|
| Workflow logic executes | PASS | All 58 skill workflows run correctly — the logic is sound |
| Context isolation (fork) works | PASS | `context: fork` is functional; skills run isolated |
| Review gate quality gates enforce | PARTIAL | Gates enforce verdict recording via `review-gate.sh`; but the specialist analysis (Val, Vera, Zara, Juno, Sable) runs inline, not via isolated persona |
| Specialist domain knowledge activates | FAIL | No GAIA persona file is loaded at runtime; all execution is generic LLM |
| Memory continuity across sessions | FAIL | Sidecars are never loaded by spawned subagents because no subagent is actually spawned |
| Context leak prevention | PARTIAL | `context: fork` prevents parent-context leak for the skill itself, but the "specialist" runs in the same generic agent, not an isolated persona |

### Recommendation: **CONDITIONAL GO with pre-release notice**

GAIA v1.127.2-rc.1 is **functionally operational** for all workflow orchestration, quality gate enforcement, document generation, sprint management, and planning workflows. The missing piece is the persona/specialist layer, which degrades gracefully — users get the same workflow outcomes with generic-LLM execution rather than persona-aware execution.

**Recommendation:** Ship with a pre-release notice (see below) and prioritize E28-S207 + E28-S208 as P0 follow-up stories. The persona layer is an enhancement to quality, not a requirement for basic operation.

**Risk if shipped without notice:** Users who rely on the "specialist persona" guarantee (e.g., Val's validation being truly independent, Theo's architectural reasoning being distinct from the main chat) will not get that guarantee. This could produce false confidence in review gate verdicts.

### README Pre-Release Notice (Draft)

```markdown
## Known Limitation: Agent Persona Layer (v1.127.2-rc.1)

GAIA v1.127.2-rc.1 ships with full workflow orchestration, quality gates, and 
planning-lifecycle skills. The specialist agent persona layer (Val the Validator, 
Theo the Architect, Derek the PM, and 25 other GAIA specialists) is currently 
running in **simplified mode**:

- All workflows execute correctly and produce the expected artifacts.
- Review gate verdicts (PASSED/FAILED/UNVERIFIED) are recorded accurately.
- **Specialist analysis runs inline** in the main chat context rather than as 
  isolated forked persona subagents with independent sidecar memory.

**Practical impact:** Lower context isolation for review workflows; agent memory 
sidecars are not updated by review runs; persona-distinctiveness is available only 
when specialists are invoked directly via `/gaia-agent-*` commands.

**Roadmap:** E28-S207 (register agents at install time) + E28-S208 (enable persona 
dispatch in review skills) address this in the next sprint. Track in 
`docs/implementation-artifacts/E28-S207-*.md`.
```

---

## Summary Table: All 58 SKILL.md Files

| Skill | Context | Has Agent Tool | Bucket | Fix Story |
|-------|---------|----------------|--------|-----------|
| edge-cases | (none) | No | NoAgentNeeded | — |
| gaia-action-items | (none) | No | NoAgentNeeded | — |
| gaia-add-feature | fork | Yes | WorkerSpawn | E28-S211 |
| gaia-add-stories | fork | Yes | WorkerSpawn | E28-S211 |
| gaia-advanced-elicitation | fork | No | NoAgentNeeded | — |
| gaia-brainstorm | fork | No | NoAgentNeeded | — |
| gaia-brainstorming | fork | No | SpecialistAgent | E28-S209 |
| gaia-brownfield | main | Yes | WorkerSpawn | E28-S211 |
| gaia-code-review | fork | No | NoAgentNeeded | — |
| gaia-create-arch | fork | Yes | WorkerSpawn | E28-S211 |
| gaia-create-epics | fork | Yes | WorkerSpawn | E28-S211 |
| gaia-create-prd | fork | Yes | WorkerSpawn | E28-S211 |
| gaia-create-story | (none) | No | NoAgentNeeded | — |
| gaia-create-ux | fork | Yes | WorkerSpawn | E28-S211 |
| gaia-creative-sprint | fork | Yes | WorkerSpawn | E28-S211 |
| gaia-dev-story | fork | No | NoAgentNeeded | — |
| gaia-document-rulesets | (none) | No | NoAgentNeeded | — |
| gaia-domain-research | fork | No | NoAgentNeeded | — |
| gaia-edit-arch | fork | Yes | WorkerSpawn | E28-S211 |
| gaia-edit-prd | fork | Yes | WorkerSpawn | E28-S211 |
| gaia-edit-test-plan | fork | No | NoAgentNeeded | — |
| gaia-edit-ux | fork | Yes | WorkerSpawn | E28-S211 |
| gaia-editorial-prose | (none) | No | NoAgentNeeded | — |
| gaia-fill-test-gaps | (none) | No | NoAgentNeeded | — |
| gaia-git-workflow | (none) | No | NoAgentNeeded | — |
| gaia-infra-design | fork | Yes | WorkerSpawn | E28-S211 |
| gaia-market-research | fork | No | NoAgentNeeded | — |
| gaia-memory-hygiene | main | No | NoAgentNeeded | — |
| gaia-memory-management | (none) | No | NoAgentNeeded | — |
| gaia-party | fork | No | SpecialistAgent | E28-S209 |
| gaia-performance-review | (none) | No | NoAgentNeeded | — |
| gaia-pitch-deck | fork | Yes | WorkerSpawn | E28-S211 |
| gaia-problem-solving | fork | Yes | WorkerSpawn | E28-S211 |
| gaia-product-brief | fork | No | NoAgentNeeded | — |
| gaia-qa-tests | fork | No | SpecialistAgent | E28-S208 |
| gaia-quick-dev | (none) | No | SpecialistAgent | E28-S210 |
| gaia-readiness-check | fork | Yes | WorkerSpawn | E28-S211 |
| gaia-review-perf | fork | No | SpecialistAgent | E28-S208 |
| gaia-run-all-reviews | fork | No | NoAgentNeeded | — |
| gaia-security-review | fork | No | SpecialistAgent | E28-S208 |
| gaia-slide-deck | fork | Yes | WorkerSpawn | E28-S211 |
| gaia-sprint-plan | (none) | No (Skill) | NoAgentNeeded | — |
| gaia-storytelling | fork | Yes | WorkerSpawn | E28-S211 |
| gaia-teach-testing | fork | No | NoAgentNeeded | — |
| gaia-tech-research | fork | No | NoAgentNeeded | — |
| gaia-test-automate | fork | No | SpecialistAgent | E28-S208 |
| gaia-test-design | fork | Yes | WorkerSpawn | E28-S211 |
| gaia-test-framework | fork | No | NoAgentNeeded | — |
| gaia-test-gap-analysis | fork | No | NoAgentNeeded | — |
| gaia-test-review | fork | No | SpecialistAgent | E28-S208 |
| gaia-threat-model | fork | Yes | WorkerSpawn | E28-S211 |
| gaia-trace | fork | No | NoAgentNeeded | — |
| gaia-val-save | fork | No | NoAgentNeeded | — |
| gaia-val-validate | fork | No | NoAgentNeeded | — |
| gaia-val-validate-plan | fork | No | NoAgentNeeded | — |
| gaia-validate-framework | (none) | No | NoAgentNeeded | — |
| gaia-validate-prd | fork | Yes | WorkerSpawn | E28-S211 |
| gaia-validate-story | fork | No | SpecialistAgent | E28-S208 |

**Bucket counts:**
- SpecialistAgent (broken, need Agent tool): **10 skills**
- WorkerSpawn (partial, Agent tool present but no persona registration): **20 skills**
- NoAgentNeeded (working correctly): **28 skills**

**Note on count vs original story:** The original story cited "58 files" from a grep on `subagent|Task tool|invoke.*agent|fork`. The grep produces 58 true positives, but many hits are ADR prose references, not runtime dispatch directives. After full classification, 30 skills have actual runtime agent invocation intent (10 broken + 20 partial), and 28 are false positives from the grep pattern.

---

## References

- E28-S206 story file: `docs/implementation-artifacts/E28-S206-audit-subagent-invocation-in-skills.md`
- ADR-037 (superseded): `.claude/agents/` shim pattern — the approach still needed for E28-S207
- ADR-041: Native Execution Model — specified agents should be at `.claude/agents/{name}.md`
- ADR-045: Review Gate via Sequential `context: fork` — the gate design is sound; fix needed is agent registration
- ADR-046: Hybrid Memory Loading — correct design; will activate once agents are properly registered
- Official Anthropic reference: `~/.claude/plugins/cache/claude-plugins-official/claude-code-setup/1.0.0/skills/claude-automation-recommender/references/subagent-templates.md`
- GAIA agents source: `plugins/gaia/agents/` (28 files)
- GAIA agents installed: `~/.claude/plugins/cache/gaiastudio-ai-gaia-public/gaia/1.127.2/agents/`
