---
task_number: 13
task_name: "theater-check (FR-SR-5) + --skip-simulated-reader (FR-SR-6) + stub contract test"
plan_path: "docs/pmos/features/2026-05-13_readme-skill/03_plan.html"
branch: "feat/readme-skill"
worktree_path: "/Users/maneeshdhabria/Desktop/Projects/agent-skills-readme-skill"
status: done
started_at: 2026-05-13T15:30:00Z
completed_at: 2026-05-13T15:45:00Z
commit_sha: 3bf8620
files_touched:
  - plugins/pmos-toolkit/skills/readme/SKILL.md
  - plugins/pmos-toolkit/skills/readme/tests/mocks/simulated_reader_stub.sh
  - plugins/pmos-toolkit/skills/readme/tests/integration/simulated_reader_contract.sh
---

## Outcome

DONE. Closes Phase 4 simulated-reader vertical.

- **SKILL.md §3 appended** (22 lines, inserted between §2's reference-link blockquote and `## Anti-Patterns`) — documents FR-SR-5 theater-check (empty friction[] + rubric≥3 → single-shot re-dispatch with bounce-suffix), FR-SR-6 `--skip-simulated-reader` flag (mutex with `--selftest`), and the `READMER_PERSONA_STUB` env-var contract-test escape (P9 hatch).
- **Stub** at `tests/mocks/simulated_reader_stub.sh` (~40 lines) emits 3 canned persona JSONs — evaluator (valid ≥40-char quote substring of the ripgrep fixture), adopter (empty friction, theater-check trigger), contributor (1-char casing slip: `Ripgrep` vs `ripgrep` — substring-grep must hard-fail).
- **Contract harness** at `tests/integration/simulated_reader_contract.sh` (~35 lines) — 3 assertions verify (1) evaluator quote substring-matches, (2) adopter empty friction is parseable, (3) contributor altered quote does NOT match.

## Deviations

- Stub fixture content adapted: original spec quoted `# acme-cli — a tiny CLI for inspecting acme widget files locally` but the actual T8 fixture `tests/fixtures/rubric/strong/01_hero-line.md` is the **ripgrep** README (hero `# ripgrep`, line 3 is the ≥40-char concrete sentence). Used line 3 verbatim — `"ripgrep is a line-oriented search tool for recursively searching the current directory for a regex pattern."` — and the casing slip on line 3's first letter (lowercase `r` → capital `R`) for the altered-quote case. Preserves spec intent (verbatim substring vs 1-char slip) against real fixture corpus.

## Verification

- Contract test: `bash plugins/pmos-toolkit/skills/readme/tests/integration/simulated_reader_contract.sh` — **3/3 PASS**, exit 0.
- `shellcheck` on stub + harness — clean (exit 0, no warnings).
- `wc -l SKILL.md` — **219 lines** (≤480 budget).
- `grep -c "skip-simulated-reader\|theater-check\|bounce-suffix" SKILL.md` — **7** (≥3 required).
- P11 append-only: `git diff d718646 -- SKILL.md | grep '^-' | grep -v '^---' | wc -l` — **0 removed lines** (pure additions between §2 and `## Anti-Patterns`).

Commit: `3bf8620`.
