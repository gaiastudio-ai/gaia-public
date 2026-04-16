---
name: gaia-a11y-testing
description: Create accessibility test plan with WCAG 2.1 compliance checks, assistive technology compatibility, and keyboard navigation. Use when "accessibility testing" or /gaia-a11y-testing.
argument-hint: "[story-key]"
context: main
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash]
---

## Setup

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-a11y-testing/scripts/setup.sh

## Mission

You are creating a WCAG 2.1 accessibility test plan for the specified story or project context. The plan covers automated checks (axe-core, pa11y), manual test procedures (keyboard navigation, screen reader testing), ARIA audits, and remediation priorities. The output is written to `docs/test-artifacts/accessibility-report-{date}.md`.

This skill is the native Claude Code conversion of the legacy `_gaia/testing/workflows/accessibility-testing` workflow (E28-S88, Cluster 12, ADR-041). The step ordering, prompts, and output path are preserved from the legacy instructions.xml.

**Main context semantics (ADR-041):** This skill runs under `context: main` with full tool access. It reads project state (architecture, test plan, story) and produces an output document.

## Critical Rules

- A story key or project context MUST be available. If no story key is provided as an argument and no project context can be loaded, prompt: "Provide a story key or confirm project-level assessment."
- Target WCAG level must be declared before testing begins. Default to WCAG 2.1 Level AA if not specified.
- Automated checks must cover ALL identified pages and components.
- Output MUST be written to `docs/test-artifacts/accessibility-report-{date}.md` where `{date}` is today's date in YYYY-MM-DD format.
- Knowledge fragments are bundled in this skill's `knowledge/` directory -- load them JIT when referenced by a step.
- Sprint-status.yaml is NEVER written by this skill (Sprint-Status Write Safety rule).

## Steps

### Step 1 -- Scope

- Identify which pages and components to test from the story context or architecture.
- Declare target WCAG level: A, AA, or AAA. Default to AA if unspecified.
- Document user personas including users with disabilities (screen reader users, keyboard-only users, low vision users, cognitive disabilities).
- If architecture.md is available at `docs/planning-artifacts/architecture.md`, extract frontend components and routes.
- If story file is available, extract UI components from acceptance criteria and subtasks.

### Step 2 -- Automated Checks

- Load knowledge fragment: `knowledge/axe-core-patterns.md`
- Design axe-core or pa11y integration for each target page and component.
- Define automated test scenarios covering all identified components.
- Configure rule sets matching the declared WCAG level (wcag2a, wcag2aa, wcag21aa).
- Include CI integration configuration for automated accessibility regression testing.

### Step 3 -- Manual Test Plan

- Define keyboard navigation testing procedure for all interactive elements.
- Define screen reader testing procedure (VoiceOver for macOS/iOS, NVDA for Windows).
- Define color contrast verification steps (4.5:1 for normal text, 3:1 for large text per WCAG 1.4.3).
- Document focus order expectations for each page.
- Load knowledge fragment: `knowledge/wcag-checks.md` for the manual testing checklist.

### Step 4 -- ARIA Audit

- Review ARIA roles and labels for correctness across all components.
- Verify focus management on modal dialogs, dropdowns, and dynamic content.
- Check live regions (aria-live) for dynamic content updates.
- Validate landmark regions (nav, main, aside, footer).
- Check for ARIA overuse -- semantic HTML should be preferred over ARIA attributes.

### Step 5 -- Remediation Priorities

- Categorize findings by impact level:
  - **Critical** -- blocks access entirely (no keyboard nav, missing alt text on functional images)
  - **High** -- significantly degrades experience (poor focus indicators, missing form labels)
  - **Medium** -- inconvenient but workaround exists (suboptimal heading hierarchy)
  - **Low** -- enhancement opportunity (decorative improvements)
- Provide at least one remediation recommendation per critical finding.
- Map each finding to the relevant WCAG success criterion.

### Step 6 -- Generate Report

- Generate accessibility report with:
  - Executive summary with WCAG level target and overall compliance rating
  - Automated check results and configuration
  - Manual test procedures with pass/fail expectations
  - ARIA audit findings
  - Remediation priorities with impact categorization
  - References to relevant WCAG 2.1 success criteria
- Write output to `docs/test-artifacts/accessibility-report-{date}.md`.

## Finalize

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-a11y-testing/scripts/finalize.sh
