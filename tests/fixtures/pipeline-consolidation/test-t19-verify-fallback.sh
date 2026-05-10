#!/bin/bash
# T19 fixture: /verify legacy slug fallback + folded-phase awareness + advisory.
set -e
cd "$(git rev-parse --show-toplevel)"

f=plugins/pmos-toolkit/skills/verify/SKILL.md

/usr/bin/grep -q "Folded-phase awareness" "$f"
/usr/bin/grep -q "msf-req-findings.md" "$f"
/usr/bin/grep -q "msf-findings.md" "$f"
/usr/bin/grep -q "legacy slug detected" "$f"
/usr/bin/grep -q "folded phases skipped per documented flags" "$f"
/usr/bin/grep -q "FR-20\|D4" "$f"
/usr/bin/grep -q "FR-52" "$f"
/usr/bin/grep -q "advisory per D11" "$f"

# Setup E (F4): advisory for Tier-3 with no folded artifacts/skips
/usr/bin/grep -q "may have been bypassed silently" "$f"

echo OK
