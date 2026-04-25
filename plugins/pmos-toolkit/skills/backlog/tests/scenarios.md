# Scenario Fixtures

Each section below describes an expected agent behavior given the matching fixture under `tests/fixtures/`.

## Fixture: with-items

The `with-items` fixture contains canonical item files demonstrating every frontmatter field. After reading `schema.md`, the agent should be able to:
- Identify all enum values for `type`, `status`, `priority`.
- Reproduce the body section structure (## Context, ## Acceptance Criteria, ## Notes).
- Recognize that empty optional fields (`spec_doc:`, `plan_doc:`, `pr:`) are written as bare keys with no value, not omitted.
