<!-- pmos:update-skills-triage v=1 -->
# Triage — Retro paste-back, 4-skill pipeline friction

**Source:** Inline retro paste-back via `/update-skills` slash arg (2026-05-08).
**Affected skills:** `/execute`, `/verify`, `/complete-dev`, `/changelog` (all in-scope).
**Out-of-scope skills mentioned:** none.
**Cross-cutting findings:** none.
**Findings cap (>20)?** No — 10 findings.

## Findings table (parsed)

| ID | Skill | Sev | Finding (one-line) | Proposed fix (verbatim summary) |
|---|---|---|---|---|
| E1 | execute | friction | `HALT_FOR_COMPACT` hard-stop fires at every phase boundary even after user requests "continue without compacting". | Add `--no-halt` flag (or honor session-sticky `continue_through_phases: true` set by first such user message). |
| E2 | execute | friction | Phase 0.5 Resume Report names the resume task but doesn't replay the in-flight task's last thinking trace. | When `resume_mode == "resume"` and the in-flight task has `started_at` but no `completed_at`, append the last 5 lines of the task log body. |
| E3 | execute | nit | `task_goal_hash` sha256 normalization rule documented but no reusable script — every task creation shells out via `node -e`. | Bundle `scripts/compute-task-hash.sh "<goal-line>"` (or have the skill compute and inject the hash via Edit tool). |
| V1 | verify | friction | Phase 4 Entry Gate insists on `TodoWrite` per FR-ID even for phase-scoped runs whose per-task logs already contain evidence-typed FR coverage tables. | When `--scope phase --phase N`, allow markdown table in `review.md` to be the structural enforcement. Reserve `TodoWrite`-as-gate for standalone feature-scope runs. |
| V2 | verify | friction | Playwright synth `KeyboardEvent` requires `bubbles: true` to reach document-level listeners — undocumented; nearly caused FR false-negative. | Phase 4 sub-step 3d evidence guidance: add one-liner about `bubbles: true` on synth events for document-level listeners. |
| V3 | verify | nit | 7-state outcome model (Verified / NA — alt-evidence / Unverified — action required) not surfaced as a copy-pasteable markdown table template. | Provide a copy-pasteable markdown table template in Phase 5 sub-section 4b. |
| C1 | complete-dev | friction | Phase 9 version-bump heuristic ("no git tags = recommend Skip") wrong for first-tagged-release on a mature project with active changelog history. | If `{docs_path}/changelog.md` exists with ≥3 dated entries AND `git tag` is empty, recommend "minor bump (X.Y+1.0)". |
| C2 | complete-dev | friction | Phase 6 learnings scan marks "Skip — already in /verify open items" as Recommended, discouraging useful capture. | When a candidate maps to a verify Open Item, default to "Add as proposed" (CLAUDE.md is durable; verify review is ephemeral). |
| C3 | complete-dev | nit | Phase 5 deploy-norm detection misses `pyproject.toml`/PyPI publish path. | Extend Phase 5 detection to also scan `backend/pyproject.toml` (or any `pyproject.toml`) and offer "Build + publish via `uv publish`" when found, gated on user approval. |
| CL1 | changelog | friction | Skill follows `.pmos/settings.yaml :: docs_path` literally; doesn't honor sibling `docs/changelog.md` even when CLAUDE.md says to. | After reading `docs_path`, also check `{repo_root}/docs/changelog.md`. If present, prefer it (and warn about the settings/observed-convention mismatch). |

## Critique table (Phase 4)

| ID | Already handled? | Classification | Recommendation | Scope hint |
|---|---|---|---|---|
| E1 | No — line 298 emits HALT message unconditionally on green | UX-friction | Apply (with both `--no-halt` and session-sticky flag) | medium |
| E2 | No — Phase 0.5 resolver doesn't include log tail | UX-friction | Apply | small |
| E3 | No — only prose rule exists in `_shared/execute-resume.md`; no script under `tools/` or `scripts/` | nit | Apply (helper script + skill auto-injection) | small |
| V1 | No — line 173 retains full Phase 2–7; line 295 mandates TodoWrite | UX-friction | Apply | medium |
| V2 | No — Phase 4 3d evidence guidance silent on synth-event bubbles | bug (doc gap) | Apply | small |
| V3 | Partial — vocabulary used (lines 443–474), no copy-pasteable template surfaced | nit | Apply | small |
| C1 | No — Step 5 menu marks Minor as recommended only for "new skills"; doesn't account for first-tag scenario | bug (heuristic) | Apply | small |
| C2 | No — Phase 6 uses Findings Presentation Protocol but recommended-marker logic on Skip is wrong for verify-open-item case | UX-friction | Apply | small |
| C3 | No — Phase 5 detection signals at lines 261–264 don't include pyproject.toml | new-capability | Apply | medium |
| CL1 | No — line 13 dictates `{docs_path}/changelog.md` with no sibling check | UX-friction | Apply | small |

## Disposition log

| ID | Disposition | Reason |
|---|---|---|
| E1 | Apply as recommended | — |
| E2 | Apply as recommended | — |
| E3 | Skip | Not worth the maintenance overhead — inline `node -e` is fine |
| V1 | Apply as recommended | — |
| V2 | Apply as recommended | — |
| V3 | Apply as recommended | — |
| C1 | Skip | Heuristic edge-case not worth coding — happens once per repo, manual override is fine |
| C2 | Skip | Recommended marker is fine as-is — dedup signal more valuable than capture default |
| C3 | Apply as recommended | — |
| CL1 | Apply as recommended | — |

**Approved: 7. Skipped: 3. Deferred: 0.**

## Approved changes by skill

### `/execute` (2 changes)
- **E1** — Add `--no-halt` flag AND honor session-sticky `continue_through_phases: true` set by user mid-run. After the first such message, subsequent phase boundaries silently roll into the next phase (handshake preserved for fresh sessions).
- **E2** — In Phase 0.5 Resume Report, when `resume_mode == "resume"` and the in-flight task has `started_at` but no `completed_at`, list the last 5 lines from the task's log body so the resuming agent has a recent thinking trace.

### `/verify` (3 changes)
- **V1** — When invoked with `--scope phase --feature <slug> --phase N`, allow the markdown table in `review.md` to be the structural enforcement for Phase 4 (since it already contains outcome+evidence triple). Reserve `TodoWrite`-as-gate for standalone feature-scope invocations.
- **V2** — Add a one-liner to Phase 4 sub-step 3d evidence guidance: "Synthesized `KeyboardEvent`s must use `bubbles: true` to reach document-level listeners; otherwise the listener won't fire and you'll log a false negative."
- **V3** — Provide a copy-pasteable markdown table template in Phase 5 sub-section 4b so the three-state outcome column (`Verified` / `NA — alt-evidence` / `Unverified — action required`) is structural, not a free-form choice.

### `/complete-dev` (1 change)
- **C3** — Extend Phase 5 deploy-norm detection to scan for `pyproject.toml` (root + nested `backend/`) with `[project]` metadata; when found, offer "Build + publish to PyPI via `uv publish`" as a deploy option, gated on user approval.

### `/changelog` (1 change)
- **CL1** — In Phase 1, after reading `docs_path` from settings, also check `{repo_root}/docs/changelog.md`. If it exists, prefer it (and emit a one-line note suggesting the user fix the `settings.yaml` mismatch). Pattern of "settings says X but observed convention is Y" is repo-specific and worth honoring.

## Per-skill tier table

| Skill | Approved changes | Recommended tier | Rationale |
|---|---|---|---|
| `/execute` | 2 (E1 medium, E2 small) | **Tier 3** _(user-bumped from Tier 2)_ | E1 modifies phase-boundary control flow + adds CLI flag + session-state handling; user opted to add `/grill` before `/plan` |
| `/verify` | 3 (V1 medium, V2 small, V3 small) | **Tier 2** | V1 adds conditional gate logic per scope; V2/V3 are documentation but V1 is phase-modifying |
| `/complete-dev` | 1 (C3 medium new-capability) | **Tier 2** | New deploy-detection signal + new menu option + reference rubric update |
| `/changelog` | 1 (CL1 small UX-friction) | **Tier 1** | Single Phase 1 path-resolution tweak; no new phases, no reference files |

No Tier 3 → no `/grill` step.

## Pipeline status

| Skill | Phase | Status | Artifact path | Timestamp |
|---|---|---|---|---|
| execute | requirements | pending | — | — |
| verify | requirements | pending | — | — |
| complete-dev | requirements | pending | — | — |
| changelog | requirements | in-progress | docs/pmos/features/2026-05-08_update-skills-retro-pipeline-friction/changelog/00_seed.md | 2026-05-08 |
