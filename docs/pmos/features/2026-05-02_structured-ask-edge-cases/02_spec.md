# Structured-Ask Edge Cases + Per-Skill Retro Patches — Spec

**Date:** 2026-05-02
**Status:** Draft
**Tier:** 2 — Enhancement
**Source:** Retro findings from a 4-skill pipeline session (`/requirements`, `/spec`, `/simulate-spec`, `/plan`)
**Affected skills:** `requirements`, `spec`, `simulate-spec`, `plan`, plus a new shared protocol file

---

## 1. Problem Statement

A single retro session across four pipeline skills surfaced two classes of issues:

1. **Cross-cutting gap:** every skill that uses `AskUserQuestion`-batched dispositions has the same blind spot — what to do when **user input slips outside the structured form**. Three concrete shapes recurred:
   - User answers a structured question with **free-form text** (caught by the agent and back-mapped manually, but not prescribed).
   - User picks a **non-recommended option that breaks an existing invariant** (agent caught it and added a Decision-Log entry independently, but the skill didn't ask for it).
   - **Leftover findings** in the last batch don't share a category, so the "≤4 per call" rule produces incoherent question groupings.
2. **Per-skill nits:** small template/checklist issues in each individual skill (Non-Goals format, N/A pseudocode sections, plan-length bias from long inline code blocks, missing structural-checklist item for refactor-then-modify tasks).

Both classes are well-defined and were already worked around manually during the retro session — codifying them removes the manual-workaround cost.

**Primary success metric:** in the next pipeline run, the agent does not need to independently invent any of these behaviors — the skill prescribes them.

---

## 2. Goals

| # | Goal | Success Metric |
|---|------|---------------|
| G1 | A single shared protocol governs structured-ask edge cases across the pipeline | All four skills reference `_shared/structured-ask-edge-cases.md` from their findings/disposition sections |
| G2 | Each per-skill retro nit is fixed in-place at the existing template/checklist anchor | The 5 specific patches in §6 land on their named line ranges with no template-wide rewrites |
| G3 | The change is additive and non-breaking for in-flight pipeline runs | No section header renames; no removed checklist items; references are appended, not replacing existing prose |

---

## 3. Non-Goals

- NOT redesigning the AskUserQuestion batching rules — because the existing "≤4 per call" rule works for the common case; we're only handling edge cases
- NOT touching `/execute` or `/verify` — because the retro covered four skills and the cross-cutting pattern is in the requirements→plan range
- NOT bumping the plugin manifest version (`.claude-plugin` / `.codex-plugin`) — because this is a docs/protocol change with no code surface; bumping is the user's call at release time
- NOT writing an RFC for "edge cases of structured asks" — because four concrete patterns are enough; over-generalizing risks rule-bloat

---

## 4. Decision Log

| # | Decision | Options Considered | Rationale |
|---|----------|-------------------|-----------|
| D1 | Place the shared protocol at `plugins/pmos-toolkit/skills/_shared/structured-ask-edge-cases.md` | (a) `_shared/`, (b) per-skill duplication, (c) inside `interactive-prompts.md` | (a). `_shared/` already hosts `feature-folder.md` and `interactive-prompts.md` — same pattern. (b) drifts. (c) bundles two distinct topics (input collection vs. finding dispositions). |
| D2 | Reference the protocol via a one-line pointer at each skill's existing "Findings Presentation Protocol" section, not by inlining content | (a) Pointer + new section in shared file, (b) inline copy, (c) only update shared file | (a). Keeps each skill's prose the same length; new behaviors live in one place. (b) creates 4 places to update on next change. (c) makes the rules invisible from the skill itself. |
| D3 | Cover three specific edge cases in the shared protocol: free-form-reply, non-recommended-pick-with-invariant-impact, leftover-batch-coherence | (a) Just the 3 from retro, (b) Add hypothetical extras (silent dispositions, ambiguous "yes", multi-pick), (c) Combine with new `interactive-prompts.md` section | (a). The retro produced exactly these three with evidence. Adding hypotheticals is rule-bloat; the protocol is meant to grow with future retros, not preempt them. |
| D4 | `/requirements` Non-Goals: change format from `- NOT doing [X] because [reason]` to `- NOT doing [X] — because [reason]` (em-dash separator) | (a) Em-dash, (b) "Because:" prefix as the agent used, (c) Keep current | (a). The em-dash is the format already used in the spec template's `## 3. Non-Goals` block; standardizes across docs. (b) inconsistent with neighboring artifacts. |
| D5 | `/simulate-spec` Phase 6 four-section template: allow declaring a section "N/A — <one-line reason>" instead of forcing an empty bullet list | (a) Allow N/A, (b) Always require all four, (c) Drop the four-section requirement entirely | (a). The discipline is that *the question is asked*, not that every flow has DB calls. (c) loses the catch-the-bugs-pseudocode-misses value. |
| D6 | `/simulate-spec` Phase 7 batching: explicit "category coherence > batch fullness" rule | (a) Add the rule, (b) Drop the ≤4 cap, (c) Add cap of 3 instead | (a). The cap is a useful upper bound; the actual fix is to stop padding when leftovers are unrelated. Issue 1-2 question calls when needed. |
| D7 | `/plan` long-task code block: add explicit guidance at "Task Design Rules" — if a single task's pasted code block exceeds ~80 lines, prefer splitting / external scratch / interface-only prescription | (a) Add the guidance as new bullet, (b) Add a hard line limit, (c) Keep as-is | (a). A hard limit fights legitimate cases; a heuristic with three concrete remedies models the right thinking. |
| D8 | `/plan` Cleanup template items: mark each bullet as `[only if applicable]` inline rather than relying on agent judgment | (a) Inline marker, (b) Convert to "Pick relevant items from this menu" prose, (c) Keep current with footer hint | (a). The footer hint at line 251 already says this but the agent leaked unrelated items into a real plan; making it inline per-bullet removes the ambiguity. |
| D9 | `/plan` Structural Checklist: add item 12 — "Does any task modify a function whose existing structure isn't preserved by the modification? If yes, the prerequisite refactor must be its own numbered sub-step before the additive change." | (a) Add item 12, (b) Add as a Design-Level Self-Critique question, (c) Skip — agent caught it independently | (a). The retro evidence showed the agent's design critique caught it; making it structural means it's checked every loop, not only when the agent reads adversarially. |

---

## 5. User Journeys

**Primary user:** the agent running a pipeline skill in a future session.

### 5.1 Free-form reply to structured question

1. Skill issues `AskUserQuestion` for finding F1 with options Fix / Modify / Skip / Defer.
2. User replies in free-form text rather than picking an option (e.g., "actually, just clean up the old data first").
3. Skill (per shared protocol): paraphrase the reply back as one of the four options, ask the user to confirm the disposition, then apply.
4. Audit trail: Review Log entry cites both the original reply and the back-mapped disposition.

### 5.2 Non-recommended option breaks an invariant

1. Skill presents finding F2; agent's recommended option is (a). User picks (b).
2. Skill (per shared protocol): before moving on, ask "Does this choice change any existing invariant or contract? If yes, capture as a Decision-Log entry with the trade-off explicit."
3. If yes, agent appends a numbered Decision-Log entry to the working artifact.
4. If no, agent records the disposition and moves on.

### 5.3 Leftover findings don't share a category

1. Skill has 9 findings. First two batches (4+4) are category-coherent. The 9th is a stray.
2. Skill (per shared protocol): issue the 9th as a 1-question call rather than padding to 4 with unrelated items from earlier categories.

### 5.4 Per-skill nits (no journey change)

Template/checklist text is updated; existing skill behavior unchanged. Future runs adopt the new wording on first read.

---

## 6. Functional Requirements

### 6.1 New shared protocol file

| ID | Requirement |
|----|-------------|
| FR-01 | A new file exists at `plugins/pmos-toolkit/skills/_shared/structured-ask-edge-cases.md` |
| FR-02 | The file documents three edge-case sections: (1) Free-form reply to structured ask, (2) Non-recommended pick with invariant impact, (3) Leftover-batch coherence |
| FR-03 | Each section has: trigger condition, prescribed behavior (1-3 numbered steps), and an audit-trail rule (what to log where) |
| FR-04 | The file links back to consumer skills (`requirements`, `spec`, `simulate-spec`, `plan`) so future maintainers can find all reference points |
| FR-05 | A "Platform fallback" subsection covers the case where `AskUserQuestion` is unavailable (numbered-list reply mode) — same edge cases, fallback handling |

### 6.2 Reference insertion in each consumer skill

| ID | Requirement |
|----|-------------|
| FR-06 | `plugins/pmos-toolkit/skills/requirements/SKILL.md` — at the existing review/findings section, append a one-line pointer to `_shared/structured-ask-edge-cases.md`. (Note: `/requirements` doesn't currently have a "Findings Presentation Protocol" section; the pointer goes immediately after its review-loop instructions.) |
| FR-07 | `plugins/pmos-toolkit/skills/spec/SKILL.md` — at the end of the `### Findings Presentation Protocol` section (after current line 520), append: "For edge cases (free-form replies, invariant-breaking picks, incoherent leftover batches), see `../_shared/structured-ask-edge-cases.md`." |
| FR-08 | `plugins/pmos-toolkit/skills/simulate-spec/SKILL.md` — at the end of the Phase 7 "Tier-based interaction" section (after current line 351), append the same pointer line |
| FR-09 | `plugins/pmos-toolkit/skills/plan/SKILL.md` — at the end of `### Findings Presentation Protocol` (after current line ~370), append the same pointer line |
| FR-10 | All four pointer lines use the relative path `../_shared/structured-ask-edge-cases.md` so they work from the skill's own directory |

### 6.3 Per-skill nit patches

| ID | Requirement |
|----|-------------|
| FR-11 | `requirements/SKILL.md` line 231 — change `- NOT doing [X] because [reason]` to `- NOT doing [X] — because [reason]`. Apply the same em-dash to line 282-283 (Tier 3 template) for consistency. |
| FR-12 | `spec/SKILL.md` Phase 3 Role Protocol — after current line 154, add a step 4: "If the user picks a non-recommended option, before moving to the next role, ask: 'Does this choice change any existing invariant or contract? If yes, capture it as a Decision-Log entry with the trade-off explicit.'" |
| FR-13 | `simulate-spec/SKILL.md` Phase 6 — at the four-section template (current lines 316-321), add a sentence: "If a section doesn't apply to this flow (e.g., file-IO-only flows have no DB calls), declare it as `**DB calls:** N/A — <one-line reason>` and move on. Do not pad with empty bullets." |
| FR-14 | `simulate-spec/SKILL.md` Phase 7 — at the "Tier 3" line (current line 349), add a sentence after the existing rule: "**Category coherence over batch fullness:** if leftover findings don't share a category, issue them as separate 1-2 question calls rather than padding a final batch to 4 with unrelated items." |
| FR-15 | `plan/SKILL.md` Task Design Rules — after the "Prescribe the interface, leave the implementation" rule (current line 282), add a new bullet: "**Task code block size:** if a single task's pasted code block exceeds ~80 lines, choose one of: (a) split the task, (b) reference an external scratch file, (c) prescribe the interface and let the implementor write the body." |
| FR-16 | `plan/SKILL.md` Cleanup template (current lines 246-249) — append `[only if applicable]` to each individual bullet, e.g., `- [ ] Stop worktree containers if running: <command> [only if applicable]`. Drop the existing footer line at 251 (becomes redundant) OR keep it if removal is unsafe. (Pick during patching — see §9 Open Questions.) |
| FR-17 | `plan/SKILL.md` Structural Checklist — add item 12 after the current item 11 (line 339): "**Refactor-before-modify:** Does any task modify a function whose existing structure isn't preserved by the modification? If yes, the prerequisite refactor must be its own numbered sub-step before the additive change." |

---

## 7. API Changes

None. This is a documentation-only change.

---

## 8. Frontend Design

None.

---

## 9. Edge Cases

| # | Scenario | Condition | Expected Behavior |
|---|----------|-----------|-------------------|
| E1 | A skill is invoked from a non-CC platform (Codex, Gemini CLI) where `AskUserQuestion` is unavailable | Platform fallback mode | Shared protocol's "Platform fallback" subsection (FR-05) prescribes how to handle each edge case via numbered-list replies |
| E2 | A skill is in mid-loop and the user replies with a free-form *clarifying question* rather than a disposition (e.g., "what does S25 affect again?") | Reply is interrogative, not declarative | Out of scope — the agent answers the question and re-issues the disposition prompt. This is normal conversation, not the "free-form-as-disposition" edge case. |
| E3 | The agent considers a finding both "free-form reply" AND "non-recommended pick" simultaneously | User picked option (b) but added free-form context | Apply both rules: confirm the back-mapped disposition (here, Modify is likely correct), then run the invariant-impact check |
| E4 | `/requirements` doesn't currently have a `### Findings Presentation Protocol` heading like the others | Reference insertion location ambiguous | FR-06 specifies "review/findings section" — anchor on the existing review-loop instructions; do not invent a new section header |
| E5 | The Cleanup-bullet patch (FR-16) accidentally creates `[only if applicable] [only if applicable]` if the line is re-edited later | Idempotency on re-application | Use unique anchor strings per Edit call; verify with a final grep that no double-marker exists |

---

## 10. Testing & Verification Strategy

This is a documentation-only change with no executable code. Verification is structural and behavioral-via-next-use.

### 10.1 Structural verification (post-edit, one-shot)

Run after all edits land. Each command's expected output is shown.

```bash
# 1. Shared protocol file exists and has the three required sections
test -f plugins/pmos-toolkit/skills/_shared/structured-ask-edge-cases.md && \
  grep -c "^## " plugins/pmos-toolkit/skills/_shared/structured-ask-edge-cases.md
# Expected: file exists; ≥4 H2 sections (3 edge cases + Platform fallback)

# 2. All four consumer skills reference the new file
grep -l "structured-ask-edge-cases.md" \
  plugins/pmos-toolkit/skills/requirements/SKILL.md \
  plugins/pmos-toolkit/skills/spec/SKILL.md \
  plugins/pmos-toolkit/skills/simulate-spec/SKILL.md \
  plugins/pmos-toolkit/skills/plan/SKILL.md
# Expected: all four file paths printed

# 3. Em-dash applied to Non-Goals template in /requirements
grep -n "NOT doing \[X\] — because" plugins/pmos-toolkit/skills/requirements/SKILL.md
# Expected: ≥2 matches (Tier 2 + Tier 3 templates)

# 4. Plan structural-checklist item 12 added
grep -n "Refactor-before-modify" plugins/pmos-toolkit/skills/plan/SKILL.md
# Expected: 1 match in the Structural Checklist section

# 5. /plan task-code-block-size rule added
grep -n "Task code block size" plugins/pmos-toolkit/skills/plan/SKILL.md
# Expected: 1 match in Task Design Rules

# 6. /simulate-spec category-coherence rule added
grep -n "Category coherence over batch fullness" plugins/pmos-toolkit/skills/simulate-spec/SKILL.md
# Expected: 1 match in Phase 7

# 7. /simulate-spec N/A pseudocode-section rule added
grep -n "N/A —" plugins/pmos-toolkit/skills/simulate-spec/SKILL.md
# Expected: ≥1 match in Phase 6

# 8. /spec invariant-impact step added
grep -n "change any existing invariant" plugins/pmos-toolkit/skills/spec/SKILL.md
# Expected: 1 match in Phase 3 Role Protocol

# 9. No double-marker leak from Cleanup edits
! grep -E "\[only if applicable\] \[only if applicable\]" plugins/pmos-toolkit/skills/plan/SKILL.md
# Expected: command succeeds (no matches found)
```

### 10.2 Behavioral verification (next pipeline run)

Cannot be tested ahead of time; checked by observation in the next session that exercises any of these skills:

- The agent uses the back-map-and-confirm pattern for free-form replies *because the protocol said so*, not as an emergent behavior.
- The agent surfaces the invariant-impact question after a non-recommended pick, *not* as a self-initiated decision.
- A `/simulate-spec` Phase 7 with leftover unrelated findings issues 1-2 question calls instead of padding to 4.
- A `/plan` Cleanup section in a real plan contains only relevant bullets.

### 10.3 Manual review

The five-finding-per-skill mapping (FR-11 through FR-17) is small enough for one human pass. After edits land, re-read each modified section in context and confirm the patch reads naturally — does not introduce a non sequitur, doesn't break the surrounding numbered list, doesn't duplicate adjacent content.

---

## 11. Open Questions

| # | Question | Owner | Needed By |
|---|----------|-------|-----------|
| 1 | FR-16: do we keep the existing footer line `[Only include items that apply to this feature...]` at line 251 of `plan/SKILL.md` after applying inline `[only if applicable]` markers, or remove it as redundant? | user | before plan |
| 2 | Should the shared protocol also live at the codex variant path (`.codex/...`) or is `_shared/` automatically consumed across plugin manifests? | user | before plan |
| 3 | Are there other pipeline skills (e.g., `/wireframes`, `/prototype`) that use `AskUserQuestion`-batched dispositions and should also reference the shared protocol? Out-of-scope for this iteration but worth noting. | user (later) | future work |

---

## 12. Research Sources

| Source | Type | Key Takeaway |
|--------|------|-------------|
| Retro paste-back from 2026-05-02 session | Conversation context | Source of all 8 findings; named line evidence and proposed fixes |
| `plugins/pmos-toolkit/skills/_shared/feature-folder.md` | Existing code | Pattern for shared protocol files: clear "MUST READ" header, numbered steps, anti-patterns section |
| `plugins/pmos-toolkit/skills/_shared/interactive-prompts.md` | Existing code | Two-path protocol pattern (primary `AskUserQuestion` + fallback numbered-list); structured "Consumers" footer listing skill references |
| `plugins/pmos-toolkit/skills/spec/SKILL.md` lines 502-520 | Existing code | Canonical "Findings Presentation Protocol" structure — the new shared file extends this, doesn't replace it |
| `plugins/pmos-toolkit/skills/plan/SKILL.md` lines 328-339 | Existing code | Structural Checklist current item count (11) — confirms FR-17 adds item 12 |
