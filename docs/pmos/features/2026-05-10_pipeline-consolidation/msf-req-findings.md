# MSF-Req Findings — pipeline-consolidation

**Mode:** /msf-req (req-mode; no PSYCH)
**Date:** 2026-05-10
**Target:** `01_requirements.md` (post-Loop-2 Tier 3, 18 decisions D1–D18, 7 OQs)
**Slug override:** `msf-req-findings.md` (D3/W4 dogfood — pre-shipping the slug-clash fix this very feature designs)
**Persona shape:** 1 persona × 4 scenarios; 4 journeys walked

## Persona × Scenarios

Single user (skill-author + toolkit-owner — same person, different hats). Scenarios:

- **S1 — First Tier-3 feature run after this ships.** User invokes `/feature-sdlc <new-idea>`; pipeline auto-tiers to 3; folded MSF/sim-spec runs default-on; user confronts the new D14/D16/D17 surfaces for the first time.
- **S2 — Tier-1 bug fix run.** Same orchestrator, lighter path; folded phases collapse to soft Recommended=Skip gates; tests whether tier-keyed gating actually feels light.
- **S3 — Multi-session retro debugging.** `/retro --last 5 --skill spec` standalone (W8 surface).
- **S4 — Resume after `/compact` mid-pipeline.** Pipeline at /spec; user runs `/compact`; invokes `/feature-sdlc --resume`; folded phases re-resolve from last-good HEAD per D16; D17 failure subsection re-prints.

## Journey × MSF Matrix

### J1 — Primary Tier-3 /feature-sdlc end-to-end (S1)

**Motivation**

| Consideration | Assessment | Evidence |
|---|---|---|
| Job-to-be-done | Strong; doc frames "ship Tier-3 feature with appropriate rigor without manual gate-memory" clearly | §Motivation/Job-to-be-done |
| Urgency | Strong; daily-use compounding | §Why now |
| Alternatives considered | Strong; 4 alternatives enumerated and rejected with reasoning | §Motivation/Alternatives |
| Value clarity | **Weak — bury-the-lede risk.** §Problem opens with mechanics ("three pseudo-stages") not user-visible win ("4 gates instead of 7, daily-friction reduction"). New reader has to mine for the value | §Problem opening paragraphs |

**Friction**

| Consideration | Assessment | Evidence |
|---|---|---|
| Cognitive load | **Mixed.** Gate count drops 7→4, but folded phases are still phases — the user sees `Phase 5.5 [folded] /msf-req` inside `/requirements`. Net visible-decision-points may be ~unchanged; only the prompt-count drops | §Solution Direction pipeline diagram lines 87–111; §Success Metrics row 1 |
| Perceived effort — auto-apply commit noise | **High at Tier 3.** D16 per-finding commits could yield 30–50 auto-apply commits per Tier-3 feature (10 from msf-req + 10 from msf-wf-per-wireframe + 10 from sim-spec). `git log` becomes dominated by auto-apply noise rather than human design choices | D16; W1/W2/W3 atomicity sub-bullets |
| Perceived loss — undo safety | **Per-finding revert is unsafe when findings are interrelated.** D16 documents `git revert <sha>` as undo. But if finding F2 builds on F1's edit (e.g., F1 added a section, F2 added a sub-section under it), reverting F1 alone leaves F2's sub-section orphaned. The doc doesn't address dependency-aware undo | D16 |
| Decision fatigue — flag count | **Creep.** /feature-sdlc + /requirements + /spec now collectively parse: `--tier`, `--resume`, `--no-worktree`, `--non-interactive`, `--interactive`, `--backlog`, `--skip-folded-msf`, `--skip-folded-sim-spec`, `--skip-folded-msf-wf` (if D7 splits per OQ-7). 9 flags. Argument-hint will be long | D13, D15, OQ-7; §Release prerequisites argument-hint requirement |
| Error recovery — failure surface latency | **High.** D17 surfaces folded-phase failures in Phase 11 (end-of-run) and on `--resume`. If `/requirements`'s folded MSF crashes at phase-3, the user drives 7 more phases (grill → wireframes → spec → plan → execute → verify → complete-dev) before being told. By Phase 11 the failure may be too late to act on | D17; D11 advisory contract |

**Satisfaction**

| Consideration | Assessment | Evidence |
|---|---|---|
| Completion confidence | **Weak — no affirmative success signal at Tier 3.** With softened /verify edge-case (advisory not blocking), a Tier-3 run with all folded phases skipped via flags AND no failures recorded looks identical to a Tier-3 run where they all ran cleanly. User has no positive signal "yes, the rigor actually happened" | Edge-cases table row 1 (post-Loop-2); D11 |
| Reassurance — audit trail | Strong for auto-applied; weak for deferred-NI. Per-finding commits give git-log audit. But sub-threshold findings deferred to OQ in NI mode go to the OQ index, not a folded-phase-scoped record | D14 NI refinement; D17 |
| Fit-for-job | Strong; each of 8 goals has a measurable observable | §Goals & Non-Goals |
| Progress signals | Strong; `00_pipeline.html` updates atomically post-phase | §Phase 2 atomic update protocol (Loop-1 doc body, /feature-sdlc reference) |

### J2 — Tier-1 bug fix /feature-sdlc (S2)

**Motivation**

| Consideration | Assessment | Evidence |
|---|---|---|
| Job-to-be-done | Strong; Tier 1 explicitly carved as lightweight | §Tier matrix; D2 tier-keyed default-on |
| Urgency | Bug-fix urgency self-evident | implicit |

**Friction**

| Consideration | Assessment | Evidence |
|---|---|---|
| Cognitive load — gate-prompt count at Tier 1 | **Tier-1 still confronts ~5 soft gates** (msf-req=Skip-rec, creativity=Skip-rec, wireframes=Skip-rec per Tier-1 override, prototype=Skip-rec, retro=Skip-rec). The user has to acknowledge each one even though all default to Skip. The "4 gates instead of 7" benefit is Tier-3-coded; Tier 1 didn't actually get fewer prompts | §Tier matrix; D2 |
| Perceived effort — pipeline ceremony at Tier 1 | Tier-1 minimal run still touches: requirements → spec → plan → execute → verify → complete-dev (6 hard phases). For a 5-line bug fix that's heavyweight. Out-of-scope for this feature (Non-Goal #3 freezes pipeline order) but worth noting as a related-work pointer | §Non-Goals; §Solution Direction |

**Satisfaction**

| Consideration | Assessment | Evidence |
|---|---|---|
| Completion confidence | Strong; Tier 1 has tight acceptance criteria template | §Tier matrix |

### J3 — Multi-session /retro standalone (S3)

**Motivation**

| Consideration | Assessment | Evidence |
|---|---|---|
| Job-to-be-done | Strong; capability gap clearly addressed | §Problem (last paragraph) |
| Alternatives | Strong; "run /retro per-session and visually diff" enumerated and rejected | §Motivation/Alternatives |

**Friction**

| Consideration | Assessment | Evidence |
|---|---|---|
| Cognitive load — scope-confirmation table at scale | At N=20 candidate transcripts, the `(date, size, skill-invocation-count, project-slug)` table is 20 rows. Scannable. At `--project all` × 30 projects × 5 sessions = 150 → table becomes a wall (D18 caps the dispatch but the *enumeration table* shown to the user is uncapped). User has to scan 150 rows to confirm scope | W8; D18 |
| Perceived effort — wave progress visibility | 5 in-flight × 4 waves = 20 subagents over wall-clock T. If 1 of 5 in-flight stalls, parent waits silently. Doc doesn't specify per-wave progress emission | W8; D18 |
| Perceived loss — flat-text rendering of nested findings | D10 emits constituent raw findings as nested sub-list under aggregated rows. In flat-text terminals (no Markdown rendering), the nested indentation may be ambiguous — aggregated rows and constituents run together visually | D10 Loop-2 refinement |

**Satisfaction**

| Consideration | Assessment | Evidence |
|---|---|---|
| Completion confidence | Strong; recurring patterns at top, unique below | W8 Phase 5 output |
| Reassurance — version-drift annotation | Strong; `seen across <session-dates>` per finding lets author spot pre-revision findings | W8; §Friction Points table row 6 |
| Fit-for-job | Strong; directly addresses the gap | §Problem; G8 |

### J4 — Resume after /compact mid-pipeline (S4)

**Motivation**

| Consideration | Assessment | Evidence |
|---|---|---|
| Job-to-be-done | Strong; resume contract is invariant | /feature-sdlc Phase 0.b reference |
| Urgency | Critical; every compact threatens loss | implicit |

**Friction**

| Consideration | Assessment | Evidence |
|---|---|---|
| Cognitive load — re-orientation surfaces | Post-compact resume now has THREE artifacts to re-orient on: (1) status table, (2) OQ index, (3) folded-phase-failures subsection (new D17). Each is self-contained but reading them as separate paragraphs adds latency vs. a single combined "Resume Status" view | D17; §Resume protocol |
| Perceived effort — resume granularity inside folded phase | **Underspecified.** D16 says per-finding commits land sequentially; on resume from last-good HEAD, does the orchestrator re-run the entire folded phase, or pick up at the next finding? If a sub-threshold AskUserQuestion was mid-flight at compact-time, resume needs to re-prompt that specific question, not re-apply the high-confidence batch from scratch. State schema for per-finding resume granularity isn't pinned | D16; G-A grill gap |
| Perceived loss — state.yaml atomicity for new field | `state.yaml.phases.<parent>.folded_phase_failures[]` is the source of truth for D17 surfacing. `/feature-sdlc` Phase 2 atomic-update-protocol covers (state.yaml, 00_pipeline.md, chat table) but doesn't explicitly extend to the new field's write-atomicity. Compact mid-write could corrupt | D17; G-A |

**Satisfaction**

| Consideration | Assessment | Evidence |
|---|---|---|
| Completion confidence — resume to last-good HEAD | Strong design intent; D16 makes this concrete | D16 |
| Progress signals — failure subsection re-print | Strong — failure record survives compact and re-surfaces on resume per D17 | D17 |

---

## Recommendations — Must / Should / Nice

### Must (3) — pin in /spec; don't ship without resolving

| # | Finding | Fold into | Effort |
|---|---|---|---|
| **M1** (was F5) | **Folded-phase failure must surface in-line at point-of-failure**, not just Phase 11. Tier-3 user driving 7 more phases after a phase-3 MSF crash is blind. Add a chat-line warning the moment `state.yaml.phases.<parent>.folded_phase_failures[]` is appended; Phase 11 then re-summarizes | D17 spec body in /spec; mention in /feature-sdlc anti-patterns | low — single chat-emit at append-time |
| **M2** (was F12) | **Resume granularity inside a folded phase is underspecified.** Either pin coarse-grained (resume = re-run-whole-folded-phase from last-good HEAD) and document it explicitly so user knows what to expect, OR specify fine-grained resume state in `state.yaml.phases.<parent>.folded_phase_progress` | D16/D17 spec; state-schema bump (G-A already deferred to /spec; expand scope) | medium — schema work |
| **M3** (was F3) | **Per-finding revert is unsafe when findings are interrelated.** Either: (a) commit interrelated findings as a unit with shared annotation; (b) document explicitly that revert may need cherry-pick-rebase for dependent findings; (c) emit a CAUTION line in the auto-apply commit message body for findings flagged as having dependencies on prior findings | D16 spec body | low — convention + commit-message format |

### Should (5) — ship-quality polish; don't block

| # | Finding | Fold into | Effort |
|---|---|---|---|
| **S1** (was F2) | **Auto-apply commit-log noise.** 30–50 auto-apply commits per Tier-3 feature dominate `git log`. Mitigations: squash all auto-applies from one folded phase into one commit at phase-end (preserving per-finding messages in body); OR add `git log --invert-grep="auto-apply"` recipe to /complete-dev output | /spec — propose commit-strategy choice as design decision | medium |
| **S2** (was F6) | **Tier-1 still confronts 5 soft gates.** Add `--minimal` or `--no-soft-gates` flag to `/feature-sdlc` that AUTO-PICKs Skip on every soft gate. Tier 1 default-on for this flag if not specified | /spec — new flag on /feature-sdlc; matches D2 spirit | low |
| **S3** (was F11) | **Post-compact resume re-prints THREE artifacts.** Combine into a single "Resume Status" panel in chat with clear sections (status table, failures, OQs). Reduce re-orientation latency | /feature-sdlc Phase 0.b template | low |
| **S4** (was M1 motivation) | **Bury-the-lede risk in §Problem.** Open §Problem with the user-visible value ("daily pipeline user feels gate fatigue; Tier-3 mandates are convention not enforcement") before mechanics ("three pseudo-stages"). Aids comprehension for cold-context readers | edit `01_requirements.md` §Problem in this run, OR defer to /spec rewrite of `02_spec.md` §Problem | low — single paragraph |
| **S5** (was F13) | **Atomicity of state.yaml writes for `folded_phase_failures[]`.** /feature-sdlc Phase 2 atomic-update-protocol covers the existing 3-tuple; explicitly extend to cover the new field. State the write-order and roll-back contract | /spec G-A scope expansion | low |

### Nice (6) — opportunistic; gate at /spec discretion

| # | Finding | Fold into | Effort |
|---|---|---|---|
| **N1** (was F1) | **Net cognitive load metric.** Add a "visible-decision-points" measure (gates + folded-phase boundaries surfaced to user) to §Success Metrics alongside the gate-count drop. Honest accounting | edit §Success Metrics | low |
| **N2** (was F4) | **Flag-count creep.** 9 flags across 3 skills. `/feature-sdlc --help` quick reference recipe; ensure argument-hint catches up per §Release prerequisites FR-RELEASE.i | /complete-dev release notes | low |
| **N3** (was F8) | **Scope-confirmation table grouping for `--project all`.** At >20 transcripts, group by project-slug; collapse to "5 projects, 47 transcripts (expand)". Tightens visual surface | W8 Phase 1 spec | medium |
| **N4** (was F9) | **Per-wave progress emit during multi-session retro scan.** "Wave 2/4: 5/5 subagents complete (T+47s)" — keeps user oriented when a wave stalls | W8 Phase 2 spec | low |
| **N5** (was F10) | **Flat-text legibility of nested aggregated findings.** Use indented bullet markers that render acceptably in plaintext (e.g., `  └─ raw:`); don't rely on Markdown nesting | D10 spec body | trivial |
| **N6** (was S1) | **Affirmative completion signal at Tier 3.** /verify currently silent on "all folded phases ran cleanly." Add an explicit `✓ folded phases complete (msf-req: 6 findings, msf-wf: 4 findings, sim-spec: 28 scenarios)` line at /verify run | /verify spec edit (out of feature scope; flag for /spec review) | low |

---

## Summary

- **3 Must, 5 Should, 6 Nice = 14 actionable findings.** None are doc-rewrites; all are spec-level refinements to fold into /spec or, for S4 only, an edit to §Problem of the live requirements doc this run.
- **High-leverage Must items cluster around the resume + failure-surfacing surface (M1, M2, M3)** — exactly where D11 / D16 / D17 added contracts in Loop-2 but didn't fully spec them. Loop-2 closed the *what*; Must items demand the *when* and *granularity*.
- **Should items split into UX polish (S1, S3, S4) and contract-completion (S2, S5).**
- **No persona-conditional findings.** Single-user tool collapses persona axis; all 14 findings apply to the same user across the 4 scenarios.
- **No PSYCH score** — req-mode is text-only.
