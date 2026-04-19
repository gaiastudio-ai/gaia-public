---
name: gaia-review-api
description: Review REST API design against standards and best practices — resource naming conventions, HTTP methods, status codes, RFC 7807 error format, versioning strategy. Produces a markdown findings report organised by category with severity levels. Use when "review API design" or /gaia-review-api.
argument-hint: "[target — API spec, OpenAPI doc, or route code]"
tools: Read, Write, Edit, Bash, Grep
---

## Mission

You are performing a **REST API design review** on the target the user supplies — an OpenAPI spec, route definitions, or API implementation code. You evaluate the target across four categories: resource naming conventions, HTTP method usage + status codes, error response format (RFC 7807), and versioning strategy. You produce a markdown findings report organised by category with per-finding severity and recommendation.

This skill is the native Claude Code conversion of the legacy `_gaia/core/tasks/review-api-design.xml` task (38 lines). Per **ADR-041** (Native Execution Model) and **ADR-042** (Scripts-over-LLM for Deterministic Operations), the legacy task-runner engine is retired and this skill runs natively under the Claude Code primitives model. Deterministic report-header generation is delegated to the shared foundation script `template-header.sh` (E28-S16) rather than re-prosed per skill.

## Critical Rules

- **Check naming conventions, HTTP methods, status codes.** Resources are plural nouns, URLs are kebab-case, URLs contain no verbs; HTTP methods carry the verb (GET / POST / PUT / PATCH / DELETE); status codes are appropriate (2xx / 4xx / 5xx).
- **Verify versioning strategy.** The API MUST declare a versioning scheme — URL-path (`/v1/`), custom header (`Api-Version`), media-type versioning, or query param. Lack of versioning is a critical finding.
- **Reference RFC 7807 for error responses.** Errors MUST follow RFC 7807 (Problem Details for HTTP APIs) or a consistent documented pattern — type, title, status, detail, instance.
- The review is READ-ONLY on the target — findings go in the report artifact, not inline edits.

## Inputs

- `$ARGUMENTS`: optional target (API spec file, OpenAPI YAML/JSON, routes source file, or directory). If omitted, ask the user inline: "Which API spec or route code should I review?"

## Steps

### Step 1 — Scope

- If `$ARGUMENTS` is non-empty, resolve it as the target. Otherwise ask the user inline for the API spec or route code (preserves the legacy Step 1 "Ask user for API specification or code to review" behavior — AC-EC4).
- Read the target file(s). If a directory is given, recursively read all relevant API-definition files.

### Step 2 — Naming Conventions

- Check resource naming: plural nouns (`/users` not `/user`), kebab-case in path segments (`/audit-logs` not `/auditLogs`), no verbs in URLs (prefer `GET /orders/{id}/items` over `GET /getOrderItems`).
- Verify consistent naming across endpoints — pluralisation, casing, hyphenation must be uniform.
- Check path parameter naming — `{id}`, `{userId}`, consistent casing.

### Step 3 — HTTP Methods and Status Codes

- Verify correct HTTP method usage:
  - `GET` — safe, idempotent retrieval
  - `POST` — create or non-idempotent action
  - `PUT` — idempotent full replacement
  - `PATCH` — partial update
  - `DELETE` — remove
- Check status codes are appropriate:
  - `200 OK`, `201 Created`, `202 Accepted`, `204 No Content` for success
  - `400 Bad Request`, `401 Unauthorized`, `403 Forbidden`, `404 Not Found`, `409 Conflict`, `422 Unprocessable Entity` for client error
  - `500`, `502`, `503`, `504` for server error
- Flag misuse (e.g., returning `200` with an error body, or using `POST` where `PATCH` is correct).

### Step 4 — Error Format and Versioning

- Check the error response format follows RFC 7807 (Problem Details) or a consistent documented pattern. Required RFC 7807 fields: `type`, `title`, `status`; recommended: `detail`, `instance`. Deviations are flagged with severity.
- Verify the API declares a versioning strategy — URL segment (`/v1/`), custom header (`Api-Version: 1`), media-type (`Accept: application/vnd.example+json; version=1`), or query parameter. Lack of versioning is a critical finding.
- Verify breaking changes follow the declared versioning strategy — additive changes inside a major version, breaking changes require a new version.

### Step 5 — Report

Invoke the shared foundation script to emit the deterministic artifact header (ADR-042):

```bash
!${CLAUDE_PLUGIN_ROOT}/scripts/template-header.sh --template api-design-review --workflow gaia-review-api
```

If `template-header.sh` is missing or non-executable (AC-EC7), degrade gracefully to an inline prose header (`# API Design Review — {date}`), log a warning, and still write a valid report.

Write the report to the following path (preserved verbatim from the legacy task — AC4):

```
{planning_artifacts}/api-design-review-{date}.md
```

If the file already exists for the same day (AC-EC3), write to a suffix-incremented filename (`api-design-review-{date}-2.md`, ...).

The report is organised by category (naming, HTTP methods, status codes, error format, versioning). Each finding row includes: category, severity (critical / high / medium / low), endpoint or location, finding description, recommendation.

If the target is empty or resolves to no API definitions (AC-EC6), exit with `No review target resolved` and do NOT write an empty report.

## References

- Source: `_gaia/core/tasks/review-api-design.xml` (legacy 38-line task body — ported per ADR-041 + ADR-042).
- ADR-041: Native Execution Model via Claude Code Skills + Subagents + Plugins + Hooks.
- ADR-042: Scripts-over-LLM for Deterministic Operations.
- ADR-048: Engine Deletion as Program-Closing Action — legacy task coexists until program close.
- FR-323: Skill Conversion — slash-command identity preserved.
- NFR-053: Full v1.127.2-rc.1 Feature Parity.
- RFC 7807: Problem Details for HTTP APIs.
