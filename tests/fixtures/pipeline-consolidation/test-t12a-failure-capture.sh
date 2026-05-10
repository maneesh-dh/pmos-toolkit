#!/bin/bash
# T12a fixture: folded-phase failure capture documented in 3 parent skills.
# State.yaml.phases.<parent>.folded_phase_failures[] append + chat-emit at append.
set -e
cd "$(git rev-parse --show-toplevel)"

for s in requirements wireframes spec; do
  f=plugins/pmos-toolkit/skills/$s/SKILL.md
  /usr/bin/grep -q "folded_phase_failures" "$f" || { echo "MISS: folded_phase_failures in $s"; exit 1; }
  /usr/bin/grep -q "advisory continue per D11" "$f" || { echo "MISS: advisory continue in $s"; exit 1; }
  /usr/bin/grep -q "FR-50\|M1" "$f" || { echo "MISS: FR-50/M1 in $s"; exit 1; }
done

echo OK
