---
name: gaia-editorial-structure
description: Structural editing review — proposes specific cuts, merges, splits, and reorders to improve document organization without touching prose quality. Evaluates information architecture, section ordering, section balance, depth, and navigation. Produces a markdown report comparing current vs. proposed structure with prioritized recommendations. Use when "review structure" or /gaia-editorial-structure.
argument-hint: "[target — document path]"
tools: Read, Grep
---

## Mission

You are performing a **structural review** on the document the user supplies. You map the current outline, evaluate information architecture, and propose specific reorganization moves (cuts, merges, splits, reorders, additions). You produce a markdown report that shows the current structure, the proposed structure, a numbered list of moves, and a priority ranking — so the author can apply the highest-impact changes first.

This skill is the native Claude Code conversion of the legacy `_gaia/core/tasks/editorial-review-structure.xml` task (43 lines). Per **ADR-041** (Native Execution Model) and **ADR-042** (Scripts-over-LLM for Deterministic Operations), the legacy task-runner engine is retired and this skill runs natively under the Claude Code primitives model.

## Critical Rules

- **Review only — never rewrite the document.** The skill produces a report of proposed structural moves; the author decides which to apply.
- **Structure-only scope.** Prose quality, grammar, jargon, and copy-edit concerns are **out of scope** — route the author to `/gaia-editorial-prose`. Keep the structural pass strictly on hierarchy, ordering, section balance, and information architecture.
- **Propose specific reorganization moves, not vague suggestions.** Every recommendation is a concrete instruction — e.g., "Move §3.2 Metrics before §3.1 Goals" or "Split §4 into §4 (Design) and §5 (Implementation) to break the 900-line section." Avoid soft suggestions like "consider reorganizing".
- Every finding cites the specific section(s) affected by line number or heading text, and names the move category (`cut`, `merge`, `split`, `reorder`, `add`).
- Do NOT modify the source document. The report artifact is the only output.

## Inputs

- `$ARGUMENTS`: optional target document path. If omitted, ask the user inline: "Which document should I review for structure?"

## Instructions

### Step 1 — Load Document

- If `$ARGUMENTS` is non-empty, use it as the target path. Otherwise ask the user inline for the document to review.
- Read the entire document with the Read tool.
- Map the current structure: enumerate every heading (H1, H2, H3, …) with its line number, and compute the approximate length of each section in lines.

### Step 2 — Analyze Structure

Evaluate the document across these dimensions:

- **Information architecture** — does the top-level hierarchy reflect the document's purpose? Does it match the doc-type convention (PRD, architecture, story, brief)?
- **Section ordering / sequence** — does the order of sections support the reader's path of understanding? Are prerequisites introduced before dependents?
- **Section balance** — are some sections disproportionately long (>400 lines) or disproportionately short (<10 lines) compared to peers at the same level? Imbalance often signals a missing split or a redundant stub.
- **Redundancy / duplication** — are the same topics covered in multiple sections? If yes, recommend a merge or a single canonical location.
- **Missing sections** — are sections expected for this document type absent (e.g., "Risks" in a PRD, "Decision Log" in an architecture doc)?
- **Depth / nesting** — are there more than three nesting levels (H1 → H2 → H3 → H4)? Deep nesting signals an opportunity to promote or split.
- **Navigation** — can a reader find a specific topic quickly? Does the document have a TOC where warranted? Are forward references clearly marked?

### Step 3 — Generate Report

Produce a markdown structural report with this structure:

1. **Current structure outline** — the document's heading tree with line counts per section.
2. **Proposed structure outline** — the same tree after the recommended moves, clearly marked diffs where possible.
3. **Recommended moves** — numbered list. Each entry has: move category (`cut` / `merge` / `split` / `reorder` / `add`), affected section(s), and rationale in one sentence.
4. **Priority ranking** — which moves would produce the most reader-comprehension uplift, in order.

The report is the only output artifact. It is displayed to the user. If the user asks the skill to save the report, write it with the Write tool — but the default is display-only to mirror the legacy task's behavior.

## References

- Source: `_gaia/core/tasks/editorial-review-structure.xml` (legacy 43-line task body — ported per ADR-041 + ADR-042).
- ADR-041: Native Execution Model via Claude Code Skills + Subagents + Plugins + Hooks.
- ADR-042: Scripts-over-LLM for Deterministic Operations.
- ADR-048: Engine Deletion as Program-Closing Action — legacy task coexists with this skill until program close.
- FR-323: Skill Conversion — slash-command identity preserved.
- NFR-053: Full v1.127.2-rc.1 Feature Parity.

## Related

- `/gaia-editorial-prose` — prose / copy-edit review. Use this sibling skill for grammar, clarity, passive voice, and jargon; this skill (structure) deliberately stays out of that scope.
