/**
 * commitlint configuration for gaia-public.
 *
 * Enforces Conventional Commits on PR titles targeting staging and main.
 * Used by .github/workflows/commitlint.yml via wagoid/commitlint-github-action.
 *
 * AC4: Non-conforming PR titles (e.g., "fix stuff") fail the check.
 *      Conforming titles (e.g., "fix(skill): repair broken reference") pass.
 */
export default {
  extends: ["@commitlint/config-conventional"],
  rules: {
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
    "subject-empty": [2, "never"],
    "subject-max-length": [2, "always", 100],
    "type-empty": [2, "never"],
  },
};
