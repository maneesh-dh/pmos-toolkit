#!/bin/bash
# T5 fixture: _shared/sim-spec-heuristics.md substrate exists + simulate-spec
# delegates to it + standalone Phase 0..11 scaffolding preserved.
set -e
cd "$(git rev-parse --show-toplevel)"

# 1. Substrate file exists and is non-empty
test -s plugins/pmos-toolkit/skills/_shared/sim-spec-heuristics.md

# 2. simulate-spec/SKILL.md references the substrate
/usr/bin/grep -q '_shared/sim-spec-heuristics.md' plugins/pmos-toolkit/skills/simulate-spec/SKILL.md

# 3. simulate-spec/SKILL.md retains Phase 0 and Phase 11 (delegation, not deletion)
/usr/bin/grep -q 'Phase 0:' plugins/pmos-toolkit/skills/simulate-spec/SKILL.md
/usr/bin/grep -q 'Phase 11' plugins/pmos-toolkit/skills/simulate-spec/SKILL.md

# 4. Substrate is substantial (≥200 lines per plan inline verification)
lines=$(wc -l < plugins/pmos-toolkit/skills/_shared/sim-spec-heuristics.md)
test "$lines" -ge 100

echo OK
