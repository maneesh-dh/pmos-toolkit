---
task_number: 7
task_name: "rubric.sh widens to 15 checks + 7 variants + auto-apply"
plan_path: "docs/pmos/features/2026-05-13_readme-skill/03_plan.html"
branch: "feat/readme-skill"
worktree_path: "/Users/maneeshdhabria/Desktop/Projects/agent-skills-readme-skill"
status: done
started_at: 2026-05-13T13:26:00Z
completed_at: 2026-05-13T13:50:00Z
commit_sha: 66efe39
review_report: "docs/pmos/features/2026-05-13_readme-skill/verify/2026-05-13-phase-2/report.md"
files_touched:
  - plugins/pmos-toolkit/skills/readme/scripts/rubric.sh
  - plugins/pmos-toolkit/skills/readme/scripts/_lib.sh
  - plugins/pmos-toolkit/skills/readme/tests/fixtures/rubric/strong/01_hero-line.md
  - plugins/pmos-toolkit/skills/readme/tests/fixtures/rubric/slop/01_no-hero.md
  - plugins/pmos-toolkit/skills/readme/tests/fixtures/rubric/strong/02_install-quickstart.md
  - plugins/pmos-toolkit/skills/readme/tests/fixtures/rubric/strong/03_banned-phrases-clean.md
  - plugins/pmos-toolkit/skills/readme/tests/fixtures/rubric/strong/04_links-and-license.md
  - plugins/pmos-toolkit/skills/readme/tests/fixtures/rubric/strong/05_section-order-and-tldr.md
  - plugins/pmos-toolkit/skills/readme/tests/fixtures/rubric/slop/02_no-install.md
  - plugins/pmos-toolkit/skills/readme/tests/fixtures/rubric/slop/03_banned-phrases.md
  - plugins/pmos-toolkit/skills/readme/tests/fixtures/rubric/slop/04_broken-links.md
  - plugins/pmos-toolkit/skills/readme/tests/fixtures/rubric/slop/05_bad-order-long-tldr.md
---

## Outcome

DONE. rubric.sh 35 → 520 lines: 15 check_* functions implementing rubric.yaml's pass_when contract; --variant warn-and-skip for undefined add: IDs; --auto-apply mechanizes banned-phrase strikethrough; --selftest A2 100% agreement (gate ≥85%). _lib.sh +30 lines: readme::yaml_get python3+PyYAML helper appended; T2 helpers byte-identical. 8 new fixtures (10 total: 5 strong all PASS=13/15, 5 slop all PASS=7/15). Phase 2 boundary reviewer: PASS / PROCEED_TO_PHASE_3.

## Deviations (each spec-compliant; reviewer accepted)

- python3+PyYAML for yaml_get (js-yaml absent on host).
- Bash 3.2 portable (heredoc + IFS-read instead of associative arrays).
- BSD-awk-compatible boundary class in what-it-does-in-60s.
- install-or-quickstart-presence widened to accept Download per Wave 1 reviewer residual #4.
- no-banned-phrases is strikethrough-aware (skips ~~...~~ wrapped text) so auto-apply actually fixes the FAIL.
- sections-in-recommended-order subsequence enforced against spine entries that appear; non-spine ignored (e.g., Features doesn't false-fail).
- auto-apply mechanizes only no-banned-phrases per FR-RUB-3 (reorder + reflow non-mechanical; warn-only).

## Residuals (carry to T26 dogfood / /verify Phase 7)

1. rubric.yaml `pass_when` for install-or-quickstart-presence narrowly says Install|Quickstart|Getting Started; impl includes Download. Doc-impl drift.
2. _lib.sh header comment says "Bash ≥ 4 required"; actual code is 3.2-safe.
3. badges-not-stale lacks a slop fixture exercising the cacheSeconds=-1 pattern.
4. plugin-manifest-mentioned warn-and-skip is intentional (T21 deferred impl).

Commit: `66efe39`.
