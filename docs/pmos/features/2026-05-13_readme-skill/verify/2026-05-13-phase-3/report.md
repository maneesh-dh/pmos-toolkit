# /verify --scope phase-3 — readme-skill

## Verdict
**PASS**

Combined per-task (T8 + T9 + T10) + Phase 3 boundary review. Phase 3 is a single sequential wave — all three tasks touch `workspace-discovery.sh` and were authored serially. The boundary reviewer subsumes per-task spec+quality review for this serialised phase (same shape as Phase 2 Wave 2).

## Deterministic evidence

**Selftest gate (T10):**
```
  OK   12_pnpm-filter
  OK   13_multi-stack-js-go
  OK   14_babel-style
  OK   15_next-style
  OK   16_turborepo-style
  OK   17_kubernetes-style
  OK   18_ruff-style
  OK   19_lerna-classic
  OK   20_long-tail-bazel
selftest: 20/20 pass (gate >=19/20)
```
exit 0 — gate exceeded (20/20 vs. 19/20 floor).

**Shellcheck:** only SC1091 info on `. "$HERE/_lib.sh"` (acceptable; source-not-followed convention, unchanged from Phase 1/2).

**MS01 multi-stack (FR-WS-4 / fixture 13):**
```
manifest_sources: ['go.work', 'package.json#workspaces']
```
Two distinct `manifest_source` values across the 4 packages — JS half tagged `package.json#workspaces`, Go half tagged `go.work`. F15 keeps `package.json#workspaces` as primary; `go.work` lands as a disjoint secondary contributing rows.

**Long-tail fallback (FR-WS-6 / fixture 20):**
```
detected: unknown layout primary: None
```
Empty `WORKSPACE.bazel` short-circuits before F15; envelope carries the advisory `detected` key and exits 0 (per spec — long-tail is non-fatal).

**F15 precedence (FR-WS-3 / fixture 04_nx):**
```
package.json#workspaces
```
`nx.json` correctly demoted to a tooling descriptor; primary defers to the JS workspace manifest as spec'd ("nx.json/turbo.json are NOT enumeration sources").

## T8 spec-compliance (FR-WS-1, FR-WS-3, FR-WS-5)

`workspace-discovery.sh` (190-line skeleton at this revision) probes all 8 manifests in the spec-mandated order: `pnpm-workspace.yaml`, `package.json#workspaces`, `lerna.json`, `nx.json`, `turbo.json`, `Cargo.toml [workspace]`, `go.work`, `pyproject.toml [tool.uv.workspace]`. Emits the FR-WS-1 JSON envelope `{primary, secondaries, packages, repo_type}`. F15 precedence wired (Cargo ≻ pnpm ≻ pkg.json ≻ go.work ≻ uv; lerna alone is primary; nx/turbo never primary if a JS manifest exists — verified above against fixture 04). `repo_type` reduced to `monorepo-root` / `unknown` for T8 (deviation declared in log; library/cli/plugin/app refinement deferred — properly downstream of workspace discovery, not in FR-WS-5's blocking surface for this phase). `packages: []` left as a documented T9-stub. No drift.

## T9 spec-compliance (FR-WS-2)

All four FR-WS-2 glob semantics implemented:
- **(a) glob negation** — fixture 09 (`!packages/private/*`): `private/secret` excluded; `packages` array correctly drops the negated tree.
- **(b) Cargo exclude arrays** — fixture 10 (`exclude = ["crates/legacy"]`): `legacy/` dropped.
- **(c) object-form `package.json#workspaces`** — fixture 11 (`{packages:[...], nohoist:[...]}`): T8's `has_pkg_json_workspaces` already accepted both shapes; T9's `emit_patterns_pkg_json` reads `workspaces.packages` for the object form. 2 packages enumerated.
- **(d) pnpm filter** — fixture 12 (top-level `catalog:`/`overrides:`/`patchedDependencies:` siblings of `packages:`): only `packages:` enumerated.

`readme::glob_resolve` appended to `_lib.sh` (46 lines, fnmatch-based; Bash 3.2-safe). The defensive member-file existence filter (`package.json` / `Cargo.toml` / `pyproject.toml` / `go.mod` per manifest type) is a sensible elaboration that mirrors real pnpm/cargo/uv behaviour — properly justified in the task log.

## T10 spec-compliance (FR-WS-4, FR-WS-5, FR-WS-6, MS01)

MS01 lands via a 5-line inline `python3` disjoint-set filter inside `discover()` — primary's package paths vs. each secondary's; fully-disjoint secondaries contribute rows tagged with their `manifest_source`, overlapping ones (lerna mirroring pkg.json) stay as `secondaries[]` aliases without duplicating rows. FR-WS-6 long-tail fallback short-circuits before F15 when `probe_manifests` is empty, emitting `detected:"unknown layout"` and exiting 0. The 20-fixture `--selftest` gate replaces T8's primary-only stub with `jq -S`-normalised JSON diff against per-fixture `expected.json` sidecars (gate ≥19/20 actual 20/20).

FR-WS-5 repo-type classification is only partially landed (binary monorepo-root / unknown) — this is a declared deviation. The full taxonomy (library/cli/plugin/app/monorepo-package) lives downstream in the rubric layer (commit-affinity / repo-type heuristic in T17+); the workspace-discovery layer correctly emits enough signal for that classifier. Acceptable for Phase 3 boundary — no blocker.

## Code quality

| Dimension | Verdict |
|---|---|
| Bash 3.2 portability | PASS — no `declare -A`, no `${var^^}`, no `read -d`, no `mapfile`, no `[[ -v ]]`, no `shopt -s globstar`. Explicit header at line 19-20 of workspace-discovery.sh attests. `${arr[@]+"${arr[@]}"}` idiom used for empty-array safety under `set -u` (Bash 3.2 quirk; documented in T10 log). |
| Error handling | PASS — `set -euo pipefail`; `readme::die`/`readme::log` from `_lib.sh`; python3 availability check in `glob_resolve` with sensible warn-and-empty fallback. |
| Shellcheck | PASS — only SC1091 info (source-not-followed, acceptable). |
| Path portability | PASS — `$HERE` anchoring; no hard-coded absolutes; fixtures referenced relative to `$HERE/../tests/fixtures/workspaces/`. |
| JSON emission | PASS — single python3 emitter (no jq dependency for generation); jq used only in selftest for normalised comparison. |

## Append-only invariants

- **T8 → T9 `_lib.sh` diff:** 46 insertions, 0 deletions. T2 lines 1–4 byte-identical; T7 `readme::yaml_get` (lines 6–36) byte-identical; new `readme::glob_resolve` appended at line 38+. Verified via `git diff 885c4e5 5d4fc11 -- plugins/.../scripts/_lib.sh | grep '^-' | grep -v '^---'` → empty.
- **T9 → T10 `_lib.sh` diff:** **empty**. T10 correctly avoided touching `_lib.sh` per its task log — disjoint check stayed inline as 5 lines of python3 instead of being lifted into a `readme::stack_disjoint` helper (justified: single call-site).
- **P7 append-only invariant:** PRESERVED across all three commits.

## Phase 3 done-when checklist

| # | Done-when criterion | Status |
|---|---|---|
| 1 | `workspace-discovery.sh` handles all 8 manifest types | PASS (T8 probes all 8 in spec order) |
| 2 | F15 precedence applied for single-stack tiebreaks | PASS (fixture 04_nx → pkg.json wins over nx) |
| 3 | FR-WS-2 glob semantics (negation / exclude / object-form / pnpm filter) | PASS (4 dedicated fixtures, all pass) |
| 4 | MS01 multi-stack emits both stacks with per-package `manifest_source` | PASS (fixture 13 → 2 distinct sources across 4 packages) |
| 5 | Long-tail fallback (FR-WS-6) emits `detected:"unknown layout"` + exit 0 | PASS (fixture 20) |
| 6 | 20-fixture `--selftest` gate ≥19/20 | PASS (20/20 actual) |
| 7 | `shellcheck` clean | PASS (SC1091 info only) |
| 8 | Bash 3.2-safe | PASS |
| 9 | `_lib.sh` append-only invariant preserved | PASS |

9/9 PASS.

## Fixture coverage gaps

| FR | Fixture(s) | Coverage |
|---|---|---|
| FR-WS-1 (8 manifests) | 01–08 | full |
| FR-WS-2 (glob semantics) | 09–12 | full (4/4 semantics) |
| FR-WS-3 (F15 precedence) | 04_nx, 05_turbo, 16_turborepo-style | full (descriptor demotion exercised) |
| FR-WS-4 (MS01) | 13_multi-stack-js-go | covered (canonical JS + Go pair) — no second multi-stack fixture (e.g. JS + Rust) but FR-WS-4 doesn't require it; the disjoint-set check is manifest-agnostic |
| FR-WS-5 (repo-type) | n/a in this phase | partial — only `monorepo-root` / `unknown` exercised; library/cli/plugin/app deferred to downstream (declared deviation) |
| FR-WS-6 (long-tail) | 20_long-tail-bazel | covered for Bazel; no fixture for Bun / Rush / yarn-berry — but the fallback path is shape-agnostic ("no supported manifest" alone triggers it), so additional fixtures would be redundant. No new fixture residual. |
| MS01 disjoint-vs-alias distinction | 13 (disjoint) + 03_lerna (alias path implicit via T9) | adequate; the lerna-mirrors-pkg.json overlap-not-duplicated case is exercised implicitly but lacks a dedicated overlap fixture. Minor gap — carry as `phase-3-r4`. |

## Residuals carried forward

1. **[phase-2-r2 — STILL OPEN]** `_lib.sh` header line 2 still says `# _lib.sh — shared helpers for /readme bundled scripts. Bash ≥ 4 required.` — actual code is verified 3.2-safe through three append cycles. Carried unchanged from Phase 2; reconcile in T26 dogfood.
2. **[phase-3-r1]** `repo_type` classification reduced to `monorepo-root` / `unknown` at the workspace-discovery layer. FR-WS-5's full taxonomy (library/cli/plugin/app/monorepo-package) is declared as deferred to the downstream rubric / commit-affinity classifier (T17+). Acceptable per task log; no spec violation, just incomplete-by-design for Phase 3.
3. **[phase-3-r2]** F15 user-override hook (`.pmos/readme.config.yaml :: workspace_manifest`) is plumbed in `apply_f15_precedence`'s precedence chain but no CLI flag yet routes a user-supplied override into it. T22 SKILL.md prompt surface will close this; nothing to do at the script layer for now.
4. **[phase-3-r3]** Plugin-marketplace probe deferred — FR-WS-6 spec text says long-tail triggers on "no supported manifest **+ no plugin-marketplace signal**"; current impl triggers on "no supported manifest" alone. Phase 1 plugin-marketplace path is already in scope for T17+ repo-type classification; will satisfy the combined condition there. Carry as minor.
5. **[phase-3-r4]** No dedicated fixture for the MS01 "overlap secondary → kept in `secondaries[]` but contributes no rows" path (lerna-mirrors-pkg.json alias case). The disjoint-set logic is exercised positively by fixture 13 but the negative branch is only implicitly covered. Minor — author a 21st `lerna-alongside-pkg-json` fixture in T26 dogfood.

Net delta: +3 new residuals (`phase-3-r2`/`r3`/`r4`); `phase-3-r1` is a re-statement of an already-declared T8/T9/T10 deviation rather than a regression. `phase-2-r2` still open.

## Recommendation
**PROCEED_TO_PHASE_4**

Phase 4 = T11/T12/T13 (simulated-reader 3-persona parallel personas — `reference/simulated-reader.md` + parent-side FR-SR-3 quote validation + theater-check + `--skip-simulated-reader` escape). Disjoint touch-surface from Phase 3 (new reference doc + new validation hook). Phase 3 workspace-discovery vertical is sealed and demoable.
