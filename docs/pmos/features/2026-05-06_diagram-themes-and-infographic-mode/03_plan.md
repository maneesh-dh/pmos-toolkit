# /diagram — Themes + Infographic Mode — Implementation Plan

**Date:** 2026-05-06
**Spec:** `docs/superpowers/specs/2026-05-06-diagram-themes-and-infographic-mode-design.md`
**Grill report:** `docs/superpowers/specs/grills/2026-05-06_diagram-themes-and-infographic-mode-design.md`

---

## Overview

This plan implements the `/diagram` themes + infographic mode upgrade in three deployable phases:

- **Phase 1 — Theme foundation.** Move the existing house style into a `themes/technical/` directory, add `themes/_schema.json`, refactor `tests/run.py` and `eval/rubric.md` to read theme tokens instead of hardcoded constants. **No user-visible behavior change**; existing goldens pass under `theme=technical`.
- **Phase 2 — Editorial theme + role-keyed connectors.** Add `themes/editorial/`, extend the relationship model with a `role` field, implement `connectors.byRole` dispatch, ship the rubric override loader, and prove the editorial aesthetic via two new goldens.
- **Phase 3 — Infographic mode.** Add the `--mode` flag, Phase 6.6 wrapper, auto-generated copy with user-review checkpoint, caption auto-fit grid, ordinal-marker fallback, slim 4-item wrapper rubric, sidecar v2 fields, and Extend-flow handling.

**Done when:** running `python3 skills/diagram/tests/run.py` exits 0 with all existing goldens passing under `theme=technical`, three new editorial goldens (flow-fanin, radial-mindmap, infographic-full) passing, and three new editorial defects correctly detected; SKILL.md cites theme tokens; `--theme editorial --mode infographic` produces a passing infographic SVG end-to-end on a sample input; old top-level `style.md` is deleted.

**Execution order:**

```
Phase 1 (foundation, no behavior change)
  T1  ──> T2  ──> T3  ──> T4  ──> T5  ──> T6  ──> T7 (phase verify)
                                      ↓
Phase 2 (editorial theme)
  T8  ──> T9  ──> T10 ──> T11 ──> T12 ──> T13 ──> T14 (phase verify)
                                      ↓
Phase 3 (infographic mode)
  T15 ──> T16 ──> T17 ──> T18 ──> T19a ──> T19b ──> T19c ──> T20 ──> T21 ──> T22 ──> T23 ──> T24 (phase verify)
```

T1 (the JSON Schema) and T15 (the editorial-v1 layout spec) can each start before their phase begins if a developer wants to parallelize doc-writing — flagged `[P]` in the task headers — but defaults are sequential.

---

## Decision Log

| # | Decision | Options Considered | Rationale |
|---|----------|-------------------|-----------|
| D1 | One plan with three `## Phase N` groupings rather than three separate plans | (a) split into three plans, (b) two plans, (c) one plan with phases | User picked (c). Phase groupings preserve the deployable-slice property and trigger /verify at each phase boundary. |
| D2 | Plan doc lives at `docs/superpowers/specs/` alongside spec | (a) here, (b) pmos `docs/pmos/01_diagram-themes/` feature folder | (a) — repo has no pmos feature folder structure yet; co-locating with the spec keeps related artifacts together. /execute and /verify still find the file via the explicit path. |
| D3 | Reconcile stable rubric IDs against existing rubric.md content, not the spec's table verbatim | (a) restructure existing 7 items to match spec's IDs, (b) keep existing items, assign stable IDs that semantically match | (b) — existing items already capture concrete reviewer behavior; renaming preserves test fixtures and reviewer prompt grounding. T9 documents the mapping. |
| D4 | `tests/run.py` gains a PyYAML dependency to read `theme.yaml` | (a) PyYAML, (b) parse YAML manually, (c) author themes as JSON | (a) — themes are human-authored config; YAML's comments and trailing keys matter. PyYAML ships in most Python distributions; we add a stdlib-only fallback message if missing. |
| D5 | Drop v1 sidecar read support entirely (no compat shim) | (a) drop, (b) tolerant-read v1, (c) v1 with one-release deprecation | (a) — user explicit choice in grill. v1 sidecars are local files, low cost to ignore; treating them as absent triggers the existing missing-sidecar path. |
| D6 | Role-style-consistency rubric uses sidecar role tags as ground truth, not stroke-pattern clustering | (a) sidecar-driven (deterministic), (b) cluster strokes from SVG (heuristic) | (a) — Phase 3 already has the role assignment in hand; persisting it to the sidecar lets the rubric verify cheaply and unambiguously. |
| D7 | Wrapper copy generation runs inline (no subagent dispatch), even at high rigor | (a) inline always, (b) subagent at high rigor like the vision review | (a) — the prompt is short and structured (returns JSON); subagent overhead is not worth it. The user-review checkpoint is the quality gate. |
| D8 | Caption count clamp: if model returns 6+, drop weakest; if 1–2, re-prompt once then fall back to suppressing caption block | (a) silent clamp, (b) re-prompt all, (c) clamp + re-prompt-on-too-few | (c) — too many is editorial trim; too few likely reflects content that doesn't deserve captions. Sidecar logs the clamp/suppression. |
| D9 | Ordinal markers in the diagram interior render as Unicode geometric chars (●▲■◆★) drawn as `<text>` at 12px ink near the referenced element's bbox | (a) Unicode text, (b) draw polygons as `<path>` | (a) — Unicode glyphs render in any font, no extra geometry, easier to position. Renderer hard-gate already requires fonts that ship these glyphs. |
| D10 | foreignObject is skipped for rsvg/cairosvg regardless of font-metric availability; warning emitted; heuristic line-breaks used | (a) skip on non-Playwright, (b) try foreignObject and let renderer fail | (a) — silent partial-render is worse than a documented heuristic. The slim wrapper rubric's `wrapper-text-fit` item catches overflow. |
| D11 | Sidecar `relationships[]` gains a plan-level `_svgId` field to let `role-style-consistency` map sidecar role tags to SVG element IDs | (a) add `_svgId`, (b) cluster strokes from SVG to infer role | (a) — deterministic, no heuristics. Field is plan-level (not in spec); documented in `reference/sidecar-schema.md` and consumed only by `check_role_style_consistency()`. Underscore prefix signals it's a binding-not-semantic field. |

---

## Code Study Notes

- **`tests/run.py`** (631 lines) hardcodes `PALETTE` at line 26 and threads it through `evaluate(svg_path)`. Refactor: lift palette into a theme-loading helper; `evaluate(svg_path, theme="technical")` becomes the new signature; `run_corpus()` iterates fixture directories grouped by theme.
- **`eval/rubric.md`** has 7 numbered items today, all behavioral and reviewer-friendly. Stable-ID renaming keeps content; T9 records the mapping. Sidecar `evalSummary.visionItems` is keyed `"1".."7"` today — schema bumps to keyed by stable ID.
- **`SKILL.md`** quotes the palette tokens directly from `style.md` in Phase 3 step 4. Update to "Apply the active theme's tokens — palette from `palette` block, typography from `typography` block, etc."
- **`reference/sidecar-schema.md`** versioning policy currently says "newer version refuses". v2 keeps that rule (a v3 reader-side concern); but the v1-on-v2 read is now "treat as absent" per D5.
- **`examples/style-atoms/`** has 8 visual primitives. They are atoms (palette, type-specimen, swatches, single-node, single-connector, edge-label, legend) — not templates. They move to `themes/technical/atoms/` verbatim.
- **No PyYAML import exists in the repo today.** Adding it for theme loading is the only new runtime dependency.
- **Phase 1 entity model** in SKILL.md lines 93–98 already names the relationship shape inline. Adding `role?: enum` is a one-line schema bump.

---

## Prerequisites

- Working directory: `/Users/maneeshdhabria/Desktop/Projects/agent-skills`.
- Python 3.10+ available on PATH.
- `pip install pyyaml` (or available via system Python).
- A renderer for end-of-phase verification: `brew install librsvg` for `rsvg-convert` (recommended for tests; Playwright MCP for Phase 3 final).
- Working `/diagram --selftest` baseline before T1: `python3 plugins/pmos-toolkit/skills/diagram/tests/run.py` exits 0 today. Capture output for regression diff.
- A clean working tree on `main` or a feature branch.

---

## File Map

| Action | File | Responsibility |
|--------|------|---------------|
| Create | `plugins/pmos-toolkit/skills/diagram/themes/_schema.json` | Strict positive-list JSON Schema for `theme.yaml`; rejects unknown keys |
| Create | `plugins/pmos-toolkit/skills/diagram/themes/technical/theme.yaml` | Codifies current style.md tokens; mixingPermitted=false; waive=[]; add=[]; infographic.supported=false |
| Move   | `plugins/pmos-toolkit/skills/diagram/style.md` → `themes/technical/style.md` | Verbatim relocation |
| Move   | `plugins/pmos-toolkit/skills/diagram/examples/style-atoms/` → `themes/technical/atoms/` | Verbatim relocation |
| Create | `plugins/pmos-toolkit/skills/diagram/themes/editorial/theme.yaml` | Editorial tokens per spec §5 |
| Create | `plugins/pmos-toolkit/skills/diagram/themes/editorial/style.md` | Human-readable editorial spec mirroring the YAML |
| Create | `plugins/pmos-toolkit/skills/diagram/themes/editorial/atoms/{eyebrow-mono,dashed-container,pastel-chip-stack,computation-block,return-loop-arrow}.svg` | 5 visual primitives for the editorial theme |
| Create | `plugins/pmos-toolkit/skills/diagram/themes/editorial/infographic/editorial-v1.md` | Infographic layout zone spec per spec §7 |
| Modify | `plugins/pmos-toolkit/skills/diagram/tests/run.py` | Add `theme` param, theme.yaml loader, schema validator; iterate fixtures by theme; expose `evaluate_with_theme()` |
| Modify | `plugins/pmos-toolkit/skills/diagram/eval/rubric.md` | Stable IDs; theme-aware reviewer prompt template; document waive/add semantics |
| Modify | `plugins/pmos-toolkit/skills/diagram/eval/code-metrics.md` | Note that palette/type tables come from active theme |
| Modify | `plugins/pmos-toolkit/skills/diagram/reference/sidecar-schema.md` | v2 schema; theme/mode/role/wrappedText/wrapperLayout/captionAnchorMode/wrapperRubricResults; stable rubric IDs in visionItems; remove v1 tolerant-read |
| Modify | `plugins/pmos-toolkit/skills/diagram/SKILL.md` | Phase 0 theme load + schema validate; Phase 1 entity model adds `role`; Phase 3 cites theme tokens + dispatches byRole; Phase 5 theme-aware rubric; Phase 6.6 added; anti-patterns updated |
| Create | `plugins/pmos-toolkit/skills/diagram/tests/golden/editorial/{editorial-flow-fanin,editorial-radial-mindmap,editorial-infographic-full}.svg` + `.expected.json` | New goldens proving theme works for a flow, a non-flow layout, and a full infographic |
| Create | `plugins/pmos-toolkit/skills/diagram/tests/defects/editorial/{cream-but-mixed-connectors-within-one-role,infographic-caption-color-not-in-diagram,eyebrow-not-uppercase}.svg` | New defects for editorial-specific rules |
| Delete | `plugins/pmos-toolkit/skills/diagram/style.md` (top-level, after move) | Removed; references update to `themes/technical/style.md` |

---

## Risks

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| PyYAML not installed in user environment | Medium | T4 detects ImportError and prints `pip install pyyaml` install instruction with non-zero exit. Document in SKILL.md Phase 0. |
| Existing goldens fail after run.py refactor due to subtle palette-loading regression | Medium | T7 runs full corpus before committing T2–T6. T4 includes a regression-snapshot test that runs evaluate() against `01-three-step-flow.svg` and asserts exact code_score/hard_fails parity with pre-refactor output. |
| Editorial theme palette pairs (`#1E3A8A`/`#D9421C` on `#F4EFE6`) flunk WCAG AA | Low | T10 includes a contrast unit test verifying both pairs ≥ 4.5:1 against cream surface BEFORE building atoms. If they fail, adjust hexes per AA before proceeding. |
| Auto-generated wrapper copy is poor across diverse inputs | Medium | User-review checkpoint in T16; ordinal-marker fallback (T18) handles the worst structural failure (no color signal); slim wrapper rubric (T20) catches typographic overflow. |
| `<foreignObject>` rendering inconsistency catches a silent overflow | Medium | T19 detects renderer at draw time and skips foreignObject for rsvg/cairosvg unconditionally. T20's `wrapper-text-fit` item is the second line of defense. |
| Role enum becomes a leaky abstraction (authors over-use `default`) | Low | T11 enforces: when `connectors.mixingPermitted: true` AND `role` is null, the rubric flags it as a `role-style-consistency` fail. Forces explicit role tagging in editorial diagrams. |
| Sidecar v2 cutover breaks any in-flight extends on existing diagrams | Low | D5 already accepts this — v1 sidecars are treated as absent, falling through to fresh-draw collision flow. Documented in spec §12. |

---

## Rollback

This change has no DB migrations or deploys. Rollback = `git revert` of phase-boundary commits:
- After Phase 1: `git revert <T7 commit>..<T1 commit>` restores the pre-theme structure. The original `style.md` is recoverable from git history.
- After Phase 2: `git revert <T14 commit>..<T8 commit>` reverts editorial only; technical theme keeps working.
- After Phase 3: `git revert <T24 commit>..<T15 commit>` reverts infographic only.

No external system changes required.

---

## Tasks

## Phase 1: Theme foundation (no behavior change)

This phase ships when existing goldens pass under `theme=technical` and `--theme technical` (default) produces output bit-identical to today.

### T1 [P]: Write `themes/_schema.json` (strict positive-list JSON Schema)

**Goal:** Define the JSON Schema that validates all `theme.yaml` files at load time. Layout-related keys MUST NOT appear.
**Spec refs:** §4 (Layout independence enforcement), §5 (theme.yaml schema)

**Files:**
- Create: `plugins/pmos-toolkit/skills/diagram/themes/_schema.json`
- Test:   `plugins/pmos-toolkit/skills/diagram/tests/test_theme_schema.py`

**Steps:**

- [ ] Step 1: Write the failing test
  ```python
  # tests/test_theme_schema.py
  import json, pathlib, pytest
  from jsonschema import validate, ValidationError

  SCHEMA_PATH = pathlib.Path(__file__).parents[1] / "themes" / "_schema.json"

  def load_schema():
      return json.loads(SCHEMA_PATH.read_text())

  MINIMAL = {
      "name": "x",
      "displayName": "X",
      "surface": {"background": "#FFFFFF"},
      "palette": {"ink": "#000000", "inkMuted": "#444444", "accents": []},
      "typography": {"body": {"stack": "sans-serif", "weights": [400], "sizes": [12]}},
      "connectors": {"mixingPermitted": False},
      "arrowheads": {"style": "filled-triangle", "sizes": {"default": "8x6"}},
      "rubricOverrides": {"waive": [], "add": []},
      "infographic": {"supported": False},
  }

  def test_minimal_theme_validates():
      validate(MINIMAL, load_schema())

  def test_unknown_top_level_key_rejected():
      bad = {**MINIMAL, "direction": "top-down"}  # layout sneak
      with pytest.raises(ValidationError):
          validate(bad, load_schema())

  def test_layout_keys_explicitly_rejected():
      for key in ("direction", "canvas", "nodePositions", "readingOrder", "placement", "layout"):
          with pytest.raises(ValidationError):
              validate({**MINIMAL, key: "anything"}, load_schema())

  def test_extends_rejected_in_v1():
      with pytest.raises(ValidationError):
          validate({**MINIMAL, "extends": "technical"}, load_schema())
  ```

- [ ] Step 2: Run test, expect FAIL
  Run: `cd plugins/pmos-toolkit/skills/diagram && pytest tests/test_theme_schema.py -v`
  Expected: FAIL with FileNotFoundError on `_schema.json`.

- [ ] Step 3: Write `themes/_schema.json`. Top-level `properties` enumerates exactly: `name`, `displayName`, `surface`, `palette`, `typography`, `connectors`, `arrowheads`, `chips`, `nodeChrome`, `rubricOverrides`, `infographic`. Set `"additionalProperties": false`. Each nested object also sets `additionalProperties: false`. Required: all top-level keys except `chips`, `nodeChrome`. Reference spec §5 for the example shape.

- [ ] Step 4: Run test, expect PASS.

- [ ] Step 5: Commit
  ```
  git add plugins/pmos-toolkit/skills/diagram/themes/_schema.json plugins/pmos-toolkit/skills/diagram/tests/test_theme_schema.py
  git commit -m "feat(diagram): theme.yaml positive-list JSON schema"
  ```

**Inline verification:**
- `pytest tests/test_theme_schema.py -v` → 4 passed
- Schema is parseable: `python3 -c "import json,pathlib; json.loads(pathlib.Path('plugins/pmos-toolkit/skills/diagram/themes/_schema.json').read_text())"`

---

### T2: Move `style.md` and write `themes/technical/theme.yaml`

**Goal:** Relocate the existing house style under `themes/technical/`; codify its tokens in `theme.yaml`. Top-level `style.md` is **deleted** (no pointer file).
**Spec refs:** §10 step 1, step 2

**Files:**
- Move:   `plugins/pmos-toolkit/skills/diagram/style.md` → `plugins/pmos-toolkit/skills/diagram/themes/technical/style.md`
- Create: `plugins/pmos-toolkit/skills/diagram/themes/technical/theme.yaml`
- Test:   `plugins/pmos-toolkit/skills/diagram/tests/test_theme_schema.py` (extend)

**Steps:**

- [ ] Step 1: Extend the existing test file:
  ```python
  def test_technical_theme_validates_against_schema():
      import yaml
      path = pathlib.Path(__file__).parents[1] / "themes" / "technical" / "theme.yaml"
      theme = yaml.safe_load(path.read_text())
      validate(theme, load_schema())
      assert theme["name"] == "technical"
      assert theme["connectors"]["mixingPermitted"] is False
      assert theme["infographic"]["supported"] is False
      assert theme["rubricOverrides"]["waive"] == []
      assert theme["rubricOverrides"]["add"] == []
      # Palette must include ink/inkMuted/accents/warn matching today's style.md
      assert theme["palette"]["ink"].upper() == "#0F172A"
      assert theme["palette"]["inkMuted"].upper() == "#475569"
      assert theme["palette"]["warn"].upper() == "#B91C1C"
      assert any(a["hex"].upper() == "#2563EB" for a in theme["palette"]["accents"])
  ```

- [ ] Step 2: Run test, expect FAIL with FileNotFoundError on `themes/technical/theme.yaml`.

- [ ] Step 3: `git mv plugins/pmos-toolkit/skills/diagram/style.md plugins/pmos-toolkit/skills/diagram/themes/technical/style.md`. Verify `git status` shows rename, not delete+add.

- [ ] Step 4: Author `themes/technical/theme.yaml` with the tokens from the moved style.md verbatim. Single accent (`#2563EB`), warn `#B91C1C`, ink `#0F172A`, inkMuted `#475569`, surface `#FFFFFF`, surface-muted `#F4F5F7` (mapped under `palette.surface` and `palette.surfaceMuted`). Typography mirrors §5.1 (sizes 12/14/16/20, weights 400/600). `connectors.mixingPermitted: false`. `connectors.byRole.default` only.

- [ ] Step 5: Run test, expect PASS.

- [ ] Step 6: Commit
  ```
  git add -A
  git commit -m "refactor(diagram): move style.md to themes/technical/; add theme.yaml"
  ```

**Inline verification:**
- `pytest tests/test_theme_schema.py -v` → 5 passed
- `git log --diff-filter=R --name-status -1` shows `R  plugins/.../style.md -> plugins/.../themes/technical/style.md`
- File at old path is gone: `! test -f plugins/pmos-toolkit/skills/diagram/style.md`

---

### T3: Move `examples/style-atoms/` → `themes/technical/atoms/`

**Goal:** Atoms live under their owning theme.
**Spec refs:** §10 step 3, §11 file-tree

**Files:**
- Move: `plugins/pmos-toolkit/skills/diagram/examples/style-atoms/` → `plugins/pmos-toolkit/skills/diagram/themes/technical/atoms/`

**Steps:**

- [ ] Step 1: `git mv plugins/pmos-toolkit/skills/diagram/examples/style-atoms plugins/pmos-toolkit/skills/diagram/themes/technical/atoms`

- [ ] Step 2: Grep for any in-repo reference to the old path: `grep -r "examples/style-atoms" plugins/pmos-toolkit/skills/diagram/ docs/`. Update each to `themes/technical/atoms/`.

- [ ] Step 3: Remove the now-empty `examples/` directory: `rmdir plugins/pmos-toolkit/skills/diagram/examples/ 2>/dev/null || true`.

- [ ] Step 4: Commit
  ```
  git add -A
  git commit -m "refactor(diagram): move style-atoms into themes/technical/atoms/"
  ```

**Inline verification:**
- `ls plugins/pmos-toolkit/skills/diagram/themes/technical/atoms/ | wc -l` → 9 (8 atoms + README.md, matching pre-move count)
- `! test -d plugins/pmos-toolkit/skills/diagram/examples`
- `grep -r "examples/style-atoms" plugins/pmos-toolkit/skills/diagram/ docs/` → no matches

---

### T4: Refactor `tests/run.py` to be theme-aware

**Goal:** `evaluate(svg_path, theme="technical")` reads `themes/<theme>/theme.yaml` and validates against tokens from there, not hardcoded `PALETTE`.
**Spec refs:** §9 selftest changes

**Files:**
- Modify: `plugins/pmos-toolkit/skills/diagram/tests/run.py`
- Modify: `plugins/pmos-toolkit/skills/diagram/eval/code-metrics.md` (doc update — token tables now sourced from active theme)
- Create: `plugins/pmos-toolkit/skills/diagram/tests/test_theme_loader.py`

**Steps:**

- [ ] Step 1: Capture pre-refactor output for regression diff:
  ```bash
  cd plugins/pmos-toolkit/skills/diagram && python3 tests/run.py > /tmp/diagram-baseline.txt
  ```

- [ ] Step 2: Write new test file:
  ```python
  # tests/test_theme_loader.py
  import pathlib, pytest, sys
  HERE = pathlib.Path(__file__).parent
  sys.path.insert(0, str(HERE))
  import run

  def test_load_theme_returns_palette_dict():
      theme = run.load_theme("technical")
      assert "#2563EB" in {a["hex"].upper() for a in theme["palette"]["accents"]}
      assert theme["palette"]["ink"].upper() == "#0F172A"

  def test_load_unknown_theme_raises():
      with pytest.raises(FileNotFoundError):
          run.load_theme("nonexistent")

  def test_load_theme_validates_against_schema():
      # Inject a malformed theme into a tmp dir and assert it raises
      # (use monkeypatch + a tmp path)
      ...

  def test_evaluate_with_explicit_theme_matches_default():
      svg = HERE / "golden" / "01-three-step-flow.svg"
      a = run.evaluate(svg)                         # default theme=technical
      b = run.evaluate(svg, theme="technical")
      assert a["code_score"] == b["code_score"]
      assert a["hard_fails"] == b["hard_fails"]
  ```

- [ ] Step 3: Run, expect FAIL on `load_theme` not defined.

- [ ] Step 4: In `run.py`:
  - Add `import yaml` (with a try/except that prints `pip install pyyaml` and exits 2 on ImportError).
  - Add `load_theme(name: str) -> dict` that resolves `themes/<name>/theme.yaml`, parses YAML, validates against `themes/_schema.json` via `jsonschema.validate`. Raises `FileNotFoundError` if theme missing.
  - Change `evaluate(svg_path)` → `evaluate(svg_path, theme: str = "technical")`. Replace the module-level `PALETTE` with `palette = build_palette_set(load_theme(theme))` computed inside `evaluate`. `build_palette_set` returns the union of `ink`, `inkMuted`, `warn`, accent hexes, surface, surfaceMuted, and any `categoryChips` hexes.
  - `run_corpus()` keeps iterating `golden/*.svg` and `defects/*.svg` at top level under `theme=technical`. Phase-2-introduced sub-dirs come later.

- [ ] Step 5: Run new tests, expect PASS.

- [ ] Step 6: Update `eval/code-metrics.md` documentation to reflect the theme-aware refactor: replace the hardcoded palette table reference with "the active theme's `palette` block (from `themes/<theme>/theme.yaml`); the contrast metric validates against tokens declared there." Note that token tables in this doc are now examples for the technical theme, not authoritative.

- [ ] Step 7: Diff regression:
  ```bash
  python3 tests/run.py > /tmp/diagram-after.txt
  diff /tmp/diagram-baseline.txt /tmp/diagram-after.txt
  ```
  Expected: empty diff. If any line differs, fix before committing.

- [ ] Step 8: Commit
  ```
  git add -A
  git commit -m "refactor(diagram): theme-aware evaluate(); load palette from theme.yaml"
  ```

**Inline verification:**
- `pytest tests/test_theme_loader.py -v` → 4 passed
- `python3 tests/run.py` exits 0 with all goldens passing
- Regression diff is empty

---

### T5: Update `SKILL.md` Phase 0 to load theme + Phase 3 to cite theme tokens

**Goal:** SKILL.md reads the active theme in Phase 0 and references its tokens (not hardcoded #2563EB) in Phase 3 instructions.
**Spec refs:** §10 step 6, §4 architecture

**Files:**
- Modify: `plugins/pmos-toolkit/skills/diagram/SKILL.md`
- Test: visual diff (no automated test — content correctness verified by Phase 2 goldens passing under both themes)

**Steps:**

- [ ] Step 1: In Phase 0, add a new step before "Read style.md":
  ```
  4. **Resolve `--theme`** (default `technical`). Read `themes/<theme>/theme.yaml`. Validate against `themes/_schema.json`. If schema validation fails, print error and exit 2.
  5. **Read `themes/<theme>/style.md`** end-to-end. You will be quoting its tokens throughout.
  ```
  Remove the old "Read style.md" pointing at top-level path.

- [ ] Step 2: In Phase 3 step 4, replace hardcoded color list with: "Apply the active theme's tokens strictly: palette from `theme.yaml` `palette` block; typography sizes/weights from `typography`; stroke weights from `nodeChrome.primaryStroke` and theme-defined defaults; corner radii from `nodeChrome.primaryRadius` / chip radii; spacing on the 4-px grid (global)."

- [ ] Step 3: In Phase 3 step 6, replace "ONLY {6-color list}" with "ONLY colors declared in the active theme's `palette` block."

- [ ] Step 4: Update the file-map at the bottom to point `style.md` under `themes/technical/style.md`; add `themes/_schema.json`.

- [ ] Step 5: Update anti-patterns: replace "Do NOT use colors outside the 6-token palette (style.md §5.1)" with "Do NOT use colors outside the active theme's declared palette."

- [ ] Step 6: Run `python3 tests/run.py` to confirm no regression.

- [ ] Step 7: Commit
  ```
  git add plugins/pmos-toolkit/skills/diagram/SKILL.md
  git commit -m "docs(diagram): SKILL.md cites theme tokens; Phase 0 loads theme"
  ```

**Inline verification:**
- `grep -n "style.md" plugins/pmos-toolkit/skills/diagram/SKILL.md` shows only theme-relative paths, no top-level reference.
- `python3 plugins/pmos-toolkit/skills/diagram/tests/run.py` exits 0.

---

### T6: Bump sidecar to v2; remove v1 read; add `theme` and `mode` fields

**Goal:** Sidecar `schemaVersion: 2`. v1 sidecars treated as absent (no tolerant-read).
**Spec refs:** §4 sidecar v2, §10 step 4, D5

**Files:**
- Modify: `plugins/pmos-toolkit/skills/diagram/reference/sidecar-schema.md`
- Modify: `plugins/pmos-toolkit/skills/diagram/SKILL.md` (Phase 1 sidecar-read logic, Phase 7 sidecar-write logic)
- Test:   `plugins/pmos-toolkit/skills/diagram/tests/test_sidecar.py`

**Steps:**

- [ ] Step 1: Write tests:
  ```python
  # tests/test_sidecar.py
  import json, pathlib, sys, tempfile
  HERE = pathlib.Path(__file__).parent
  sys.path.insert(0, str(HERE))
  # NOTE: read_sidecar/write_sidecar are new helpers in run.py (or a new module)

  def test_v2_sidecar_round_trips():
      from run import read_sidecar, write_sidecar
      with tempfile.TemporaryDirectory() as d:
          p = pathlib.Path(d) / "x.diagram.json"
          payload = {
              "schemaVersion": 2,
              "concept": "test",
              "theme": "technical",
              "mode": "diagram",
              "approach": "left-right",
              "alternativesConsidered": [],
              "canvas": {"aspect": "16:10", "width": 1280, "height": 800},
              "entities": [],
              "relationships": [],
              "positions": {},
              "colorAssignments": {},
              "evalSummary": {},
              "createdAt": "2026-05-06T00:00:00Z",
              "createdBy": "pmos-toolkit:diagram@v2",
          }
          write_sidecar(p, payload)
          loaded = read_sidecar(p)
          assert loaded["schemaVersion"] == 2
          assert loaded["theme"] == "technical"
          assert loaded["mode"] == "diagram"

  def test_v1_sidecar_treated_as_absent():
      from run import read_sidecar
      with tempfile.TemporaryDirectory() as d:
          p = pathlib.Path(d) / "x.diagram.json"
          p.write_text(json.dumps({"schemaVersion": 1, "concept": "old"}))
          assert read_sidecar(p) is None  # v1 ignored entirely
  ```

- [ ] Step 2: Run, expect FAIL.

- [ ] Step 3: Add `read_sidecar(path) -> dict | None` and `write_sidecar(path, payload)` to `run.py` (or split into `tests/sidecar.py` if `run.py` is getting large; either is fine, prefer extracted module if `run.py` exceeds ~700 lines after this PR). `read_sidecar` returns `None` when the file is missing OR when `schemaVersion != 2`.

- [ ] Step 4: Update `reference/sidecar-schema.md`:
  - Bump `schemaVersion: 2`.
  - Add fields: `theme: "technical|editorial"`, `mode: "diagram|infographic"`.
  - Update `relationships[]` shape to include optional `role`.
  - Document v2-and-later policy: "Read older version → treat as absent. Read newer version → refuse."
  - Update migration table: `1 → 2: not supported; v1 sidecars are ignored.`

- [ ] Step 5: In SKILL.md Phase 1, change "Apply tolerant-read per `reference/sidecar-schema.md` (refuse only if `schemaVersion` is newer than current `1`)" to "Read sidecar via `read_sidecar()`; if it returns `None` (missing or pre-v2), treat as no sidecar present (skip extend/redraw flow; Phase 1 collision logic falls through to overwrite/suffix prompt)."

- [ ] Step 6: In SKILL.md Phase 7, write_sidecar payload now includes `theme`, `mode: "diagram"`, and `relationships[].role` (where assigned).

- [ ] Step 7: Run all tests + selftest:
  ```
  pytest tests/test_sidecar.py tests/test_theme_loader.py tests/test_theme_schema.py -v
  python3 tests/run.py
  ```

- [ ] Step 8: Commit
  ```
  git add -A
  git commit -m "feat(diagram): sidecar v2 with theme/mode fields; drop v1 read"
  ```

**Inline verification:**
- `pytest -v` over the three test files → all pass.
- `python3 tests/run.py` exits 0.

---

### T7: Phase 1 verify — foundation is invisible to existing users

**Goal:** Confirm Phase 1 is behaviorally a no-op for current `/diagram` users.

- [ ] **Lint:** `python3 -c "import ast; ast.parse(open('plugins/pmos-toolkit/skills/diagram/tests/run.py').read())"` — parses cleanly.
- [ ] **All Python tests:** `cd plugins/pmos-toolkit/skills/diagram && pytest tests/ -v` — all pass.
- [ ] **Existing selftest unchanged:** `python3 tests/run.py` exits 0; output matches pre-Phase-1 baseline modulo ordering. Diff against `/tmp/diagram-baseline.txt` from T4 should be empty.
- [ ] **No top-level style.md:** `! test -f plugins/pmos-toolkit/skills/diagram/style.md`.
- [ ] **All references updated:** `grep -rn 'style\.md' plugins/pmos-toolkit/skills/diagram/ docs/` shows only `themes/technical/style.md` and `themes/editorial/style.md` references (the latter from spec docs).
- [ ] **Manual spot check:** Run `/diagram "three boxes left to right"` end-to-end (fresh, no source). Confirm output SVG is identical in appearance to a pre-T1 run with the same input.
- [ ] **Cleanup:** `rm /tmp/diagram-baseline.txt /tmp/diagram-after.txt`.

If any item fails, do NOT proceed to Phase 2. Phase boundary commit:
```
git tag diagram-phase1-complete
```

---

## Phase 2: Editorial theme + role-keyed connectors

This phase ships when `--theme editorial` produces a passing diagram on the reference fan-in flow and the technical theme remains untouched.

### T8: Add `role` to relationship schema; record in sidecar

**Goal:** Phase 1 entity model gains optional `role: contribution|emphasis|feedback|dependency|reference`. Sidecar writer persists it.
**Spec refs:** §4 relationship schema, D6

**Files:**
- Modify: `plugins/pmos-toolkit/skills/diagram/SKILL.md` (Phase 1 entity model section)
- Modify: `plugins/pmos-toolkit/skills/diagram/reference/sidecar-schema.md` (relationships[] shape)
- Test:   `plugins/pmos-toolkit/skills/diagram/tests/test_sidecar.py` (extend)

**Steps:**

- [ ] Step 1: Extend test:
  ```python
  def test_v2_sidecar_relationships_carry_role():
      from run import read_sidecar, write_sidecar
      with tempfile.TemporaryDirectory() as d:
          p = pathlib.Path(d) / "x.diagram.json"
          payload = {  # ... minimal v2 payload ...
              "relationships": [
                  {"from": "a", "to": "b", "kind": "directed", "role": "feedback"},
                  {"from": "b", "to": "c", "kind": "directed"},  # role optional
              ],
              # ... other required fields ...
          }
          write_sidecar(p, payload)
          loaded = read_sidecar(p)
          assert loaded["relationships"][0]["role"] == "feedback"
          assert "role" not in loaded["relationships"][1] or loaded["relationships"][1].get("role") is None
  ```

- [ ] Step 2: FAIL; then update `write_sidecar` to passthrough `role` (it should already passthrough since it's a dict). FAIL likely already PASSes if write_sidecar is dict-passthrough — that's fine, the test then becomes a contract regression test.

- [ ] Step 3: SKILL.md Phase 1 step 3 update:
  ```
  relationships = [{id, label?, kind: directed|bidirectional, role?: contribution|emphasis|feedback|dependency|reference}]
  ```
  Add a paragraph: "When the active theme has `connectors.mixingPermitted: true`, Phase 3 MUST assign a role to every relationship. When false, `role` is optional and ignored."

- [ ] Step 4: sidecar-schema.md `relationships[]` example gains the `role` field; document the enum.

- [ ] Step 5: Run tests, expect PASS.

- [ ] Step 6: Commit
  ```
  git add -A
  git commit -m "feat(diagram): relationship.role field; persisted in sidecar v2"
  ```

**Inline verification:**
- `pytest tests/test_sidecar.py -v` — all pass (5 cases).
- `grep -n "role" plugins/pmos-toolkit/skills/diagram/SKILL.md` shows the new entity-model section.

---

### T9: Reconcile rubric to stable IDs; implement waive/add loader

**Goal:** Each of the 7 existing rubric items gets a stable ID. Reviewer prompt template is parameterized by `theme.rubricOverrides.{waive,add}`.
**Spec refs:** §8 rubric override loader, D3

**Files:**
- Modify: `plugins/pmos-toolkit/skills/diagram/eval/rubric.md`
- Create: `plugins/pmos-toolkit/skills/diagram/tests/test_rubric_loader.py`
- Modify: `plugins/pmos-toolkit/skills/diagram/tests/run.py` — add `build_rubric_prompt(theme: dict) -> str`

**Steps:**

- [ ] Step 1: Reconciliation map (record in eval/rubric.md as a one-time migration note):

  | Stable ID | Old item | Notes |
  |---|---|---|
  | `primary-emphasis` | 1. Primary node emphasis | renamed only |
  | `clear-entry` | 2. Clear starting point | renamed only |
  | `legibility` | 3. Label legibility at 50% scale | renamed only |
  | `legend-coverage` | 4. Legend coverage | renamed only |
  | `arrowhead-consistency` | 5. Arrowhead consistency | renamed only |
  | `style-atom-match` | 6. Style atoms match | renamed only |
  | `visual-balance` | 7. Visual balance (advisory) | renamed only |

  The spec's `single-accent`, `single-connector-style`, `whitespace`, `hierarchy`, `informational-fit` IDs **do not become standalone items** — they're enforced by `style-atom-match` (theme-aware) and `visual-balance`. Rationale: behavioral content stays exactly as it is today; the renaming is purely cosmetic; per-theme palette/connector rules ride on the theme-aware `style-atom-match` check (the reviewer is shown the active theme's atoms and asked to verify match).

- [ ] Step 2: Write test:
  ```python
  # tests/test_rubric_loader.py
  import pathlib, sys
  HERE = pathlib.Path(__file__).parent
  sys.path.insert(0, str(HERE))
  import run

  def test_technical_theme_includes_all_seven_items():
      theme = run.load_theme("technical")
      prompt = run.build_rubric_prompt(theme)
      for sid in ["primary-emphasis", "clear-entry", "legibility",
                  "legend-coverage", "arrowhead-consistency",
                  "style-atom-match", "visual-balance"]:
          assert sid in prompt, f"Missing item: {sid}"

  def test_waive_drops_item_from_prompt():
      theme = run.load_theme("technical")
      theme["rubricOverrides"]["waive"] = ["legend-coverage"]
      prompt = run.build_rubric_prompt(theme)
      assert "legend-coverage" not in prompt
      assert "primary-emphasis" in prompt  # untouched

  def test_add_appends_item_to_prompt():
      theme = run.load_theme("technical")
      theme["rubricOverrides"]["add"] = [
          {"id": "custom-x", "prompt": "is X true?", "evidenceHint": "look at center"}
      ]
      prompt = run.build_rubric_prompt(theme)
      assert "custom-x" in prompt
      assert "is X true?" in prompt
  ```

- [ ] Step 3: FAIL. Implement `build_rubric_prompt(theme: dict) -> str` in `run.py`:
  - Loads a parameterized prompt template (define inline as a triple-quoted string in run.py for now; can move to a file later).
  - Iterates the 7 stable items; skips any in `theme["rubricOverrides"]["waive"]`.
  - Appends each entry from `theme["rubricOverrides"]["add"]` (formatted as the template expects).
  - Returns the full prompt string.

- [ ] Step 4: Update `eval/rubric.md`:
  - Replace numbered headings (`### 1. Primary node emphasis`) with `### \`primary-emphasis\` — Primary node emphasis`.
  - Add a "Theme-aware items" section: "Themes can waive item IDs via `rubricOverrides.waive` and inject new IDs via `rubricOverrides.add` (each: `{id, prompt, evidenceHint}`)."
  - Update reviewer prompt template to reference items by stable ID.
  - Add an explicit `role-style-consistency` description as a candidate add-item that themes (editorial) may inject.

- [ ] Step 5: Update `sidecar-schema.md` `evalSummary.visionItems` example to use stable IDs (e.g., `"primary-emphasis": "pass"`).

- [ ] Step 6: Run tests; tests pass; existing selftest unchanged.

- [ ] Step 7: Commit
  ```
  git add -A
  git commit -m "feat(diagram): stable rubric IDs; theme-aware waive/add loader"
  ```

**Inline verification:**
- `pytest tests/test_rubric_loader.py -v` → 3 pass.
- `python3 tests/run.py` exits 0.

---

### T10: Author `themes/editorial/theme.yaml` + `style.md` + atoms

**Goal:** Editorial theme exists on disk and validates against the schema. Atoms exist as visual primitives (not templates).
**Spec refs:** §5 (full editorial theme.yaml), §6 (defining moves), §11 file-tree

**Files:**
- Create: `plugins/pmos-toolkit/skills/diagram/themes/editorial/theme.yaml`
- Create: `plugins/pmos-toolkit/skills/diagram/themes/editorial/style.md`
- Create: `plugins/pmos-toolkit/skills/diagram/themes/editorial/atoms/eyebrow-mono.svg`
- Create: `plugins/pmos-toolkit/skills/diagram/themes/editorial/atoms/dashed-container.svg`
- Create: `plugins/pmos-toolkit/skills/diagram/themes/editorial/atoms/pastel-chip-stack.svg`
- Create: `plugins/pmos-toolkit/skills/diagram/themes/editorial/atoms/computation-block.svg`
- Create: `plugins/pmos-toolkit/skills/diagram/themes/editorial/atoms/return-loop-arrow.svg`
- Test:   `plugins/pmos-toolkit/skills/diagram/tests/test_editorial_theme.py`

**Steps:**

- [ ] Step 1: Write tests:
  ```python
  # tests/test_editorial_theme.py
  import pathlib, sys
  HERE = pathlib.Path(__file__).parent
  sys.path.insert(0, str(HERE))
  import run

  def test_editorial_theme_validates():
      theme = run.load_theme("editorial")  # raises if invalid
      assert theme["name"] == "editorial"
      assert theme["surface"]["background"].upper() == "#F4EFE6"
      assert theme["connectors"]["mixingPermitted"] is True
      assert theme["infographic"]["supported"] is True
      assert theme["infographic"]["layout"] == "editorial-v1"

  def test_editorial_pinned_accents():
      theme = run.load_theme("editorial")
      roles = {a["pinnedRole"]: a["hex"].upper() for a in theme["palette"]["accents"]}
      assert roles["feedback"] == "#1E3A8A"
      assert roles["emphasis"] == "#D9421C"

  def test_editorial_byrole_dispatch_complete():
      theme = run.load_theme("editorial")
      by_role = theme["connectors"]["byRole"]
      for r in ["contribution", "emphasis", "feedback", "default"]:
          assert r in by_role, f"missing role: {r}"

  def test_editorial_palette_passes_aa_on_cream():
      theme = run.load_theme("editorial")
      from run import contrast_ratio
      cream = theme["surface"]["background"]
      for a in theme["palette"]["accents"]:
          ratio = contrast_ratio(a["hex"], cream)
          assert ratio >= 4.5, f"{a['hex']} on {cream} is {ratio:.2f}:1, fails AA"

  def test_editorial_atoms_exist():
      atoms = pathlib.Path(__file__).parents[1] / "themes" / "editorial" / "atoms"
      for name in ["eyebrow-mono", "dashed-container", "pastel-chip-stack",
                   "computation-block", "return-loop-arrow"]:
          assert (atoms / f"{name}.svg").exists(), f"Missing atom: {name}.svg"
  ```

- [ ] Step 2: FAIL. Author `themes/editorial/theme.yaml` per spec §5 verbatim. Use the exact hex values: `#F4EFE6` background, `#1E3A8A` accent-primary (pinnedRole: feedback), `#D9421C` accent-emphasis (pinnedRole: emphasis), pastel chips per spec.

- [ ] Step 3: Author `themes/editorial/style.md` as a human-readable spec mirroring the YAML. Cite §6's seven defining moves verbatim. Reference the atoms.

- [ ] Step 4: Author 5 atom SVGs (each ~200×80 to ~400×200 px, single-purpose):
  - `eyebrow-mono.svg`: just the text "EXTERNAL CONTEXT (objects we populate)" in mono uppercase 12px, ink-muted, letter-spaced 0.08em. Cream background.
  - `dashed-container.svg`: a 600×400 cream rect with dashed gray border, 16px inset, with the eyebrow positioned top-left.
  - `pastel-chip-stack.svg`: 4 stacked rows alternating chip-warm (`#F5C9B8`) and chip-cool (`#DCE0F0`), each ~32px tall, with sample labels.
  - `computation-block.svg`: a 240×160 black-fill rect with 12px white text "MODEL · forward pass" inside.
  - `return-loop-arrow.svg`: a single curved blue dashed bezier with arrowhead, demonstrating the feedback edge style.
  Match the exact tokens in `theme.yaml`. Atoms exist as reference, NOT layout templates (per spec).

- [ ] Step 5: Run tests, expect ALL PASS. If `test_editorial_palette_passes_aa_on_cream` fails: STOP and adjust hex values until both accents pass AA on `#F4EFE6` BEFORE proceeding to T11+. (D2 rationale: per Phase 1 contrast metric, every editorial diagram is verified at runtime; the theme MUST start AA-clean.)

- [ ] Step 6: Commit
  ```
  git add -A
  git commit -m "feat(diagram): editorial theme.yaml + style.md + 5 atoms"
  ```

**Inline verification:**
- `pytest tests/test_editorial_theme.py -v` → 5 pass.
- All 5 atom SVGs render via `rsvg-convert`: `for f in plugins/pmos-toolkit/skills/diagram/themes/editorial/atoms/*.svg; do rsvg-convert "$f" -o /tmp/atom-$(basename $f .svg).png && echo OK $f || echo FAIL $f; done` — all OK.

---

### T11: Implement `connectors.byRole` dispatch + pinned-accent enforcement in SKILL.md

**Goal:** SKILL.md Phase 3 instructs the author to assign role per relationship and select connector style via `connectors.byRole[role]`. Pinned-accent rule documented.
**Spec refs:** §5 connectors.byRole, §6 defining move 3 (pinned accents)

**Files:**
- Modify: `plugins/pmos-toolkit/skills/diagram/SKILL.md`

**Steps:**

- [ ] Step 1: In Phase 3 step 5 (Connector style), replace the current "one judgment call per diagram" text with:
  ```
  Connector aesthetic comes from the active theme:
  - If `theme.connectors.mixingPermitted: false`, use a single style — orthogonal for flows/architectures/sequences; curves for mind maps/networks/dependency graphs. Pick once for the diagram and stick with it.
  - If `theme.connectors.mixingPermitted: true`, assign a `role` to each relationship (one of `contribution | emphasis | feedback | dependency | reference`; default to `default`). Look up `theme.connectors.byRole[role]` to get `{shape, stroke, dashed}`. ALL edges sharing a role must use the same lookup result — mixing within a role is forbidden and flagged by the `role-style-consistency` rubric item.
  ```

- [ ] Step 2: In Phase 3 step 6 (Color usage), add:
  ```
  When the theme defines `palette.accents[].pinnedRole`, that mapping is fixed for every diagram drawn under the theme. Authors MUST NOT use `accent-primary` for non-feedback edges or `accent-emphasis` for non-emphasis edges. Cross-document consistency depends on this.
  ```

- [ ] Step 3: Add a new anti-pattern: "Do NOT reassign pinned-role accents per diagram."

- [ ] Step 4: Add a new anti-pattern: "Do NOT mix connector styles within a single role even when the theme permits mixed connectors. Each role uses one consistent style across the diagram."

- [ ] Step 5: Commit
  ```
  git add plugins/pmos-toolkit/skills/diagram/SKILL.md
  git commit -m "docs(diagram): SKILL.md byRole dispatch + pinned-accent rules"
  ```

**Inline verification:**
- `grep -n "byRole" plugins/pmos-toolkit/skills/diagram/SKILL.md` shows the new Phase 3 instruction.
- `grep -n "pinnedRole" plugins/pmos-toolkit/skills/diagram/SKILL.md` shows the new color usage rule.

---

### T12: Add `role-style-consistency` rubric add-item; implement check using sidecar role tags

**Goal:** Editorial theme's `rubricOverrides.add` includes a `role-style-consistency` item. The check uses sidecar `relationships[].role` as ground truth, paired with stroke/dasharray on the SVG element.
**Spec refs:** §5 (rubricOverrides), §8 rubric ID, D6

**Files:**
- Modify: `plugins/pmos-toolkit/skills/diagram/themes/editorial/theme.yaml`
- Modify: `plugins/pmos-toolkit/skills/diagram/tests/run.py` — add `check_role_style_consistency(svg_path, sidecar_path) -> tuple[bool, str]`
- Modify: `plugins/pmos-toolkit/skills/diagram/eval/rubric.md` (document the add-item)
- Create: `plugins/pmos-toolkit/skills/diagram/tests/test_role_consistency.py`

**Steps:**

- [ ] Step 1: Write tests:
  ```python
  # tests/test_role_consistency.py — uses tiny synthetic SVG+sidecar pairs
  import pathlib, sys, json, tempfile
  HERE = pathlib.Path(__file__).parent
  sys.path.insert(0, str(HERE))
  import run

  SVG_TEMPLATE = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 100">
    <line id="e1" x1="0" y1="0" x2="100" y2="0" stroke="#1E3A8A" stroke-dasharray="4 4" marker-end="url(#a)"/>
    <line id="e2" x1="0" y1="20" x2="100" y2="20" stroke="#1E3A8A" stroke-dasharray="4 4" marker-end="url(#a)"/>
  </svg>"""

  def test_role_consistency_passes_when_same_role_same_style():
      with tempfile.TemporaryDirectory() as d:
          svg = pathlib.Path(d) / "x.svg"; svg.write_text(SVG_TEMPLATE)
          sidecar = pathlib.Path(d) / "x.diagram.json"
          sidecar.write_text(json.dumps({
              "schemaVersion": 2,
              "relationships": [
                  {"from": "a", "to": "b", "kind": "directed", "role": "feedback", "_svgId": "e1"},
                  {"from": "c", "to": "d", "kind": "directed", "role": "feedback", "_svgId": "e2"},
              ],
              # ... minimal v2 fields ...
          }))
          ok, _ = run.check_role_style_consistency(svg, sidecar)
          assert ok

  def test_role_consistency_fails_when_same_role_different_style():
      svg_text = SVG_TEMPLATE.replace('stroke-dasharray="4 4"', '', 1)  # e1 solid, e2 dashed
      # ... build sidecar saying both are feedback role ...
      # assert ok is False and reason mentions role-style mismatch
      ...
  ```

- [ ] Step 2: FAIL. Implement `check_role_style_consistency(svg_path, sidecar_path) -> tuple[bool, reason]`:
  - Load sidecar; build `role_to_svgids: dict[str, list[str]]` from `relationships`.
  - Parse SVG; for each connector element ID listed, capture `(stroke, stroke-dasharray, tag-shape)`.
  - For each role with ≥ 2 edges, all edges' (stroke, dasharray, shape) tuples must be identical.
  - Return `(True, "")` or `(False, "role 'feedback': edge e1 uses solid stroke, edge e2 uses dashed; expected one style per role")`.
  - **Note:** sidecar `relationships[]` need a way to point at SVG element IDs. Add a new optional field `_svgId` to relationship records (per spec §11 file-tree this is a sidecar-only field). Document in sidecar-schema.md.

- [ ] Step 3: Update `themes/editorial/theme.yaml` `rubricOverrides.add` to include:
  ```yaml
  - { id: "role-style-consistency",
      prompt: "All edges sharing a `role` use the same connector style (stroke/dash/shape)",
      evidenceHint: "compare like-roled edges' SVG attributes" }
  ```

- [ ] Step 4: Update `eval/rubric.md` to document the `role-style-consistency` add-item: how it works, when it applies, what the reviewer/code-metric checks.

- [ ] Step 5: Hook the check into the eval pipeline: when `theme.connectors.mixingPermitted is True`, `evaluate()` calls `check_role_style_consistency()` and appends to `hard_fails` on fail.

- [ ] Step 6: Run tests, expect PASS.

- [ ] Step 7: Commit
  ```
  git add -A
  git commit -m "feat(diagram): role-style-consistency rubric check via sidecar role tags"
  ```

**Inline verification:**
- `pytest tests/test_role_consistency.py -v` → 2 pass.
- `python3 tests/run.py` still exits 0 (technical theme has `mixingPermitted: false` so this code path doesn't trigger).

---

### T13: Add 3 editorial goldens + 3 editorial defects

**Goal:** Lock in editorial theme behavior with goldens; lock in defect detection with defects.
**Spec refs:** §9 selftest changes (gold + defect lists)

**Files:**
- Create: `plugins/pmos-toolkit/skills/diagram/tests/golden/editorial/editorial-flow-fanin.svg` + `.expected.json` + `.diagram.json` (sidecar for role lookup)
- Create: `plugins/pmos-toolkit/skills/diagram/tests/golden/editorial/editorial-radial-mindmap.svg` + sidecars
- Create: `plugins/pmos-toolkit/skills/diagram/tests/defects/editorial/cream-but-mixed-connectors-within-one-role.svg` + sidecar
- Create: `plugins/pmos-toolkit/skills/diagram/tests/defects/editorial/eyebrow-not-uppercase.svg`
- Modify: `plugins/pmos-toolkit/skills/diagram/tests/run.py` `run_corpus()` — iterate `golden/<theme>/` and `defects/<theme>/` subdirs

**Steps:**

- [ ] Step 1: Hand-author `editorial-flow-fanin.svg` modeled on the user's reference image — cream surface, dashed container, three left fan-in containers (System prompt / Tools·Skills·MCP / Hooks·Middleware) + Memory store, central red-bordered "Context Fragments" box, right black "Computation Box" with chip-stack rows, three black curved fan-in beziers, one straight red emphasis edge, one dashed blue return-loop. Each connector element gets a stable `id` attribute (e.g., `id="edge-syspromp-to-fragments"`). Include sidecar with `relationships[].role` AND `relationships[]._svgId` populated, where `_svgId` matches the SVG element's `id` so T12's `check_role_style_consistency` can look it up.

- [ ] Step 2: Hand-author `editorial-radial-mindmap.svg` — same theme tokens (cream, dashed container, mono eyebrow, two-accent palette) but a different layout: a center node with 6 radial branches. **Demonstrates that theme ≠ layout.** Include sidecar.

- [ ] Step 3: Update `run_corpus()` to also iterate `golden/editorial/*.svg` with `theme="editorial"`, comparing against expected.json. Same for defects.

- [ ] Step 4: Generate `.expected.json` snapshots: `python3 tests/run.py --update-snapshots`. Manually verify each snapshot's `hard_fails` is empty and `code_score` is reasonable (≥ 0.8).

- [ ] Step 5: Hand-author `cream-but-mixed-connectors-within-one-role.svg`: editorial theme, but two `feedback` edges have different stroke patterns. Sidecar marks both as `feedback`. The `role-style-consistency` check must hard-fail.

- [ ] Step 6: Hand-author `eyebrow-not-uppercase.svg`: cream surface, eyebrow text in mixed case ("External Context (objects we populate)"). The added `eyebrow-mono-uppercase-applied` rubric item must fail (this is a vision-only check; mark it as `vision` kind in `DEFECT_EXPECT`).

- [ ] Step 7: Update `DEFECT_EXPECT` in `run.py` for the new defects:
  ```python
  DEFECT_EXPECT.update({
      "cream-but-mixed-connectors-within-one-role": ("hard", "role-style-consistency"),
      "eyebrow-not-uppercase":                       ("vision", None),
  })
  ```

- [ ] Step 8: Run full corpus: `python3 tests/run.py` — expect all goldens (technical + editorial) pass, all defects (technical + editorial) detected.

- [ ] Step 9: Commit
  ```
  git add -A
  git commit -m "test(diagram): editorial goldens + defects; corpus iterates by theme"
  ```

**Inline verification:**
- `python3 tests/run.py` exits 0 with both editorial goldens passing and both editorial defects detected.
- Visually inspect rendered PNGs of editorial-flow-fanin.svg and editorial-radial-mindmap.svg via `rsvg-convert`. Confirm cream surface, dashed boundary, mono eyebrows are visually present in both.

---

### T14: Phase 2 verify — editorial theme works end-to-end

**Goal:** Confirm Phase 2 ships an independently-usable editorial theme.

- [ ] **All Python tests:** `cd plugins/pmos-toolkit/skills/diagram && pytest tests/ -v` — all pass.
- [ ] **Full selftest:** `python3 tests/run.py` exits 0; technical AND editorial goldens pass; technical AND editorial defects detected.
- [ ] **Manual end-to-end (technical, regression):** `/diagram "three boxes left to right"` — output identical to pre-Phase-2 runs.
- [ ] **Manual end-to-end (editorial, new):** `/diagram --theme editorial "harness pulls system prompt, tools, hooks, and memory into context fragments which feed the computation box"`. Walk Phase 0–7. Confirm: cream surface, dashed container, mono eyebrows, two pinned-role accents (blue=loop, red=emphasis), `role` populated in sidecar for each edge, `role-style-consistency` check passes, output passes vision rubric.
- [ ] **Cross-document consistency manual check:** Run two distinct editorial diagrams. Confirm blue ALWAYS = loop, red ALWAYS = emphasis. No reassignment.
- [ ] **No technical regression:** `git diff diagram-phase1-complete -- plugins/pmos-toolkit/skills/diagram/themes/technical/` shows only intended changes (any new fields added to be schema-clean; no token value drift).

If any item fails, do NOT proceed to Phase 3. Tag:
```
git tag diagram-phase2-complete
```

---

## Phase 3: Infographic mode

This phase ships when `--theme editorial --mode infographic` produces a passing wrapped SVG with auto-generated copy and the wrapper rubric pass.

### T15 [P]: Author `themes/editorial/infographic/editorial-v1.md`

**Goal:** Define the editorial-v1 layout zones, the auto-fit caption grid, and the slim wrapper rubric.
**Spec refs:** §7 (full Phase 6.6 spec)

**Files:**
- Create: `plugins/pmos-toolkit/skills/diagram/themes/editorial/infographic/editorial-v1.md`

**Steps:**

- [ ] Step 1: Write the layout spec verbatim per spec §7 zones (`ZONE_EYEBROW`, `ZONE_HEADLINE`, …, `ZONE_FOOTER`).

- [ ] Step 2: Include the caption auto-fit table (3→4-col, 4→3-col, 5→2-col-with-span).

- [ ] Step 3: Include the slim 4-item wrapper rubric (`wrapper-typography-hierarchy`, `wrapper-text-fit`, `wrapper-figure-proportion`, `wrapper-edge-padding`).

- [ ] Step 4: Document foreignObject fallback policy and ordinal-marker fallback rule (cross-link to spec §7).

- [ ] Step 5: Commit
  ```
  git add plugins/pmos-toolkit/skills/diagram/themes/editorial/infographic/editorial-v1.md
  git commit -m "docs(diagram): editorial-v1 infographic layout spec"
  ```

**Inline verification:**
- File exists; renders cleanly when `cat`-ed; no markdown syntax errors via `python3 -m markdown - < ... > /dev/null` (or skip if no markdown linter available).

---

### T16: Implement Phase 6.6 — auto-gen wrapper copy + user-review checkpoint

**Goal:** SKILL.md Phase 6.6 instructions; sidecar carries `wrappedText`. Auto-gen runs inline (D7).
**Spec refs:** §7 auto-generated text + user-review checkpoint, D7

**Files:**
- Modify: `plugins/pmos-toolkit/skills/diagram/SKILL.md` — insert Phase 6.6 between current Phase 6 and Phase 7
- Modify: `plugins/pmos-toolkit/skills/diagram/reference/sidecar-schema.md` — add `mode`, `wrapperLayout`, `wrappedText`, `captionAnchorMode`, `captionAnchorRemaps`, `captionCountClamp`, `wrapperRubricResults`

**Steps:**

- [ ] Step 1: Author SKILL.md Phase 6.6:
  ```
  ## Phase 6.6 — Editorial wrapper (only if `--mode infographic`)

  Runs after Phase 6 produces a clean diagram. Skipped if `--mode diagram` or theme `infographic.supported: false` (Phase 0 already rejects the latter combo).

  1. **Generate copy.** Assemble a prompt with: original description, --source markdown if provided, entity model + relationships, chosen Phase 2 framing, color-to-element assignments. Inline LLM call returns JSON: { eyebrow, headline, lede, figLabel, captions[], footer }.

  2. **User-review checkpoint.** AskUserQuestion: "Generated infographic copy — accept, edit a field, or regenerate?" Options: Accept / Edit field / Regenerate. On Edit, present each field one at a time. On Regenerate, re-prompt once with user feedback.

  3. **Caption count clamp.** If captions[].length < 3: re-prompt once asking for 3+. If still < 3: drop caption block entirely (sidecar logs `captionCountClamp.to: 0`). If captions[].length > 5: drop weakest by length (sidecar logs `captionCountClamp.from/to`).

  4. **Determine caption anchor mode.** Count distinct token colors in the diagram (excluding ink-muted and surface). If < 3: anchorMode = "ordinal"; else "color". Sidecar records.

  5. **Compose wrapper SVG** (T17, T18, T19a–c implementation details; this step is "now compose it").

  6. **Slim wrapper rubric pass** (T20).

  7. **Write sidecar v2** with mode, wrapperLayout, wrappedText, captionAnchorMode, captionAnchorRemaps, captionCountClamp, wrapperRubricResults.
  ```

- [ ] Step 2: Update sidecar-schema.md with new fields and an example v2 payload for `mode: infographic`.

- [ ] Step 3: Update SKILL.md Phase 0 to add: "If `--mode infographic` is set AND active theme `infographic.supported: false`, refuse with: `Theme '<theme>' does not support infographic mode. Use --theme editorial or --mode diagram.` Exit 2."

- [ ] Step 4: Commit (no test code yet — composition implementation arrives in T17–T19; this is structural/docs-only):
  ```
  git add -A
  git commit -m "docs(diagram): SKILL.md Phase 6.6 + sidecar v2 infographic fields"
  ```

**Inline verification:**
- `grep -n "Phase 6.6" plugins/pmos-toolkit/skills/diagram/SKILL.md` shows the new section.
- `grep -n "captionAnchorMode" plugins/pmos-toolkit/skills/diagram/reference/sidecar-schema.md` shows the new field.

---

### T17: Caption auto-fit grid + clamp logic

**Goal:** Given N captions in [3, 5], emit the correct grid layout (cols-per-caption, gutter). For N outside [3, 5], clamp per D8.
**Spec refs:** §7 caption auto-fit grid table, D8

**Files:**
- Create: `plugins/pmos-toolkit/skills/diagram/wrapper/caption_grid.py` — pure function `caption_layout(n: int, total_width: int, margin: int) -> dict`
- Create: `plugins/pmos-toolkit/skills/diagram/tests/test_caption_grid.py`

**Steps:**

- [ ] Step 1: Write tests:
  ```python
  # tests/test_caption_grid.py
  import pathlib, sys
  HERE = pathlib.Path(__file__).parent
  sys.path.insert(0, str(HERE))
  sys.path.insert(0, str(HERE.parent))
  from wrapper.caption_grid import caption_layout, clamp_captions

  def test_three_captions_use_4_cols_each():
      r = caption_layout(3, total_width=1280, margin=64)
      assert r["cols_per_caption"] == 4
      assert r["gutter"] == 24
      assert len(r["columns"]) == 3
      # Each caption's x-position is computed
      assert r["columns"][0]["x"] == 64
      assert r["columns"][1]["x"] > r["columns"][0]["x"] + r["columns"][0]["width"]

  def test_four_captions_use_3_cols_each():
      r = caption_layout(4, total_width=1280, margin=64)
      assert r["cols_per_caption"] == 3
      assert r["gutter"] == 24

  def test_five_captions_use_2_cols_with_one_span():
      r = caption_layout(5, total_width=1280, margin=64)
      assert r["cols_per_caption"] == 2
      assert r["gutter"] == 16

  def test_clamp_too_many_drops_weakest():
      caps = [{"title": "a", "body": "x" * 10},
              {"title": "b", "body": "x" * 100},
              {"title": "c", "body": "x" * 80},
              {"title": "d", "body": "x" * 60},
              {"title": "e", "body": "x" * 40},
              {"title": "f", "body": "x" * 20},   # weakest by body length
              {"title": "g", "body": "x" * 30}]
      kept, info = clamp_captions(caps)
      assert len(kept) == 5
      assert info["from"] == 7 and info["to"] == 5
      assert "a" not in [c["title"] for c in kept]  # also weakest

  def test_clamp_too_few_returns_suppression():
      caps = [{"title": "a", "body": "x"}, {"title": "b", "body": "y"}]
      kept, info = clamp_captions(caps)
      assert kept == [] and info["to"] == 0
  ```

- [ ] Step 2: FAIL. Implement `caption_layout(n, total_width, margin) -> dict`. Returns `{cols_per_caption, gutter, columns: [{x, width}]}`. Implement `clamp_captions(caps) -> (kept, info)` per D8: > 5 drops shortest-body until 5; < 3 returns empty list + `{from: n, to: 0, reason: "insufficient captions"}`.

- [ ] Step 3: Run tests, expect PASS.

- [ ] Step 4: Commit
  ```
  git add -A
  git commit -m "feat(diagram): caption auto-fit grid + clamp logic (3-5 captions)"
  ```

**Inline verification:**
- `pytest tests/test_caption_grid.py -v` → 5 pass.

---

### T18: Caption-anchor mode (color vs ordinal markers)

**Goal:** When < 3 distinct accents present, fall back to ordinal markers (●▲■◆★) drawn beside both the caption AND the corresponding diagram element.
**Spec refs:** §7 anchor fallback, D9

**Files:**
- Create: `plugins/pmos-toolkit/skills/diagram/wrapper/anchors.py` — `decide_anchor_mode(diagram_colors: set) -> str`, `assign_markers(captions: list, diagram_elements: list) -> list[(caption_idx, marker, element_id)]`
- Create: `plugins/pmos-toolkit/skills/diagram/tests/test_anchors.py`

**Steps:**

- [ ] Step 1: Write tests:
  ```python
  # tests/test_anchors.py
  from wrapper.anchors import decide_anchor_mode, assign_markers

  def test_color_mode_when_3_or_more_accents():
      assert decide_anchor_mode({"#1E3A8A", "#D9421C", "#0F172A"}) == "color"

  def test_ordinal_mode_when_fewer():
      assert decide_anchor_mode({"#0F172A"}) == "ordinal"
      assert decide_anchor_mode({"#0F172A", "#2563EB"}) == "ordinal"

  def test_ordinal_mode_excludes_ink_muted_and_surface():
      colors = {"#475569", "#FFFFFF", "#F4F5F7", "#0F172A"}  # only ink counts
      assert decide_anchor_mode(colors) == "ordinal"

  def test_assign_markers_returns_5_glyphs():
      caps = [{"title": f"c{i}"} for i in range(5)]
      elements = [{"id": f"e{i}", "bbox": (0, i*20, 100, 20)} for i in range(5)]
      out = assign_markers(caps, elements)
      glyphs = [m for _, m, _ in out]
      assert glyphs == ["●", "▲", "■", "◆", "★"]
      assert all(eid is not None for _, _, eid in out)
  ```

- [ ] Step 2: FAIL. Implement: `decide_anchor_mode` ignores ink-muted (`#475569`) and surface tokens (`#FFFFFF`, `#F4F5F7`, `#F4EFE6`); counts only ink + accents + chips. `assign_markers` zips captions to elements (caller passes the element list in caption order — caller's responsibility) and assigns the next glyph from `["●", "▲", "■", "◆", "★"]`.

- [ ] Step 3: Run tests, expect PASS.

- [ ] Step 4: Commit
  ```
  git add -A
  git commit -m "feat(diagram): caption anchor mode + ordinal marker assignment"
  ```

**Inline verification:**
- `pytest tests/test_anchors.py -v` → 4 pass.

---

### T19a: Wrapper composition — zones + diagram embed

**Goal:** Skeleton of the wrapper SVG: 8 zones laid out vertically, diagram embedded in `zone-diagram`. No text wrapping, no captions yet — eyebrow/H1/lede render as single-line text (overflow tolerated; T19b fixes lede wrap).
**Spec refs:** §7 zones table

**Files:**
- Create: `plugins/pmos-toolkit/skills/diagram/wrapper/compose.py`
- Create: `plugins/pmos-toolkit/skills/diagram/tests/test_wrapper_compose.py`

**Steps:**

- [ ] Step 1: Write tests:
  ```python
  # tests/test_wrapper_compose.py
  import xml.etree.ElementTree as ET
  from wrapper.compose import compose_wrapper

  STUB_SVG = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 400" width="800" height="400"><rect x="0" y="0" width="800" height="400" fill="#FFFFFF"/></svg>'
  SAMPLE_TEXT = {
      "eyebrow": "EYEBROW", "headline": "Hi", "lede": "Short lede.",
      "figLabel": "FIG. 1 — STUB", "captions": [], "footer": "FOOT",
  }

  def test_compose_returns_parseable_svg(theme_editorial):
      out = compose_wrapper(STUB_SVG, SAMPLE_TEXT, theme_editorial, "color", "playwright")
      ET.fromstring(out)  # raises if invalid XML

  def test_compose_contains_all_zone_ids(theme_editorial):
      out = compose_wrapper(STUB_SVG, SAMPLE_TEXT, theme_editorial, "color", "playwright")
      for z in ("zone-eyebrow", "zone-headline", "zone-lede", "zone-fig-label",
                "zone-diagram", "zone-legend", "zone-captions", "zone-footer"):
          assert f'id="{z}"' in out, f"missing {z}"

  def test_diagram_embedded_with_translation(theme_editorial):
      out = compose_wrapper(STUB_SVG, SAMPLE_TEXT, theme_editorial, "color", "playwright")
      # the diagram contents must appear inside zone-diagram's <g>
      assert 'id="zone-diagram"' in out
      assert 'translate(' in out  # zone-diagram applies a translation
  ```
  Provide a `theme_editorial` pytest fixture in `conftest.py` that returns `run.load_theme("editorial")`.

- [ ] Step 2: FAIL.

- [ ] Step 3: Implement `compose_wrapper(diagram_svg_path_or_text, wrapped_text, theme, anchor_mode, renderer, font_metrics_available=False) -> str`:
  - Parse the diagram SVG; extract its viewBox + inner content.
  - Compute zone Y offsets in order with these heights: eyebrow=24, headline=44 (single-line for now), lede=24 (single-line for now), fig-label=16, diagram=auto-scaled-to-fit-width, legend=32, captions=0 (T19c fills), footer=16. Margins: 64 left/right, 56 top, 48 bottom.
  - Emit `<svg width="1280" height="<sum>" viewBox="0 0 1280 <sum>" xmlns="http://www.w3.org/2000/svg">` with `<title>{headline}</title>` first child.
  - Each zone is a `<g id="zone-X" transform="translate(...)">` with its content inside.
  - Diagram zone embeds the parsed inner content with a scale-to-fit transform. **Element `id` attributes from the source diagram MUST be preserved verbatim during embed** — T19c's ordinal-marker mirroring depends on them being reachable inside `zone-diagram`.
  - Surface fill: cream from theme.yaml `surface.background`.

- [ ] Step 3b: Add a test asserting ID preservation:
  ```python
  def test_diagram_element_ids_preserved_in_zone_diagram(theme_editorial):
      diagram_with_id = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><rect id="my-node" x="0" y="0" width="40" height="40" fill="#FFFFFF"/></svg>'
      out = compose_wrapper(diagram_with_id, SAMPLE_TEXT, theme_editorial, "color", "playwright")
      assert 'id="my-node"' in out
      # And it appears AFTER zone-diagram opens
      pos_zone = out.index('id="zone-diagram"')
      pos_node = out.index('id="my-node"')
      assert pos_node > pos_zone
  ```
  This is test #4 in T19a; total goes from 3 → 4 passing.

- [ ] Step 4: Run tests, expect PASS (4 of 4).

- [ ] Step 5: Commit
  ```
  git add -A
  git commit -m "feat(diagram): wrapper compose skeleton — zones + diagram embed (preserve IDs)"
  ```

**Inline verification:**
- `pytest tests/test_wrapper_compose.py -v` → 4 pass.
- Smoke render: `rsvg-convert /tmp/out.svg -o /tmp/out.png` after composing with a hand-fed diagram; confirm PNG opens.

---

### T19b: Lede paragraph wrap + foreignObject policy

**Goal:** The lede paragraph wraps to multiple lines via either `<foreignObject>` (Playwright) or a 0.55em-per-char heuristic (rsvg/cairosvg). Heading H1 also wraps if it exceeds 2 lines.
**Spec refs:** §7 text wrapping, renderer policy, D10

**Files:**
- Modify: `plugins/pmos-toolkit/skills/diagram/wrapper/compose.py` — extend with `wrap_lede(text: str, width_px: int, font_size_px: int, mode: str) -> list[str]` returning lines
- Modify: `plugins/pmos-toolkit/skills/diagram/tests/test_wrapper_compose.py` — extend

**Steps:**

- [ ] Step 1: Extend tests:
  ```python
  def test_lede_wraps_via_heuristic_for_rsvg(theme_editorial):
      long_lede = " ".join(["word"] * 60)
      txt = {**SAMPLE_TEXT, "lede": long_lede}
      out = compose_wrapper(STUB_SVG, txt, theme_editorial, "color", "rsvg-convert")
      assert "<foreignObject" not in out
      # heuristic emits multiple <tspan dy=...> lines under zone-lede
      assert out.count("<tspan") >= 3

  def test_lede_uses_foreignobject_for_playwright_no_metrics(theme_editorial):
      long_lede = " ".join(["word"] * 60)
      txt = {**SAMPLE_TEXT, "lede": long_lede}
      out = compose_wrapper(STUB_SVG, txt, theme_editorial, "color", "playwright",
                            font_metrics_available=False)
      assert "<foreignObject" in out

  def test_lede_uses_text_with_metrics_for_playwright(theme_editorial):
      long_lede = " ".join(["word"] * 60)
      txt = {**SAMPLE_TEXT, "lede": long_lede}
      out = compose_wrapper(STUB_SVG, txt, theme_editorial, "color", "playwright",
                            font_metrics_available=True)
      # accurate-metrics path uses <text>+<tspan>, no foreignObject
      assert "<foreignObject" not in out
      assert out.count("<tspan") >= 3

  def test_lede_bold_phrases_become_bold_tspans(theme_editorial):
      txt = {**SAMPLE_TEXT, "lede": "The **box** we compute on."}
      out = compose_wrapper(STUB_SVG, txt, theme_editorial, "color", "rsvg-convert")
      # at least one tspan with font-weight: 600/bold
      assert ("font-weight=\"600\"" in out) or ("font-weight: 600" in out) or ('font-weight="bold"' in out)

  def test_headline_wraps_to_max_two_lines(theme_editorial):
      txt = {**SAMPLE_TEXT, "headline": "A very long headline " * 8}
      out = compose_wrapper(STUB_SVG, txt, theme_editorial, "color", "rsvg-convert")
      # Headline tspans count <= 2 (truncated with ellipsis if needed)
      ...
  ```

- [ ] Step 2: FAIL.

- [ ] Step 3: Implement `wrap_lede(text, width_px, font_size_px, mode)`:
  - `mode == "foreignobject"`: return single string wrapped in `<foreignObject>` with HTML `<p>` (caller emits the foreignObject).
  - `mode == "metrics"`: use a stdlib font-metrics approximation if available (e.g., per-char widths from a precomputed table for Inter — small JSON in `wrapper/inter-metrics.json` if added); else fall through to heuristic. v1 may use the heuristic everywhere and accept the slight fidelity loss documented in spec §13.
  - `mode == "heuristic"`: split tokens by spaces; greedily fill lines using `font_size_px * 0.55` per character + ~5% slack.
  - Returns list of line strings.
- Markdown bold parsing: a tiny tokenizer splits the lede into runs (`{text, bold: bool}`) on `**...**`. Heuristic wrap operates on runs to keep word boundaries.
- Renderer dispatch: rsvg/cairosvg → heuristic; Playwright + no metrics → foreignobject; Playwright + metrics → metrics.
- Headline wrap: same heuristic, hard cap at 2 lines (truncate with `…` ellipsis if a 3rd line would form).

- [ ] Step 4: Run tests, expect PASS (9 total in this file now).

- [ ] Step 5: Commit
  ```
  git add -A
  git commit -m "feat(diagram): wrapper lede paragraph wrap + foreignObject policy"
  ```

**Inline verification:**
- `pytest tests/test_wrapper_compose.py -v` → 9 pass.

---

### T19c: Caption block + ordinal marker mirroring

**Goal:** Compose the caption columns using T17's grid layout. When anchor_mode == "ordinal", draw matching markers (●▲■◆★) inside `zone-diagram` next to the referenced elements. When anchor_mode == "color", draw 2px left-rules in the caption's anchor color.
**Spec refs:** §7 caption-to-diagram color mapping, anchor fallback

**Files:**
- Modify: `plugins/pmos-toolkit/skills/diagram/wrapper/compose.py`
- Modify: `plugins/pmos-toolkit/skills/diagram/tests/test_wrapper_compose.py`

**Steps:**

- [ ] Step 1: Extend tests:
  ```python
  CAPS_3_COLOR = [
      {"title": "A", "body": "aa", "anchorColor": "#1E3A8A"},
      {"title": "B", "body": "bb", "anchorColor": "#D9421C"},
      {"title": "C", "body": "cc", "anchorColor": "#0F172A"},
  ]
  CAPS_3_ORDINAL = [
      {"title": "A", "body": "aa", "anchorElementId": "e1"},
      {"title": "B", "body": "bb", "anchorElementId": "e2"},
      {"title": "C", "body": "cc", "anchorElementId": "e3"},
  ]

  def test_color_mode_emits_left_rules_in_anchor_color(theme_editorial):
      txt = {**SAMPLE_TEXT, "captions": CAPS_3_COLOR}
      out = compose_wrapper(STUB_SVG, txt, theme_editorial, "color", "playwright")
      assert "#1E3A8A" in out and "#D9421C" in out
      # Three columns laid out with left rules
      assert out.count('class="caption-rule"') == 3 or out.count("stroke=") >= 3

  def test_ordinal_mode_emits_markers_in_both_zones(theme_editorial):
      # diagram with three identifiable elements
      diagram = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 400" width="800" height="400">' \
                '<rect id="e1" x="10" y="10" width="40" height="20" fill="#FFFFFF"/>' \
                '<rect id="e2" x="60" y="10" width="40" height="20" fill="#FFFFFF"/>' \
                '<rect id="e3" x="110" y="10" width="40" height="20" fill="#FFFFFF"/></svg>'
      txt = {**SAMPLE_TEXT, "captions": CAPS_3_ORDINAL}
      out = compose_wrapper(diagram, txt, theme_editorial, "ordinal", "playwright")
      # Each glyph appears at least twice (caption + diagram-side mirror)
      for glyph in ("●", "▲", "■"):
          assert out.count(glyph) >= 2, f"glyph {glyph} appeared {out.count(glyph)} times"

  def test_caption_count_clamp_logged(theme_editorial):
      caps_too_many = [{"title": f"c{i}", "body": "x" * (10 + i)} for i in range(7)]
      txt = {**SAMPLE_TEXT, "captions": caps_too_many}
      out, info = compose_wrapper(STUB_SVG, txt, theme_editorial, "color", "playwright",
                                   return_info=True)
      assert info["captionCountClamp"]["from"] == 7
      assert info["captionCountClamp"]["to"] == 5
  ```
  Update existing tests to use `compose_wrapper(...)` returning either str or `(str, info)` based on `return_info`.

- [ ] Step 2: FAIL.

- [ ] Step 3: Implement caption block in compose.py:
  - Call T17's `clamp_captions()` first; record clamp info.
  - Call T17's `caption_layout(n, total_width, margin)` for column geometry.
  - For each caption, emit a `<g>` per column with:
    - 2px left rule (`<line>` from top-of-column to bottom-of-column) — color = caption.anchorColor in color mode; ink-muted in ordinal mode.
    - In ordinal mode, prepend a `<text>` with the ordinal glyph (●▲■◆★ for 1–5) at display-weight, ink color, 16px.
    - Title: `<text>` 14/600.
    - Body: word-wrapped via `wrap_lede` (reuses T19b function with column width, body font size 13).
  - When ordinal mode, also draw matching markers inside zone-diagram: parse the embedded diagram for elements whose `id` matches each caption's `anchorElementId`; emit a `<text>` glyph at 12px ink positioned at the element's bbox center (use simple x/y from the SVG attributes; if not parseable, position at top-left of element with a 4px offset).
  - Return either `svg_str` or `(svg_str, info)` depending on `return_info`. `info` contains `captionCountClamp`, `captionAnchorMode`, `captionAnchorRemaps`.

- [ ] Step 4: Run tests, expect PASS (12 total in this file now).

- [ ] Step 5: Commit
  ```
  git add -A
  git commit -m "feat(diagram): wrapper caption block + ordinal-marker mirroring"
  ```

**Inline verification:**
- `pytest tests/test_wrapper_compose.py -v` → 12 pass.
- Smoke render: feed STUB_SVG + 4 captions in color mode, render with rsvg-convert, open the PNG, confirm 4 columns with colored left rules render correctly.

---

### T20: Slim 4-item wrapper rubric (single pass, no refinement loop)

**Goal:** After T19 composes the wrapper, run the 4-item wrapper rubric. Failures ship-with-warning XML comment.
**Spec refs:** §7 slim wrapper rubric, D from spec

**Files:**
- Modify: `plugins/pmos-toolkit/skills/diagram/SKILL.md` Phase 6.6 step 6
- Modify: `plugins/pmos-toolkit/skills/diagram/eval/rubric.md` — add wrapper rubric section
- Modify: `plugins/pmos-toolkit/skills/diagram/tests/run.py` — add `build_wrapper_rubric_prompt() -> str`
- Create: `plugins/pmos-toolkit/skills/diagram/tests/test_wrapper_rubric.py`

**Steps:**

- [ ] Step 1: Write tests:
  ```python
  def test_wrapper_rubric_has_four_items():
      from run import build_wrapper_rubric_prompt
      prompt = build_wrapper_rubric_prompt()
      for sid in ("wrapper-typography-hierarchy", "wrapper-text-fit",
                  "wrapper-figure-proportion", "wrapper-edge-padding"):
          assert sid in prompt

  def test_wrapper_rubric_is_single_pass_no_refinement():
      # The prompt MUST NOT mention refinement loops
      prompt = build_wrapper_rubric_prompt()
      assert "refinement" not in prompt.lower()
  ```

- [ ] Step 2: FAIL. Implement `build_wrapper_rubric_prompt()` in run.py — returns a static prompt string that lists the 4 items, asks for binary verdict + evidence per item, returns JSON `{wrapper_items: {...}, wrapper_blocker_count: N}`.

- [ ] Step 3: Update `eval/rubric.md` with a "Wrapper rubric (Phase 6.6)" section: the 4 items, their pass/fail criteria, the single-pass-no-loop rule, the ship-with-warning behavior on fail.

- [ ] Step 4: Update SKILL.md Phase 6.6 step 6: "Render the composite to PNG (per `reference/render-to-raster.md`). Run the wrapper rubric **INLINE** (no subagent dispatch, regardless of `--rigor` tier — the prompt is short and the cost of a subagent isn't justified for a single pass). Single pass, no refinement loop. If `wrapper_blocker_count > 0`, write the SVG with a leading XML comment listing failures: `<!-- WRAPPER QUALITY WARNING: <comma-separated ids> -->`. Sidecar `wrapperRubricResults` records all 4 verdicts. **WRAPPER RUBRIC FAILURES DO NOT GATE.** They ship-with-warning. The full 7-item diagram rubric in Phase 5 has already gated; this wrapper pass is supplementary insurance, not a second hard gate."

- [ ] Step 5: Run tests, expect PASS.

- [ ] Step 6: Commit
  ```
  git add -A
  git commit -m "feat(diagram): slim 4-item wrapper rubric (single pass)"
  ```

**Inline verification:**
- `pytest tests/test_wrapper_rubric.py -v` → 2 pass.

---

### T21: Extend-flow handling for infographic mode

**Goal:** When user picks **Extend** in Phase 1 on an existing infographic, reuse `wrappedText` and skip Phase 6.6 generation/checkpoint.
**Spec refs:** §7 extend-flow handling

**Files:**
- Modify: `plugins/pmos-toolkit/skills/diagram/SKILL.md` Phase 1 (existing-output handling) + Phase 6.6 (extend-aware skip)

**Steps:**

- [ ] Step 1: SKILL.md Phase 1 — when sidecar has `mode: "infographic"`, the **Extend** branch's instruction expands: "Treat sidecar `positions`, `colorAssignments`, AND `wrappedText` as fixed. Apply the new instruction as a minimal patch (e.g., recolor a single node, add a single connector, relabel a node)."

- [ ] Step 2: SKILL.md Phase 6.6 — at the top, add: "If we entered Phase 6.6 via the Extend branch with an existing `wrappedText`, skip step 1 (copy generation) and step 2 (user-review checkpoint). Use the existing `wrappedText` directly. All other steps (compose, rubric, write sidecar) run normally."

- [ ] Step 3: Add to the §14 out-of-scope list note in SKILL.md anti-patterns section: "A future `--regenerate-copy` flag will allow opting back into copy regeneration on Extend; until then, users must Redraw."

- [ ] Step 4: Commit
  ```
  git add plugins/pmos-toolkit/skills/diagram/SKILL.md
  git commit -m "docs(diagram): Extend flow reuses wrappedText for infographic"
  ```

**Inline verification:**
- `grep -n "wrappedText" plugins/pmos-toolkit/skills/diagram/SKILL.md` shows both Phase 1 and Phase 6.6 references.

---

### T22: Add infographic golden + 1 caption-color defect

**Goal:** Lock in infographic behavior with a golden; lock in detection of `infographic-caption-color-not-in-diagram` defect.
**Spec refs:** §9 selftest changes (third golden + defect)

**Files:**
- Create: `plugins/pmos-toolkit/skills/diagram/tests/golden/editorial/editorial-infographic-full.svg` + `.expected.json` + sidecar
- Create: `plugins/pmos-toolkit/skills/diagram/tests/defects/editorial/infographic-caption-color-not-in-diagram.svg`

**Steps:**

- [ ] Step 1: Generate the infographic golden by running the full Phase 6.6 pipeline against `editorial-flow-fanin.svg`'s diagram with hand-authored `wrappedText`. Save the resulting composite SVG as the golden. The text content is fixed (deterministic) so the snapshot is stable.

- [ ] Step 2: Generate `.expected.json`: `python3 tests/run.py --update-snapshots`. Manually verify the golden's `code_score` ≥ 0.8 and `hard_fails` is empty.

- [ ] Step 3: TDD the caption-color validator. Write test in `tests/test_caption_color_validator.py`:
  ```python
  def test_caption_color_not_in_diagram_flagged():
      from run import check_caption_colors_in_diagram
      composite = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1280 1600">
        <g id="zone-diagram"><rect x="0" y="0" width="100" height="100" fill="#1E3A8A"/></g>
        <g id="zone-captions">
          <line class="caption-rule" x1="64" y1="100" x2="64" y2="200" stroke="#1E3A8A"/>
          <line class="caption-rule" x1="200" y1="100" x2="200" y2="200" stroke="#FF00FF"/>
        </g>
      </svg>"""
      ok, reason = check_caption_colors_in_diagram(composite)
      assert ok is False
      assert "#FF00FF" in reason or "caption-color-not-in-diagram" in reason

  def test_caption_colors_all_present_passes():
      composite = "..."  # similar but both caption rules use diagram colors
      ok, _ = check_caption_colors_in_diagram(composite)
      assert ok is True
  ```
  FAIL; implement `check_caption_colors_in_diagram(svg_text_or_path) -> (bool, reason)` in run.py: parses the SVG, gathers all stroke colors inside `<g id="zone-captions">` with class `caption-rule`, gathers all fill/stroke colors inside `<g id="zone-diagram">`, asserts the former is a subset of the latter (excluding `ink-muted` and surface tokens). PASS.

- [ ] Step 4: Hook into eval pipeline. In `evaluate()`, when the loaded sidecar has `mode: "infographic"`, also call `check_caption_colors_in_diagram(svg_text)`. Append to hard_fails on fail with prefix `caption-color-not-in-diagram: `.

- [ ] Step 5: Hand-author `infographic-caption-color-not-in-diagram.svg`: a wrapped composite where one caption's left rule uses a hex absent from the diagram interior. The check from Step 3 must hard-fail this fixture.

- [ ] Step 6: Update `DEFECT_EXPECT`:
  ```python
  DEFECT_EXPECT["infographic-caption-color-not-in-diagram"] = ("hard", "caption-color-not-in-diagram")
  ```

- [ ] Step 7: Run full corpus, expect everything PASS.

- [ ] Step 8: Commit
  ```
  git add -A
  git commit -m "test(diagram): infographic golden + caption-color validator + defect"
  ```

**Inline verification:**
- `python3 tests/run.py` exits 0 with editorial-infographic-full passing and infographic-caption-color-not-in-diagram detected.
- Render the infographic golden to PNG and confirm visually: cream surface, eyebrow → H1 → lede → FIG label → diagram → legend → caption columns → footer all present and well-proportioned.

---

### T23: SKILL.md anti-patterns + Phase listings final pass

**Goal:** Anti-patterns section reflects the post-themes/infographic world. File map updated. Track progress section names all phases including 6.6.
**Spec refs:** §10 step 6 (SKILL.md edits)

**Files:**
- Modify: `plugins/pmos-toolkit/skills/diagram/SKILL.md`

**Steps:**

- [ ] Step 1: Update the anti-pattern "Do NOT mix orthogonal and curved connectors in one diagram. Pick one style and stick with it." → "Do NOT mix connectors unless the active theme permits role-keyed mixing (`connectors.mixingPermitted: true`). Even then, mixing within a single role is forbidden."

- [ ] Step 2: Add anti-pattern: "Do NOT skip Phase 6.6 in infographic mode. Auto-generated copy + user review + slim wrapper rubric are mandatory; failures ship-with-warning, never silently."

- [ ] Step 3: Add anti-pattern: "Do NOT use `<foreignObject>` for diagram-interior content. It is permitted only inside Phase 6.6 wrapper text zones, and only when the renderer is Playwright."

- [ ] Step 4: Update file-map at bottom of SKILL.md:
  ```
  skills/diagram/
  ├── SKILL.md                              # this file (orchestrator)
  ├── themes/
  │   ├── _schema.json                      # JSON schema for theme.yaml
  │   ├── technical/
  │   │   ├── theme.yaml
  │   │   ├── style.md
  │   │   └── atoms/                        # 8 visual primitives
  │   └── editorial/
  │       ├── theme.yaml
  │       ├── style.md
  │       ├── atoms/                        # 5 visual primitives
  │       └── infographic/
  │           └── editorial-v1.md
  ├── eval/
  │   ├── rubric.md                         # stable IDs; theme-aware waive/add; wrapper rubric
  │   └── code-metrics.md
  ├── reference/
  │   ├── svg-primer.md
  │   ├── render-to-raster.md
  │   └── sidecar-schema.md                 # v2; theme/mode/role/wrappedText
  ├── wrapper/                              # NEW
  │   ├── caption_grid.py
  │   ├── anchors.py
  │   └── compose.py
  └── tests/
      ├── golden/
      │   ├── (5 fixtures @ technical theme)
      │   └── editorial/                    # 3 fixtures
      ├── defects/
      │   ├── (10 fixtures @ technical theme)
      │   └── editorial/                    # 3 fixtures
      ├── run.py
      ├── test_theme_schema.py
      ├── test_theme_loader.py
      ├── test_sidecar.py
      ├── test_rubric_loader.py
      ├── test_editorial_theme.py
      ├── test_role_consistency.py
      ├── test_caption_grid.py
      ├── test_anchors.py
      ├── test_wrapper_compose.py
      └── test_wrapper_rubric.py
  ```

- [ ] Step 5: Update Track Progress section: "This skill has multiple phases (0, 1, 2, 3, 4, 5, 6, 6.6, 7, 8). Phase 6.6 runs only in infographic mode."

- [ ] Step 6: Commit
  ```
  git add plugins/pmos-toolkit/skills/diagram/SKILL.md
  git commit -m "docs(diagram): SKILL.md anti-patterns + file-map for themes/wrapper"
  ```

**Inline verification:**
- `grep -c "Do NOT" plugins/pmos-toolkit/skills/diagram/SKILL.md` → at least 14 (was 11; added 3 new).
- `grep -n "wrapper/" plugins/pmos-toolkit/skills/diagram/SKILL.md` shows the new directory in the file map.

---

### T24: Phase 3 verify — full final verification

**Goal:** Verify the entire implementation works end-to-end.

- [ ] **Lint & format:** `python3 -m py_compile plugins/pmos-toolkit/skills/diagram/tests/*.py plugins/pmos-toolkit/skills/diagram/wrapper/*.py` — no errors.
- [ ] **Type check:** N/A (project does not use mypy).
- [ ] **Unit tests:** `cd plugins/pmos-toolkit/skills/diagram && pytest tests/ -v` — all pass (target: ~25–30 tests across all test files added).
- [ ] **Selftest corpus:** `python3 tests/run.py` exits 0; output shows:
  - 5 technical goldens PASS
  - 3 editorial goldens PASS (flow-fanin, radial-mindmap, infographic-full)
  - 10 technical defects detected
  - 3 editorial defects detected (mixed-connectors-in-role, caption-color, eyebrow-not-uppercase)
- [ ] **Manual end-to-end (technical):** `/diagram "three boxes left to right"` — output identical to pre-Phase-1 baseline.
- [ ] **Manual end-to-end (editorial diagram):** `/diagram --theme editorial "harness pulls system prompt, tools, hooks, and memory into context fragments which feed the computation box"` — passes vision rubric, sidecar v2, role tags populated, cross-document accent consistency confirmed.
- [ ] **Manual end-to-end (editorial infographic, happy path):** Same input + `--mode infographic`. Phase 6.6 auto-generates copy. User accepts via checkpoint. Wrapper composes. Slim wrapper rubric passes. Output: a single SVG with eyebrow + H1 + lede + diagram + legend + 4 captions + footer, cream surface, dashed boundary. Manually inspect via `rsvg-convert -o /tmp/out.png` and open in Preview/equivalent.
- [ ] **Manual end-to-end (editorial infographic, low-color fallback):** `/diagram --theme editorial --mode infographic "two boxes connect"` (a deliberately monochromatic input). Confirm captions render with ordinal markers (●▲■◆), and the diagram interior has matching markers next to the referenced elements.
- [ ] **Manual end-to-end (Extend on infographic):** Run the happy-path infographic, then re-run with the same `--out` path and a small label tweak. Confirm Extend branch is offered, taking it reuses `wrappedText` (no copy regeneration prompt fires), composes a patched wrapper, ships in seconds.
- [ ] **Mode rejection on technical:** `/diagram --theme technical --mode infographic "anything"` — refuses with the documented error and exits 2.
- [ ] **Renderer fallback:** Install rsvg-convert as the only renderer. Run an editorial infographic. Confirm console warning fires about foreignObject fallback. Output ships. Wrapper rubric flags any text overflow if it occurs.
- [ ] **No technical regression:** `git diff diagram-phase1-complete -- plugins/pmos-toolkit/skills/diagram/themes/technical/` shows only intended additions; no token drift.
- [ ] **Force an error path:** Run `/diagram --theme nonexistent "x"`. Confirm: clear error message naming the missing theme; exits non-zero; no partial output written.
- [ ] **UX polish checklist:** SKILL.md is internally consistent — Phase numbering monotone, anti-patterns don't contradict each other, file-map matches actual filesystem (`find plugins/pmos-toolkit/skills/diagram -type f -not -path "*/.*"` matches the documented map).
- [ ] **Manual spot check:** Read `themes/editorial/style.md` and the editorial-flow-fanin golden side-by-side. Confirm every defining move (§6 of spec) is visible in the golden.

**Cleanup:**
- [ ] Remove `/tmp/diagram-baseline.txt` and `/tmp/diagram-after.txt` if still present.
- [ ] Verify no `.tmp` files left in `{docs_path}/diagrams/` from interrupted runs.
- [ ] Confirm CHANGELOG / pmos-toolkit version bump if the project follows semver-on-main; otherwise note for the maintainer.
- [ ] Update plugins/pmos-toolkit/CHANGELOG (if it exists) with: "/diagram: themes (technical default, editorial new) + infographic mode."

If any item fails, do NOT tag complete. Tag on success:
```
git tag diagram-phase3-complete
```

---

## Review Log

| Loop | Findings | Changes Made |
|------|----------|-------------|
| 1    | (a) T19 too large; (b) T9 ID reconciliation deviates from spec §8; (c) T12's `_svgId` field undocumented; (d) `eval/code-metrics.md` updates not assigned to a task | (a) Split T19 → T19a/b/c. (b) Updated **spec §8** table to match plan's reconciliation (existing 7 items renamed, theme-awareness via `style-atom-match`). (c) Added Decision D11 documenting `_svgId` as plan-level field. (d) Added step 6 to T4 to update `eval/code-metrics.md`. |
| 2    | (a) T22 lacked TDD for the caption-color validator; (b) T13 sidecar didn't specify `_svgId` per relationship for T12's role-style check; (c) T19a didn't pin element-ID preservation during diagram embed | (a) Added Steps 3–4 to T22 implementing `check_caption_colors_in_diagram` with TDD before authoring the defect fixture. (b) Updated T13 step 1 to require `relationships[]._svgId` populated and matching SVG element IDs. (c) Added "preserve element IDs verbatim" to T19a step 3, plus a 4th test (`test_diagram_element_ids_preserved_in_zone_diagram`) asserting it; downstream cumulative counts in T19b/c bumped to 9 and 12. |
| Final | (a) Wrapper rubric invoker (subagent vs inline) unspecified; (b) ship-with-warning semantics easy to misread as gating; (c) auto-gen copy LLM call has no automated test path | (a) Pinned to INLINE regardless of --rigor in T20 + SKILL.md Phase 6.6 step 6. (b) Added explicit "WRAPPER RUBRIC FAILURES DO NOT GATE" callout in T20 step 4. (c) Acknowledged as acceptable per YAGNI — T22 hand-authors deterministic wrappedText for the golden; T24 manual end-to-end exercises real LLM. No code change. |
