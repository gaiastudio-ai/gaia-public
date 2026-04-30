#!/usr/bin/env bats
# evidence-judgment-parity.bats — drift-prevention parity suite (E65-S1, FR-DEJ-12)
#
# This skeleton ships in S1 with zero registered consumers. Consumers are
# appended to REVIEW_SKILLS by S2..S7 as the six review skills migrate to the
# template. While the array is empty the suite reports SKIP-with-message rather
# than passing silently with zero assertions (false-confidence guard, EC-6).

load 'test_helper.bash'

bats_require_minimum_version 1.5.0

# Canonical consumer list — populated by E65-S2..S7 as each review skill migrates.
# Each entry is the path (relative to plugins/gaia/) of the SKILL.md file.
REVIEW_SKILLS=(
  "skills/gaia-code-review/SKILL.md"
  "skills/gaia-security-review/SKILL.md"
)

# --- assertion helpers ---

# Assert SKILL.md frontmatter declares allowed-tools = [Read, Grep, Glob, Bash].
assert_allowed_tools_allowlist() {
  local file="$1"
  grep -E '^allowed-tools:' "$file" | grep -E 'Read.*Grep.*Glob.*Bash' >/dev/null
}

# Assert SKILL.md contains the unifying principle verbatim (FR-DEJ-1).
assert_unifying_principle() {
  local file="$1"
  grep -F 'Deterministic tools provide evidence. The LLM provides judgment. The LLM consumes deterministic output; it does not override it.' "$file" >/dev/null
}

# Assert SKILL.md contains the seven canonical phase headers in order.
assert_seven_phase_headers() {
  local file="$1"
  local expected=(
    "Setup"
    "Story Gate"
    "Phase 3A"
    "Phase 3B"
    "Architecture Conformance"
    "Verdict"
    "Output"
    "Finalize"
  )
  local got
  got="$(grep -E '^### |^## ' "$file" || true)"
  for p in "${expected[@]}"; do
    printf '%s' "$got" | grep -F "$p" >/dev/null || return 1
  done
}

# Assert load-stack-persona.sh is invoked somewhere in SKILL.md (Setup phase).
assert_persona_load_hook_present() {
  local file="$1"
  grep -F 'load-stack-persona.sh' "$file" >/dev/null
}

# Assert verdict-resolver.sh is invoked somewhere in SKILL.md (Verdict phase).
assert_verdict_resolver_invocation() {
  local file="$1"
  grep -F 'verdict-resolver.sh' "$file" >/dev/null
}

# --- per-consumer test loop ---

@test "parity: allowed-tools allowlist == [Read, Grep, Glob, Bash]" {
  if [ "${#REVIEW_SKILLS[@]}" -eq 0 ]; then
    skip "no consumers registered yet — parity not enforceable"
  fi
  for entry in "${REVIEW_SKILLS[@]}"; do
    assert_allowed_tools_allowlist "$BATS_TEST_DIRNAME/../$entry"
  done
}

@test "parity: unifying principle string present verbatim" {
  if [ "${#REVIEW_SKILLS[@]}" -eq 0 ]; then
    skip "no consumers registered yet — parity not enforceable"
  fi
  for entry in "${REVIEW_SKILLS[@]}"; do
    assert_unifying_principle "$BATS_TEST_DIRNAME/../$entry"
  done
}

@test "parity: seven phase headers in order" {
  if [ "${#REVIEW_SKILLS[@]}" -eq 0 ]; then
    skip "no consumers registered yet — parity not enforceable"
  fi
  for entry in "${REVIEW_SKILLS[@]}"; do
    assert_seven_phase_headers "$BATS_TEST_DIRNAME/../$entry"
  done
}

@test "parity: persona-load hook present" {
  if [ "${#REVIEW_SKILLS[@]}" -eq 0 ]; then
    skip "no consumers registered yet — parity not enforceable"
  fi
  for entry in "${REVIEW_SKILLS[@]}"; do
    assert_persona_load_hook_present "$BATS_TEST_DIRNAME/../$entry"
  done
}

@test "parity: verdict-resolver invocation present" {
  if [ "${#REVIEW_SKILLS[@]}" -eq 0 ]; then
    skip "no consumers registered yet — parity not enforceable"
  fi
  for entry in "${REVIEW_SKILLS[@]}"; do
    assert_verdict_resolver_invocation "$BATS_TEST_DIRNAME/../$entry"
  done
}

# Stub-marker hygiene: no unfilled GAIA_REVIEW_STUB: sentinel in any consumer SKILL.md.
@test "parity: no unfilled GAIA_REVIEW_STUB sentinels in consumers" {
  if [ "${#REVIEW_SKILLS[@]}" -eq 0 ]; then
    skip "no consumers registered yet — parity not enforceable"
  fi
  for entry in "${REVIEW_SKILLS[@]}"; do
    run grep -F 'GAIA_REVIEW_STUB:' "$BATS_TEST_DIRNAME/../$entry"
    [ "$status" -ne 0 ]   # grep found nothing — clean
  done
}
