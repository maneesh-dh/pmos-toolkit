---
task_id: T13
detected_at: 2026-05-10T00:15:00Z
detected_by: /execute (this run)
---

## Defect

Plan T13 ("Update reviewer prompts in 5 skills") cites concrete line ranges
from `/spec` Phase 2 Subagent A's report — *grill 179-200, verify 244-268,
msf-req 150-200, msf-wf 220-290, simulate-spec 426-447* — and instructs
/execute to **insert a chrome-strip step + FR-51 canonical reviewer prompt +
FR-52 sections.json validation block** "immediately before the subagent
dispatch" at each cited site. Direct inspection of those line ranges shows
that **4 of the 5 skills do not dispatch reviewer subagents at all** — the
cited offsets contain unrelated content:

- **grill ~175-205:** Phase 3 grill-report markdown template (no subagent).
- **msf-req ~145-200:** Phase 8 capture-learnings + Anti-Patterns list
  (no subagent — explicit "No subagents: sequential single-agent analysis"
  in Platform Adaptation).
- **msf-wf ~215-295:** Phase 6 PSYCH scoring + Phase 7 save-findings +
  Phase 8 apply-edits (no subagent — explicit "No subagents: sequential
  single-agent analysis" in Platform Adaptation).
- **simulate-spec ~420-450:** Phase 7 gap-resolution disposition prompts
  (no subagent — explicit "No subagents: Perform research and analysis
  sequentially as a single agent" in Platform Adaptation).

Only **/verify** has a real reviewer-subagent dispatch (Phase 3 "Multi-Agent
Code Quality Review" at lines 248-302 in the current SKILL.md). Those
reviewers consume **code diffs from `git diff`**, not artifact HTML —
chrome-strip is not applicable to that pattern either.

The mismatch means T13's instruction "Insert a chrome-strip step immediately
before the subagent dispatch" cannot be executed as written for 4 of 5 skills
and is semantically wrong for the 5th.

## Suggested fix

Spec FR-50/51/52/72/73 describe a reviewer-contract (HTML-aware input,
sections_found enumeration, verbatim-quote validation, hard-fail on
mismatch). The actual skill architecture realizes this in three different
shapes that T13 should address separately:

1. **/verify Phase 3 reviewers (only real reviewer-subagent dispatch):** wire
   chrome-strip + FR-51 prompt + FR-52 validation into the existing
   "Parallel Review Agents" block at `plugins/pmos-toolkit/skills/verify/SKILL.md`
   lines ~248-302 — but **note** these reviewers consume code diffs, not
   artifact HTML, so the chrome-strip-of-an-artifact contract may not apply
   directly; needs a /spec clarification on whether FR-50 covers code-diff
   reviewers too.

2. **/grill, /msf-req, /msf-wf, /simulate-spec — input contract documentation
   only:** these skills are themselves reviewers (consumed by parent
   orchestrators like /feature-sdlc). They don't dispatch sub-reviewers
   internally. The fix is to add a Phase-1 "Input Contract" section to each
   stating: "When invoked as a reviewer subagent, this skill expects its
   parent to chrome-strip the artifact via
   `${CLAUDE_PLUGIN_ROOT}/skills/_shared/html-authoring/assets/chrome-strip.js`
   before passing it. The skill returns findings with `{section_id, severity,
   message, quote: <≥40-char verbatim>}` and `sections_found: [...]` per
   FR-51. The parent validates per FR-52."

3. **Parent skills /feature-sdlc, /requirements (if it dispatches /grill),
   etc. — chrome-strip the dispatch site:** add the chrome-strip step to the
   parent skill that dispatches each of these 4 reviewers. T10
   (orchestrator) already landed but did not address chrome-strip — needs a
   T13.5 or a T10 follow-up.

T13 should be split into three subtasks (T13a /verify, T13b 4-skill input
contract, T13c parent dispatch chrome-strip) with the file lists and step
sequences corrected accordingly. Alternatively, /spec FR-50 should be
narrowed to the real architecture (likely just /verify + chrome-strip on
the orchestrator dispatch sites), and T13 rewritten against the narrower FR.

The new line ranges (verify only) should be re-derived from the current
SKILL.md state (not the stale Subagent A report). Run:

```
grep -nE "Parallel Review Agents|reviewer subagent|dispatch.*subagent" \
  plugins/pmos-toolkit/skills/verify/SKILL.md
```

## Reproducer

```bash
# Show that the cited line ranges contain no reviewer-subagent dispatch:
for s in grill msf-req msf-wf simulate-spec; do
  echo "=== $s ==="
  grep -cE "Task tool|spawn.*subagent|dispatch.*reviewer|Agent\\(" \
    plugins/pmos-toolkit/skills/$s/SKILL.md
done

# Show /verify is the sole skill with a real reviewer-subagent dispatch:
grep -nE "Parallel Review Agents|reviewer subagent|review the diff" \
  plugins/pmos-toolkit/skills/verify/SKILL.md
```

Output of the first loop: each of the 4 skills returns 0 (no reviewer
subagent dispatch). The second grep returns ≥1 hit only for /verify —
confirming it is the only skill T13 can apply to as written.

## /execute halt

/execute halts here per Phase 2 §7.5 "Defect handoff (T36)" contract.
T12 sealed at commit `2416c7a`. T13 not started. T14 deferred. Phase 2.5
verify deferred. Resume via `/plan --fix-from T13` (FR-56) or by running
`/spec --fix-from FR-50` if the spec needs the narrowing first.
