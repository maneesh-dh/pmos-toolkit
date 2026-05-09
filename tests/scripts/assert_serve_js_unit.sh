#!/usr/bin/env bash
# Regression tests for assets/serve.js (FR-06 + path-traversal hardening).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec node "$HERE/serve.test.js"
