---
name: gaia-brownfield
description: Apply GAIA to an existing project — deep discovery, multi-scan gap analysis, NFR assessment, and template-driven artifact generation. Use when "onboard existing project" or /gaia-brownfield. Runs multi-scan logic (doc-code, hardcoded, integration-seam, runtime-behavior, security) plus NFR assessment via test-architect subagent.
argument-hint: "[project-path]"
context: main
tools: Read, Write, Edit, Grep, Glob, Bash, Agent
model: inherit
---

## Setup

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-brownfield/scripts/setup.sh

## Mission

You are applying the GAIA framework to an existing codebase. This skill runs **deep project discovery, parallel documentation subagents, multi-scan gap analysis, NFR assessment, gap consolidation, PRD/architecture generation, and optional ground-truth bootstrap**, then writes the canonical brownfield onboarding artifact set.

This skill is the native Claude Code conversion of the legacy `brownfield-onboarding` workflow (E28-S105, Cluster 14). The step ordering, prompts, subagent delegation, template-driven output generation, and post-complete quality gates are preserved from the legacy `instructions.xml` — parity confirmed per NFR-053.

**Main context semantics (ADR-041):** This skill runs under `context: main` with full tool access. It orchestrates a large discovery pipeline that reads the target project and produces a canonical artifact set under `docs/planning-artifacts/` and `docs/test-artifacts/`.

**Scripts-over-LLM (ADR-042 / FR-325):** Deterministic operations (config resolution, checkpoint writes, gate validation, lifecycle events) are delegated to the shared foundation scripts under `plugins/gaia/scripts/` via inline `!scripts/*.sh` calls. The canonical foundation set includes: `resolve-config.sh`, `checkpoint.sh` (with `write` / `read` / `validate` subcommands — the consolidated checkpoint surface per architecture §10.26.3), `validate-gate.sh` (deployed equivalent for spec's `file-gate.sh`), `template-header.sh`, `memory-loader.sh`, `lifecycle-event.sh`. See the Reconciliation Note under Critical Rules for the one remaining spec-vs-deployed name mapping.

## Critical Rules

- **Document existing state before proposing changes.** Stories written downstream must cover gaps only, not re-implement existing features.
- **Gap-only PRD:** When generating the brownfield PRD, fill every section with gap-focused content. Do NOT re-document working features as new requirements.
- **Mermaid diagrams only:** Every diagram in generated artifacts must use Mermaid syntax — no ASCII art, no prose descriptions of diagrams.
- **Swagger/OpenAPI for APIs:** All API documentation must use Swagger/OpenAPI format. If an OpenAPI spec exists, validate it against actual routes; if not, generate one from code.
- **Limit flow diagrams to 3–5 key flows** to avoid output bloat.
- **Subagent completion MUST NOT auto-advance.** After parallel subagents return, pause for user review before proceeding to the next phase. Halt-on-failure is scoped per subagent — individual scanner failures do not block the overall workflow (see the Failure Semantics section), but the post-complete gates halt when their required files are absent.
- **Sprint-status.yaml is NEVER written by this skill** (Sprint-Status Write Safety rule). This skill writes only planning and test artifacts.
- **Parallel invocation isolation (AC-EC7):** Each invocation uses an isolated checkpoint path and independent `_resolved` config derived from `resolve-config.sh`. Two concurrent runs on different project roots never share mutable state or contaminate each other's artifacts.
- **Token budget (NFR-048 / AC-EC1):** Keep the SKILL.md body under the activation budget. Scanners stream/chunk results and emit a "scan truncated — review manually" advisory rather than exceed the budget (AC-EC6).
- **Fail-fast on missing foundation scripts (AC-EC2):** `setup.sh` aborts with an actionable error identifying the missing / non-executable script path. No partial scan output is written if the setup step fails.

### Reconciliation Note — Architecture Spec vs Deployed Scripts

Architecture §10.26.3 specifies the foundation-script surface. The live `plugins/gaia/scripts/` set exposes `checkpoint.sh` (with `write` / `read` / `validate` subcommands — same canonical name used by architecture §10.26.3 since E28-S172) alongside `validate-gate.sh`, which is the deployed equivalent for the spec's `file-gate.sh`. This skill calls the deployed names for parity with the live script set. If the `file-gate.sh` spec name is added later under a separate story (E28-S9..E28-S16), the inline calls in `setup.sh` / `finalize.sh` can be updated without touching the skill body. The checkpoint surface no longer requires reconciliation — `checkpoint.sh` is the canonical name in both the spec and the product.

## Inputs

This skill accepts the following inputs (from `$ARGUMENTS` when invoked via slash command, or from interactive prompt otherwise):

1. **Project path** — absolute or relative path to the target codebase. Defaults to the current working directory.
2. **Execution mode** — `normal` (pause for user review at checkpoints) or `yolo` (auto-advance). YOLO mode always uses the safe default of `merge` when resolving `test-environment.yaml` conflicts.

## Pipeline Overview

The skill runs nine phases in strict order:

1. **Deep Project Discovery** — capability detection and project classification
2. **Parallel Documentation Subagents** — API, UX, events, dependencies
3. **Deep Analysis Multi-Scan Subagents** — five scan branches + doc-code + config-contradiction + dead-code
4. **Test Execution During Discovery** — non-blocking test runner probe
5. **Auto-Generate test-environment.yaml** — from detected test infrastructure (conditional)
6. **NFR Assessment & Performance Test Plan** — test-architect subagent (Sable)
7. **Gap Consolidation & Deduplication** — merge, rank, budget-check
8. **PRD + Adversarial Review + Code-Verified Review** — gap-focused PRD generation
9. **Architecture + Ground-Truth Bootstrap** — optional Val seed + Tier 1 agent extraction

Each phase is independent in its write targets but must run sequentially because later phases consume earlier outputs.

## Phase 1 — Deep Project Discovery

1. Scan the project root for the primary tech stack, frameworks, runtime versions, and conventions.
2. Set capability flags by scanning source files:
   - `{has_apis}` — route/controller definitions, OpenAPI/Swagger specs present
   - `{has_events}` — Kafka / RabbitMQ / SNS-SQS / Redis pub-sub / NATS patterns
   - `{has_external_deps}` — outbound HTTP clients, SDKs, service URLs, database connections
   - `{has_frontend}` — call the shared `detectProjectType` module; set `true` when result.type is `frontend`, `fullstack`, or `mobile`
3. Classify infrastructure markers across six categories (Terraform, Docker, Helm, Kubernetes, Pulumi, CloudFormation) to set `{has_infra}`.
4. Detect framework imports (Express, Spring Boot, Django, FastAPI, Angular, React, Next.js, NestJS, Flask, Gin, Fiber) to set `{has_app_code}`.
5. Apply the classification decision tree to set `{project_type}`:
   - `has_infra` + `has_app_code` → `platform`
   - `has_infra` + no `has_app_code` → `infrastructure`
   - no `has_infra` → `application` (default)
6. Generate the brownfield assessment artifact by reading the assessment template, capturing component inventory, technical debt, migration constraints, coexistence strategy, and adoption path. Include `{project_type}` in the output. Write to `docs/planning-artifacts/brownfield-assessment.md`.
7. Write the enhanced project documentation — all standard sections plus detected capability flags, `{project_type}`, testing infrastructure summary, and CI/CD pipeline summary. Write to `docs/planning-artifacts/project-documentation.md`.

Checkpoint after Phase 1 via `!${CLAUDE_PLUGIN_ROOT}/scripts/checkpoint.sh`.

## Phase 2 — Parallel Documentation Subagents

Spawn the following subagents in parallel (single message, multiple `Agent` tool calls). Only spawn subagents for detected capabilities:

- **If `{has_apis}`** — API Documenter subagent. Scan for routes, controllers, and specs. Validate existing OpenAPI specs against routes or generate a new OpenAPI 3.x spec from code. Document all endpoints with method, path, handler, auth, parameters, request/response schemas, error formats. Include a Mermaid API flow diagram. List undocumented endpoints as gaps. Output to `docs/planning-artifacts/api-documentation.md`.
- **If `{has_frontend}`** — UX Assessor subagent. Scan UI frameworks, components, design patterns, styling. Document UI patterns, navigation structure (Mermaid sitemap), interaction patterns, accessibility (WCAG, ARIA, keyboard nav). Propose improvements for gaps only. Output to `docs/planning-artifacts/ux-design.md`.
- **If `{has_events}`** — Event Cataloger subagent. Scan messaging infrastructure, produced/consumed events with schemas, external events, delivery guarantees (retry, DLQ, idempotency). Include Mermaid event flow diagrams (2–3 key flows). Output to `docs/planning-artifacts/event-catalog.md`.
- **Always** — Dependency Mapper subagent. Document external service dependencies, infrastructure dependencies, key library dependencies (ORM, auth lib — check version currency and CVE risk). Build a Mermaid dependency graph. Document contracts, SLAs, fallback strategies. Identify dependency risks. Output to `docs/planning-artifacts/dependency-map.md`. After writing, run the shared `review-dependency-audit` task to generate a dependency audit report at `docs/test-artifacts/dependency-audit-{date}.md`.

**Post-subagent validation:** verify each expected output file exists. If any subagent failed to write its output file, the orchestrator (this skill) MUST write a stub file on the subagent's behalf using the paths declared in the legacy `output.artifacts` contract. Dependency-audit goes to `docs/test-artifacts/`; all other Phase 2 artifacts go to `docs/planning-artifacts/`. Do NOT use hardcoded paths.

After all subagents return, write a subagent summary at `docs/planning-artifacts/brownfield-subagent-summary.md` (which subagents ran, artifacts produced, file paths, any errors). Pause for user review in `normal` mode before continuing.

## Phase 3 — Deep Analysis Multi-Scan Subagents (Infra-Aware)

Spawn seven scan subagents in parallel. These run alongside Phase 2 documentation to detect gaps that structural analysis misses. Each scanner receives `{tech_stack}`, `{project-path}`, and `{project_type}` as context. When `{project_type}` is `infrastructure` or `platform`, infra-specific detection patterns are applied alongside application patterns; for `application`, only application patterns run.

### Doc-Code Scan

Read the doc-vs-code scan prompt template from the bundled knowledge. Scan the project for mismatches between documentation and code — stale claims, missing endpoints in docs, config values that differ from the documented defaults. Output gap entries to `docs/planning-artifacts/brownfield-scan-doc-code.md` using the standardized gap-entry schema. Contradictory signals between docs and code produce gap rows tagged with evidence_file and evidence_line.

### Hardcoded Values Scan

Scan for hard-coded logic, magic numbers, embedded literals that should be configuration. For `infrastructure` / `platform` projects, also detect hard-coded IPs, magic ports, embedded secrets / AMI IDs, and hard-coded resource limits in IaC files. Output to `docs/planning-artifacts/brownfield-scan-hardcoded.md`.

### Integration Seam Scan

Scan for integration seams between modules, services, and external systems — contracts, shared state, coupling patterns. For `infrastructure` / `platform`, also map service mesh topology, ingress / egress routes, and cross-namespace dependencies. Output to `docs/planning-artifacts/brownfield-scan-integration-seam.md`.

### Runtime Behavior Scan

Catalog runtime behavior: `@Scheduled`, Quartz, startup hooks, background threads, health checks. For `infrastructure` / `platform`, also catalog CronJobs, DaemonSets, init containers, sidecar patterns, health probes. Output to `docs/planning-artifacts/brownfield-scan-runtime-behavior.md`.

### Security Scan

Audit security posture: mutating endpoints, IDOR candidates, authorization gaps, missing CSRF. For `infrastructure` / `platform`, also detect exposed ports in k8s manifests, permissive ingress rules, overly broad RBAC bindings, missing NetworkPolicy. Output to `docs/planning-artifacts/brownfield-scan-security.md`.

### Config Contradiction Scan (infra-aware)

Detect contradictions between configuration files (e.g., different service limits in `values.yaml` vs `deployment.yaml`). For `infrastructure` / `platform`, apply patterns for `terraform.tfvars`, `values.yaml`, and kustomize overlays. Output to `docs/planning-artifacts/brownfield-scan-config-contradiction.md`.

### Dead Code & Dead State Scan

Identify unused modules, orphaned routes, dead migrations, unused feature flags. Output to `docs/planning-artifacts/brownfield-scan-dead-code.md`.

**Partial-failure semantics (AC-EC8):** If a scanner crashes mid-run, the other scanners continue. The failed scan writes a gap row tagged `scan failed: {reason}`. The overall skill exits non-zero with a partial-result summary listing which scanners succeeded, which failed, and what recoverable evidence is available. The remaining scanners continue — one failure does not block the cohort.

## Phase 4 — Test Execution During Discovery

After Phases 2 / 3 scans complete, execute the existing test suite at the project path to capture test failures as gap entries. **This step is non-blocking** — test execution failures must not halt the overall brownfield onboarding workflow.

Spawn a Test Execution Scanner subagent:

- Auto-detect test runners (package.json with `test` script, pytest, Maven, Gradle, Go, Flutter) in priority order.
- Execute each detected runner with a 5-minute timeout.
- Parse test output for metrics (total, passing, failing, skipped).
- Convert failing tests to gap entries with severity mapped by test type (unit → medium, integration → high, e2e → critical).
- Detect infrastructure errors (ECONNREFUSED, missing env vars) and log as warning gaps rather than test-failure gaps.
- For monorepo / polyglot projects, execute all detected runners sequentially and aggregate results.
- Truncate output per NFR-024 token budget if needed.
- If no test suite is detected, log an info-level gap entry `GAP-TEST-INFO-001`.

Output to `docs/planning-artifacts/brownfield-scan-test-execution.md`. If the subagent fails to write its output file, log a warning and continue.

## Phase 5 — Auto-Generate test-environment.yaml from Detected Infrastructure

This phase aggregates the four brownfield test-infrastructure detectors (E19-S12 test-runner, E19-S13 ci-test, E19-S14 docker-test, E19-S15 browser-matrix) into a single `docs/test-artifacts/test-environment.yaml` file compatible with the E17-S7 schema.

1. Invoke the four detectors at the project path and collect results into a single detections object. Each detector runs best-effort: wrap each call in try/catch; record `null` on failure so one crash cannot block the cohort.
2. Call `hasDetectedInfrastructure(detections)`. If it returns `false`, log `No test infrastructure detected — skipping test-environment.yaml generation (AC6 gate is also skipped)` and proceed. This keeps **greenfield-ish projects with zero test infrastructure** (AC-EC3) from being blocked by a gate they cannot satisfy — the conditional `test_environment_yaml_required_when_infra_detected` gate is NOT triggered in that case.
3. Otherwise, call `generateTestEnvironmentYaml(detections)` to build the document with the six story-required metadata fields: `test_runner`, `ci_provider`, `docker_test_config`, `browser_matrix`, `generated_by: brownfield`, `generated_date` — alongside the E17-S7 schema-required `version` and `runners` fields.
4. Resolve the target path as `docs/test-artifacts/test-environment.yaml`. Check whether the file already exists.
5. **Conflict resolution:**
   - File does not exist → call `writeTestEnvironmentYaml(targetPath, doc, "merge")` (merge mode is a no-op for fresh writes). Log `Created test-environment.yaml from detected infrastructure.`
   - File exists AND execution mode is `yolo` → always use the safe default: merge. Detected values fill only null or missing fields; every non-null user-supplied field is preserved byte-for-byte. Log `Merged detected values into existing test-environment.yaml (YOLO safe default).`
   - File exists AND execution mode is not `yolo` → prompt the user `test-environment.yaml already exists — [m]erge detected values (safe, default) / [s]kip (leave file unchanged) / [o]verwrite (REPLACE entire file — destructive)`. Wait for the user to choose one of the three options.
6. **If the write fails (AC-EC4)** — e.g., test-infrastructure detected but the emitter cannot write to disk — halt with the actionable remediation `Re-run step 2.8 or run /gaia-brownfield again` preserving legacy gate semantics.
7. After writing, validate the file against the E17-S7 schema via `validateTestEnvironment(readFileSync(targetPath, 'utf8'))`. Log any schema warnings as WARN-level messages listing the specific failing field; continue — the file is written but the user is notified. Never halt the overall workflow on schema warnings.
8. Record the detection results and chosen conflict-resolution action in the brownfield onboarding report for traceability.

## Phase 6 — NFR Assessment & Performance Test Plan

Invoke the `test-architect` subagent (Sable) via the `Agent` tool:

- Analyze the codebase for non-functional requirements across code quality (linting, complexity, duplication), security posture (dependency vulnerabilities, secrets handling, auth quality), performance (bundle size for frontend, query patterns, caching, resource management), accessibility (ARIA, semantic HTML, keyboard nav for frontend), test coverage (framework, count, coverage %, untested areas, quality), and CI/CD (pipeline, deploy strategy, environments, IaC).
- Create an NFR Baseline Summary Table with measured values (not placeholders).
- Output the NFR assessment to `docs/test-artifacts/nfr-assessment.md`.
- Generate a performance test plan: load k6 patterns; if frontend, also load Lighthouse-CI patterns. Define performance budgets (P50/P95/P99), load test scenarios (gradual, spike, soak), backend profiling targets (slow queries, N+1, connection pools), CI performance gates. If frontend, define Core Web Vitals targets (LCP < 2.5s, INP < 200ms, CLS < 0.1).
- Output the performance test plan to `docs/test-artifacts/performance-test-plan-{date}.md`.

**AC-EC5 fallback — test-architect unavailable:** If the `test-architect` subagent is not installed or unreachable at runtime, log a non-blocking warning and write a stub `nfr-assessment.md` with a clear banner:

```
> WARNING: test-architect subagent (Sable) unavailable at runtime.
> This is a stub file emitted by gaia-brownfield to satisfy the
> post-complete nfr_assessment_exists gate. Re-run /gaia-nfr after
> installing the test-architect agent to populate real content.
```

The post-complete gate then reports the gap rather than crashing. Also write a stub `performance-test-plan-{date}.md` with the same banner and re-run instruction.

**AC-EC9 — both outputs required:** The legacy gate requires BOTH `nfr-assessment.md` AND `performance-test-plan-{date}.md`. If the subagent completes but emits only one of the two, the orchestrator MUST write the second (at minimum as a stub) so both exist before the post-complete gate fires. Missing either one halts the skill at the gate with the same error text as the legacy workflow: `HALT: NFR assessment not found at {test_artifacts}/nfr-assessment.md.` or `HALT: Performance test plan not found at {test_artifacts}/. Run /gaia-perf-testing.` Both files are required for pass.

**Gate check after Phase 6:** Invoke the shared validate-gate pathway inline — see the Post-Complete Gates section at the end of this skill for the three gates enforced via `!${CLAUDE_PLUGIN_ROOT}/scripts/validate-gate.sh`.

## Phase 7 — Gap Consolidation & Deduplication

Spawn a Gap Consolidation subagent:

**Step 1 — Load all scan outputs.** Load gap entries from all of the following sources. If a file is empty or missing, log a warning noting which scanner produced no results and continue.

- Deep analysis scans (7 files from Phase 3): config-contradiction, dead-code, hardcoded, security, runtime-behavior, doc-code, integration-seam.
- Test execution scan (1 file from Phase 4): brownfield-scan-test-execution.md.
- Phase 2 documentation outputs (4 files): api-documentation.md (API gaps), event-catalog.md (messaging gaps), ux-design.md (frontend/UX gaps), dependency-map.md (dependency gaps).
- Phase 6 NFR: nfr-assessment.md (NFR gap findings).

**Step 2 — Validate entries against schema.** Required fields: `id`, `category`, `severity`, `title`, `description` (or `evidence`), `evidence_file`, `evidence_line`, `recommendation`. Entries missing required fields are logged as warnings (noting source file and missing field) and skipped from consolidation.

**Step 3 — Deduplicate.** Group gap entries by `evidence_file` + `evidence_line` exact match. For each group:
- Retain the entry with the highest severity (critical > high > medium > low).
- Merge recommendations from all duplicate entries into the retained entry.
- Add a `merged_from` field listing all original gap IDs.
- If duplicates have different categories, retain the primary category from the highest-severity entry and note the alternate category in the description.

**Step 4 — Rank.** Sort by severity DESC, then confidence DESC, then category alphabetical. Assign sequential numbering.

**Step 5 — Budget check.** Estimate token count (~100 tokens per gap entry). If the total exceeds the 40K token budget, truncate low-severity and info entries with a count summary `N additional low/info gaps omitted for budget`. Stay within budget (AC-EC6).

**Step 6 — Generate consolidated output.** Write `docs/planning-artifacts/consolidated-gaps.md` with summary statistics at the top:
- Total raw gaps (pre-dedup count)
- Duplicates removed
- Final unique count
- Breakdown by category
- Breakdown by severity
- Per-scanner source counts

## Phase 8 — PRD + Adversarial Review + Code-Verified Review

### 8a — Create PRD for Gaps

Select the PRD template based on `{project_type}`:

| project_type     | Template File              | Requirement ID Scheme                        |
|------------------|----------------------------|----------------------------------------------|
| application      | prd-template.md            | FR-###, NFR-###                              |
| infrastructure   | infra-prd-template.md      | IR-###, OR-###, SR-###                       |
| platform         | platform-prd-template.md   | FR-###, NFR-### and IR-###, OR-###, SR-###   |

Verify the template file exists. If missing, halt with `Template {selected_template} not found. Ensure E12-S2 (infra) or E12-S3 (platform) templates are installed.` If `{project_type}` is unrecognized, default to `application`.

Read upstream artifacts to inform gap analysis:
- `project-documentation.md` → project context (tech stack, patterns, conventions, capability flags, CI/CD).
- `consolidated-gaps.md` → primary input (deduplicated, ranked, code-verified gap list). If a `## Verification Corrections for PRD` section exists (from Phase 8c), apply its corrections.
- `nfr-assessment.md` → NFR "Current Baseline" and "Target" columns with real values.
- `api-documentation.md` (if exists) → API gaps.
- `event-catalog.md` (if exists) → messaging gaps.
- `dependency-map.md` → dependency risks.
- `dependency-audit-{date}.md` → critical / high findings.
- `ux-design.md` (if exists) → UX gaps.

Generate the PRD in brownfield mode — every section filled with gap-focused content only. Overview = existing project summary + what gaps this PRD addresses. Goals = gap closure goals only. Non-Goals = existing features that will NOT be re-implemented. User Stories = gap stories only. Functional Requirements = gap requirements organized by priority. NFRs = NFR gaps with baseline and target from the NFR assessment.

If `prd.md` already exists, warn the user: `A PRD already exists. Continuing will overwrite it with brownfield gap content. Choose: (a) overwrite, (b) save as prd-brownfield-gaps.md instead.` If the user chooses (b), adjust the output path.

YAML frontmatter MUST include `mode: brownfield`, `baseline_version: {version from package.json or inferred}`, `focus: gap-filling`. Add `Mode: Brownfield — gaps only` to the header. Include a Priority Matrix section mapping each gap to priority / effort / impact.

Write to `docs/planning-artifacts/prd.md`.

### 8b — Adversarial Review & PRD Refinement

Spawn a subagent that runs the shared adversarial-review task against the PRD. Target `docs/planning-artifacts/prd.md`; target label `prd`. When the subagent returns, verify `adversarial-review-prd-{date}.md` exists in `docs/planning-artifacts/`. Extract critical and high severity findings. For each critical/high finding, add a new requirement or refine an existing requirement in the PRD. Add a `## Review Findings Incorporated` section to the PRD listing each finding, its severity, and how it was addressed.

### 8c — Code-Verified Review

Spawn a Code-Verified Review subagent to verify every factual claim in the consolidated gap entries against the actual codebase.

**Step 1 — Load and parse `consolidated-gaps.md`.** Parse all YAML gap entries. If empty or zero parseable entries, exit gracefully with `0 gaps to verify`. For malformed entries missing required fields, log a warning, skip, and include in the summary as skipped.

**Step 2 — Extract verifiable claims.** For each valid entry: file existence (`evidence_file`), line range (`evidence_line` within file's total line count), pattern / string presence from `description` and `recommendation`, config key existence (for `configuration` category gaps). Entries with no verifiable claims → classify as `unverifiable`.

**Step 3 — Verify each claim against the codebase** using `Grep`, `Glob`, `Read` (not shell commands). For each claim:
- File existence: glob/read the path. Missing file → classify gap as `contradicted` with reason `Referenced file not found: {evidence_file}`. Preserve original gap with downgraded confidence.
- Binary files (extensions `.png`, `.jpg`, `.gif`, `.woff`, `.ttf`, `.ico`, `.pdf`, `.zip`, `.tar`, `.gz`, `.exe`, `.dll`, `.so`, `.dylib`) → classify as `unverifiable` with reason `Binary file — cannot verify textual claims`.
- Line range: total line count vs `evidence_line`. Out of range → `contradicted` with reason `Line {evidence_line} exceeds file length ({actual_lines} lines)`.
- Pattern search: use grep with escaped regex special characters. Pattern found → confirmed. Pattern not found → contributes to `contradicted`.
- Config key: parse YAML/JSON and check for key existence at stated paths.

**Step 4 — Apply tristate classification.** `verified` (all claims confirmed), `unverifiable` (cannot be confirmed from code alone — runtime behavior, subjective assessments, binary files), `contradicted` (evidence directly contradicts one or more claims). For contradicted gaps, downgrade confidence, attach a `reason` string, and generate a new entry `GAP-VERIFIED-{seq}` with `verified_by: code-verified` and the actual state found.

**Step 5 — Update `consolidated-gaps.md`.** Add `verification_status` and `verified_by: code-verified` to each entry. Preserve all existing fields — do not remove or overwrite original data. Append new entries from contradicted claims at the end.

**Step 6 — Verification summary.** Include total processed, verified, unverifiable, contradicted, new entries from contradictions, and skipped (malformed) counts.

**Step 7 — Feedback to Step 8a.** Write contradicted claims and reasons to a section `## Verification Corrections for PRD` at the top of `consolidated-gaps.md`. When the PRD is regenerated, this section corrects factual errors.

## Phase 9 — Architecture + Ground-Truth Bootstrap

### 9a — Architecture

The architecture is generated by invoking the shared `create-architecture` pipeline via a subagent in YOLO mode. The `create-architecture` pipeline auto-detects brownfield mode from the PRD `Mode: Brownfield` header set in Phase 8a.

If `architecture.md` already exists, warn the user: `An architecture document already exists. Continuing will overwrite it with the brownfield version. Choose: (a) overwrite, (b) save as architecture-brownfield.md instead.` If the user chooses (b), instruct the subagent to output to `architecture-brownfield.md`.

After architecture is generated, verify it has YAML frontmatter with `mode: brownfield`, `baseline_version: {version}`, and `update_scope: [list of components being modified]`. If missing, append them.

### 9b — Bootstrap Val Ground Truth (optional)

Check if Val is installed: `plugins/gaia/agents/validator.md` exists AND `.validator-sidecar/` directory is present. If not installed, skip this phase silently — brownfield onboarding continues without ground-truth bootstrap.

Ask: `Step 7: Bootstrap Val ground truth from brownfield assessment? [y/n]`

If yes: invoke `/gaia-refresh-ground-truth` (if the skill exists) to scan the filesystem and populate framework inventory facts. Load the `brownfield-extraction` section of `ground-truth-management` JIT. Read available brownfield artifacts and extract project-specific facts:
- `brownfield-assessment.md` → tech stack, dependencies, file counts, project structure
- `project-documentation.md` → architecture patterns, conventions, config values
- `nfr-assessment.md` (if present) → performance targets, security requirements

Write extracted facts to `_memory/validator-sidecar/ground-truth.md`. If the file already exists with content, merge — add new facts, update changed facts, flag removed facts. Never destructive overwrite.

### 9c — Tier 1 Agent Ground Truth (optional)

Ask: `Bootstrap Tier 1 agent ground truth (Theo, Derek, Nate)? [y/n]`

If yes:

- **Theo (Architect)** — Read `architecture.md` (fall back to `brownfield-assessment.md`). Extract tech stack (→ variable-inventory), ADRs (→ structural-pattern), component inventory (→ file-inventory), dependency map (→ cross-reference). Token budget: 150K; trim at 60% threshold (90K). Write to `_memory/architect-sidecar/ground-truth.md`.
- **Derek (Product Manager)** — Read `prd.md` (fall back to `prd-brownfield-gaps.md`). Extract functional requirements, user stories, acceptance criteria summaries. Also read `epics-and-stories.md` for epic overviews and story-to-epic mappings. Also read `nfr-assessment.md` for quality baselines. Token budget: 100K; trim at 60% threshold (60K). Write to `_memory/pm-sidecar/ground-truth.md`.
- **Nate (Scrum Master)** — Read `sprint-status.yaml` (if exists) for sprint state. Read `_memory/sm-sidecar/velocity-data.md` (if exists) for velocity and capacity. If neither exists, log `insufficient sprint data, velocity unavailable` and write ground-truth.md omitting velocity. Token budget: 100K; trim at 60% threshold (60K). Write to `_memory/sm-sidecar/ground-truth.md`.

After all Tier 1 extractions complete, output a summary: `Seeded {N} entries for Theo, {M} entries for Derek, {K} entries for Nate`. If sprint data was absent, append `(sprint data absent — velocity entries omitted)`. Include token budget status (GREEN/YELLOW/RED) per agent.

## Output — Primary Artifact

Write the final brownfield onboarding report to `docs/planning-artifacts/brownfield-onboarding.md`. This is the primary output artifact (preserved verbatim from the legacy workflow's `output.primary` contract for NFR-053 parity). It summarizes:

- Project discovery findings (`{project_type}`, capability flags, tech stack)
- Links to all generated secondary artifacts
- Consolidated gap summary (counts by severity / category)
- NFR baseline summary
- Test-environment generation outcome (created / merged / skipped / not-applicable)
- Next-step recommendations (remaining Phase 3 chain)

## Output — Secondary Artifacts

The full artifact set emitted by this skill (preserved from the legacy `output.artifacts` contract):

- `docs/planning-artifacts/project-documentation.md` (Phase 1)
- `docs/planning-artifacts/api-documentation.md` (Phase 2, if `{has_apis}`)
- `docs/planning-artifacts/ux-design.md` (Phase 2, if `{has_frontend}`)
- `docs/planning-artifacts/event-catalog.md` (Phase 2, if `{has_events}`)
- `docs/planning-artifacts/dependency-map.md` (Phase 2)
- `docs/test-artifacts/dependency-audit-{date}.md` (Phase 2)
- `docs/planning-artifacts/brownfield-subagent-summary.md` (Phase 2)
- `docs/planning-artifacts/brownfield-scan-doc-code.md` (Phase 3)
- `docs/planning-artifacts/brownfield-scan-hardcoded.md` (Phase 3)
- `docs/planning-artifacts/brownfield-scan-integration-seam.md` (Phase 3)
- `docs/planning-artifacts/brownfield-scan-runtime-behavior.md` (Phase 3)
- `docs/planning-artifacts/brownfield-scan-security.md` (Phase 3)
- `docs/planning-artifacts/brownfield-scan-config-contradiction.md` (Phase 3)
- `docs/planning-artifacts/brownfield-scan-dead-code.md` (Phase 3)
- `docs/planning-artifacts/brownfield-scan-test-execution.md` (Phase 4)
- `docs/test-artifacts/test-environment.yaml` (Phase 5, conditional)
- `docs/test-artifacts/nfr-assessment.md` (Phase 6 — gated)
- `docs/test-artifacts/performance-test-plan-{date}.md` (Phase 6 — gated)
- `docs/planning-artifacts/consolidated-gaps.md` (Phase 7)
- `docs/planning-artifacts/prd.md` (Phase 8a)
- `docs/planning-artifacts/adversarial-review-prd-{date}.md` (Phase 8b)
- `docs/planning-artifacts/architecture.md` (Phase 9a)
- `docs/planning-artifacts/epics-and-stories.md` (downstream, via next-step chain — see below)
- `docs/planning-artifacts/brownfield-onboarding.md` (primary)

The `{date}` placeholder is substituted with the current date in `YYYY-MM-DD` form at write time, preserving the legacy substitution pattern.

## Post-Complete Gates

Three gates enforced via `!${CLAUDE_PLUGIN_ROOT}/scripts/validate-gate.sh` after all phases complete:

1. **`nfr_assessment_exists`** — checks `docs/test-artifacts/nfr-assessment.md` exists. On fail: `HALT: NFR assessment not found at {test_artifacts}/nfr-assessment.md.`
2. **`performance_test_plan_exists`** — checks a `docs/test-artifacts/performance-test-plan-*.md` file exists. On fail: `HALT: Performance test plan not found at {test_artifacts}/. Run /gaia-perf-testing.`
3. **`test_environment_yaml_required_when_infra_detected`** (conditional) — if any of the four test-infrastructure detectors (E19-S12 / S13 / S14 / S15) fired during Phase 5, then `docs/test-artifacts/test-environment.yaml` MUST exist. On fail: `HALT: Brownfield detected test infrastructure but test-environment.yaml was not generated. Re-run step 2.8 or run /gaia-brownfield again.` When zero test infrastructure was detected (AC-EC3), this gate is NOT triggered — the conditional gate stays silent for greenfield-ish projects.

`validate-gate.sh` serves the role of the spec-level `file-gate.sh` in the deployed script set (see Reconciliation Note).

## Failure Semantics

- **Scanner crash mid-run (AC-EC8):** Remaining scanners continue. The failed scan writes a gap row tagged `scan failed: {reason}`. Skill exits non-zero with a partial-result summary.
- **Test-architect subagent unavailable (AC-EC5):** Log a non-blocking warning. Write stub `nfr-assessment.md` and stub `performance-test-plan-{date}.md` with `agent unavailable` banners. Post-complete gate reports the gap rather than crashing.
- **NFR output missing (AC-EC9):** Both `nfr-assessment.md` and `performance-test-plan-{date}.md` are required by the post-complete gates. Missing either one halts with the legacy error text — both required for pass.
- **Foundation script missing (AC-EC2):** `setup.sh` aborts fail-fast with an actionable error identifying the missing / non-executable script path. No partial scan output is written.
- **Large codebase (AC-EC6):** Scanners stream / chunk results, emit incremental gap rows, and produce a `scan truncated — review manually` advisory rather than exceeding the NFR-048 activation token budget.

## Frontmatter Linter Compliance

This SKILL.md passes the E28-S7 / E28-S74 frontmatter linter (`.github/scripts/lint-skill-frontmatter.sh`) with zero errors. Required fields are present: `name` matches the directory slug `gaia-brownfield`; `description` is a trigger-signature with a concrete action phrase; `allowed-tools` is validated against the canonical tool set (`Agent` is required because Phase 2, 3, 4, 6, 7, 8, and 9 delegate to subagents via the `Agent` tool); `model: inherit` is set per E28-S74 schema.

If a future edit removes the `description` field or any other required field, the frontmatter linter reports the missing field and the CI gate fails — no silent skill registration is permitted (AC-EC4 equivalent for the legacy conditional test-environment gate is covered by the conditional gate wiring above).

## Parity Notes vs. Legacy Workflow

The native skill preserves the legacy 7-step structure as 9 native phases (Steps 2.5, 2.75, 2.8, 3, 3.5, 4, 5, 5.5, 6, 7 of the legacy `instructions.xml` map to Phases 1–9 here). Data flow between phases is identical to the legacy workflow — each phase's output feeds the next via the documented input contracts. The skill does not re-implement the workflow engine; it uses native Claude Code primitives (Skills + Subagents + inline scripts) per ADR-041.

Legacy file paths are intentionally not re-referenced in this body per the E28-S105 parity check (the reference pointer lives only in the References section below). This matches the E28-S102 / E28-S103 precedent.

## Finalize

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-brownfield/scripts/finalize.sh

## References

- ADR-041 — Native Execution Model via Claude Code Skills + Subagents + Plugins + Hooks (replaces the legacy workflow engine).
- ADR-042 — Scripts-over-LLM for Deterministic Operations (foundation script set invoked inline via `!scripts/*.sh`).
- FR-323 — Native Skill Format Compliance (frontmatter schema per E28-S74).
- FR-325 — Foundation scripts wired inline.
- NFR-048 — Conversion token-reduction target / activation-budget ceiling.
- NFR-053 — Functional parity with the legacy workflow.
- E28-S74 — Canonical SKILL.md frontmatter schema.
- E28-S88 — `gaia-nfr` SKILL.md (pattern for the test-architect subagent integration mirrored here in Phase 6).
- E28-S9..E28-S16 — Foundation scripts implementation stories (deployed equivalents referenced in the Reconciliation Note).
- E19-S12 / S13 / S14 / S15 — Test infrastructure detectors aggregated in Phase 5.
- Reference implementations (parity pattern and Cluster 14 sibling skills):
  - `plugins/gaia/skills/gaia-nfr/SKILL.md` — test-architect subagent pattern (Phase 6 mirrors this).
  - `plugins/gaia/skills/gaia-creative-sprint/SKILL.md` — sequential multi-subagent orchestration pattern.
- Legacy parity source (for reference only; not invoked from this skill; legacy path intentionally omitted from the body to satisfy the "zero legacy references" parity check — see E28-S105 test scenario 5).
