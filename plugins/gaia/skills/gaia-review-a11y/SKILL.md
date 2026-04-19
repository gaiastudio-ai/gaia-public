---
name: gaia-review-a11y
description: Review code and UI for WCAG 2.1 accessibility compliance — semantic HTML, ARIA, keyboard navigation, color contrast, screen reader support. Produces a markdown findings report with per-finding WCAG criterion ID, conformance level (A/AA/AAA), severity, and remediation guidance. Use when "review accessibility" or /gaia-review-a11y.
argument-hint: "[target — file, directory, or component name]"
allowed-tools: [Read, Write, Edit, Bash, Grep]
---

## Mission

You are performing a **WCAG 2.1 accessibility review** on the target the user supplies (a file, directory, or named component). You evaluate the target across four categories — semantic HTML + ARIA, keyboard + focus, visual + screen reader — and produce a markdown findings report where every finding cites the specific WCAG 2.1 success criterion ID, its conformance level, a severity rating, and concrete remediation guidance.

This skill is the native Claude Code conversion of the legacy `_gaia/core/tasks/review-accessibility.xml` task (47 lines). Per **ADR-041** (Native Execution Model) and **ADR-042** (Scripts-over-LLM for Deterministic Operations), the legacy task-runner engine is retired and this skill runs natively under the Claude Code primitives model. Deterministic report-header generation is delegated to the shared foundation script `template-header.sh` (E28-S16) rather than re-prosed per skill.

## Critical Rules

- **Check ARIA attributes and roles.** Every interactive component must declare a role, label, and state appropriate to its behavior.
- **Verify keyboard navigation support.** Every interactive element must be reachable and operable by keyboard alone — no pointer-only affordances.
- **Evaluate color contrast and screen reader support.** Text must meet WCAG 1.4.3 ratios (4.5:1 body / 3:1 large) and be announced correctly by screen readers.
- Every finding MUST cite a specific WCAG 2.1 success criterion (e.g., `1.1.1 Non-text Content`, `2.1.1 Keyboard`, `1.4.3 Contrast (Minimum)`) and its conformance level (A/AA/AAA). Findings without a criterion reference are not acceptable.
- The review is READ-ONLY on the target — do NOT refactor the target code. Findings go in the report artifact.

## Inputs

- `$ARGUMENTS`: optional target (file, directory, or component name). If omitted, ask the user inline: "Which code or component should I review for accessibility?"

## Steps

### Step 1 — Scope

- If `$ARGUMENTS` is non-empty, use it as the target. Otherwise ask the user inline for the code or component to review (preserves the legacy Step 1 "Ask user for code/component to review" behavior — AC-EC4).
- Read the target file(s). If a directory is given, recursively read all source files under it.

### Step 2 — Semantic HTML and ARIA

- Check that interactive elements use the proper semantic HTML element (`<button>`, `<a>`, `<nav>`, `<main>`, `<article>`, etc.) rather than `<div>` + `onclick`.
- Verify ARIA attributes, roles, states, and labels — `aria-label`, `aria-labelledby`, `aria-describedby`, `role`, `aria-expanded`, `aria-controls`, `aria-live`, etc.
- Check for `alt` text on images (WCAG 1.1.1) and labels on form inputs (WCAG 1.3.1, 3.3.2, 4.1.2).
- For every finding, cite the specific WCAG 2.1 criterion — e.g., `1.1.1 Non-text Content (A)`, `1.3.1 Info and Relationships (A)`, `4.1.2 Name, Role, Value (A)` — and note its conformance level.

### Step 3 — Keyboard and Focus

- Verify every interactive component is keyboard-reachable and operable with `Tab`, `Shift+Tab`, `Enter`, `Space`, and arrow keys where applicable.
- Check focus management — focus visible at all times (WCAG 2.4.7), focus trapped inside modals, focus returned on close.
- Check tab order follows logical reading order (WCAG 2.4.3).
- Verify skip-navigation links are present on pages with repeated blocks (WCAG 2.4.1).
- For every finding, cite the specific WCAG 2.1 criterion — e.g., `2.1.1 Keyboard (A)`, `2.4.3 Focus Order (A)`, `2.4.1 Bypass Blocks (A)`, `2.4.7 Focus Visible (AA)` — and note its conformance level.

### Step 4 — Visual and Screen Reader

- Measure color contrast ratios: body text ≥ 4.5:1, large text (≥ 18pt or 14pt bold) ≥ 3:1 — WCAG 1.4.3.
- Check screen reader compatibility: announced labels match visible labels, reading order is logical, dynamic content uses `aria-live` appropriately.
- Verify text scaling: content must remain usable when scaled up to 200% (WCAG 1.4.4) and 400% (WCAG 1.4.10 Reflow).
- Confirm no information is conveyed by color alone — WCAG 1.4.1 and 1.3.3.
- For every finding, cite the specific WCAG 2.1 criterion — e.g., `1.4.3 Contrast (Minimum) (AA)`, `1.4.4 Resize Text (AA)`, `1.3.3 Sensory Characteristics (A)`, `1.4.1 Use of Color (A)` — and note its conformance level.

### Step 5 — Generate Report

Invoke the shared foundation script to emit the deterministic artifact header (ADR-042):

```bash
!${CLAUDE_PLUGIN_ROOT}/scripts/template-header.sh --template accessibility-review --workflow gaia-review-a11y
```

If `template-header.sh` is missing or non-executable (AC-EC7), degrade gracefully to an inline prose header (`# Accessibility Review — {date}`), log a warning, and still write a valid report.

Write the report to the following path (preserved verbatim from the legacy task for downstream consumers — traceability, deploy checklist, run-all-reviews aggregation — AC4):

```
{test_artifacts}/accessibility-review-{date}.md
```

If the file already exists for the same day (AC-EC3), write to a suffix-incremented filename (`accessibility-review-{date}-2.md`, `-3.md`, ...) to match the legacy task's safe behavior and avoid clobbering a prior same-day run.

The report is organised by category (semantic HTML, ARIA, keyboard, focus, visual, screen reader). Every finding row uses this exact schema:

| WCAG Criterion ID | Criterion Name | Conformance Level (A/AA/AAA) | Severity (Critical/High/Medium/Low) | Finding Description | Remediation Guidance |

If the target directory is empty or the target resolves to no files (AC-EC6), exit with `No review target resolved` and do NOT write an empty report file — mirrors the legacy task's behavior on empty fixtures.

## References

- Source: `_gaia/core/tasks/review-accessibility.xml` (legacy 47-line task body — ported per ADR-041 + ADR-042).
- ADR-041: Native Execution Model via Claude Code Skills + Subagents + Plugins + Hooks.
- ADR-042: Scripts-over-LLM for Deterministic Operations.
- ADR-048: Engine Deletion as Program-Closing Action — legacy task coexists with this skill until program close.
- FR-323: Skill Conversion — slash-command identity preserved.
- NFR-053: Full v1.127.2-rc.1 Feature Parity.

## Next Step

After an accessibility review run, the legacy next-step hint pointed to `/gaia-create-arch` (Phase 3 onboarding). Preserved here so downstream onboarding does not regress.
