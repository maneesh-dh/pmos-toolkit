# Add /plan and /verify to /create-skill — Spec

**Date:** 2026-05-08
**Status:** Ready for Plan
**Requirements:** `docs/pmos/features/2026-05-08_update-skills-add-plan-verify/01_requirements.md`

---

## 1. Problem Statement

`/pmos-toolkit:create-skill` is the only multi-skill orchestrator in the toolkit that doesn't dogfood the requirements→spec→[grill]→plan→execute→verify pipeline. It jumps from spec/grill straight to implement, then runs an inline pre-save checklist instead of `/verify`. This spec defines the SKILL.md edits that align `/create-skill` with `/update-skills` Phase 8 contract — adding a `/plan` invocation (Tier 2+) and a `/verify` invocation (mandatory all tiers), and deleting the redundant inline checklist.

Primary success metric: 100% of Tier 2+ runs produce a plan artifact; 100% of all-tier runs produce a verify artifact.

---

## 2. Goals

| # | Goal | Success Metric |
|---|---|---|
| G1 | `/create-skill` Tier 2+ invokes `/pmos-toolkit:plan` after spec/grill, before implement. | grep + audit of next 3 Tier 2+ runs. |
| G2 | `/create-skill` (all tiers) invokes `/pmos-toolkit:verify` after implement. | grep + audit of next 3 runs. |
| G3 | Inline pre-save checklist deleted; release prereqs preserved in /verify seed. | Phase 7/checklist headers absent from new SKILL.md; release-prereq language present in Phase 8 invocation. |
| G4 | Tier table workflow column reflects new phases. | Visual diff of L44-L48 (legacy) vs new tier table. |

---

## 3. Non-Goals

- NOT modifying `/update-skills` — already-handled (F3 skipped).
- NOT modifying `/plan` or `/verify` — black-box dependencies.
- NOT adding new tiers, signals, or interview questions.
- NOT changing Phase 1 (intent), 2 (auto-tier), 3 (interview), 4 (spec), or 5 (grill).
- NOT introducing a new feature flag — change ships unconditionally as a minor version bump.

---

## 4. Decision Log

| # | Decision | Options Considered | Rationale |
|---|---|---|---|
| D1 | `/plan` runs at Tier 2+ only. | (a) T2+; (b) T3 only; (c) all tiers. | Match `/update-skills` Phase 8 contract; T1 has no spec/plan. |
| D2 | `/plan` runs **after** `/grill`. | (a) After grill; (b) before grill. | Plan consumes the grill-hardened spec. Mirrors `/update-skills`. |
| D3 | `/verify` mandatory all tiers. | (a) Optional T1; (b) mandatory; (c) skip T1. | User-mandated. T1 still benefits from lint/test/multi-agent review. |
| D4 | Inline pre-save checklist deleted entirely. | (a) Drop; (b) keep T1 fallback; (c) keep all tiers. | `/verify` is single source of truth; checklist redundant per D3. |
| D5 | Spec status flow: draft → grilled (T3) → planned (T2+) → approved → implemented → verified. | (a) granular; (b) reuse `approved`. | Granular states make resume/skip checks unambiguous; matches grill status pattern. |
| D6 | `/plan` invoked with the spec doc path as first positional arg. | (a) Spec path; (b) wrapper. | Code recon: `plan/SKILL.md` argument-hint is `<path-to-spec-doc>`. Use directly. |
| D7 | `/verify` invoked with the spec doc path as first positional arg, default scope. | (a) Spec path default; (b) `--scope phase`; (c) custom mode. | Code recon: `verify/SKILL.md` argument-hint accepts spec path; default mode covers static + multi-agent + spec compliance, which is what skill verification needs. No `--for-skill` mode exists. |
| D8 | `/create-skill` emits a final pipeline-status table à la `/update-skills` Phase 8. | (a) Emit; (b) skip. | Author needs to see which phases ran (esp. when /plan or /verify fall back). Cheap to add; high audit value. |
| D9 | Release prereqs (README row, version bump) live as **FR rows in this spec** so `/verify` Phase 5 4b picks them up via normal spec-compliance. | (a) FR rows in spec; (b) seed-brief hints (rejected — /verify has no slot for free-form invocation hints); (c) drop, rely on /push hook. | Code recon: /verify Phase 5 4b reads the spec doc and grades each FR; this is the only mechanism that actually flows. Seed-brief hints would be invented integration. |
| D10 | Renumber: implement = Phase 7, verify = Phase 8, learnings = Phase 9. | (a) Renumber; (b) decimal Phase 5.5 / 6.5. | Clean monotonic numbering matches doc readability and avoids "what runs first at T1" confusion. |

---

## 5. Phase Outline (the system being designed)

The implementation is a rewrite of `plugins/pmos-toolkit/skills/create-skill/SKILL.md`. The new phase structure:

| # | Phase | Tier 1 | Tier 2 | Tier 3 |
|---|---|---|---|---|
| 1 | Intent capture | ✓ | ✓ | ✓ |
| 2 | Auto-tier | ✓ | ✓ | ✓ |
| 3 | Requirements gathering (interview) | abbreviated | ✓ | ✓ |
| 4 | Write spec to disk | skip | ✓ | ✓ |
| 5 | Adversarial review via /grill | skip | skip | ✓ |
| **6** | **/plan invocation** *(NEW)* | **skip** | **✓** | **✓** |
| **7** | Implement against the spec *(renumbered from current Phase 6)* | ✓ (from interview) | ✓ (from plan) | ✓ (from plan) |
| **8** | **/verify invocation** *(NEW; replaces current Phase 7 checklist)* | **✓ mandatory** | **✓ mandatory** | **✓ mandatory** |
| 9 | Capture Learnings *(renumbered from current Phase 8)* | ✓ | ✓ | ✓ |

Spec status flow: `draft → grilled (T3) → planned (T2+) → approved → implemented → verified`.

### Phase 6 contract (new)

```
1. Skip if Tier 1.
2. Resolve spec path from Phase 4 output.
3. Invoke `/pmos-toolkit:plan <spec-path>`. Default-foreground.
4. On success: spec status approved → planned. User approves the plan doc (gated by /plan's own Phase 5 review).
5. On failure (skill missing / cancelled / errored):
   - Skill missing → log warning to spec §14, AskUserQuestion: Continue (skip plan) / Abort.
   - Cancelled → AskUserQuestion: Retry / Abort.
   - Default Retry once; second failure surfaces same dialog.
6. Do not proceed to Phase 7 until plan status is `approved` (or user explicitly chose Continue).
```

### Phase 8 contract (new — replaces current Phase 7 inline checklist)

```
1. Mandatory all tiers (no skip gate).
2. Invoke `/pmos-toolkit:verify <spec-path>`. Default-foreground.
3. (No "hints" mechanism — release prereqs live as FR-12 / FR-13 in this spec. /verify Phase 5 4b reads the spec doc and grades each FR; that is how the README row + version bump get verified. See D9.)
4. On success: spec status implemented → verified.
5. On blocker findings unresolved: status stays `implemented`; final pipeline-status table flags the skill as not-ready. User can re-run /create-skill from Phase 8 to retry verification.
6. On /verify skill missing: HARD ERROR. AskUserQuestion: Install/upgrade /verify / Accept-as-risk override (logs warning to spec §14, sets status `unverified`) / Abort. Default Abort.
7. After Phase 8, emit a pipeline-status table mirroring /update-skills Phase 8 format:
   | phase | status | artifact path | timestamp |
```

---

## 6. Functional Requirements

### 6.1 SKILL.md edits

| ID | Requirement |
|---|---|
| FR-01 | A new numbered Phase 6 "/plan invocation" section exists in SKILL.md, gated to Tier 2+, invokes `/pmos-toolkit:plan` with the spec-path arg. |
| FR-02 | A new numbered Phase 8 "/verify invocation" section exists, mandatory all tiers, invokes `/pmos-toolkit:verify` with the spec-path arg and the release-prereq seed hints from D9. |
| FR-03 | The current "Phase 7: Pre-save checklist" section AND the "Checklist Before Saving" Conventions section are deleted. No remaining checklist headers in the file. |
| FR-04 | The Tier table at current SKILL.md L44-L48 has its "Workflow" column rewritten per §5 of this spec. Tier-detection signals (left columns) unchanged. |
| FR-05 | The Anti-patterns section gains two new bullets verbatim:<br>• "Skipping the /plan phase at Tier 2+. Plan is the cheapest place to map the spec to TDD-friendly tasks before code lands."<br>• "Skipping /verify because /execute looked clean. /verify is non-skippable per the per-skill pipeline contract; no opt-out at any tier." |
| FR-06 | The Phase 6 implement section (renumbered from current Phase 6) gains one sentence: "If a plan was produced in Phase 6, implement against it; the plan is the source of truth, the spec is its parent." |
| FR-07 | Spec status flow language in Phase 4 updated to include `planned` and `verified` states per D5. |
| FR-08 | Pipeline-status table emitted at end of Phase 8 mirrors /update-skills Phase 8 columns: `phase | status | artifact path | timestamp`. Implementation: a Markdown table that the skill instructs the agent to write to chat (not a file). |
| FR-09 | All inter-phase references in SKILL.md (e.g., "see Phase 6 below") are renumbered to match new structure. |

### 6.2 Reference + assets (no changes)

| ID | Requirement |
|---|---|
| FR-10 | `reference/spec-template.md` is unchanged by this spec. |
| FR-11 | No new files added under `plugins/pmos-toolkit/skills/create-skill/`. |
| FR-12 | A row is added to `README.md` under the appropriate Skills section noting the updated /create-skill pipeline (or, if /create-skill already has a row, updating that row's description to reflect plan+verify). |
| FR-13 | A **minor** version bump is applied in BOTH `plugins/pmos-toolkit/.claude-plugin/plugin.json` AND `plugins/pmos-toolkit/.codex-plugin/plugin.json` (2.24.0 → 2.25.0). Versions MUST stay in sync; pre-push hook enforces. |

---

## 7. Non-Functional Requirements

| ID | Category | Requirement |
|---|---|---|
| NFR-01 | Size | New SKILL.md ≤ 500 lines (current ~356; expected ~400-420). |
| NFR-02 | Numbering | Phase numbering is monotonic 1→9; no gaps; learnings is Phase 9 (last numbered phase before Conventions/Anti-patterns). |
| NFR-03 | Backward compat | Existing in-flight `/create-skill` invocations (mid-spec, mid-grill) are NOT supported across this version bump — same as any other SKILL.md change. Document in changelog only. |
| NFR-04 | Convention adherence | New phases include skip-gate language ("Skip if Tier N") and findings-protocol references where applicable, per Convention 6. |

---

## 8. API Changes

N/A — no service APIs. The "API" between `/create-skill` and `/plan` / `/verify` is the SLASH-COMMAND invocation contract, locked by D6/D7.

---

## 9. Database Design

N/A — no DB.

---

## 10. Findings Presentation Protocol additions

The new Phase 6 and Phase 8 each invoke an external skill that has its own Findings Presentation Protocol. `/create-skill` does NOT layer its own protocol on top — it surfaces the child skill's findings to the user verbatim and accepts the dispositions there.

Specifically:
- Phase 6 `/plan` invocation: dispositions handled by `/plan` Phase 4 review loops. `/create-skill` only consumes the final approved plan.
- Phase 8 `/verify` invocation: dispositions handled by `/verify` Phase 5 spec-compliance + Phase 6 test-hardening. `/create-skill` consumes the final verify report and decides only whether to mark spec status `verified` or `implemented` (blocker findings → stay at `implemented`).

The user-facing AskUserQuestion calls in `/create-skill` are limited to:
1. Continue / Retry / Abort dialogs on Phase 6 or Phase 8 failure.
2. Accept-as-risk override on Phase 8 hard error.

---

## 11. Platform Fallbacks

Per the existing Platform Adaptation section of `/create-skill`, plus new entries:

| Condition | Behavior |
|---|---|
| `AskUserQuestion` unavailable | Phase 6 / Phase 8 failure dialogs degrade to a numbered table with disposition column; user replies inline. |
| Subagent dispatch unavailable | Both `/plan` and `/verify` invoke inline (sequential) — they already support this per their own Platform Adaptation. |
| `/plan` skill missing | Log warning to spec §14, AskUserQuestion Continue/Abort, default Continue. Pipeline-status table marks Phase 6 as `skipped (skill missing)`. |
| `/verify` skill missing | HARD ERROR (per Phase 8 contract step 6). AskUserQuestion Accept-as-risk/Abort, default Abort. |
| Pipeline-setup `_shared/pipeline-setup.md` missing | Inherit current `/create-skill` behavior — out of scope here. |

---

## 12. Edge Cases

| # | Scenario | Condition | Expected Behavior |
|---|---|---|---|
| E1 | User passes `--tier 1` for what interview signals as Tier 2 | Tier override | Honor override per current Phase 2; skip Phase 4/5/6; still run Phase 8 /verify. |
| E2 | User cancels `/plan` mid-flow | Phase 6 cancelled | AskUserQuestion Retry/Abort; default Retry once. |
| E3 | `/plan` skill returns success but plan doc was not written | Pathological | Detect by: after /plan returns, check expected plan path exists. If missing → treat as failure, run E2 dialog. |
| E4 | `/verify` blocker findings unresolved | User dispositions in /verify, blockers remain | `/create-skill` does NOT mark status verified; pipeline-status flags as not-ready. User re-invokes `/pmos-toolkit:verify <spec-path>` directly (idempotent) to resume — `/create-skill` itself has no `--resume` flag. |
| E5 | User runs `/create-skill` against a spec that was approved before this version | Pre-existing approved spec, no `planned` status | Treat `approved` as eligible to enter Phase 6 directly; bump status to `planned` after /plan completes. |
| E6 | Two consecutive `/plan` invocations (resume) | Plan doc already exists | `/plan` itself handles update vs. fresh; `/create-skill` passes the spec path; behavior inherited. |
| E7 | New SKILL.md exceeds 500 lines after edits | NFR-01 breach | Refactor: extract the longer Convention 1 block into `reference/conventions-save-location.md`. (Triggered if measured > 500.) |

---

## 13. Configuration & Feature Flags

None. Change ships unconditionally with the next minor version bump of `pmos-toolkit`.

---

## 14. Testing & Verification Strategy

### 14.1 Static checks (run during /verify Phase 2)

```bash
# Line count
wc -l plugins/pmos-toolkit/skills/create-skill/SKILL.md
# Expect: ≤ 500

# Phase numbering monotonic 1..9
grep -E '^## Phase [0-9]+:' plugins/pmos-toolkit/skills/create-skill/SKILL.md | awk '{print $3}' | tr -d ':'
# Expect: 1 2 3 4 5 6 7 8 9 (in order)

# /plan invocation present under Phase 6
grep -A 5 '^## Phase 6:' plugins/pmos-toolkit/skills/create-skill/SKILL.md | grep -c 'pmos-toolkit:plan'
# Expect: ≥ 1

# /verify invocation present under Phase 8, mandatory language
grep -A 10 '^## Phase 8:' plugins/pmos-toolkit/skills/create-skill/SKILL.md | grep -E 'pmos-toolkit:verify|mandatory|non-skippable'
# Expect: ≥ 2 hits

# Inline checklist removed
grep -E 'Pre-save checklist|Checklist Before Saving' plugins/pmos-toolkit/skills/create-skill/SKILL.md
# Expect: 0 hits

# Anti-patterns include /plan + /verify skip bullets
grep -E 'Skipping.*/plan|Skipping.*/verify' plugins/pmos-toolkit/skills/create-skill/SKILL.md
# Expect: ≥ 2 hits

# Tier table workflow column updated
sed -n '/^| Tier |/,/^$/p' plugins/pmos-toolkit/skills/create-skill/SKILL.md | grep -E 'Phase 6|Phase 8'
# Expect: hits in T2 and T3 rows
```

### 14.2 Manual spot check

Invoke `/pmos-toolkit:create-skill make a tiny test skill that echoes hi` after install; confirm:
1. Phase 6 invokes /plan (Tier 2+).
2. Phase 8 invokes /verify (all tiers).
3. Pipeline-status table emitted at end of Phase 8.

(Out of scope to fully run — verify via reading SKILL.md output and the agent's announcements during invocation.)

### 14.3 Multi-agent review (run during /verify Phase 3)

`/verify` Phase 3 runs `git diff` on the SKILL.md edits and dispatches the multi-agent code review. No special hooks needed.

### 14.4 Spec compliance (run during /verify Phase 5)

`/verify` Phase 5 reads `02_spec.md`, checks each FR-XX has a corresponding implementation in the diff. Pass the release-prereq hints (D9) so the compliance check flags missing README row / version bump.

### 14.5 Verification commands (final)

```bash
# Run during /execute T19 (final verify command)
git diff --stat plugins/pmos-toolkit/skills/create-skill/SKILL.md
wc -l plugins/pmos-toolkit/skills/create-skill/SKILL.md

# Then invoke /verify itself on this spec
/pmos-toolkit:verify docs/pmos/features/2026-05-08_update-skills-add-plan-verify/02_spec.md
```

---

## 15. Rollout Strategy

- Single commit edits `plugins/pmos-toolkit/skills/create-skill/SKILL.md`.
- README row under "Tracking & context" or "Pipeline" remains valid (no new skill row needed; this is a modification).
- Minor version bump: `plugins/pmos-toolkit/.claude-plugin/plugin.json` AND `.codex-plugin/plugin.json` (from current 2.24.0 to 2.25.0). Pre-push hook enforces sync.
- No data migration. No feature flag. Rollback: `git revert` if a downstream skill (`/update-skills` calling `/create-skill`) breaks.
- Document change in CHANGELOG/changelog skill on next `/push`.

---

## 16. Research Sources

| Source | Type | Key Takeaway |
|---|---|---|
| `plugins/pmos-toolkit/skills/create-skill/SKILL.md` | Existing code | Current pipeline; tier table at L44-L48; Phase 7 inline checklist at L131-133 + Conventions checklist at L314-344. |
| `plugins/pmos-toolkit/skills/update-skills/SKILL.md` Phase 8 | Existing code | Reference pattern for plan + verify dispatch; failure dialog UX. |
| `plugins/pmos-toolkit/skills/plan/SKILL.md` L5 | Existing code | argument-hint: `<path-to-spec-doc> [--backlog <id>] [--feature <slug>]`. Confirms D6. |
| `plugins/pmos-toolkit/skills/verify/SKILL.md` L5, L88 | Existing code | argument-hint accepts spec path; supports `--scope phase --feature --phase` for partial verify; default mode runs all phases. Confirms D7, no `--for-skill` mode. |
| Triage doc + requirements doc (this folder) | Source of truth | Approved findings F1, F2; F3 skipped. Tier 3. |
| `~/.pmos/learnings.md` /create-skill entries | Internal | Tier-3 grill on orchestrator skills has high yield; path resolution should delegate to `_shared/pipeline-setup.md`. Both apply. |
