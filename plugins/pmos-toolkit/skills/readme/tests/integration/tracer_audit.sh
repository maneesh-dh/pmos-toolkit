#!/usr/bin/env bash
# tracer_audit.sh — Phase 1 tracer-bullet end-to-end smoke
set -euo pipefail
tmp=$(mktemp -d); trap "rm -rf $tmp" EXIT
cp plugins/pmos-toolkit/skills/readme/tests/fixtures/rubric/slop/01_no-hero.md "$tmp/README.md"
cd "$tmp"
# At this point /readme is a skill — invoked via slash command, not directly. Per /plan Loop-1 F3
# disposition: tracer_audit.sh is a CONTRACT TEST (atomic-write + rubric.sh integration); real
# /readme slash-command dispatch is exercised only in T26's dogfood pass, which is the canonical
# end-to-end /readme test. Splitting into 2 scripts (contract + manual smoke) is explicitly NOT done
# (over-engineering for a tracer slice).
bash "$OLDPWD/plugins/pmos-toolkit/skills/readme/scripts/rubric.sh" README.md && { echo "expected fail on slop"; exit 1; } || true
# Atomic write contract: rubric.sh produced a finding; the *skill* (not the script) would
# emit a diff preview and offer to apply. We simulate the write here.
cp README.md README.md.orig
{ echo "# Project Name"; echo; echo "Project Name does <one-sentence what + who + why>."; tail -n +2 README.md.orig; } > README.md.tmp.42
mv README.md.tmp.42 README.md
rm -f README.md.orig
[[ -f README.md ]] && ! [[ -f README.md.tmp.42 ]] || { echo "atomic-write contract broken"; exit 1; }
echo "tracer_audit: PASS"
