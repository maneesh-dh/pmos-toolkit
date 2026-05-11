# /execute summary — survey-design skill

**Plan:** `03_plan.html` (Tier 3, 11 tasks T1-T9 + TN, single implicit phase). **Branch:** `feat/survey-design-skill`. **Commit cadence:** per-task. All tasks done; working tree clean.

| Task | What | Commit |
|---|---|---|
| T1 | Scaffold `plugins/pmos-toolkit/skills/survey-design/{reference,assets,tests/fixtures}` + placeholder files | `feat(survey-design,T1): scaffold skill directory` |
| T2 | `tests/scripts/assert_survey_design_skill.sh` (the "red" static-check script) + `tests/fixtures/sample-brief.txt` + `tests/expected.yaml` | `test(survey-design,T2): add static-check script + sample-brief fixture` |
| T3 | `reference/survey-best-practices.md` (165 lines, from research Stream 1) | `feat(survey-design,T3): reference/survey-best-practices.md from research Stream 1` |
| T4 | `reference/question-antipatterns.md` (278 lines, A1-E6 catalog, 35 detection-heuristic lines, from Stream 2) | `feat(survey-design,T4): reference/question-antipatterns.md (A1-E6 catalog) from research Stream 2` |
| T5 | `reference/platform-export.md` (252 lines, Typeform/SurveyMonkey/Google Forms/Qualtrics, from Stream 3) | `feat(survey-design,T5): reference/platform-export.md from research Stream 3` |
| T6 | `assets/survey-preview.js` (~600 lines, standalone vanilla-JS preview engine, all 12 question types, skip-logic, ASCII-only) | `feat(survey-design,T6): assets/survey-preview.js standalone preview engine` |
| T7 | `SKILL.md` part 1 — frontmatter + Platform Adaptation + verbatim non-interactive block + Phases 0-3 (setup, intake, variable interpretation, generate: survey.json schema + time constants + best-practices application + render survey.html/preview.html/index.html + commit) | `feat(survey-design,T7): SKILL.md part 1 — shell + Phases 0-3 + survey.json schema` |
| T8 | `SKILL.md` part 2 — Phases 4-9 (reviewer subagent + contract + validation, apply critique, simulated-respondent + heuristic-stand-in disclaimer, viewer, export recipes + AskUserQuestion multiSelect, summary) + Anti-Patterns + Release prerequisites + Capture Learnings + Edge-cases table | `feat(survey-design,T8): SKILL.md part 2 — Phases 4-9 + anti-patterns + release prereqs + capture-learnings` |
| T9 | Release wiring: both `plugin.json` → `2.36.0` (byte-identical), README `### Utilities` row + standalone list, `CHANGELOG.md` `2.36.0` section, `~/.pmos/learnings.md` `## /survey-design` header | `chore(survey-design,T9): release wiring — bump to 2.36.0, README row, CHANGELOG` |
| TN | Final verification — see `task-tn.md` | (no code change) |

**Verification (static suite, all PASS):** `assert_survey_design_skill.sh` exit 0; `audit-recommended.sh -- .../survey-design/SKILL.md` PASS (0 unmarked AskUserQuestion checkpoints); `node --check survey-preview.js` exit 0; non-interactive block byte-identical to canonical; manifest version lines byte-identical at `2.36.0`; README + CHANGELOG carry the new skill; `survey-preview.js` `init()` smoke-tested via a Node DOM stub.

**Deferred to `/verify` + manual follow-up (transparently):** the full `--non-interactive` live integration run of `/survey-design` in a scratch repo (a nested LLM-driven multi-phase run; `tests/expected.yaml` records the assertions) and the manual `preview.html` browser walk (no browser available in this environment). Plan decisions D-P3 (static-check-first TDD — no JS/Python test runner exists for skill content) and the plan's own "if no browser is available, state so explicitly" hedge cover this.

**Deviations:** none affecting the implementation. The `CHANGELOG.md` running narrative trails the release tags (most-recent existing entry was `2.26.0`); T9 prepends the `2.36.0` section at the top in the existing style as planned — `/complete-dev` regenerates the changelog narrative.

**Next pipeline stage:** `/verify`.
