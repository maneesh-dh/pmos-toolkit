#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
load test_helper

setup() {
  EXTRACTOR_AWK="$(awk '/<!-- awk-extractor:start -->/,/<!-- awk-extractor:end -->/' "$SHARED_FILE" \
    | awk '/^```awk$/{flag=1;next}/^```$/{flag=0}flag')"
  PERF_FIX="$(mktemp)"
  {
    echo "---"; echo "name: perf-fix"; echo "---"; echo
    for i in $(seq 1 20); do
      for _ in $(seq 1 9); do echo "filler line"; done
      echo 'AskUserQuestion: "test '"$i"'"'
      echo 'Options: "x (Recommended)", "y"'
    done
  } > "$PERF_FIX"
}
teardown() { rm -f "$PERF_FIX"; }

@test "NFR-01 resolver: 100 stand-in invocations under 1000ms total (avg < 10ms)" {
  local start_ms end_ms elapsed_ms
  start_ms=$(python3 -c 'import time; print(int(time.time()*1000))')
  for _ in $(seq 1 100); do
    resolve_mode --flag non-interactive --parent null --settings null >/dev/null
  done
  end_ms=$(python3 -c 'import time; print(int(time.time()*1000))')
  elapsed_ms=$((end_ms - start_ms))
  [ "$elapsed_ms" -lt 1000 ]
}

@test "NFR-01 classifier: awk extractor on 200-line/20-call SKILL.md under 100ms" {
  local start_ms end_ms elapsed_ms
  start_ms=$(python3 -c 'import time; print(int(time.time()*1000))')
  awk "$EXTRACTOR_AWK" "$PERF_FIX" >/dev/null
  end_ms=$(python3 -c 'import time; print(int(time.time()*1000))')
  elapsed_ms=$((end_ms - start_ms))
  [ "$elapsed_ms" -lt 100 ]
}
