#!/usr/bin/env bash
# Pre-push lint: viewer.js MUST be a classic <script defer> with no ES-module
# patterns. file:// loads (FR-26) require classic-script semantics.
# FR-05.1; spec §14.1.
set -e
VIEWER=${1:-plugins/pmos-toolkit/skills/_shared/html-authoring/assets/viewer.js}
if [ ! -f "$VIEWER" ]; then
  echo "FAIL: $VIEWER not found"
  exit 1
fi
PATTERN='^[[:space:]]*(import|export)[[:space:]]+|type=["'"'"']module["'"'"']'
hits=$(grep -nE "$PATTERN" "$VIEWER" || true)
if [ -n "$hits" ]; then
  echo "FAIL: ES-module pattern in $VIEWER"
  echo "$hits"
  exit 1
fi
echo "PASS: lint-no-modules-in-viewer ($VIEWER)"
