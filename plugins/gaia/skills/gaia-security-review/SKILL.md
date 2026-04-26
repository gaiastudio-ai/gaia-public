---
name: gaia-security-review
description: Pre-merge OWASP-focused security review. Use when "security review" or /gaia-security-review.
argument-hint: "[story-key]"
context: fork
allowed-tools: [Read, Grep, Glob, Bash]
---

## Setup

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-security-review/scripts/setup.sh

## Mission

You are performing a pre-merge OWASP-focused security review for a story. The story is resolved by `{story_key}` via the canonical glob `{story_key}-*.md` in `docs/implementation-artifacts/`. You review each changed file against the OWASP Top 10 categories, scan for hardcoded secrets, review authentication/authorization patterns, assess data privacy compliance, and produce a machine-readable verdict (PASSED or FAILED) written to the story's Review Gate row via `review-gate.sh`.

This skill is the native Claude Code conversion of the legacy `_gaia/lifecycle/workflows/4-implementation/security-review` workflow (brief Cluster 9, story E28-S67, ADR-042). It follows the canonical reviewer skill pattern established by E28-S66.

**Fork context semantics (ADR-041, ADR-045):** This skill runs under `context: fork` with read-only tools (`Read Grep Glob Bash`). It CANNOT modify files — the tool allowlist enforces NFR-048 (no-write isolation). Do NOT attempt to call Write or Edit.

**Subagent dispatch:** OWASP analysis is dispatched to the Zara security subagent (E28-S21). The fork context invokes Zara for threat assessment; Zara's verdict is returned across the fork boundary and surfaced to the user per ADR-063.

**Threat-model context (ADR-064):** When `docs/planning-artifacts/threat-model.md` exists, this skill loads it via the `Read` tool and injects it into the Zara dispatch context under a "Threat Model Context" section so Zara can cross-reference OWASP findings against modeled threat IDs (e.g., "see T3 in threat model"). When the file is absent, the skill proceeds silently — no error, no warning, no user-visible message about the missing file — preserving exact pre-E48-S2 behavior.

## Critical Rules

- A story key argument MUST be provided. If missing, fail fast with "usage: /gaia-security-review [story-key]".
- The story file MUST exist at `docs/implementation-artifacts/{story_key}-*.md`. Use the canonical glob to resolve regardless of title slug. If zero matches, fail with "story file not found for key {story_key}".
- The story MUST be in `review` status. If not, fail with "story must be in review status before security review".
- This skill is READ-ONLY. Do NOT attempt to call Write or Edit tools — the fork context allowlist enforces this.
- OWASP analysis MUST be dispatched to the Zara security subagent — do NOT perform inline analysis in the fork context.
- Zara's return MUST be parsed as the ADR-037 structured schema (`{status, summary, artifacts, findings, next}`) and the verdict MUST be surfaced to the user per ADR-063 (the Subagent Dispatch Contract). Never silently consume Zara's return.
- A CRITICAL verdict from Zara HALTS the skill before the Review Gate is written. This applies in all execution modes (normal and YOLO) per ADR-067.
- The verdict uses PASSED or FAILED (canonical Review Gate vocabulary, per CLAUDE.md).
- Verdict logic: NO critical or high severity findings = PASSED; ANY critical or high severity finding = FAILED.
- Call `review-gate.sh` to update the Review Gate row — do NOT manually edit the story file.
- Sprint-status.yaml is NEVER written by this skill (Sprint-Status Write Safety rule).

## Subagent Dispatch Contract

This skill follows the framework-wide Subagent Dispatch Contract (ADR-063). The Zara dispatch in Step 3 is invoked via `context: fork` per ADR-045 with the same read-only tool allowlist `[Read, Grep, Glob, Bash]`. After Zara returns:

1. **Parse the subagent return** using the ADR-037 structured schema: `{ status, summary, artifacts, findings, next }`. The `status` field is one of `PASS`, `WARNING`, `CRITICAL`. Each entry in `findings` carries a `severity` of `CRITICAL`, `WARNING`, `INFO`, plus an OWASP category and (when threat-model context was provided) an optional `threat_ref` (e.g., "T3").
2. **Surface the verdict** to the user inline: display `status` and `summary`, then list every finding with its severity, OWASP category, location, recommended remediation, and any `threat_ref` cross-reference.
3. **Halt on CRITICAL** — if `status == "CRITICAL"` or any finding has `severity == "CRITICAL"`, the skill HALTS before writing the Review Gate row. The user must resolve the finding before re-running the security review. No Review Gate write occurs on a CRITICAL halt — the existing UNVERIFIED row stays as-is.
4. **Display WARNING** — findings with `severity == "WARNING"` are displayed inline before proceeding. The skill does NOT halt; warnings are recorded in the security review report and counted toward the PASSED/FAILED verdict per the canonical verdict logic (any critical OR high severity finding ⇒ FAILED).
5. **Log INFO** — findings with `severity == "INFO"` are written to the security review report but are not surfaced inline unless the user requests verbose output.

This contract is enforced uniformly per ADR-063. CRITICAL findings cannot be auto-dismissed in any execution mode. This closes the "validation gates swallowed by subagents" regression class for `/gaia-security-review`.

## YOLO Behavior

This skill conforms to the framework-wide YOLO Mode Contract (ADR-067).

| Behavior | YOLO Action |
|----------|-------------|
| Template-output prompts (`[c]/[y]/[e]`) | Auto-continue (skip prompt). |
| Severity / filter selection | Auto-accept defaults. |
| Optional confirmation prompts | Auto-confirm. |
| Subagent verdict display (Zara return) | Auto-display, but a CRITICAL verdict still HALTS per ADR-063. |
| Open-question indicators (unchecked checkboxes, TBD markers) | HALT — never auto-skip; require human input. |
| Memory save prompt at end | HALT — require human input (Phase 4 per ADR-061). |

In YOLO mode the Zara verdict is auto-displayed but a CRITICAL verdict still halts the skill — this is the canonical YOLO/CRITICAL interaction established by ADR-067.

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

### Step 2b -- Threat-Model Context Detection (ADR-064)

- Probe for `docs/planning-artifacts/threat-model.md` via the `Read` tool (the threat-model read uses the Read tool, which is in the fork-context allowlist `[Read, Grep, Glob, Bash]` per ADR-045).
- **If the file exists:** read its full content and bind it to the local variable `threat_model_context` for the Step 3 dispatch. Do NOT log "threat model loaded" or any other progress message — the presence of the cross-reference instructions in Zara's prompt is the only user-visible signal.
- **If the file is absent:** proceed silently. Do NOT emit a warning, error, or user-visible message about the missing file — the skill must produce zero new output when threat-model.md does not exist. This preserves the exact pre-E48-S2 dispatch behavior. The `threat_model_context` variable is unset; downstream Step 3 omits the "Threat Model Context" section and the cross-reference instruction entirely.
- The skill remains read-only: no `Write` or `Edit` calls are introduced by threat-model detection (ADR-041, ADR-045, NFR-048).

### Step 3 -- Dispatch OWASP Analysis to Zara

Invoke the Zara security subagent to perform the OWASP Top 10 analysis on all changed files. Pass the story key, file list, and — when present — the `threat_model_context` from Step 2b, into Zara's dispatch prompt. Zara performs Steps 3a through 3f below and returns her findings across the fork boundary using the ADR-037 structured schema.

**Conditional Threat Model Context block.** If `threat_model_context` is set (Step 2b found `threat-model.md`), include it in the Zara dispatch prompt under a clearly labeled section, plus a cross-reference instruction. If `threat_model_context` is unset, omit BOTH the section and the cross-reference instruction — Zara then produces standard OWASP findings without cross-references (no behavioral change from the pre-E48-S2 baseline).

The dispatch prompt template, with the conditional block shown in `<<<...>>>` markers, is:

> Story: {story_key}
> Files changed: {file_list}
>
> <<<IF threat_model_context IS SET, INCLUDE THIS BLOCK:
>
> ## Threat Model Context
>
> The following threat model was extracted from `docs/planning-artifacts/threat-model.md`. Each modeled threat carries a stable identifier (e.g., T1, T2, T3). When you find an OWASP issue that directly relates to a modeled threat, **cross-reference the threat ID** in the finding using the format `see T{n} in threat model` (for example: "SQL injection in /api/users — see T3 in threat model"). Only cross-reference when a modeled threat directly applies — do not force cross-references where no threat matches.
>
> ```
> {threat_model_context}
> ```
>
> END CONDITIONAL BLOCK>>>
>
> Perform the OWASP Top 10 analysis described in steps 3a-3f and return your findings using the ADR-037 structured schema `{status, summary, artifacts, findings, next}`. Each finding should include `severity`, `owasp_category`, `location`, `remediation`, and (when threat-model context was provided) an optional `threat_ref` field carrying the matched threat ID.

After Zara returns, apply the Subagent Dispatch Contract above: parse the ADR-037 schema, surface the verdict, halt on CRITICAL, display WARNINGs inline, log INFO findings to the report.

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
- When threat-model context was provided: include a `threat_ref` field on findings that match a modeled threat (e.g., `threat_ref: "T3"`). Findings that do not match a modeled threat have no `threat_ref` — do not invent matches.
- Provide overall security risk assessment

#### Step 3f -- Verdict

- If NO critical or high severity findings: verdict is PASSED
- If ANY critical or high severity finding exists: verdict is FAILED — list blocking findings

### Step 4 -- Write Security Review Report

- Generate the security review report and print it to the conversation. The report must contain:
  - Story key and title
  - Summary of files reviewed
  - Whether threat-model context was loaded (one-line note: "Threat model: loaded" or "Threat model: not present")
  - OWASP findings table (category, severity, finding, location, remediation, threat_ref when present)
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
  ${CLAUDE_PLUGIN_ROOT}/scripts/review-gate.sh update --story "{story_key}" --gate "Security Review" --verdict "{PASSED|FAILED}"
  ```
- Confirm the update succeeded (exit code 0).
- Report the final status to the user.
- Note: sprint-status.yaml may now be out of sync. Run `/gaia-sprint-status` to reconcile.

### Step 6 -- Composite Review Gate Check

- After the individual gate update completes successfully, invoke the composite review-gate-check to show the overall story review status:
  ```bash
  ${CLAUDE_PLUGIN_ROOT}/scripts/review-gate.sh review-gate-check --story "{story_key}"
  ```
- Capture stdout and include the Review Gate table and summary line (`Review Gate: COMPLETE|PENDING|BLOCKED`) in the command's output.
- This check is informational only -- do not halt on non-zero exit codes. Exit codes 0/1/2 correspond to COMPLETE/BLOCKED/PENDING per ADR-054. Log the result and continue regardless of exit code.

## References

- ADR-037 — Structured subagent return schema `{status, summary, artifacts, findings, next}`.
- ADR-041 — Native Execution Model via Claude Code Skills + Subagents + Plugins + Hooks.
- ADR-042 — Scripts-over-LLM for Deterministic Operations.
- ADR-045 — Review Gate via Sequential `context: fork` Subagents.
- ADR-063 — Subagent Dispatch Contract — Mandatory Verdict Surfacing.
- ADR-064 — Threat-Model Context Plumbing for Security Skills.
- ADR-067 — YOLO Mode Contract — Consistent Non-Interactive Behavior.

## Finalize

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-security-review/scripts/finalize.sh
