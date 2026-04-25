# Scenario Fixtures

Each section below describes an expected agent behavior given the matching fixture under `tests/fixtures/`.

## Fixture: with-items

The `with-items` fixture contains canonical item files demonstrating every frontmatter field. After reading `schema.md`, the agent should be able to:
- Identify all enum values for `type`, `status`, `priority`.
- Reproduce the body section structure (## Context, ## Acceptance Criteria, ## Notes).
- Recognize that empty optional fields (`spec_doc:`, `plan_doc:`, `pr:`) are written as bare keys with no value, not omitted.

## Fixture: empty-repo

A repo with no `backlog/` directory yet.

### Scenario: `/backlog add ssl renewal cron is flaky`

Expected agent behavior (single round-trip, no clarifying questions):
1. Create `backlog/`, `backlog/items/`.
2. Allocate id `0001`.
3. Infer `type: bug` (keyword "flaky").
4. Write `backlog/items/0001-ssl-renewal-cron-flaky.md` with frontmatter only (no body), `status: inbox`, `priority: should`, `created`/`updated` = today.
5. Generate `backlog/INDEX.md`.
6. Output: `Captured #0001 (bug, should): "ssl renewal cron is flaky"`.
7. Do NOT ask any clarifying questions. Do NOT load workstream context. Do NOT mention pipeline integration.

### Scenario: `/backlog "we should add OAuth"`

(No verb prefix; falls through Phase 0 router as add.)

Expected:
- id `0002`, `type: feature` (keyword "we should"), `status: inbox`, `priority: should`.
- Output: `Captured #0002 (feature, should): "we should add OAuth"`.

### Scenario: `/backlog add something completely vague`

Expected:
- id `0003`, `type: idea` (no keyword match → fallback), `status: inbox`.
- Output includes the inference fallback notice: `Captured #0003 (idea, should): "something completely vague" — type inferred as 'idea' (no strong signal); use /backlog set 0003 type=... to correct.`
