---
name: gaia-summarize
description: Generate an executive summary of a long document. Extracts key decisions, action items, and open questions; writes a 1-2 page markdown summary that preserves critical nuances without oversimplifying. Use when "summarize document" or /gaia-summarize.
argument-hint: "[target-doc-path]"
tools: Read, Write
---

## Mission

You are producing an **executive summary** of a long document. The summary captures the document's main thesis, key decisions, action items (with owners where specified), and open / unresolved questions. It stays short — one to two pages at most — while preserving the nuances that matter. The summary is not a replacement for the source; it is a front door, and section references let the reader drill into the full document when needed.

This skill is the native Claude Code conversion of the legacy `_gaia/core/tasks/summarize-doc.xml` task (33 lines). Per **ADR-041** (Native Execution Model) and **ADR-042** (Scripts-over-LLM for Deterministic Operations), the legacy task-runner engine is retired and this skill runs natively under the Claude Code primitives model.

## Critical Rules

- **Extract the three canonical categories:** key decisions, action items, open questions. Every summary MUST surface each category if the source contains material for it. If a category is empty in the source, state "None" rather than silently omitting it.
- **Keep the summary to 1-2 pages maximum** (roughly 400-900 words rendered). A summary longer than two pages has failed its purpose and must be compressed.
- **Preserve critical nuances — don't oversimplify.** If a decision is contingent on an assumption, carry the assumption forward. If an action item has a deadline or dependency, carry that forward. Do not flatten qualifications into absolutes.
- **Accept the target doc path as an argument.** If the argument is missing, fail fast with `usage: /gaia-summarize <target-doc-path>` rather than asking the user to guess what the skill is expecting (AC-EC4).
- **Include section references** (e.g., `see §4.2`) so readers who want more detail can jump straight to the relevant part of the source.
- Do NOT write speculative content. If a decision is not made in the source, do not invent one; list it as an open question instead.

## Inputs

- `$ARGUMENTS`: required target document path. If empty, fail with `usage: /gaia-summarize <target-doc-path>` (AC-EC4).

## Instructions

### Step 1 — Load Document

- If `$ARGUMENTS` is empty, fail fast with `usage: /gaia-summarize <target-doc-path>` and exit. Do NOT produce partial output.
- Read the entire document with the Read tool.
- Identify the document type (PRD, architecture, brief, retro, ADR, meeting notes, research report, etc.) and note its apparent purpose.

### Step 2 — Extract Key Points

Walk the document and extract:

- **Main thesis / purpose** — one or two sentences describing what the document exists to do.
- **Key decisions** — decisions that have been made, with the reasoning or trade-off that drove them. Record the section reference.
- **Action items** — tasks that follow from the document. Capture the owner (person, team, role) if named, the deadline if given, and any blocking dependencies.
- **Open questions** — unresolved items, contradictions, decisions deferred, topics flagged for follow-up.

### Step 3 — Generate Summary

Produce the summary with this structure (markdown):

```
# Executive Summary — {document title}

> Source: {target-doc-path} | Summarized: {YYYY-MM-DD}

## Purpose
{1-2 sentences}

## Key Findings
{3-6 bullets capturing the thesis material — preserve critical nuance}

## Decisions Made
- {decision} — {rationale} (see §{section})
- …
(or "None documented" if the source contains no decisions)

## Action Items
- {action} — owner: {owner}, deadline: {deadline}, blockers: {blockers} (see §{section})
- …
(or "None" if the source contains no actions)

## Open Questions
- {question} (see §{section})
- …
(or "None" if all items are resolved)

## Next Steps
{1-2 sentences on the recommended next action — if the source contains one}
```

Length budget: aim for 400-900 words total. If the summary exceeds two pages, cut lower-priority items.

By default the summary is displayed to the user (matches the legacy task's behavior). If the user asks the skill to save it, write to a sensible path such as `{target-doc-dir}/{target-doc-basename}-summary.md`.

## References

- Source: `_gaia/core/tasks/summarize-doc.xml` (legacy 33-line task body — ported per ADR-041 + ADR-042).
- ADR-041: Native Execution Model via Claude Code Skills + Subagents + Plugins + Hooks.
- ADR-042: Scripts-over-LLM for Deterministic Operations.
- ADR-048: Engine Deletion as Program-Closing Action — legacy task coexists with this skill until program close.
- FR-323: Skill Conversion — slash-command identity preserved.
- NFR-053: Full v1.127.2-rc.1 Feature Parity.
