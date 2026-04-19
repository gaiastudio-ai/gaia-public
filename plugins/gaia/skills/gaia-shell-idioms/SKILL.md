---
name: gaia-shell-idioms
description: Reusable shell and awk idioms for GAIA scripts and bats tests. Captures recurring anti-patterns (like the awk range-bug) and the canonical state-machine fixes. Reference-only skill — loaded by authors writing new scripts or tests.
tools: Read, Grep
---

## About

Project convention doc for small shell and awk idioms that have bitten the codebase more than once. Each idiom is presented as a pair: the broken form (and why it fails) followed by the state-machine fix (and a short runnable example).

This skill is prose-only — it documents conventions but does not execute anything. Authors reading this skill should apply the idiom directly in scripts under `gaia-public/plugins/gaia/scripts/` and in bats tests under `gaia-public/tests/`.

- ADR-041 — Native execution model; this skill is consumed directly by the Skills runtime.
- ADR-042 — Scripts-over-LLM for deterministic operations; the idioms here are the canonical shell-side implementations.

> **Scope:** GNU awk / POSIX awk / mawk. All examples are POSIX-compatible unless noted.

<!-- SECTION: awk-range-bug -->
## awk Range Bug — `/start/,/end/` Terminates at the Start Line

### The Broken Idiom

The classic awk range expression `/start/,/end/` selects every line from a line matching `/start/` up to and including the next line matching `/end/`. That works beautifully when the two patterns are disjoint. It **breaks silently** when both patterns can match the **same line** — the range opens and closes on that one line, and every subsequent line is dropped.

Concrete failure case: printing the body of a markdown section up to the next same-level heading.

```bash
# BROKEN — returns only the first "## Foo" line, not the section body.
# Both /^## Foo/ and /^## / match the heading line itself, so the range
# opens at "## Foo" and immediately closes on the same line.
awk '/^## Foo/,/^## /' README.md
```

### Why It Fails

The awk range `expr1,expr2` is a two-state toggle: once `expr1` matches a line, the range is "on" starting with that line. On every subsequent line (including the line that flipped the range on), awk re-evaluates `expr2`. If `expr2` matches the same line that `expr1` matched, the range flips back off on that one line — so only the start line is printed. `expr2` is not deferred to the next line; it is checked on the current line after `expr1` fires.

This bug has recurred **3 times** across this codebase — once in `verify-cluster-gates.sh` (E28-S126), once in section-scoped bats greps (E28-S128), and again in the section-queries for the migration guide tests (E28-S130). Codifying the fix here is the remediation.

### The State-Machine Fix

Replace the range expression with an explicit flag that is set when the start pattern matches and cleared when the end pattern matches. The key move is `flag && /end/{flag=0}` — the end check fires **only after** the flag is already on, so it cannot close the range on the same line that opened it.

```bash
# FIXED — prints the body of the "## Foo" section up to (but not including)
# the next "## " heading. The start line itself is skipped with `next`.
awk '
  /^## Foo/        { flag = 1; next }
  flag && /^## /   { flag = 0 }
  flag
' README.md
```

The three-line form generalises to any start/end pair that can collide on a single line:

```awk
/<start>/        { flag = 1; next }   # open the range (skip the start line)
flag && /<end>/  { flag = 0 }         # close only after the range is open
flag                                  # print lines while the flag is on
```

If the start line itself should be included in the output, drop the trailing `next` from the first rule and print the line before setting the flag:

```awk
/<start>/        { print; flag = 1; next }
flag && /<end>/  { flag = 0 }
flag
```

### Canonical Uses in This Codebase

- YAML frontmatter extraction (first pair of `---` delimiters only):

  ```awk
  /^---$/{n++; next} n==1{print}
  ```

  Seen in every `tests/skills/*.bats` frontmatter check and in `tests/cluster-13-parity/*.bats`.

- Markdown section extraction up to the next same-level heading (the recurring case above):

  ```awk
  /^## .*X/{flag=1; next} flag && /^## /{flag=0} flag
  ```

- Dropping a trailing section (e.g., everything after `## References`):

  ```awk
  /^## References/ { in_refs = 1 } !in_refs { print }
  ```

### Review Checklist

When reviewing a script or bats test, flag any occurrence of `awk '/start/,/end/'` where **both** regexes could match a single line. The fix is mechanical — rewrite it with the three-line state machine above.

<!-- SECTION: frontmatter-extraction -->
## YAML Frontmatter Extraction

### The Idiom

Markdown files in this repo carry YAML frontmatter between the first pair of `---` delimiters. A naive `sed -n '/^---$/,/^---$/p'` or `awk '/^---$/,/^---$/'` hits the range-bug above the moment the file contains a third `---` (for example, a horizontal rule inside the body).

### The Fix

Count delimiter hits and print only while the counter is exactly 1:

```awk
BEGIN { in_fm = 0; seen = 0 }
/^---[[:space:]]*$/ {
  if (seen == 0) { in_fm = 1; seen = 1; next }
  else if (in_fm == 1) { in_fm = 0; exit }
}
in_fm == 1 { print }
```

This is the `_frontmatter` helper used by `tests/cluster-15-parity/E28-S112-core-dev-skills-parity.bats` and by the newer skill-parity bats tests.

<!-- SECTION: review-notes -->
## Review Notes

- Prefer an explicit `flag` state machine over range expressions whenever the start/end patterns share any overlap. The range form is only safe when the two patterns are provably disjoint.
- Always use `next` after the start rule fires (unless you want the start line itself in the output) so the end rule cannot evaluate against the same line.
- Keep the flag check (`flag && /end/`) ahead of the print rule so the end line is not printed.
- For bats tests, this idiom is preferred over piping to `sed` or `grep -A`/`-B` with magic line counts — those are fragile when section bodies grow.

## References

- E28-S126 review (Finding #4) — first recurrence in `verify-cluster-gates.sh`.
- E28-S130 QA tests — second recurrence, documented state-machine fix.
- E28-S130 review summary — third recurrence; triage finding promoted to this story (E28-S168).
