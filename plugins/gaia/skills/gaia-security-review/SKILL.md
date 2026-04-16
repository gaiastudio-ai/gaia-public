---
name: gaia-security-review
description: Pre-merge OWASP-focused security review. Use when "security review" or /gaia-security-review.
argument-hint: "[story-key]"
context: fork
allowed-tools: Read Grep Glob Bash
---

## Setup

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-security-review/scripts/setup.sh

## Mission

You are performing a pre-merge OWASP-focused security review for a story. The story is resolved by `{story_key}` via the canonical glob `{story_key}-*.md` in `docs/implementation-artifacts/`. You review each changed file against the OWASP Top 10 categories, scan for hardcoded secrets, review authentication/authorization patterns, assess data privacy compliance, and produce a machine-readable verdict (PASSED or FAILED) written to the story's Review Gate row via `review-gate.sh`.

This skill is the native Claude Code conversion of the legacy `_gaia/lifecycle/workflows/4-implementation/security-review` workflow (brief Cluster 9, story E28-S67, ADR-042). It follows the canonical reviewer skill pattern established by E28-S66.

**Fork context semantics (ADR-041, ADR-045):** This skill runs under `context: fork` with read-only tools (`Read Grep Glob Bash`). It CANNOT modify files — the tool allowlist enforces NFR-048 (no-write isolation). Do NOT attempt to call Write or Edit.

**Subagent dispatch:** OWASP analysis is dispatched to the Zara security subagent (E28-S21). The fork context invokes Zara for threat assessment; Zara's verdict is returned across the fork boundary.

## Critical Rules

- A story key argument MUST be provided. If missing, fail fast with "usage: /gaia-security-review [story-key]".
- The story file MUST exist at `docs/implementation-artifacts/{story_key}-*.md`. Use the canonical glob to resolve regardless of title slug. If zero matches, fail with "story file not found for key {story_key}".
- The story MUST be in `review` status. If not, fail with "story must be in review status before security review".
- This skill is READ-ONLY. Do NOT attempt to call Write or Edit tools — the fork context allowlist enforces this.
- OWASP analysis MUST be dispatched to the Zara security subagent — do NOT perform inline analysis in the fork context.
- The verdict uses PASSED or FAILED (canonical Review Gate vocabulary, per CLAUDE.md).
- Verdict logic: NO critical or high severity findings = PASSED; ANY critical or high severity finding = FAILED.
- Call `review-gate.sh` to update the Review Gate row — do NOT manually edit the story file.
- Sprint-status.yaml is NEVER written by this skill (Sprint-Status Write Safety rule).

## Steps

### Step 1 -- Resolve Story File

- If no story key was provided as an argument, fail with: "usage: /gaia-security-review [story-key]"
- Resolve the story file path using the canonical glob: `docs/implementation-artifacts/{story_key}-*.md`
- If zero matches: fail with "story file not found for key {story_key} -- searched docs/implementation-artifacts/{story_key}-*.md"
- If multiple matches: fail with "multiple story files matched key {story_key} -- resolve ambiguity"
- Read the resolved story file.

### Step 2 -- Status Gate

- Parse the story file YAML frontmatter and extract the `status` field.
- If status is not `review`, fail with: "story {story_key} is in '{status}' status -- must be in 'review' status for security review"
- Extract the list of files changed from the story file's "File List" section under "Dev Agent Record".

### Step 3 -- Dispatch OWASP Analysis to Zara

Invoke the Zara security subagent to perform the OWASP Top 10 analysis on all changed files. Pass the story key, file list, and threat model (if available at `docs/planning-artifacts/threat-model.md`) to Zara. Zara performs Steps 3a through 3f below and returns her findings across the fork boundary.

#### Step 3a -- OWASP Top 10 Scan

Check code changes against each OWASP category:

- A01: Broken Access Control — authorization checks, RBAC, CORS
- A02: Cryptographic Failures — encryption, hashing, key management
- A03: Injection — SQL, XSS, command injection, input validation
- A04: Insecure Design — missing security controls in design
- A05: Security Misconfiguration — default configs, unnecessary features
- A06: Vulnerable Components — outdated dependencies, known CVEs
- A07: Auth Failures — password policies, session management, MFA
- A08: Data Integrity Failures — deserialization, CI/CD integrity
- A09: Logging Failures — insufficient logging, missing audit trail
- A10: SSRF — server-side request forgery vectors

#### Step 3b -- Secrets Scan

- Check for hardcoded secrets, API keys, credentials in code
- Verify secrets are loaded from environment or secrets manager
- Check .gitignore covers sensitive files (.env, credentials, keys)

#### Step 3c -- Auth Pattern Review

- Verify authentication flow follows security best practices
- Check authorization at every access point (not just UI)
- Validate session management and token handling
- Check for privilege escalation paths

#### Step 3d -- Data Privacy and Compliance

- Identify if the story handles PII (names, emails, addresses, phone numbers, payment data, health data, authentication tokens, user-generated content with metadata)
- If PII is handled:
  - GDPR applicability: check for consent mechanisms, right-to-delete support, data portability, lawful basis for processing
  - Data encryption: verify PII is encrypted at rest (database-level or field-level) and in transit (TLS)
  - Data retention: check if retention policies are defined — flag if no retention period or deletion mechanism exists
  - Data minimization: flag collection of PII fields not required for the feature's purpose
  - Cross-border transfer: flag if PII may be stored or processed in different jurisdictions without safeguards
- If no PII detected: record "No PII handling identified in this story" for auditability

#### Step 3e -- Generate Findings

- Classify each finding by severity: critical, high, medium, low, info
- Include: finding description, location, OWASP category, remediation suggestion
- Provide overall security risk assessment

#### Step 3f -- Verdict

- If NO critical or high severity findings: verdict is PASSED
- If ANY critical or high severity finding exists: verdict is FAILED — list blocking findings

### Step 4 -- Write Security Review Report

- Generate the security review report and print it to the conversation. The report must contain:
  - Story key and title
  - Summary of files reviewed
  - OWASP findings table (category, severity, finding, location, remediation)
  - Secrets scan results
  - Auth review results
  - Data Privacy and Compliance assessment
  - Overall risk assessment
  - Machine-readable verdict line: `**Verdict: PASSED**` or `**Verdict: FAILED**`
- Save the report to `docs/implementation-artifacts/{story_key}-security-review.md`.

### Step 5 -- Update Review Gate

- Map the verdict to the canonical Review Gate vocabulary:
  - PASSED stays PASSED
  - FAILED stays FAILED
- Invoke the shared `review-gate.sh` script to update the story's Review Gate table:
  ```bash
  ${CLAUDE_PLUGIN_ROOT}/../scripts/review-gate.sh update --story "{story_key}" --gate "Security Review" --verdict "{PASSED|FAILED}"
  ```
- Confirm the update succeeded (exit code 0).
- Report the final status to the user.
- Note: sprint-status.yaml may now be out of sync. Run `/gaia-sprint-status` to reconcile.

## Finalize

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-security-review/scripts/finalize.sh
