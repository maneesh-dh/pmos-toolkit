#!/usr/bin/env bash
# assert_chrome_strip.sh — run 5 fixtures through chrome-strip.js + assert structure.
# Plan ref: T12 Step 2. Spec ref: FR-50.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HELPER="$ROOT/plugins/pmos-toolkit/skills/_shared/html-authoring/assets/chrome-strip.js"
FIX="$ROOT/tests/fixtures/chrome-strip"

fail() { echo "FAIL: $1" >&2; exit 1; }
contains() {
  local out="$1" needle="$2" label="$3"
  printf '%s' "$out" | grep -qF -- "$needle" || fail "$label: expected substring not found: $needle"
}
excludes() {
  local out="$1" needle="$2" label="$3"
  if printf '%s' "$out" | grep -qF -- "$needle"; then
    fail "$label: forbidden substring present: $needle"
  fi
}
run() { node "$HELPER" "$1"; }

# F1: simple section
out="$(run "$FIX/1.html")"
contains "$out" '<h1' F1-h1
contains "$out" '<main' F1-main
contains "$out" 'body-marker-1' F1-body
excludes "$out" '<head' F1-head
excludes "$out" '<link' F1-link
excludes "$out" '<script' F1-script
excludes "$out" 'pmos-artifact-toolbar' F1-toolbar-class
excludes "$out" 'pmos-artifact-footer' F1-footer-class
excludes "$out" 'Source: f1' F1-footer-source

# F2: nested section + aside
out="$(run "$FIX/2.html")"
contains "$out" '<section id="s1"' F2-section
contains "$out" '<aside id="a1"' F2-aside
contains "$out" 'aside-marker-2' F2-aside-marker

# F3: literal <main> in code (balanced-tag tracker — must NOT truncate at inner close)
out="$(run "$FIX/3.html")"
contains "$out" 'after-marker-3' F3-after
contains "$out" 'fake' F3-inner-text

# F4: multiple top-level <main> — extract first only
out="$(run "$FIX/4.html")"
contains "$out" 'main-one-marker-4' F4-first
excludes "$out" 'main-two-should-be-excluded' F4-second

# F5: chrome before/after main
out="$(run "$FIX/5.html")"
contains "$out" 'body-marker-5' F5-body
excludes "$out" 'toolbar-marker-5' F5-toolbar
excludes "$out" 'footer-marker-5' F5-footer

echo "OK: 5 chrome-strip fixtures passed"
