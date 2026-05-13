#!/usr/bin/env bash
# rubric.sh <readme-path> [--variant <type>] | --selftest
# Deps: bash ≥ 4, coreutils. Exit 0 (all pass), 1 (any fail), 2 (script error).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./_lib.sh
source "$HERE/_lib.sh"

check_hero_line() {
  local path="$1"
  # Hero line = the first prose paragraph line after the H1 (not a heading,
  # list item, blockquote, code fence, or indented code).
  local hero
  hero=$(awk '
    NR==1 && /^# / {h1=1; next}
    h1 && NF && !/^#/ && !/^[-*+] / && !/^[0-9]+\. / && !/^>/ && !/^```/ && !/^    / {print; exit}
  ' "$path")
  if [[ -z "$hero" ]]; then
    printf 'hero-line-presence\tFAIL\tHEAD\t1\tNo hero line found\n'
    return 1
  fi
  printf 'hero-line-presence\tPASS\tHEAD\t1\t\n'
  return 0
}

main() {
  if [[ "${1:-}" == "--selftest" ]]; then
    local fail=0
    check_hero_line "$HERE/../tests/fixtures/rubric/strong/01_hero-line.md" || fail=1
    check_hero_line "$HERE/../tests/fixtures/rubric/slop/01_no-hero.md" && fail=1 || true
    # Strong must pass; slop must fail. fail=1 if either gate breaks.
    if [[ $fail -eq 0 ]]; then
      readme::log "selftest: PASS"; exit 0
    else
      readme::log "selftest: FAIL"; exit 1
    fi
  fi
  [[ -f "${1:-}" ]] || readme::die "usage: rubric.sh <readme-path> [--variant <type>] | --selftest"
  check_hero_line "$1" && exit 0 || exit 1
}
main "$@"
