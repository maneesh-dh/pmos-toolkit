# Scenario Fixtures

Each section describes an expected agent behavior given the matching fixture under `tests/fixtures/`. To verify, the implementer reads the relevant SKILL.md phases and walks through each scenario manually.

## Fixture: empty-tasks

A directory with no items (or missing `~/.pmos/tasks/`).

### Scenario: `/mytasks` (no args, empty fixture)

Expected:
- Output: `No tasks yet. Capture one with /mytasks <text> or /mytasks add <text>.`
- No files created.

### Scenario: `/mytasks rebuild-index` (empty fixture)

Expected:
- Glob returns 0 item files.
- Write `~/.pmos/tasks/INDEX.md` with header + 3 empty buckets (each bucket has its `## {name}` header + column row, no data rows).
- Output: `Regenerated INDEX.md: 0 active items (0 completed/dropped excluded).`

## Fixture: with-tasks

Four items: 0001 (leverage, in-progress, due 2026-05-12), 0002 (neutral, call, pending, due 2026-05-01, next_checkin 2026-05-08), 0003 (overhead, waiting), 0004 (neutral, read, pending).

### Scenario: `/mytasks` (no args, with-tasks fixture)

Expected:
- Read INDEX.md (skip regen since INDEX is fresh).
- Render verbatim.
- Output groups: `## leverage` with 0001, `## neutral` with 0002 and 0004 (sorted by due asc; 0002 first because it has a due date), `## overhead` with 0003.

### Scenario: `/mytasks rebuild-index` (with-tasks fixture)

Expected:
- Read all 4 items.
- Group by importance: leverage (0001), neutral (0002, 0004), overhead (0003).
- Within neutral: sort by due asc, no-due last → 0002 (due 2026-05-01), then 0004 (no due).
- Write INDEX.md with the expected shape.
- Output: `Regenerated INDEX.md: 4 active items (0 completed/dropped excluded).`

## Fixture: empty-tasks (continued — quick capture)

### Scenario: `/mytasks Call sarah about Q3 OKRs by Friday` (today is 2026-04-25, a Saturday)

Expected single tool-call sequence (no blocking, no questions):
1. Parse: `Call` → type `call`. `by Friday` → due `2026-05-01` (next Friday after Sat 2026-04-25).
2. Strip `by Friday` from the title; `Call` stays in title (it's the type signal but also natural language).
3. The remaining title: `Call sarah about Q3 OKRs`.
4. Allocate id `0001`.
5. Workstream: if invoked outside a `.pmos/settings.yaml` repo, leave absent.
6. People: `sarah` is bare (no `@`), stays in title. Empty `people:`.
7. Slug: `call-sarah-about-q3-okrs`.
8. Write `~/.pmos/tasks/items/0001-call-sarah-about-q3-okrs.md` with frontmatter only (no body).
9. Frontmatter: `id: 0001`, `title: Call sarah about Q3 OKRs`, `type: call`, `importance: neutral`, `status: pending`, `due: 2026-05-01`, `created`/`updated` = today, all other optional fields as bare keys.
10. Apply Phase 12 (rebuild INDEX).
11. Output: `Captured #0001 (call, neutral): "Call sarah about Q3 OKRs" — due 2026-05-01.`

### Scenario: `/mytasks Sync with @sarah on roadmap` (with-people fixture sibling exists; sarah → sarah-chen via alias)

Expected:
1. Parse: no type keyword, default `execution`. No date. `@sarah` → `/people find sarah` → tier 2 alias match → `sarah-chen`.
2. Strip `@sarah` from title (resolved). Remaining: `Sync with on roadmap`. (Acceptable — preserve user's words; do NOT prettify mid-sentence.)
3. Allocate id `0002`.
4. Slug: `sync-with-on-roadmap`.
5. Write item file with `people: [sarah-chen]`, all other fields as default.
6. Output: `Captured #0002 (execution, neutral): "Sync with on roadmap" — people: sarah-chen.`

### Scenario: `/mytasks Sync with @unknown_person on roadmap`

Expected:
1. `@unknown_person` → `/people find unknown_person` → 0 matches.
2. Token NOT stripped from title (preserves user intent).
3. `people: []` (empty list).
4. Output includes unresolved warning:
   ```
   Captured #0003 (execution, neutral): "Sync with @unknown_person on roadmap"
     ⚠ unresolved: @unknown_person — run /people add unknown_person, then /mytasks set 0003 people=<handle>
   ```

### Scenario: `/mytasks Sync with @sara on roadmap` (with-people fixture; ambiguous — substring match returns sarah-chen and sarah-patel)

Expected:
1. `@sara` → `/people find sara` → tier 4 substring match → 2 results.
2. Multi-match: skip (do not pick), token stays in title.
3. `people: []`.
4. Output:
   ```
   Captured #0004 (execution, neutral): "Sync with @sara on roadmap"
     ⚠ unresolved: @sara — multiple matches (sarah-chen, sarah-patel); run /mytasks set 0004 people=<handle>
   ```

### Scenario: `/mytasks Read OKR doc tomorrow`

Expected:
1. `Read` → type `read`. `tomorrow` → due = today + 1.
2. Strip `tomorrow`. Title: `Read OKR doc`.
3. Output: `Captured #0005 (read, neutral): "Read OKR doc" — due {today+1}.`

### Scenario: `/mytasks Buy birthday gift` (no inferable type, no date)

Expected:
1. No type keyword → default `execution`. No date.
2. Title: `Buy birthday gift`.
3. Output: `Captured #0006 (execution, neutral): "Buy birthday gift".` (No due, no people, no workstream — minimal report.)
