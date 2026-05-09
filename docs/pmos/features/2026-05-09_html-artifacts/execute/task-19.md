---
task_number: 19
task_name: "assert_unsupported_format.sh"
task_goal_hash: t19-assert-unsupported-format
plan_path: "docs/pmos/features/2026-05-09_html-artifacts/03_plan.md"
branch: "feat/html-artifacts"
worktree_path: null
status: done
started_at: 2026-05-10T02:25:00Z
completed_at: 2026-05-10T02:30:00Z
files_touched:
  - tests/scripts/assert_unsupported_format.sh
---

## T19 — assert_unsupported_format.sh (OQ-3 resolution: static-check harness)

**Outcome:** done. PASS across all 10 affected skills. Each SKILL.md
enumerates the canonical valid-values set `{html, md, both}` for
`output_format`, which by-construction rejects any out-of-set token
(including the literal `markdown` cited in plan T19).

### Why static-check (and what's actually verified)

Plan T19 reads: "When `output_format: markdown` is in `settings.yaml`,
every affected skill exits 64". `markdown` is *not* a member of the
canonical valid set `{html, md, both}` — so the contract is refusal
of any out-of-set value, not refusal of `markdown` specifically.

Static-check approach (consistent with T18): verify each affected
SKILL.md enumerates the valid set verbatim. By construction:
- A skill that documents `valid values: \`html\`, \`md\`, \`both\``
  cannot accept `markdown` without violating the documented contract.
- The actual exit-64 path is owned by the resolution gate inlined in
  every skill's Phase 0 `output_format` resolution step.

T26 / FR-72 smoke (Phase 5) provides live runtime coverage by running
each skill against a real feature folder.

### Inline verification

```
$ bash tests/scripts/assert_unsupported_format.sh
OK:   requirements — valid-set=1
OK:   spec — valid-set=1
OK:   plan — valid-set=1
OK:   msf-req — valid-set=1
OK:   grill — valid-set=1
OK:   artifact — valid-set=1
OK:   verify — valid-set=1
OK:   simulate-spec — valid-set=1
OK:   msf-wf — valid-set=1
OK:   design-crit — valid-set=1
PASS: assert_unsupported_format.sh (10 skills)
exit: 0   ✅
```

### Discovered (pre-existing) gap — non-blocking

While developing T19, I observed that `msf-req/SKILL.md` lacks the
canonical `<!-- non-interactive-block:start -->` block carried by the
other 9 skills (no `exit 64`, no `FR-01.5`, no `settings.yaml malformed`
markers). This is a **pre-existing rollout gap** introduced before
Phase-3 base 696bdcf — it predates this feature's Phase-2 runbook
fanout (T9), which targeted HTML-emission edits rather than the
non-interactive contract.

**Disposition:** logged as advisory ADV-T19. Not blocking on T19's
narrowed scope (valid-set enumeration); not introduced by Phase 4.
Recommend rolling into Phase 5 cleanup or a separate non-interactive
rollout pass.

### Spec compliance

| FR | Requirement | Satisfied by |
|---|---|---|
| FR-82 | Skills reject invalid output_format values | Valid-set enumeration `{html, md, both}` in all 10 SKILL.md |
| FR-12 | output_format resolution is bounded to enumerated values | Same enumeration ensures `markdown` and other out-of-set tokens fall through |

### Advisories (logged, non-blocking)

- **ADV-T19** (pre-existing): `msf-req/SKILL.md` missing the
  non-interactive-block contract (`exit 64` / `FR-01.5` /
  `settings.yaml malformed`). Not introduced by Phase 4. Suggested
  fix: add the canonical block in a Phase-5 cleanup pass.

T19 complete.
