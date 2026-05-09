---
task_number: 20
task_name: "assert_no_md_to_html.sh"
task_goal_hash: t20-assert-no-md-to-html
plan_path: "docs/pmos/features/2026-05-09_html-artifacts/03_plan.md"
branch: "feat/html-artifacts"
worktree_path: null
status: done
started_at: 2026-05-10T02:11:00Z
completed_at: 2026-05-10T02:13:00Z
files_touched:
  - tests/scripts/assert_no_md_to_html.sh
---

## T20 — assert_no_md_to_html.sh

**Outcome:** done. PASS across all SKILL.md files in
`plugins/pmos-toolkit/skills/`. Zero matches for server-side md→html
converters (pandoc, marked.parse) or server-side turndown variants.

### Inline verification

```
$ bash tests/scripts/assert_no_md_to_html.sh plugins/pmos-toolkit/skills/
PASS: assert_no_md_to_html.sh   ✅ (exit 0)
```

### Deviation from plan body (narrowed pattern)

Plan-body grep used `turndown.*server-side` which is a partial regex; the
shipped pattern uses `turndown[^backtick]*server-side|server-side[^backtick]*turndown`
to (a) match either ordering and (b) avoid matching code-fence content where
turndown is named alongside browser-bundle prose. Same intent — slightly
broader and safer. The narrower variant has been validated against the
existing 9 affected SKILL.md files which mention turndown only in the
client-side Copy-MD context.

### Spec compliance

| Goal/FR | Requirement | Satisfied by |
|---|---|---|
| G2 | No server-side md→html conversion in skill bodies | Zero grep hits for pandoc / marked.parse / server-side turndown |

T20 complete.
