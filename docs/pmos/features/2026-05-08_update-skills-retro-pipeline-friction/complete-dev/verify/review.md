# /verify review — /complete-dev C3 PyPI signal

**Date:** 2026-05-08
**Scope:** feature (single Tier 2 finding: C3)
**Mode:** Lightweight inline review (skill-prose change, no runtime surface). **Deviation logged.**

## AC verification

| AC | Status | Outcome | Evidence |
|---|---|---|---|
| AC1 — Phase 5 lists 6th signal: pyproject.toml at `./` or `./backend/` | Verified | New bullet "6. `pyproject.toml` with `[project]` metadata at `./pyproject.toml` or `./backend/pyproject.toml`" added to Phase 5 enumeration | `plugins/pmos-toolkit/skills/complete-dev/SKILL.md` Phase 5 (line ~262) |
| AC2 — `reference/deploy-norms.md` gains signal section #6 with bash probe + parsing notes | Verified | New "### 6. pyproject.toml (PyPI publish via uv)" section with `tomllib`-based probe and parsing semantics | `plugins/pmos-toolkit/skills/complete-dev/reference/deploy-norms.md` lines 53–73 |
| AC3 — Recommendation logic table extended for PyPI-alone, PyPI+CI, PyPI+plugin-manifest | Verified | 3 new rows added in correct positions; PyPI+CI defers to CI per D4 | `plugins/pmos-toolkit/skills/complete-dev/reference/deploy-norms.md` recommendation table |
| AC4 — Phase 5 example block updated with PyPI-detected example | Verified | Second example block added showing `(1) pyproject.toml at ./pyproject.toml — package "<name>" v<version>` flow | `plugins/pmos-toolkit/skills/complete-dev/SKILL.md` Phase 5 |
| AC5 — Behavior unchanged when no `pyproject.toml` is present | Verified | Probe is gated by `[ -f "$f" ] || continue`; signal counts only when `[project]` table has `name`; unchanged code paths for the existing 5 signals | `reference/deploy-norms.md` probe block |
| AC6 — `argument-hint`, phase numbering, public contract unchanged | Verified | `argument-hint` frontmatter at SKILL.md line 5 unchanged; no new phases; phase numbering intact | `git diff HEAD --stat` shows 2 files changed in scope |

**Three-state rollup:** 6 Verified / 0 NA / 0 Unverified.

## Design decision verification

- **D1** — paths limited to `./pyproject.toml` and `./backend/pyproject.toml`: Verified in the bash probe loop.
- **D2** — recommended tool is `uv publish` (not `twine`/`poetry`): Verified in both SKILL.md example block and reference rubric.
- **D3** — `[project]` table required (not file existence alone): Verified in the parsing block ("A signal counts only when the `[project]` table is present with a `name` key").
- **D4** — combined CI + PyPI defers to CI: Verified in recommendation logic table row "CI auto-deploy + pyproject.toml | Skip local; trust CI".

## Open items

None.
