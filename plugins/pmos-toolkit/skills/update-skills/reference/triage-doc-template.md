<!-- pmos:update-skills-triage v=1 -->
# Update-skills triage — {YYYY-MM-DD} — {slug}

**Source:** {raw text | file: <path> | --from-retro: run <n> at <timestamp>}
**Feature folder:** {docs_path}/features/{YYYY-MM-DD}_update-skills-{slug}/
**Affected skills (in scope):** {comma-separated skill names}
**Out-of-scope skill mentions:** {list with reason; or "none"}

> Resume by re-invoking `/update-skills <path-to-this-file>`. Phase 8 will pick up the next `pending` row in the pipeline-status table.

---

## Findings (parsed)

| # | Skill | Severity | Finding (one line) | Evidence (≤2 lines) | Proposed fix (verbatim from input) |
|---|-------|----------|--------------------|---------------------|-------------------------------------|
| 1 |       |          |                    |                     |                                     |

## Critique (Phase 4)

| # | Already handled? | Classification | Recommendation | Rationale (one line) | Scope hint |
|---|------------------|----------------|----------------|----------------------|------------|
| 1 | yes/no/partial   | bug \| UX-friction \| new-capability \| nit | Apply \| Modify \| Skip \| Defer | … | small \| medium \| large |

## Disposition log (Phase 6)

| # | User disposition | Notes / Skip reason / Modified text |
|---|------------------|-------------------------------------|
| 1 |                  |                                     |

## Approved changes by skill (Phase 6)

### /<skill-name-1>

- Finding #N — <one-line summary> — <Apply | Modified-as: …>
- Finding #M — …

### /<skill-name-2>

- …

## Per-skill tier (Phase 7)

| Skill | Approved-change count | Recommended tier | User-confirmed tier | Rationale |
|-------|-----------------------|------------------|---------------------|-----------|
|       |                       | Tier N           | Tier N              |           |

## Pipeline status (Phase 8)

### /<skill-name-1>

| Phase | Status | Artifact path | Timestamp |
|-------|--------|---------------|-----------|
| /requirements | pending |              |           |
| /spec         | pending |              |           |
| /grill        | n/a (Tier <3) |        |           |
| /plan         | pending |              |           |
| /execute      | pending |              |           |
| /verify       | pending |              |           |

### /<skill-name-2>

…

## Failure log (Phase 8)

| Skill | Phase | Reason | User decision (continue/retry/abort) | Timestamp |
|-------|-------|--------|---------------------------------------|-----------|
|       |       |        |                                       |           |

---

## Final summary (Phase 9)

- Processed: N findings across M skills
- Approved: K. Skipped: S. Deferred: D. Out-of-scope: O.
- Pipeline complete: <list>
- Failed: <list>
- Pending: <list>
