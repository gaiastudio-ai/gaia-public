---
name: gaia-test-framework
description: Initialize test framework with appropriate tooling based on detected project stack. Use when "setup test framework" or /gaia-test-framework.
context: fork
tools: Read, Write, Edit, Grep, Glob, Bash
---

## Setup

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-test-framework/scripts/setup.sh

## Mission

Initialize a test framework for the current project by detecting the project stack, selecting the appropriate test framework, scaffolding configuration files and folder structure, and designing fixture/factory patterns. The output is a test framework setup document written to `docs/test-artifacts/test-framework-setup.md`.

This skill is the native Claude Code conversion of the legacy `_gaia/testing/workflows/test-framework` workflow (E28-S87, Cluster 11). The step ordering, prompts, and output path are preserved verbatim from the legacy `instructions.xml` — do not restructure, re-prompt, or reorder.

## Critical Rules

- Knowledge fragments are bundled in this skill's `knowledge/` directory -- load them JIT when referenced by a step.
- Detect the project stack before recommending any framework — never assume.
- Scaffold complete setup: config files, folder structure, and test runner scripts (npm scripts or equivalent).
- Do NOT implement or run any tests — test implementation happens in Phase 4 workflows (/gaia-dev-story, /gaia-qa-tests, /gaia-atdd).
- Do NOT write sample tests or run any test suite — only set up the infrastructure so tests can be added later.
- Output ALL artifacts to `docs/test-artifacts/`.
- This is a single-prompt operation — no subagent invocation needed.

## Steps

### Step 1 — Detect Stack

- Identify project language, framework, and existing test setup.
- Check for package.json (Node/TypeScript), requirements.txt / pyproject.toml (Python), build.gradle / pom.xml (Java), pubspec.yaml (Flutter/Dart), go.mod (Go).
- Identify any existing test configuration (vitest.config.ts, jest.config.js, pytest.ini, etc.).
- Report detected stack to the user: language, framework, existing test infrastructure.

### Step 2 — Select Framework

- Load stack-specific knowledge fragments based on detected stack:
  - Load knowledge fragment: `knowledge/jest-vitest-patterns.md` for JS/TS projects
  - Load knowledge fragment: `knowledge/pytest-patterns.md` for Python projects
  - Load knowledge fragment: `knowledge/junit5-patterns.md` for Java projects
- Load knowledge fragment: `knowledge/test-isolation.md` for test doubles and dependency injection patterns
- Recommend test framework based on detected stack:
  - TypeScript/JavaScript: Vitest (preferred) or Jest for unit/integration, Playwright or Cypress for E2E
  - Python: pytest for unit/integration, Playwright for E2E
  - Java: JUnit 5 for unit/integration, Selenium or Playwright for E2E
  - Flutter/Dart: flutter_test for unit, integration_test for integration
  - Go: built-in testing package, testify for assertions
- Consider existing project conventions — if a framework is already partially set up, prefer extending it over replacing it.
- Present recommendation with rationale.

### Step 3 — Scaffold

- Generate config files for the selected framework (e.g., vitest.config.ts, jest.config.js, pytest.ini).
- Create folder structure for tests (e.g., `tests/unit/`, `tests/integration/`, `tests/e2e/`).
- Add test runner scripts to the project build tool (e.g., npm scripts in package.json, Makefile targets).
- Do NOT write sample tests or run any test suite — only set up the infrastructure.

### Step 4 — Fixture Architecture

- Load knowledge fragment: `knowledge/fixture-architecture.md` for fixture patterns and pure function wrappers
- Load knowledge fragment: `knowledge/data-factories.md` for builder pattern and factory function patterns
- Design fixture/factory patterns appropriate for the stack.
- Pure functions first — framework fixtures as wrappers around pure factory functions.
- Define a consistent pattern for test data creation (factory functions, builder pattern, or fixture files).
- Document the fixture architecture in the output.

### Step 5 — Generate Output

Write the test framework setup document to `docs/test-artifacts/test-framework-setup.md` with:
- Detected stack summary
- Selected framework and rationale
- Configuration files created
- Folder structure
- Test runner commands
- Fixture/factory architecture
- Instructions for adding tests

## Finalize

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-test-framework/scripts/finalize.sh
