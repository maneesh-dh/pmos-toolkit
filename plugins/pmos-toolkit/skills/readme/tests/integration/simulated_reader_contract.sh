#!/usr/bin/env bash
# simulated_reader_contract.sh — FR-SR-3 substring-validation contract test.
# Asserts:
#   1. evaluator's valid quote substring-matches the fixture README → pass.
#   2. adopter's empty friction is parseable (theater-check input).
#   3. contributor's altered quote does NOT substring-match the fixture README.
# (The parent-side hard-fail on (3) is documented in SKILL.md §2/§3; this harness
# verifies the stub itself produces the contract-triggering shape.)
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STUB="$HERE/../mocks/simulated_reader_stub.sh"
README="$HERE/../fixtures/rubric/strong/01_hero-line.md"

[[ -x "$STUB" ]] || { echo "FAIL: stub not executable"; exit 1; }
[[ -f "$README" ]] || { echo "FAIL: fixture README missing"; exit 1; }

readme_text=$(<"$README")

# Test 1: evaluator quote substring-matches README
eval_quote=$(bash "$STUB" --persona=evaluator "$README" | python3 -c "import json,sys; print(json.load(sys.stdin)['friction'][0]['quote'])")
if [[ "$readme_text" == *"$eval_quote"* ]]; then
  echo "PASS: evaluator quote substring-matches README"
else
  echo "FAIL: evaluator quote MISSING from README"; exit 1
fi

# Test 2: adopter empty friction is parseable
adopter_count=$(bash "$STUB" --persona=adopter "$README" | python3 -c "import json,sys; print(len(json.load(sys.stdin)['friction']))")
if [[ "$adopter_count" == "0" ]]; then
  echo "PASS: adopter empty friction (theater-check trigger)"
else
  echo "FAIL: adopter friction not empty"; exit 1
fi

# Test 3: contributor altered quote does NOT substring-match
contrib_quote=$(bash "$STUB" --persona=contributor "$README" | python3 -c "import json,sys; print(json.load(sys.stdin)['friction'][0]['quote'])")
if [[ "$readme_text" == *"$contrib_quote"* ]]; then
  echo "FAIL: contributor altered quote unexpectedly substring-matches README"; exit 1
else
  echo "PASS: contributor altered quote does NOT match (parent will hard-fail FR-SR-3)"
fi

echo "All 3 contract assertions pass."
