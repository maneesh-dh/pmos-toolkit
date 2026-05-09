#!/usr/bin/env bash
# Tiny shell mirror of _shared/resolve-input.md picking rule:
#   if .html sibling exists → return .html
#   else if .md sibling exists → return .md
#   else → ERROR
# Usage: _resolve_input_harness.sh <fixture-dir> [<base>]
#   <base> defaults to 01_requirements
set -e
DIR=${1:?fixture dir required}
BASE=${2:-01_requirements}
if [ -f "$DIR/$BASE.html" ]; then
  echo "$BASE.html"
elif [ -f "$DIR/$BASE.md" ]; then
  echo "$BASE.md"
else
  echo "ERROR"
fi
