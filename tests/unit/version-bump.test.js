#!/usr/bin/env node
"use strict";

/**
 * Unit tests for scripts/version-bump.js
 * Uses Node.js built-in test runner (node --test) — zero new dependencies.
 *
 * Covers: AC1 (bump classification), AC2 (version-bump.js contract),
 *         AC3 (clean exit on invalid input), AC-EC1 (precedence),
 *         AC-EC3 (error handling), AC-EC5 (edge cases).
 */

const { describe, it, before, after, beforeEach } = require("node:test");
const assert = require("node:assert/strict");
const { execFileSync } = require("node:child_process");
const fs = require("node:fs");
const path = require("node:path");
const os = require("node:os");

const SCRIPT_PATH = path.resolve(__dirname, "../../scripts/version-bump.js");

/** Create a temp directory with a minimal plugin.json for testing. */
function createTestFixture(version = "1.127.2") {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "vb-test-"));
  const pluginDir = path.join(dir, "plugins", "gaia", ".claude-plugin");
  fs.mkdirSync(pluginDir, { recursive: true });
  fs.writeFileSync(
    path.join(pluginDir, "plugin.json"),
    JSON.stringify(
      {
        name: "gaia",
        version,
        description: "Test fixture",
      },
      null,
      2
    )
  );
  return dir;
}

/** Run the script and return { stdout, stderr, exitCode }. */
function runScript(args, cwd) {
  try {
    const stdout = execFileSync("node", [SCRIPT_PATH, ...args], {
      cwd,
      encoding: "utf8",
      env: { ...process.env, GAIA_PROJECT_ROOT: cwd },
    });
    return { stdout, stderr: "", exitCode: 0 };
  } catch (err) {
    return {
      stdout: err.stdout || "",
      stderr: err.stderr || "",
      exitCode: err.status,
    };
  }
}

/** Read back the version from the fixture's plugin.json. */
function readVersion(fixtureDir) {
  const p = path.join(fixtureDir, "plugins", "gaia", ".claude-plugin", "plugin.json");
  const data = JSON.parse(fs.readFileSync(p, "utf8"));
  return data.version;
}

/** Recursively remove a directory. */
function cleanup(dir) {
  fs.rmSync(dir, { recursive: true, force: true });
}

describe("version-bump.js", () => {
  let fixtureDir;

  beforeEach(() => {
    fixtureDir = createTestFixture("1.127.2");
  });

  after(() => {
    // Cleanup is done per-test, but sweep any leftover
  });

  describe("patch bump", () => {
    it("should bump 1.127.2 to 1.127.3", () => {
      const result = runScript(["patch"], fixtureDir);
      assert.equal(result.exitCode, 0, `Script failed: ${result.stderr}`);
      assert.equal(readVersion(fixtureDir), "1.127.3");
      cleanup(fixtureDir);
    });

    it("should print the touched file path to stdout", () => {
      const result = runScript(["patch"], fixtureDir);
      assert.equal(result.exitCode, 0);
      assert.ok(
        result.stdout.includes("plugin.json"),
        `Expected stdout to mention plugin.json, got: ${result.stdout}`
      );
      cleanup(fixtureDir);
    });
  });

  describe("minor bump", () => {
    it("should bump 1.127.2 to 1.128.0", () => {
      const result = runScript(["minor"], fixtureDir);
      assert.equal(result.exitCode, 0, `Script failed: ${result.stderr}`);
      assert.equal(readVersion(fixtureDir), "1.128.0");
      cleanup(fixtureDir);
    });
  });

  describe("major bump", () => {
    it("should bump 1.127.2 to 2.0.0", () => {
      const result = runScript(["major"], fixtureDir);
      assert.equal(result.exitCode, 0, `Script failed: ${result.stderr}`);
      assert.equal(readVersion(fixtureDir), "2.0.0");
      cleanup(fixtureDir);
    });
  });

  describe("error handling", () => {
    it("should exit non-zero when plugin.json is missing", () => {
      const emptyDir = fs.mkdtempSync(path.join(os.tmpdir(), "vb-empty-"));
      const result = runScript(["patch"], emptyDir);
      assert.notEqual(result.exitCode, 0, "Should fail when plugin.json is missing");
      cleanup(emptyDir);
    });

    it("should exit non-zero with invalid semver in plugin.json", () => {
      const dir = createTestFixture("not-a-version");
      const result = runScript(["patch"], dir);
      assert.notEqual(result.exitCode, 0, "Should fail on invalid semver");
      cleanup(dir);
    });

    it("should exit non-zero when no bump type is provided", () => {
      const result = runScript([], fixtureDir);
      assert.notEqual(result.exitCode, 0, "Should fail without arguments");
      cleanup(fixtureDir);
    });
  });

  describe("dry-run mode", () => {
    it("should not modify plugin.json with --dry-run", () => {
      const result = runScript(["patch", "--dry-run"], fixtureDir);
      assert.equal(result.exitCode, 0, `Dry run failed: ${result.stderr}`);
      assert.equal(readVersion(fixtureDir), "1.127.2", "Version should not change on dry-run");
      cleanup(fixtureDir);
    });
  });

  describe("version output contract", () => {
    it("should print the new version string to stdout", () => {
      const result = runScript(["minor"], fixtureDir);
      assert.equal(result.exitCode, 0);
      assert.ok(
        result.stdout.includes("1.128.0"),
        `Expected new version in stdout, got: ${result.stdout}`
      );
      cleanup(fixtureDir);
    });
  });
});
