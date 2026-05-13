# T16 — §6: Scaffold flow

**Phase:** 5 (Implementation — close)
**Commit:** 0b8c5cc
**Status:** sealed

## What landed
Appended `### §6: Scaffold flow` to `plugins/pmos-toolkit/skills/readme/SKILL.md` between §5 and `## Anti-Patterns`. Documents the end-to-end scaffold path that ties §4 mode resolution + §5 repo-miner + reference/opening-shapes.md + reference/section-schema.yaml + §1 rubric pass + §2/§3 simulated-reader pass into a single coherent flow.

## 10-step scaffold flow
1. Repo-miner dispatch (§5) → validated `RepoMinerResult`.
2. `scripts/workspace-discovery.sh` → resolve `repo_type` from manifest set.
3. **≤6 Q user cap (FR-OUT-3)** — `AskUserQuestion` for nullable required fields; cap reached → emit stub README with `<!-- TODO(/readme): <field> — <reason> -->` markers (E2 path).
4. Per-type opening shape from `reference/opening-shapes.md` (library/cli/plugin/app/monorepo-root/monorepo-package; `unknown` → library default + TODO).
5. Section spine from `reference/section-schema.yaml` (Title → Description → Install → Quickstart → Usage → Contributing → License).
6. Rubric pass (§1) via `rubric.sh --variant <repo_type>`; <12/15 → inline TODO warnings, do not block.
7. Simulated-reader pass (§2+§3) — 3 personas; friction merged into diff preview as inline comments.
8. Diff preview + `AskUserQuestion` confirm (Write / Edit / Discard), defer-tagged `destructive`.
9. Atomic write (FR-OUT-4) via temp-then-rename to `<package-path>/README.md`.
10. Per-package iteration for `audit+scaffold` composition (D16); per-package 6-Q budget (not shared).

## Constraint compliance
- **P8 line budget:** SKILL.md 335 lines / 480 cap ✅
- **P11 append-only:** `git diff beeb4ed -- SKILL.md | grep '^-'` → 0 removed lines ✅
- **Plan grep ≥3:** FR-OUT-3 (1) + TODO(/readme) (2) = 3 lines ✅
- **Touch scope:** SKILL.md only; reference/* scripts/* tests/* untouched ✅

## Cross-references
- §4 (T13) — mode resolution gate
- §5 (T15) — repo-miner subagent (upstream `RepoMinerResult`)
- §1 (T03) — rubric pass (reused in step 6)
- §2/§3 (T07/T11) — simulated-reader pass (reused in step 7)
- `reference/opening-shapes.md` (T09)
- `reference/section-schema.yaml` (T09)
- `scripts/workspace-discovery.sh` (T10)
- Anti-patterns specific to scaffold inlined; cross-cutting list under `## Anti-Patterns`.

## Deviations
None. Plan-prescribed §6 content landed verbatim.
