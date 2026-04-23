/**
 * commitlint configuration for gaia-public.
 *
 * Enforces Conventional Commits on PR titles targeting staging and main.
 * Used by .github/workflows/commitlint.yml via wagoid/commitlint-github-action.
 *
 * AC4: Non-conforming PR titles (e.g., "fix stuff") fail the check.
 *      Conforming titles (e.g., "fix(skill): repair broken reference") pass.
 */
module.exports = {
  extends: ["@commitlint/config-conventional"],
  rules: {
    // Allowed Conventional Commit types
    "type-enum": [
      2,
      "always",
      [
        "feat",
        "fix",
        "chore",
        "docs",
        "refactor",
        "test",
        "build",
        "ci",
        "perf",
        "style",
      ],
    ],
    // Subject must not be empty
    "subject-empty": [2, "never"],
    // Subject max length
    "subject-max-length": [2, "always", 100],
    // Type must not be empty
    "type-empty": [2, "never"],
  },
};
