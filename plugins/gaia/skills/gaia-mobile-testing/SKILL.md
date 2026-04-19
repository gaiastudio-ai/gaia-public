---
name: gaia-mobile-testing
description: Create mobile test plan with device matrix, Appium configuration, and responsive testing scenarios. Use when "mobile testing" or /gaia-mobile-testing.
argument-hint: "[story-key]"
context: main
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash]
---

## Setup

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-mobile-testing/scripts/setup.sh

## Mission

You are creating a mobile test plan covering device matrix, Appium test infrastructure, React Native / cross-platform testing, responsive viewport testing, and platform-specific checks. The output is written to `docs/test-artifacts/mobile-test-plan-{date}.md`.

This skill is the native Claude Code conversion of the legacy `_gaia/testing/workflows/mobile-testing` workflow (E28-S88, Cluster 12, ADR-041). The step ordering, prompts, and output path are preserved from the legacy instructions.xml.

**Main context semantics (ADR-041):** This skill runs under `context: main` with full tool access. It reads project state (architecture, test plan, story) and produces an output document.

## Critical Rules

- A story key or project context MUST be available. If no story key is provided as an argument and no project context can be loaded, prompt: "Provide a story key or confirm project-level assessment."
- Device matrix must cover top 90% of the target user base.
- Platform-specific behaviors must be tested on real devices or emulators.
- Output MUST be written to `docs/test-artifacts/mobile-test-plan-{date}.md` where `{date}` is today's date in YYYY-MM-DD format.
- Knowledge fragments are bundled in this skill's `knowledge/` directory -- load them JIT when referenced by a step.
- Sprint-status.yaml is NEVER written by this skill (Sprint-Status Write Safety rule).

## Steps

### Step 1 -- Platform Matrix

- Define target devices by OS version, screen size, and market share.
- Include minimum supported versions for iOS and Android.
- Document screen size breakpoints and orientation requirements.
- Identify device-specific features used (camera, GPS, biometrics).
- If architecture.md is available, extract mobile stack details (React Native, Flutter, native).

### Step 2 -- Appium Setup

- Load knowledge fragment: `knowledge/appium-patterns.md`
- Design Appium test infrastructure and capabilities for iOS and Android.
- Configure device farm integration (BrowserStack, SauceLabs, or local emulators).
- Define element location strategies and wait patterns.
- Include Page Object Model structure for test maintainability.

### Step 3 -- React Native / Cross-Platform Testing

- Load knowledge fragment: `knowledge/react-native-testing.md`
- Design Jest + React Native Testing Library unit test patterns.
- Configure Detox for E2E testing if applicable.
- Define native module mocking strategies.
- Include navigation testing patterns.

### Step 4 -- Responsive Testing

- Load knowledge fragment: `knowledge/responsive-testing.md`
- Define viewport testing matrix across target breakpoints (320px through 1920px).
- Design touch interaction tests (swipe, pinch, long press).
- Configure visual regression testing for mobile viewports.
- Include orientation change testing (portrait/landscape).

### Step 5 -- Platform-Specific Checks

- Test permission handling flows (camera, location, notifications).
- Verify deep linking behavior on both platforms.
- Test push notification delivery and handling.
- Validate platform gesture differences (back button on Android, swipe-back on iOS).
- Check app lifecycle handling (background, foreground, kill, restore).

### Step 6 -- Generate Output

- Generate mobile test plan with:
  - Device matrix with OS versions, screen sizes, and market share coverage
  - Appium infrastructure setup and capabilities configuration
  - React Native / cross-platform test patterns
  - Responsive viewport testing matrix
  - Platform-specific test scenarios
  - Touch interaction and gesture testing procedures
- Write output to `docs/test-artifacts/mobile-test-plan-{date}.md`.

## Finalize

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-mobile-testing/scripts/finalize.sh
