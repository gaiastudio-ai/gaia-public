---
name: gaia-review-security
description: Perform an OWASP-focused security review on provided code or document — OWASP Top 10 scan, hardcoded secrets / API keys / credentials detection, authentication and authorization pattern review. Produces a markdown findings report with severity levels and remediation recommendations. Use when "review security" or /gaia-review-security.
argument-hint: "[target — file, directory, or document]"
tools: Read, Write, Edit, Bash, Grep
---

## Mission

You are performing an **OWASP-focused security review** on the target the user supplies. You evaluate the target across three categories: OWASP Top 10 scan, hardcoded secrets detection, and authentication / authorization pattern review. You produce a markdown findings report with OWASP findings table, secrets scan results, auth pattern review, per-finding severity, and remediation recommendations.

This skill is the native Claude Code conversion of the legacy `_gaia/core/tasks/review-security.xml` task (37 lines). Per **ADR-041** (Native Execution Model) and **ADR-042** (Scripts-over-LLM for Deterministic Operations), the legacy task-runner engine is retired and this skill runs natively under the Claude Code primitives model. Deterministic report-header generation is delegated to the shared foundation script `template-header.sh` (E28-S16) rather than re-prosed per skill.

## Critical Rules

- **Check against all OWASP Top 10 categories.** Every category must be evaluated — none may be silently skipped. The Top 10 (2021) list is the reference: Broken Access Control, Cryptographic Failures, Injection, Insecure Design, Security Misconfiguration, Vulnerable and Outdated Components, Identification and Authentication Failures, Software and Data Integrity Failures, Security Logging and Monitoring Failures, Server-Side Request Forgery (SSRF).
- **Flag hardcoded secrets, API keys, credentials.** Any literal token, password, connection string, or key-shaped constant is a finding — severity escalated if the value looks live.
- **Check authentication and authorization patterns.** Review how identity is established, how sessions or tokens are managed, and how authorization decisions are made at every trust boundary — look for privilege escalation paths.

## Inputs

- `$ARGUMENTS`: optional target (file, directory, or document path). If omitted, ask the user inline: "Which code or document should I review for security?"

## Steps

### Step 1 — Scope

- If `$ARGUMENTS` is non-empty, resolve it as the target. Otherwise ask the user inline for the code or document to review (preserves the legacy Step 1 "Ask user what code/doc to review" behavior — AC-EC4).
- Read the target file(s). If a directory is given, recursively read all source files under it.

### Step 2 — OWASP Top 10 Scan

Evaluate each category — record a verdict for every one (PASS / FINDING / N/A-with-justification):

1. **Broken Access Control** — missing authorization checks, IDOR, forced browsing, CORS misconfigurations, privilege escalation paths.
2. **Cryptographic Failures** — weak hashing (MD5, SHA-1 for passwords), no TLS, hard-coded keys, insecure random, missing integrity.
3. **Injection** — SQL, NoSQL, OS command, LDAP, XPath, template injection; untrusted input reaching an interpreter.
4. **Insecure Design** — missing threat model, lack of rate limiting, insecure defaults, unprotected workflows.
5. **Security Misconfiguration** — default credentials, verbose errors in production, unused features enabled, missing headers (CSP, HSTS, X-Frame-Options).
6. **Vulnerable and Outdated Components** — packages with known CVEs, unpatched frameworks, unmaintained libraries. (Cross-reference `/gaia-review-deps` output if available.)
7. **Identification and Authentication Failures** — missing MFA, weak password policy, session fixation, no account lockout, insecure credential recovery.
8. **Software and Data Integrity Failures** — unsigned updates, untrusted deserialization, CI/CD pipeline without artifact verification.
9. **Security Logging and Monitoring Failures** — no audit log, no alerting, logs contain secrets, no anomaly detection.
10. **Server-Side Request Forgery (SSRF)** — unvalidated URL inputs, metadata service access, internal-network reachable from user-controlled URLs.

### Step 3 — Secrets Scan

- Look for hardcoded secrets, API keys, credentials, database connection strings, JWT signing secrets, encryption keys, OAuth client secrets, SSH private keys.
- Flag any literal that looks like a token (high-entropy string, base64-like pattern, AWS key shape `AKIA...`, etc.).
- Verify the secrets management approach: env vars + secret manager vs. committed files; check `.env` files are gitignored; check the CI does not echo secrets.

### Step 4 — Auth Review

- Verify authentication pattern: how is identity established at request entry? Is the session or token validated on every protected route?
- Verify authorization pattern: role / scope / attribute checks at the right trust boundary; least privilege by default; consistent enforcement.
- Check for privilege escalation paths: horizontal (same role, different user's data — IDOR) and vertical (user → admin via weak role check).
- Check token lifecycle: issue, refresh, revoke, expiry.

### Step 5 — Report

Invoke the shared foundation script to emit the deterministic artifact header (ADR-042):

```bash
!${CLAUDE_PLUGIN_ROOT}/scripts/template-header.sh --template security-review --workflow gaia-review-security
```

If `template-header.sh` is missing or non-executable (AC-EC7), degrade gracefully to an inline prose header (`# Security Review — {date}`), log a warning, and still write a valid report.

Write the report to the following path (preserved verbatim from the legacy task — AC4):

```
{planning_artifacts}/security-review-{date}.md
```

If the file already exists for the same day (AC-EC3), write to a suffix-incremented filename (`security-review-{date}-2.md`, ...).

The report contains:

- **OWASP findings table** — columns: OWASP category (1–10), location (file:line or component), severity (critical / high / medium / low), finding description, remediation recommendation.
- **Secrets scan results** — list of any hardcoded tokens / keys / credentials, with file:line, detection rationale, and a redacted sample.
- **Auth pattern review** — authentication, authorization, token lifecycle, privilege escalation findings.
- **Remediation recommendations** — prioritised action list, critical first.

If the target is empty or resolves to no files (AC-EC6), exit with `No review target resolved` and do NOT write an empty report file.

## References

- Source: `_gaia/core/tasks/review-security.xml` (legacy 37-line task body — ported per ADR-041 + ADR-042).
- ADR-041: Native Execution Model via Claude Code Skills + Subagents + Plugins + Hooks.
- ADR-042: Scripts-over-LLM for Deterministic Operations.
- ADR-048: Engine Deletion as Program-Closing Action — legacy task coexists until program close.
- FR-323: Skill Conversion — slash-command identity preserved.
- NFR-053: Full v1.127.2-rc.1 Feature Parity.
- OWASP Top 10 (2021): https://owasp.org/Top10/
