#!/usr/bin/env bash
# T3 inline verification — viewer.js JSDOM unit tests (FR-05/FR-22/FR-26/FR-40).
# Bootstraps jsdom into /tmp/pmos-jsdom-boot if not already available via NODE_PATH
# or HTML_TO_MD_JSDOM_PATH (mirrors T6's escape hatch convention).

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1) Honor explicit override first.
if [[ -n "${HTML_TO_MD_JSDOM_PATH:-}" ]] && [[ -d "$HTML_TO_MD_JSDOM_PATH/jsdom" ]]; then
  export NODE_PATH="${NODE_PATH:+$NODE_PATH:}$HTML_TO_MD_JSDOM_PATH"
fi

# 2) Probe — is jsdom resolvable as-is?
if ! node -e "require('jsdom')" >/dev/null 2>&1; then
  BOOT_DIR="${PMOS_JSDOM_BOOT:-/tmp/pmos-jsdom-boot}"
  if [[ ! -d "$BOOT_DIR/node_modules/jsdom" ]]; then
    echo "[viewer-test] bootstrapping jsdom into $BOOT_DIR ..." >&2
    mkdir -p "$BOOT_DIR"
    ( cd "$BOOT_DIR" && npm install --silent --no-save --no-audit --no-fund jsdom@^24 ) >&2
  fi
  export NODE_PATH="${NODE_PATH:+$NODE_PATH:}$BOOT_DIR/node_modules"
fi

# 3) Final probe before running tests.
if ! node -e "require('jsdom')" >/dev/null 2>&1; then
  echo "[viewer-test] FAIL: jsdom unavailable. Set HTML_TO_MD_JSDOM_PATH=/abs/path/to/node_modules or pre-install in PMOS_JSDOM_BOOT." >&2
  exit 70
fi

exec node "$HERE/viewer.test.js"
