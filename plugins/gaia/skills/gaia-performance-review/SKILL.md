---
name: gaia-performance-review
description: Run anytime performance bottleneck analysis on a story — N+1 queries, memory/bundle impact, caching, and algorithmic complexity. Emits a machine-readable PASSED/FAILED verdict and updates the Review Gate. Use when "performance review" or /gaia-performance-review.
argument-hint: "[story-key]"
tools: Read, Write, Edit, Bash, Grep
---

> **Scope note — two perf skills exist.** This skill (`gaia-performance-review`) is the **anytime bottleneck analysis** covering N+1 queries, memory/bundle impact, caching strategy, and algorithmic complexity on a story-scoped basis. For the **PR-gate performance check** invoked by the Review Gate orchestrator, see `gaia-review-perf` (Cluster 9 / E28-S71). The two skills coexist deliberately — `gaia-review-perf` runs in fork context with a read-only tool allowlist and dispatches to the Juno subagent; `gaia-performance-review` (this skill) runs in main context and produces the full bottleneck report.

## Setup

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-performance-review/scripts/setup.sh

## Mission

You are performing an **anytime performance bottleneck analysis** for a story. The story is resolved by `{story_key}` via the canonical glob `{story_key}-*.md` in `docs/implementation-artifacts/`. You analyze each performance-relevant changed file for bottlenecks — N+1 queries, memory leaks, algorithmic complexity, bundle size, caching gaps — and produce a machine-readable verdict (PASSED or FAILED) written to both the story's Review Gate "Performance Review" row (via `review-gate.sh`) and a per-story report file.

This skill is the native Claude Code conversion of the legacy `_gaia/lifecycle/workflows/anytime/performance-review` workflow (brief P14-S4, story E28-S108, Cluster 14). The 9-step instruction body from the legacy `instructions.xml` is preserved in prose — parity confirmed per NFR-053.

**Native execution (ADR-041):** This skill runs under Claude Code's native execution model — no workflow.xml engine, no pre-resolved config chain. Steps are prose; deterministic operations are scripts.

**Scripts-over-LLM (ADR-042 / FR-325):** The auto-pass fast path (file-type classification for performance relevance) is a deterministic operation and is delegated to `skills/gaia-performance-review/scripts/classify-files.sh`. Foundation operations (config resolution, checkpoint writes, lifecycle events) are delegated to `plugins/gaia/scripts/` via inline `!${CLAUDE_PLUGIN_ROOT}/...` calls.

**No memory sidecar reads:** Performance review is per-story and does not consult agent memory. The hybrid memory-loading pattern (ADR-046) is intentionally **not** used in this skill — this SKILL.md does not invoke the foundation loader script at all.

## Critical Rules

- A story key argument MUST be provided. If missing, fail fast with `usage: /gaia-performance-review [story-key]`.
- The story file MUST exist at `docs/implementation-artifacts/{story_key}-*.md`. Use the canonical glob regardless of title slug. If zero matches, fail with `story file not found for key {story_key}`.
- The story MUST be in `review` status. If not, fail with `story must be in review status before performance review`.
- **Auto-pass fast path:** if `classify-files.sh` emits `PASSED (auto)` (zero performance-relevant files changed), the verdict is PASSED with note "No performance-relevant code changes — auto-passed". Skip directly to Step 8 (write report) and Step 9 (update Review Gate). This optimization is not cosmetic — it is what keeps the anytime review fast enough to run across a sprint-review batch.
- **Percentiles, not averages:** when citing performance measurements, use P50/P95/P99 percentiles. Never cite arithmetic means for latency or throughput — percentiles surface tail behavior.
- **Machine-readable verdict:** the report MUST include a line that matches `**Verdict: PASSED**` or `**Verdict: FAILED**` exactly. Downstream tooling (Review Gate orchestrator, dashboards) parses this line.
- **Verdict logic:** NO critical or high severity findings = PASSED. ANY critical or high severity finding = FAILED.
- **Review Gate updates go through `review-gate.sh`** — never edit the story Review Gate table by hand. The script is the canonical atomic writer (E28-S14).
- **Story status is not modified by this skill.** The Review Gate orchestrator (or `/gaia-run-all-reviews`) handles the status transitions on failure.
- **Sprint-status.yaml is NEVER written by this skill** (Sprint-Status Write Safety rule).

## Inputs

- **Positional argument:** `{story_key}` — the story key in canonical `E{epic}-S{n}` form (e.g., `E28-S108`). Required. Passed via `$ARGUMENTS`.

## Steps

### Step 1 — Load Story

- If no story key was provided, fail with: `usage: /gaia-performance-review [story-key]`.
- Resolve the story file using the canonical glob: `docs/implementation-artifacts/{story_key}-*.md`.
- If zero matches, fail with `story file not found for key {story_key} — searched docs/implementation-artifacts/{story_key}-*.md`.
- If multiple matches, fail with `multiple story files matched key {story_key} — resolve ambiguity`.
- Read the resolved story file. Extract the `## File List` section under `Dev Agent Record` into a newline-separated list of changed files. If no File List section exists, treat the changed-file list as empty.

### Step 2 — Status Gate

- Parse the story YAML frontmatter and extract the `status` field.
- If status is not `review`, fail with: `story {story_key} is in '{status}' status — must be in 'review' status before performance review`.

### Step 3 — Auto-Pass Classification

- Write the changed-file list to a temp file.
- Invoke the classifier:
  ```
  !${CLAUDE_PLUGIN_ROOT}/skills/gaia-performance-review/scripts/classify-files.sh --file-list <tmp>
  ```
- Parse the first line of output. If it is `PASSED (auto)`:
  - Set `verdict = PASSED`.
  - Set `auto_pass_note = "No performance-relevant code changes — auto-passed"`.
  - Skip Steps 4–7 and jump directly to Step 8 (Generate Output).
- Otherwise (first line is `REVIEW`), continue to Step 4 with the list of performance-relevant files emitted by the classifier.

Classifier rules (enforced by `classify-files.sh`):

- **Performance-relevant:** `.ts .tsx .js .jsx .py .java .go .rb .php .dart .swift .kt .rs .cs .cpp .c .sql` and similar application source-code extensions.
- **Not relevant:** markdown, YAML / JSON / TOML, HTML / CSS / SCSS, static assets (images, SVGs), test files (`*.test.*`, `*.spec.*`, `__tests__/`, `tests/`, `*.bats`), lock files, `.gitignore`, `.editorconfig`.

### Step 4 — N+1 and Database Analysis

For each performance-relevant file, scan for:

- **N+1 query patterns** — loops issuing a query per iteration where a single bulk query would do (per-row fetches inside a `for` / `forEach` loop).
- **Missing indexes** — query predicates on columns that are not indexed (requires reading migration / schema files when present).
- **Unbounded queries** — `SELECT` without `LIMIT`, `findAll` without pagination, query builders missing `.take(n)` / `.limit(n)`.
- **Over-fetching** — `SELECT *` when only a subset of columns is used; joins that pull unrelated tables into the working set.

Measure, don't guess. Where a finding is load-sensitive, cite P50 / P95 / P99 latency numbers if they are available in profiling output or test artifacts. Do not cite averages — averages hide tails.

### Step 5 — Memory and Bundle Analysis

- **Memory leaks** — closures retaining DOM references; event listeners registered without a corresponding `removeEventListener`; subscriptions / timers / intervals not torn down.
- **Large payloads** — response bodies that materialize the full dataset client-side; server-to-server payloads that serialize the entire entity graph.
- **Bundle size impact** — large transitive imports (`lodash` vs. `lodash-es`, whole-library imports), images shipped client-side without compression or responsive `srcset`.
- **Render blocking** — synchronous hydration paths that block the main thread; long tasks > 50 ms; unnecessary re-renders on parent state change without memoization.

### Step 6 — Caching and Algorithmic Complexity Review

- **Caching strategy** — what is cached, what should be, and how cache invalidation is triggered. Flag TTL-less caches and missing cache-busting on write paths.
- **Blocking operations** — synchronous I/O on hot paths; long-running synchronous computations inside request handlers.
- **Algorithmic complexity** — flag O(n²) or worse on hot paths (double-nested iteration over `N`-sized collections; quadratic membership checks like `indexOf` inside a loop).

### Step 7 — Verdict

- Aggregate findings by severity:
  - **Critical** — must fix before merge (N+1 in hot path, memory leak, O(n²) on a hot path, unbounded query).
  - **High** — should fix before merge (missing caching, blocking operation, material bundle-size bloat).
  - **Medium** — recommended improvement.
  - **Low** — minor suggestion.
- Map severity to verdict:
  - NO critical or high findings → `verdict = PASSED`.
  - ANY critical or high finding → `verdict = FAILED` — list each blocking finding with file, line, and recommendation.

### Step 8 — Generate Output

Write the report to `docs/implementation-artifacts/{story_key}-performance-review.md`. Required sections:

- **Story:** key + title.
- **Auto-Pass Classification** (if triggered): `No performance-relevant code changes — auto-passed`.
- **Files Reviewed:** list of performance-relevant files analyzed.
- **N+1 and Database Analysis** — findings, empty block if none.
- **Memory and Bundle Analysis** — findings, empty block if none.
- **Caching and Complexity Review** — findings, empty block if none.
- **Findings by Severity** — sorted tables: Critical, High, Medium, Low.
- **Machine-readable verdict line** — exactly `**Verdict: PASSED**` or `**Verdict: FAILED**` on its own line. This is the single source of truth for Review Gate parsing.

### Step 9 — Update Review Gate

- Invoke the shared atomic writer:
  ```
  !${CLAUDE_PLUGIN_ROOT}/scripts/review-gate.sh update --story "{story_key}" --gate "Performance Review" --verdict "{PASSED|FAILED}"
  ```
- Confirm exit code 0.
- Report the final status to the user. Include the full path to the report file.
- Note: `sprint-status.yaml` may now be out of sync. Run `/gaia-sprint-status` to reconcile.

## Finalize

!${CLAUDE_PLUGIN_ROOT}/skills/gaia-performance-review/scripts/finalize.sh

## References

- **E28-S108 / P14-S4** — this conversion story (Cluster 14).
- **E28-S71** — `gaia-review-perf` (PR-gate, Cluster 9) — the sibling skill this one is disambiguated from.
- **E28-S14** — `review-gate.sh` atomic Review Gate writer.
- **ADR-041** — Native Execution Model via Claude Code Skills + Subagents + Plugins + Hooks.
- **ADR-042** — Scripts-over-LLM for deterministic operations (drives the `classify-files.sh` fast path).
- **ADR-048** — Engine Deletion as Program-Closing Action (legacy `_gaia/lifecycle/workflows/anytime/performance-review/` remains in place until Cluster 18/19 cleanup).
- **NFR-048** — Framework context budget (40K tokens per activation).
- **NFR-053** — Functional parity across native conversions.
- **Legacy source:** `_gaia/lifecycle/workflows/anytime/performance-review/instructions.xml` (9 steps ported above).
