#!/usr/bin/env bash
# Verify canonical-path invariants documented in _shared/canonical-path.md.
# Run from any pmos-toolkit checkout.
set -euo pipefail

# Test 1: realpath canonicalization on macOS /tmp (or whatever /tmp resolves to)
ACTUAL="$(realpath /tmp 2>/dev/null || python3 -c 'import os; print(os.path.realpath("/tmp"))')"
case "$(uname -s)" in
  Darwin)
    [ "$ACTUAL" = "/private/tmp" ] || { echo "FAIL Test 1: macOS /tmp expected /private/tmp, got '$ACTUAL'"; exit 1; }
    ;;
  *)
    # On Linux, /tmp typically is /tmp itself; just assert it resolves to a non-empty absolute path
    case "$ACTUAL" in
      /*) ;;
      *)  echo "FAIL Test 1: realpath /tmp returned non-absolute path '$ACTUAL'"; exit 1 ;;
    esac
    ;;
esac

# Test 2: idempotent realpath (realpath(realpath(p)) == realpath(p))
P1="$(realpath /tmp 2>/dev/null || python3 -c 'import os; print(os.path.realpath("/tmp"))')"
P2="$(realpath "$P1" 2>/dev/null || python3 -c "import os; print(os.path.realpath('$P1'))")"
[ "$P1" = "$P2" ] || { echo "FAIL Test 2: idempotent realpath broke ('$P1' vs '$P2')"; exit 1; }

# Test 3: distinct paths produce distinct canonical outputs
HOME_REAL="$(realpath "$HOME" 2>/dev/null || python3 -c 'import os, sys; print(os.path.realpath(os.environ["HOME"]))')"
[ "$P1" != "$HOME_REAL" ] || { echo "FAIL Test 3: distinct paths collided ('$P1' = '$HOME_REAL')"; exit 1; }

# Test 4: realpath fallback path (python3) when realpath unavailable
if command -v python3 >/dev/null 2>&1; then
  PY_OUT="$(python3 -c 'import os; print(os.path.realpath("/tmp"))')"
  case "$(uname -s)" in
    Darwin) [ "$PY_OUT" = "/private/tmp" ] || { echo "FAIL Test 4: python3 fallback returned '$PY_OUT'"; exit 1; } ;;
    *)      case "$PY_OUT" in /*) ;; *) echo "FAIL Test 4: python3 fallback returned non-absolute '$PY_OUT'"; exit 1 ;; esac ;;
  esac
else
  echo "SKIP Test 4: python3 not installed"
fi

echo "OK: canonical-path invariants hold"
