#!/usr/bin/env bats
# e34-s1-val-sidecar-perf.bats
#
# TC-VSP-7 — 100 consecutive invocations with distinct payloads.
# NFR-VSP-1: median write latency ≤ 50ms.
# Additional guard: no single invocation exceeds 1s.

load 'test_helper.bash'

setup() {
  common_setup
  PROJECT_ROOT="$TEST_TMP/proj"
  mkdir -p "$PROJECT_ROOT/_memory/validator-sidecar"
  export PROJECT_ROOT
}

teardown() { common_teardown; }

SCRIPT="$(cd "$BATS_TEST_DIRNAME/../scripts" && pwd)/val-sidecar-write.sh"

@test "TC-VSP-7: 100 invocations with distinct payloads — median latency ≤ 50ms, no single call > 1s" {
  # Warm-up invocation (amortize any first-run OS page-cache / interpreter
  # startup costs — NFR-VSP-1 measures steady-state median, not cold start).
  "$SCRIPT" --root "$PROJECT_ROOT" --command-name "/gaia-create-story" \
    --input-id "WARMUP" \
    --decision-payload '{"verdict":"passed","findings":[],"artifact_path":"w"}' \
    --sprint-id "sprint-26" >/dev/null 2>&1

  # Use python3 once (outside the hot loop) to drive timing — we amortize
  # Python startup across all 100 iterations. This keeps measurement
  # overhead close to zero (the python process just wraps subprocess.run).
  local report
  report=$(python3 - "$SCRIPT" "$PROJECT_ROOT" <<'PY'
import subprocess, time, statistics, sys, json
script, root = sys.argv[1], sys.argv[2]
durations = []
for i in range(100):
    payload = json.dumps({
        "verdict": "passed",
        "findings": [{"id": f"F{i}", "msg": f"m{i}"}],
        "artifact_path": f"docs/x{i}.md",
    })
    t0 = time.perf_counter_ns()
    subprocess.run(
        [script,
         "--root", root,
         "--command-name", "/gaia-create-story",
         "--input-id", f"ID-{i}",
         "--decision-payload", payload,
         "--sprint-id", "sprint-26"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    t1 = time.perf_counter_ns()
    durations.append((t1 - t0) / 1_000_000)  # ms
median = statistics.median(durations)
p99 = sorted(durations)[98]
hi = max(durations)
print(f"{median:.1f} {p99:.1f} {hi:.1f}")
PY
)
  local median p99 hi
  read -r median p99 hi <<<"$report"
  echo "median_ms=$median p99_ms=$p99 max_ms=$hi" >&3
  # No single call exceeds 1000ms.
  local hi_int=${hi%.*}
  [ "$hi_int" -lt 1000 ]
  # Median ≤ 50ms (NFR-VSP-1).
  local median_int=${median%.*}
  [ "$median_int" -le 50 ]
}
