# /artifact Skill — v2.10.0 Smoke Test

**Date:** 2026-05-02
**Status:** Stub — to be filled in after first interactive run
**Owner:** Maneesh Dhabria

This file is the home for the inaugural smoke-test transcript. The skill was implemented across 16 tasks (16 commits, see `git log` for `feat(artifact): ...`). The interactive smoke test cannot be executed by the agent that built the skill — it requires invoking `/artifact create prd` in a fresh Claude Code session and observing behavior end-to-end.

---

## Smoke-test plan

### Setup

```bash
mkdir -p /tmp/artifact-smoke/features/2026-05-02_demo-flag
cat > /tmp/artifact-smoke/features/2026-05-02_demo-flag/01_requirements.md <<'EOF'
# Requirements — Demo Flag

## Problem
Sarah, a senior PM at a B2B SaaS company, can't easily share early prototypes
with her CEO because the production app gates everything behind auth. She
currently sends Loom videos, which take 15 min to produce per iteration.
12/30 PMs we interviewed described this exact frustration (research session
2026-04-15).

## Goals
- Cut prototype-share time from 15 min to <2 min for internal stakeholders.
- Maintain SOC2 audit trail.

## Out
- External (non-employee) prototype sharing — separate project.
EOF
```

### Invocation

In a fresh Claude Code session, with cwd set to `/tmp/artifact-smoke`:

```
/artifact create prd --tier lite --preset narrative
```

### Expected behavior

1. **Phase 0** — loads context from `/tmp/artifact-smoke`. No workstream → skips workstream context.
2. **Phase 2.1** — resolves built-in `prd` template; validates frontmatter + section IDs.
3. **Phase 2.2** — `--tier lite` flag bypasses auto-detection.
4. **Phase 2.3** — feature folder resolves to `2026-05-02_demo-flag/`.
5. **Phase 2.4** — reads `01_requirements.md`. No spec doc, no wireframes, no workstream.
6. **Phase 2.5** — gap interview filters preconditions for Lite tier. From the requirements input, `evidence-cited` (§2) is satisfied (12/30 quote present), `customer-named` is satisfied. Likely gap-questions:
   - §5 primary metric baseline + target — already present? "15 min → <2 min" is target; baseline implied. Should be auto-satisfied.
   - §5 mechanism for "why we expect <2 min movement" — likely a gap.
   - §6 wireframe link — gap (no wireframes).
   Expect **1–3 gap questions** in this run.
7. **Phase 2.6** — `--preset narrative` flag bypasses default.
8. **Phase 2.7** — generates 7-section PRD Lite. Frontmatter: type=prd, tier=lite, preset=narrative, sources=[01_requirements.md].
9. **Phase 3** — reviewer subagent runs against `eval.md`. Auto-applies high+medium findings. Max 2 loops.
10. **Phase 4** — summary printed; offers commit.
11. **Phase 5** — no workstream → skipped.
12. **Phase 6** — learnings capture phase.

---

## Capture during run

Replace each section below with actual observed values.

### Outputs
- Path written: `<fill in>`
- Section count: `<fill in>` (expect 7)
- Time-to-draft: `<fill in>` seconds
- Refinement loop iterations: `<1 or 2>`
- Findings (high/medium/low): `<N/M/K>`
- Auto-applied: `<count>`
- Deferred: `<count>`
- Gap questions asked: `<count + brief list>`

### Issues found during run
- (fill in any unexpected behavior, errors, prompt confusion, missing references)

### Decisions captured for next iteration
- (concrete tweaks to templates / SKILL.md / reviewer prompt based on what surfaced)

---

## Follow-up smoke tests (recommended)

After the PRD Lite run is clean, repeat with:

1. **PRD Full + tabular preset** on the same feature folder. Verify tabular_schema rendering for §5, §8 (User Stories), §10 (Risks).
2. **Experiment Design Doc Lite** on the same folder. Verify §9 Decision Criteria thresholds get gathered properly.
3. **Engineering Design Doc Lite** on the same folder. Verify §7 Alternatives (≥2 + boring option) and §3 existing-system-named gap question.
4. **Discovery Doc** on a less-defined input (just a problem hunch, no requirements doc). Verify §1 Decision and §2 Job Story preconditions trigger correct gap questions.
5. **`/artifact refine <path>`** on the previously-generated PRD — confirm it's a re-run and writes to `.refined.md`.
6. **`/artifact update <path>`** with a paste of synthetic stakeholder feedback — confirm Comment Resolution Log is appended and Findings Presentation Protocol fires.
7. **`/artifact template add` --quick** — author a tiny custom template at `~/.pmos/artifacts/templates/test-doc/`; verify lookup precedence and that it appears in `/artifact template list` with `[user]` source label.
8. **Slug collision** — try `/artifact template add` with slug `prd`. Should reject before any files are written.

---

## Implementation summary (for reference)

Built across 16 commits on main, version `2.10.0`:

```
6ec0a42 scaffold + version bump
d360e91 PRD template (later fixed: 0cd187b)
001cd87 experiment-design template
ae48926 eng-design template
fa82b3f discovery template
6d6b36a writing-style presets
427e7df reviewer subagent prompt
2270def SKILL.md Phase 0 + Phase 1
7c44685 Phase 2 create flow
5a2a662 Phase 3 refinement loop
e42c5e7 Phases 4-6 (save, workstream, learnings)
5597adc Refine flow
4a61bfa Update flow + Comment Resolution Log
29e4501 Template management
49e5a79 Preset management
(this commit) README + smoke test stub
```

Files:
- `plugins/pmos-toolkit/skills/artifact/SKILL.md` — 416 lines
- 4 templates × 2 files = 8 template files (template.md + eval.md)
- 4 preset files
- 1 reviewer-prompt.md

Total eval items across built-in templates: ~217 (PRD 62, ED 54, EDD 65, Discovery 36).
