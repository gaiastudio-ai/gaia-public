---
template: 'story'
version: 1.4.0
key: "FIX-SEC-01"
title: "Security-finding fixture — planted unsafe shell interpolation"
epic: "FIX — Cluster 19 Review-Gate Fixtures"
status: review
priority: "P2"
size: "S"
points: 2
risk: "low"
sprint_id: "fixture-sprint"
date: "2026-04-17"
author: "Nate (Scrum Master)"
fixture_profile: security-finding
planted_defect:
  kind: security
  signature: unsafe-shell-interpolation
  owasp: A03-Injection
  review_expected_to_fail: security-review
---

# Story: Security-finding fixture

> **Epic:** FIX — Cluster 19 Review-Gate Fixtures
> **Priority:** P2
> **Status:** review
> **Date:** 2026-04-17
> **Fixture Profile:** security-finding (security-review expected to FAIL; others PASS)

## User Story

As the Cluster 19 review-gate harness, I want a fixture story whose implementation contains a single deterministic OWASP-relevant security defect, so that AC5 of E28-S134 can verify the `review → in-progress` transition on a FAILED security-review row.

## Acceptance Criteria

- [x] **AC1:** Given the `runBackup` utility, when called with a filename, then it executes a backup command. *(The implementation has a deliberate unsafe shell interpolation — OWASP A03 injection. /gaia-security-review flags this deterministically.)*

## Implementation Notes

```typescript
// src/run-backup.ts — DELIBERATELY unsafe: caller-supplied string interpolated into shell.
// This is the planted security defect. /gaia-security-review flags shell injection (OWASP A03).
// Fixture only — NEVER ship this pattern to production.
import { execSync } from 'child_process';
export function runBackup(filename: string): void {
  // PLANTED DEFECT (OWASP A03 — command injection via unsafe interpolation)
  execSync(`tar -czf /tmp/backup-${filename}.tgz /data`);
}
```

## Review Gate

| Review | Status | Report |
|--------|--------|--------|
| Code Review | UNVERIFIED | — |
| QA Tests | UNVERIFIED | — |
| Security Review | UNVERIFIED | — |
| Test Automation | UNVERIFIED | — |
| Test Review | UNVERIFIED | — |
| Performance Review | UNVERIFIED | — |

## Definition of Done

- [x] All acceptance criteria verified
- [x] Planted defect is present and deterministic
- [x] Defect is clearly labeled test-only (no production leakage)
