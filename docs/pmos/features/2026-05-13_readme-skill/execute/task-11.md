---
task_number: 11
task_name: "reference/simulated-reader.md — 3 persona prompts + return-shape contract"
plan_path: "docs/pmos/features/2026-05-13_readme-skill/03_plan.html"
branch: "feat/readme-skill"
worktree_path: "/Users/maneeshdhabria/Desktop/Projects/agent-skills-readme-skill"
status: done
started_at: 2026-05-13T15:10:00Z
completed_at: 2026-05-13T15:22:00Z
commit_sha: c9e6c80
files_touched:
  - plugins/pmos-toolkit/skills/readme/reference/simulated-reader.md
---

## Outcome

DONE. `reference/simulated-reader.md` (167 lines, plain markdown) authored against spec §7.7 (FR-SR-1..6) and §9.2.1 (return shape). Structure:

- **ToC** in the first 15 lines (anchor links to §1–§4, with §1 split into 1.1/1.2/1.3 sub-anchors).
- **§1 The three personas** — `evaluator-60s`, `adopter-5min`, `contributor-30min`. Each has task framing (one sentence), persona-specific anti-script (extending the common "you are NOT a reviewer" anti-script in the section preamble), and 4–5 concrete bounce-trigger bullets per persona (generic hero, missing install steps, no test command, etc.).
- **§2 Return shape** — JSON block mirroring spec §9.2.1 field-for-field (`persona`, `friction[].quote`, `.line`, `.severity`, `.message`); FR-SR-1 persona-name match rule; FR-SR-3 ≥40-char verbatim substring-grep contract with the exact hard-fail message from spec; FR-SR-4 severity vocabulary + dedup rule.
- **§3 Theater-check escape (FR-SR-5)** — re-dispatch rule with the bounce-suffix prompt; single retry cap; acceptance criterion; suggested log line.
- **§4 Parent-side validation reference** — explicit cite of `plugins/pmos-toolkit/skills/grill/SKILL.md` § "Input Contract" with a verbatim 4-line quote of its FR-52 self-validation prohibition, and a 3-row mapping table from grill's FR-50/51/52 → /readme's parent actions. Closes with FR-SR-6 `--skip-simulated-reader` skip path.

FR IDs cited explicitly at point-of-use: FR-SR-1 (§2), FR-SR-2 (preamble), FR-SR-3 (§2 + §4 mapping), FR-SR-4 (§2 severity + D6 in §3), FR-SR-5 (§3), FR-SR-6 (§4 closer).

## Deviations

None. All constraints met:
- 167 lines ≤ 200-line cap.
- Plain markdown, no HTML.
- All 6 FR-SR IDs cited at point-of-use.
- SKILL.md / rubric.* / workspace-discovery.sh / scripts/ / tests/ untouched (per task scope).

## Verification (plan §1 inline checks)

- `head -15 …simulated-reader.md` — ToC present (lines 8–15 enumerate §1.1, §1.2, §1.3, §2, §3, §4 with anchor links). PASS.
- `grep -c "evaluator\|adopter\|contributor" …simulated-reader.md` — **8** (expected ≥3). PASS.
- `grep -c "≥40-char\|substring-grep" …simulated-reader.md` — **4** (expected ≥1; FR-SR-3 contract surfaced in §2 twice + §4 once + JSON-block schema once). PASS.

Commit: `c9e6c80`.
