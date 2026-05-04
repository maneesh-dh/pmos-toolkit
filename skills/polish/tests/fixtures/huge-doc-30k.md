# Huge document fixture (stub)

This file is a stub representing a >25,000-polishable-word document used to test the hard-ceiling refusal path.

**To populate for actual test runs:** concatenate ~30,000 words of any prose. Content quality doesn't matter — the test asserts only that /polish refuses BEFORE running the rubric.

**Test assertion** (per `tests/expected.yaml`):

- Phase 1 measures polishable word count
- /polish refuses immediately with: `"Doc too large for a single polish run. Split into sections and polish individually, or use --dry-run for a rubric report only."`
- No LLM-judge calls are made
- No patches are generated
- No `<doc>.polished.md` file is created

**Why this is a stub:** see `large-doc-12k.md` rationale. Generate at test time from a public-domain corpus (e.g., Project Gutenberg) rather than version-controlling 200KB of prose.
