---
task_number: 8
task_name: "workspace-discovery.sh skeleton + 8 manifests + F15 precedence"
plan_path: "docs/pmos/features/2026-05-13_readme-skill/03_plan.html"
branch: "feat/readme-skill"
worktree_path: "/Users/maneeshdhabria/Desktop/Projects/agent-skills-readme-skill"
status: done
started_at: 2026-05-13T14:05:00Z
completed_at: 2026-05-13T14:18:00Z
commit_sha: 885c4e5
files_touched:
  - plugins/pmos-toolkit/skills/readme/scripts/workspace-discovery.sh
  - plugins/pmos-toolkit/skills/readme/tests/fixtures/workspaces/01_pnpm/pnpm-workspace.yaml
  - plugins/pmos-toolkit/skills/readme/tests/fixtures/workspaces/01_pnpm/packages/foo/package.json
  - plugins/pmos-toolkit/skills/readme/tests/fixtures/workspaces/01_pnpm/packages/bar/package.json
  - plugins/pmos-toolkit/skills/readme/tests/fixtures/workspaces/02_npm-workspaces/package.json
  - plugins/pmos-toolkit/skills/readme/tests/fixtures/workspaces/02_npm-workspaces/packages/foo/package.json
  - plugins/pmos-toolkit/skills/readme/tests/fixtures/workspaces/02_npm-workspaces/packages/bar/package.json
  - plugins/pmos-toolkit/skills/readme/tests/fixtures/workspaces/03_lerna/lerna.json
  - plugins/pmos-toolkit/skills/readme/tests/fixtures/workspaces/03_lerna/packages/foo/package.json
  - plugins/pmos-toolkit/skills/readme/tests/fixtures/workspaces/03_lerna/packages/bar/package.json
  - plugins/pmos-toolkit/skills/readme/tests/fixtures/workspaces/04_nx/nx.json
  - plugins/pmos-toolkit/skills/readme/tests/fixtures/workspaces/04_nx/package.json
  - plugins/pmos-toolkit/skills/readme/tests/fixtures/workspaces/04_nx/packages/foo/package.json
  - plugins/pmos-toolkit/skills/readme/tests/fixtures/workspaces/04_nx/packages/bar/package.json
  - plugins/pmos-toolkit/skills/readme/tests/fixtures/workspaces/05_turbo/turbo.json
  - plugins/pmos-toolkit/skills/readme/tests/fixtures/workspaces/05_turbo/package.json
  - plugins/pmos-toolkit/skills/readme/tests/fixtures/workspaces/05_turbo/packages/foo/package.json
  - plugins/pmos-toolkit/skills/readme/tests/fixtures/workspaces/05_turbo/packages/bar/package.json
  - plugins/pmos-toolkit/skills/readme/tests/fixtures/workspaces/06_cargo/Cargo.toml
  - plugins/pmos-toolkit/skills/readme/tests/fixtures/workspaces/06_cargo/crates/foo/Cargo.toml
  - plugins/pmos-toolkit/skills/readme/tests/fixtures/workspaces/06_cargo/crates/bar/Cargo.toml
  - plugins/pmos-toolkit/skills/readme/tests/fixtures/workspaces/07_go-work/go.work
  - plugins/pmos-toolkit/skills/readme/tests/fixtures/workspaces/07_go-work/moduleA/go.mod
  - plugins/pmos-toolkit/skills/readme/tests/fixtures/workspaces/07_go-work/moduleB/go.mod
  - plugins/pmos-toolkit/skills/readme/tests/fixtures/workspaces/08_uv/pyproject.toml
  - plugins/pmos-toolkit/skills/readme/tests/fixtures/workspaces/08_uv/pkgs/foo/pyproject.toml
  - plugins/pmos-toolkit/skills/readme/tests/fixtures/workspaces/08_uv/pkgs/bar/pyproject.toml
---

## Outcome

DONE. `workspace-discovery.sh` (~190 lines) probes the 8 supported workspace manifests at `<repo-root>` and applies F15 precedence (Cargo -> pnpm -> pkg.json#workspaces -> go.work -> uv; lerna alone is primary; nx/turbo are descriptors only). Emits JSON via python3 with shape `{primary, secondaries, packages: [], repo_type}`. `packages: []` is a documented T9 stub; `repo_type` is `monorepo-root` when any manifest is present, else `unknown` (T10 refinement). `--selftest` stub confirms 8/8 fixtures detect the expected primary. `_lib.sh` untouched per T8 append-only invariant.

## Deviations

- python3 instead of the plan's node-based `package.json#workspaces` parse — node + js-yaml absent on host; python3 is verified available (mirrors T7's deviation).
- Bash 3.2 portable (heredoc + IFS-read for the selftest table; no associative arrays, no `mapfile`, no `read -d`).
- JSON emission via python3 inline (not jq), since we generate not consume.

## Residuals (carry to T9/T10)

1. `packages: []` is a stub — T9 lands glob resolution (negation, exclude arrays, object-form, pnpm `packages:` filter).
2. `--selftest` is a stub gate against 8 fixtures; T10 lands the 20-repo gate (≥19/20).
3. `repo_type` only knows `monorepo-root`/`unknown` — T10 refines for library/cli/plugin/app.
4. User-override hook in F15 chain is plumbed (precedence comment) but not wired to a CLI flag — /readme will pass it through later.

## Verification

- `shellcheck plugins/pmos-toolkit/skills/readme/scripts/workspace-discovery.sh` — only SC1091 (info) on `. "$HERE/_lib.sh"`, acceptable.
- `--selftest`: 8/8 primaries detected correctly.
- `git diff plugins/pmos-toolkit/skills/readme/scripts/_lib.sh` — empty.

Commit: `885c4e5`.
