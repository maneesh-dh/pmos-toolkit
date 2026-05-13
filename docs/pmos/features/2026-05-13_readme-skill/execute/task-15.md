# T15 — Repo-miner subagent §5

**Commit:** `beeb4ed` — feat(T15): repo-miner subagent dispatch + return validation
**Base:** `acb0de1` (T14 sealed)
**Phase:** 5 (Implementation §5)

## Scope

Appended new SKILL.md subsection **§5: Repo-miner subagent** between §4 (mode resolution) and `## Anti-Patterns`. Documents the Task-dispatch contract for the scaffold-mode repo-miner subagent.

## Content delivered

1. **Dispatch protocol (5 steps):**
   - Step 1: ONE Task call after §4 resolves to `scaffold` / `audit+scaffold`; prompt body carries 8-manifest list + repo-root path + return-shape contract; 90s timeout with explicit fallback log.
   - Step 2: Return-shape JSON contract mirroring spec §9.2.2 — `name`, `entry_point`, `license`, `contributors`, `repo_type_hint` (7-value enum), `manifest_source`, `evidence.*_from`.
   - Step 3: Parent-side validation — type-check, non-empty `name`, enum-membership for `repo_type_hint`, and **evidence-grep** check (substring-grep the named file for the field value — mirrors FR-SR-3 sim-reader pattern from §2).
   - Step 4: AskUserQuestion fallback for `null` fields with sensible defaults; license-prompt defer-tagged `<!-- defer-only: ambiguous -->` so the Phase 0b non-interactive classifier DEFERS rather than auto-picks.
   - Step 5: Cross-ref to §6 (T16) — `RepoMinerResult` seeds the scaffold draft; `evidence.*_from` flows into README footnotes.

2. **Cross-references:**
   - Upstream link to §4 (mode resolution gate).
   - Downstream link to §6 (scaffold flow, T16) — forward-reference is intentional; §6 lands in T16.

## P11 append-only verification

```
git diff acb0de1 -- plugins/pmos-toolkit/skills/readme/SKILL.md | grep '^-' | grep -v '^---' | wc -l
→ 0
```

§1-§4 untouched; only insertion is the new §5 block between §4 closer and `## Anti-Patterns`.

## Quantitative checks

| Check | Threshold | Actual |
|---|---|---|
| SKILL.md line count | ≤480 | 295 |
| Lines added | n/a | +41 |
| Plan grep `repo-miner\|repo_type_hint` | ≥2 | 8 |
| Lines removed vs `acb0de1` | 0 | 0 |
| Reference / scripts / tests touched | 0 | 0 |

## Pattern mirroring

Validation-by-evidence-grep in step 3 mirrors §2's FR-SR-3 sim-reader substring-grep pattern. Both treat the artifact-on-disk as the source of truth and the subagent's claim as a hypothesis to verify.

## Deviations

None. Content matches the dispatch-spec block in the T15 task brief verbatim.

## Next

T16 — §6 scaffold flow (consumes the validated `RepoMinerResult` from §5).
