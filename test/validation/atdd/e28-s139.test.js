// E28-S139 — Token-reduction measurement suite (Cluster 19, NFR-048)
//
// ATDD contract test. These tests validate the artifacts, fixtures, and
// driver-behavior contract declared by AC1–AC5 and AC-EC1–AC-EC8 of
// docs/test-artifacts/atdd-E28-S139.md.
//
// In RED phase, every test fails because no artifact exists yet. In GREEN
// phase, after the driver harness, fixtures, methodology document, and
// results table are produced, every test passes.
//
// Framework: vitest (per ATDD). This repo does not yet have vitest installed
// as a root dependency, so the file is also structured so the bats-equivalent
// at tests/cluster-19-e2e/token-reduction.bats can shell-out the same
// structural assertions. See that file for the CI-executed counterpart.

import { describe, it, expect } from "vitest";
import { readFileSync, existsSync, statSync } from "fs";
import { join, resolve } from "path";
import { createHash } from "crypto";

const PROJECT_ROOT = resolve(import.meta.dirname, "../../..");

// Repo layout paths (per story Technical Notes)
const DRIVER_DIR = join(PROJECT_ROOT, "plugins", "gaia", "test", "scripts", "token-reduction");
const TOKENIZER_PIN = join(DRIVER_DIR, "tokenizer.version");
const FIXTURES_DIR = join(PROJECT_ROOT, "plugins", "gaia", "test", "fixtures", "parity-baseline", "token-budget");

// Artifact paths (per story Technical Notes) — docs/ lives at the GAIA-Framework root, not {project-path}
const REPO_ROOT = resolve(PROJECT_ROOT, "..");
const CLUSTER_19_DIR = join(REPO_ROOT, "docs", "test-artifacts", "cluster-19");
const TOKEN_BUDGET_DIR = join(CLUSTER_19_DIR, "token-budget");
const METHODOLOGY = join(CLUSTER_19_DIR, "token-reduction-methodology.md");
const RESULTS = join(CLUSTER_19_DIR, "token-reduction-results.md");
const CLUSTER_19_PLAN = join(REPO_ROOT, "docs", "test-artifacts", "cluster-19-e2e-test-plan.md");
const CHANGELOG = join(PROJECT_ROOT, "CHANGELOG.md");
const TEST_PLAN = join(REPO_ROOT, "docs", "test-artifacts", "test-plan.md");

const WORKFLOWS = [
  "dev-story",
  "create-prd",
  "code-review",
  "sprint-planning",
  "brownfield-onboarding",
];

function loadText(path) {
  if (!existsSync(path)) return null;
  return readFileSync(path, "utf-8");
}

function loadJson(path) {
  const text = loadText(path);
  if (text === null) return null;
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}

function sha256(buf) {
  return createHash("sha256").update(buf).digest("hex");
}

describe("E28-S139: Token-reduction measurement suite (Cluster 19, NFR-048)", () => {
  // ───────── AC1 ─────────
  it("AC1: all 5 workflows have baseline + native prompt captures and token-count.json", () => {
    for (const wf of WORKFLOWS) {
      const baselinePrompt = join(TOKEN_BUDGET_DIR, wf, "baseline.prompt.txt");
      const baselineCount = join(TOKEN_BUDGET_DIR, wf, "baseline.token-count.json");
      const nativePrompt = join(TOKEN_BUDGET_DIR, wf, "native.prompt.txt");
      const nativeCount = join(TOKEN_BUDGET_DIR, wf, "native.token-count.json");

      expect(existsSync(baselinePrompt), `${wf} baseline.prompt.txt missing`).toBe(true);
      expect(existsSync(baselineCount), `${wf} baseline.token-count.json missing`).toBe(true);
      expect(existsSync(nativePrompt), `${wf} native.prompt.txt missing`).toBe(true);
      expect(existsSync(nativeCount), `${wf} native.token-count.json missing`).toBe(true);

      const bc = loadJson(baselineCount);
      const nc = loadJson(nativeCount);
      expect(bc, `${wf} baseline.token-count.json not valid JSON`).not.toBeNull();
      expect(nc, `${wf} native.token-count.json not valid JSON`).not.toBeNull();
      expect(typeof bc.tokens, `${wf} baseline tokens not numeric`).toBe("number");
      expect(typeof nc.tokens, `${wf} native tokens not numeric`).toBe("number");
    }
  });

  // ───────── AC2 ─────────
  it("AC2: token-reduction-methodology.md covers required sections", () => {
    const doc = loadText(METHODOLOGY);
    expect(doc, "methodology document missing").not.toBeNull();
    expect(/tokenizer/i.test(doc)).toBe(true);
    expect(/pin(ned)?\s+version|sha/i.test(doc)).toBe(true);
    expect(/(included|includes).*(system prompt|skills|knowledge)/i.test(doc)).toBe(true);
    expect(/(excluded|excludes).*(response|assistant)/i.test(doc)).toBe(true);
    expect(/determinism|fixed seed|frozen fixture/i.test(doc)).toBe(true);
    expect(/v-parity-baseline/.test(doc)).toBe(true);
    expect(/native plugin|native implementation/i.test(doc)).toBe(true);
    for (const wf of WORKFLOWS) {
      expect(doc.includes(wf), `methodology does not mention ${wf}`).toBe(true);
    }
  });

  // ───────── AC3 ─────────
  it("AC3: token-reduction-results.md contains the required comparison table", () => {
    const doc = loadText(RESULTS);
    expect(doc, "results document missing").not.toBeNull();
    const requiredColumns = [
      "Workflow",
      "Baseline tokens",
      "Native tokens",
      "Delta (tokens)",
      "Reduction %",
      "NFR-048 pass/fail",
      "Stretch (≥55%) pass/warn",
      "Evidence",
    ];
    for (const col of requiredColumns) {
      expect(doc.includes(col), `results table missing column "${col}"`).toBe(true);
    }
    for (const wf of WORKFLOWS) {
      expect(doc.includes(wf), `results table missing row for ${wf}`).toBe(true);
    }
    expect(/-?\d+\.\d%/.test(doc), "no one-decimal percentage found in results").toBe(true);
    expect(/token-budget\/(dev-story|create-prd|code-review|sprint-planning|brownfield-onboarding)\/(baseline|native)\.(prompt|token-count)/.test(doc)).toBe(true);
  });

  // ───────── AC4 ─────────
  it("AC4: aggregate reduction and per-workflow PASS/FAIL gates are computed correctly", () => {
    const doc = loadText(RESULTS);
    expect(doc, "results document missing").not.toBeNull();
    expect(/aggregate reduction/i.test(doc)).toBe(true);
    expect(/overall.*nfr-048.*verdict|overall verdict/i.test(doc)).toBe(true);
    for (const wf of WORKFLOWS) {
      const rowRegex = new RegExp(`\\|\\s*${wf}\\s*\\|[^\\n]*\\|\\s*(PASS|FAIL|N\\/A)[^\\n]*`, "i");
      expect(rowRegex.test(doc), `row for ${wf} has no PASS/FAIL verdict`).toBe(true);
    }
    expect(/55\s*%|≥\s*55/.test(doc)).toBe(true);
  });

  // ───────── AC5 ─────────
  it("AC5: results artifact is published and cross-referenced from cluster-19-e2e-test-plan.md", () => {
    expect(existsSync(RESULTS), "results artifact not published").toBe(true);
    const plan = loadText(CLUSTER_19_PLAN);
    expect(plan, "cluster-19-e2e-test-plan.md missing").not.toBeNull();
    expect(/token.?reduction/i.test(plan)).toBe(true);
    expect(plan.includes("token-reduction-results.md")).toBe(true);

    const testPlan = loadText(TEST_PLAN);
    expect(testPlan, "test-plan.md missing").not.toBeNull();
    for (const ncp of ["NCP-14", "NCP-15", "NCP-16", "NCP-17", "NCP-18", "NCP-19", "NCP-20"]) {
      const marked = new RegExp(`${ncp}[^\\n]*(PASS|FAIL)`).test(testPlan);
      expect(marked, `${ncp} not marked PASS/FAIL in test-plan §11.37.3`).toBe(true);
    }

    const changelog = loadText(CHANGELOG);
    expect(changelog, "CHANGELOG.md missing").not.toBeNull();
    expect(/cluster 19.*token.?reduction/i.test(changelog)).toBe(true);
    expect(/nfr-048.*(pass|fail)/i.test(changelog)).toBe(true);
  });

  // ───────── AC-EC1 ─────────
  it("AC-EC1: driver aborts on tokenizer version mismatch", () => {
    expect(existsSync(TOKENIZER_PIN), "tokenizer.version pin missing").toBe(true);
    const driverEntry = join(DRIVER_DIR, "index.js");
    const src = loadText(driverEntry);
    expect(src, "driver entrypoint missing").not.toBeNull();
    expect(/tokenizer[_-]?sha|tokenizer_version/i.test(src)).toBe(true);
    expect(/(process\.exit\(\s*[1-9])|(throw\s+new\s+Error[^)]*tokenizer)/i.test(src)).toBe(true);
  });

  // ───────── AC-EC2 ─────────
  it("AC-EC2: every token-count.json records cache_control: \"disabled\"", () => {
    for (const wf of WORKFLOWS) {
      for (const run of ["baseline", "native"]) {
        const path = join(TOKEN_BUDGET_DIR, wf, `${run}.token-count.json`);
        const json = loadJson(path);
        expect(json, `${wf}/${run}.token-count.json missing or invalid`).not.toBeNull();
        expect(json.cache_control, `${wf}/${run} cache_control not "disabled"`).toBe("disabled");
      }
    }
  });

  // ───────── AC-EC3 ─────────
  it("AC-EC3: driver-input.txt is byte-identical across baseline and native runs", () => {
    for (const wf of WORKFLOWS) {
      const fixture = join(FIXTURES_DIR, wf, "driver-input.txt");
      expect(existsSync(fixture), `${wf} driver-input.txt fixture missing`).toBe(true);
      const bytes = readFileSync(fixture);
      expect(bytes.length, `${wf} driver-input.txt is empty`).toBeGreaterThan(0);

      const baselineCount = loadJson(join(TOKEN_BUDGET_DIR, wf, "baseline.token-count.json"));
      const nativeCount = loadJson(join(TOKEN_BUDGET_DIR, wf, "native.token-count.json"));
      expect(baselineCount, `${wf} baseline token-count missing`).not.toBeNull();
      expect(nativeCount, `${wf} native token-count missing`).not.toBeNull();
      const expectedSha = sha256(bytes);
      expect(baselineCount.driver_input_sha256, `${wf} baseline driver_input_sha256 mismatch`).toBe(expectedSha);
      expect(nativeCount.driver_input_sha256, `${wf} native driver_input_sha256 mismatch`).toBe(expectedSha);
    }
  });

  // ───────── AC-EC4 ─────────
  it("AC-EC4: workflow failure produces failure.log and marks row N/A with overall FAIL", () => {
    const doc = loadText(RESULTS);
    expect(doc, "results document missing").not.toBeNull();
    for (const wf of WORKFLOWS) {
      const failureLog = join(TOKEN_BUDGET_DIR, wf, "failure.log");
      if (existsSync(failureLog)) {
        const rowRegex = new RegExp(`\\|\\s*${wf}\\s*\\|[^\\n]*N\\/A[^\\n]*measurement failed`, "i");
        expect(rowRegex.test(doc), `${wf} failed but row is not "N/A — measurement failed"`).toBe(true);
        expect(/overall.*verdict[^\\n]*fail/i.test(doc), "overall verdict must be FAIL when a measurement failed").toBe(true);
      }
    }
  });

  // ───────── AC-EC5 ─────────
  it("AC-EC5: non-positive baseline_tokens is rejected", () => {
    const driverEntry = join(DRIVER_DIR, "index.js");
    const src = loadText(driverEntry);
    expect(src, "driver entrypoint missing").not.toBeNull();
    expect(/baseline_tokens\s*(>|must be positive|<=\s*0)/i.test(src)).toBe(true);

    for (const wf of WORKFLOWS) {
      const path = join(TOKEN_BUDGET_DIR, wf, "baseline.token-count.json");
      const json = loadJson(path);
      if (json !== null) {
        expect(json.tokens, `${wf} baseline tokens is non-positive`).toBeGreaterThan(0);
      }
    }
  });

  // ───────── AC-EC6 ─────────
  it("AC-EC6: negative reductions are displayed as negative and marked FAIL", () => {
    const doc = loadText(RESULTS);
    expect(doc, "results document missing").not.toBeNull();
    const lines = doc.split("\n");
    for (const line of lines) {
      const match = line.match(/\|\s*(-\d+\.\d)%/);
      if (match) {
        expect(/\|\s*FAIL\s*\|/i.test(line), `row with negative reduction not marked FAIL: ${line}`).toBe(true);
        expect(/abs\(\)/.test(line)).toBe(false);
      }
    }
  });

  // ───────── AC-EC7 ─────────
  it("AC-EC7: assistant-role turns in prompt capture are rejected", () => {
    const driverEntry = join(DRIVER_DIR, "index.js");
    const src = loadText(driverEntry);
    expect(src, "driver entrypoint missing").not.toBeNull();
    expect(/role\s*[:=]\s*['"]assistant['"]|assistant[- ]role/i.test(src)).toBe(true);
    expect(/Response tokens leaked into prompt capture|leaked.*prompt.*capture/i.test(src)).toBe(true);

    for (const wf of WORKFLOWS) {
      for (const run of ["baseline", "native"]) {
        const path = join(TOKEN_BUDGET_DIR, wf, `${run}.prompt.txt`);
        const prompt = loadText(path);
        if (prompt !== null) {
          expect(/"role"\s*:\s*"assistant"/.test(prompt), `${wf}/${run}.prompt.txt contains assistant turn`).toBe(false);
        }
      }
    }
  });

  // ───────── AC-EC8 ─────────
  it("AC-EC8: second run produces byte-identical token-count.json (NCP-20 determinism gate)", () => {
    for (const wf of WORKFLOWS) {
      const run1 = join(TOKEN_BUDGET_DIR, wf, "native.token-count.json");
      const run2 = join(TOKEN_BUDGET_DIR, wf, "run2.token-count.json");
      expect(existsSync(run1), `${wf} first-run native.token-count.json missing`).toBe(true);
      expect(existsSync(run2), `${wf} NCP-20 run2.token-count.json missing`).toBe(true);
      const b1 = readFileSync(run1);
      const b2 = readFileSync(run2);
      expect(sha256(b1), `${wf} run 1 vs run 2 not byte-identical`).toBe(sha256(b2));
    }
  });
});
