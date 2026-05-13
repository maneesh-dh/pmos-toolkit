---
task_number: 9
task_name: "glob negation + exclude + object-form + pnpm filter (FR-WS-2)"
plan_path: "docs/pmos/features/2026-05-13_readme-skill/03_plan.html"
branch: "feat/readme-skill"
worktree_path: "/Users/maneeshdhabria/Desktop/Projects/agent-skills-readme-skill"
status: done
started_at: 2026-05-13T14:30:00Z
completed_at: 2026-05-13T14:55:00Z
commit_sha: 5d4fc11
files_touched:
  - plugins/pmos-toolkit/skills/readme/scripts/_lib.sh
  - plugins/pmos-toolkit/skills/readme/scripts/workspace-discovery.sh
  - plugins/pmos-toolkit/skills/readme/tests/fixtures/workspaces/09_glob-negation/pnpm-workspace.yaml
  - plugins/pmos-toolkit/skills/readme/tests/fixtures/workspaces/09_glob-negation/packages/alpha/package.json
  - plugins/pmos-toolkit/skills/readme/tests/fixtures/workspaces/09_glob-negation/packages/beta/package.json
  - plugins/pmos-toolkit/skills/readme/tests/fixtures/workspaces/09_glob-negation/packages/private/secret/package.json
  - plugins/pmos-toolkit/skills/readme/tests/fixtures/workspaces/10_cargo-exclude/Cargo.toml
  - plugins/pmos-toolkit/skills/readme/tests/fixtures/workspaces/10_cargo-exclude/crates/foo/Cargo.toml
  - plugins/pmos-toolkit/skills/readme/tests/fixtures/workspaces/10_cargo-exclude/crates/bar/Cargo.toml
  - plugins/pmos-toolkit/skills/readme/tests/fixtures/workspaces/10_cargo-exclude/crates/legacy/Cargo.toml
  - plugins/pmos-toolkit/skills/readme/tests/fixtures/workspaces/11_object-form/package.json
  - plugins/pmos-toolkit/skills/readme/tests/fixtures/workspaces/11_object-form/packages/foo/package.json
  - plugins/pmos-toolkit/skills/readme/tests/fixtures/workspaces/11_object-form/packages/bar/package.json
  - plugins/pmos-toolkit/skills/readme/tests/fixtures/workspaces/12_pnpm-filter/pnpm-workspace.yaml
  - plugins/pmos-toolkit/skills/readme/tests/fixtures/workspaces/12_pnpm-filter/packages/foo/package.json
  - plugins/pmos-toolkit/skills/readme/tests/fixtures/workspaces/12_pnpm-filter/packages/bar/package.json
---

## Outcome

DONE. `workspace-discovery.sh` now enumerates `packages: [{path, manifest_source}, ...]` for every supported primary manifest, honoring the four edge-case semantics from A8:

1. **Glob negation** (`!packages/private/*` pnpm/yarn) — `readme::glob_resolve` in `_lib.sh` applies `!`-prefixed patterns as fnmatch-based negations against the accumulated include set.
2. **Exclude arrays** (`Cargo.toml [workspace] exclude = [...]`) — `emit_patterns_cargo` reads both `members` and `exclude`, emitting excludes as `!`-prefixed lines so `glob_resolve` filters them out.
3. **Object-form `package.json#workspaces`** (grafana `{"packages":[...], "nohoist":[...]}`) — `emit_patterns_pkg_json` accepts both array and object forms; reads `workspaces.packages` for the object shape. T8's `has_pkg_json_workspaces` already detected both forms, so primary detection is unchanged.
4. **pnpm filter** — `emit_patterns_pnpm` reads ONLY top-level `packages:` via `readme::yaml_get packages`; `catalog:`, `overrides:`, `patchedDependencies:` are not enumeration sources and never appear in output.

Additionally, the enumerator filters glob matches to dirs that contain the per-manifest member file (`package.json` for JS, `Cargo.toml` for Rust, `pyproject.toml` for uv, `go.mod` for go.work). This mirrors real pnpm/cargo/uv behavior and naturally drops empty intermediate dirs like `packages/private/` (whose children were excluded) — the alternative would have leaked `packages/private` into the JS test output.

`readme::glob_resolve` is **appended** to `_lib.sh` (zero removed lines vs. 885c4e5 — verified). T2/T7 helpers (`readme::log`, `readme::die`, `readme::yaml_get`) are byte-identical.

`emit_json` signature changed from `(primary, ...secondaries)` to `(primary, packages_json, ...secondaries)`. This is internal — selftest + downstream T10 are unaffected, and the public JSON shape stays `{primary, secondaries, packages, repo_type}`.

## Deviations

- **Fixture numbering** — the prompt suggested `03_/04_/05_/06_` for the 4 new fixtures, but those slots are already taken by T8 (`03_lerna`, `04_nx`, `05_turbo`, `06_cargo`). Used `09_glob-negation/`, `10_cargo-exclude/`, `11_object-form/`, `12_pnpm-filter/` instead to avoid collision. T10's 20-fixture set will continue from `13_`.
- **`tomllib` + regex fallback for Cargo / pyproject** — host Python is 3.11+ so `tomllib` is used; regex fallback retained for portability per spec A8's "no node, no extra deps" constraint.
- **Member-file existence filter** added during enumeration (not in `glob_resolve` itself). This keeps `glob_resolve` a pure path-glob helper (reusable for non-package contexts later) and pushes the per-manifest semantic into `enumerate_packages`.

## Residuals (carry to T10)

1. `manifest_source` is set uniformly to the primary on every package row. T10 will refine for **multi-stack** (MS01): when grafana-style (JS root + nested Go), each package row carries its own `manifest_source`.
2. `repo_type` is still `monorepo-root`/`unknown`. T10 lands the library/cli/plugin/app refinement.
3. `--selftest` still gates 8 T8 fixtures only; T10 lands the 20-fixture regression gate (≥19/20).
4. User-override hook in F15 is still un-wired to a CLI flag.

## Verification

- 4 new fixtures pass assertions (excluding `private/`, excluding `legacy`, object-form yields 2 packages, pnpm filter ignores catalog/overrides).
- T8 regression: `--selftest` still 8/8; all 8 T8 fixtures now also report `packages: 2` (previously stub `[]` — T8 had asserted only on `primary` so this is additive, not a breaking change).
- `shellcheck workspace-discovery.sh _lib.sh` — only SC1091 (source not followed), acceptable.
- `git diff 885c4e5 -- _lib.sh | grep '^-'` (excluding `---` header) — empty: append-only invariant preserved.

Commit: `5d4fc11`.
