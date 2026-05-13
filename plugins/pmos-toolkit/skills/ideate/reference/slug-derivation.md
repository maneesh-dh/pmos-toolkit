# slug-derivation.md — idea-slug rules

The artifact filename is `{docs_path}/ideate/{YYYY-MM-DD}_<slug>.html`. The slug is derived from the seed; `--slug <custom>` overrides.

## Rules (applied in order)

1. **Pick the source string.**
   - If `--slug <custom>` was passed → use it verbatim (after validation).
   - If the seed starts with "what if we …" / "how might we …" / "what about …" → drop the wrapper and use what follows.
   - Else → use the first sentence (up to first `.`, `?`, `!`, or first 80 chars, whichever comes first).
2. **Lowercase.**
3. **Drop stopwords:** `a`, `an`, `the`, `is`, `for`, `of`, `to`, `we`, `i`, `our`, `my`, `their`, `if`, `should`, `could`, `would`, `can`, `do`, `does`, `with`, `and`, `or`.
4. **Replace every non-alphanumeric run with a single `-`.**
5. **Trim leading/trailing `-`.**
6. **Truncate to 4 words.** Split on `-`; keep the first 4 tokens.
7. **Collision suffix.** If `{docs_path}/ideate/{YYYY-MM-DD}_<slug>.html` already exists, append `-2`, `-3`, … until a free slot is found.

## Validation (rejected slugs)

A custom `--slug` is rejected (with a clear error) when:
- It contains `/`, `\`, `..`, or any character outside `[a-z0-9-]`.
- It is longer than 50 characters after lowercasing.
- It is empty after applying rules 2–5 above.
- It matches `^-+$` or `^[0-9-]+$` (no alphabetic content).

On rejection, fall back to the derived slug and emit a stderr warning naming the offending input.

## Examples

| Seed | Derived slug |
|---|---|
| "what if we tracked decisions like commits?" | `tracked-decisions-like-commits` |
| "how might we reduce onboarding friction" | `reduce-onboarding-friction` |
| "Fix the slow dashboard" | `fix-slow-dashboard` |
| "A weekly digest for product launches" | `weekly-digest-product` |
| "Improve the export flow for power users" | `improve-export-flow-power` |
| "an AI co-pilot for incident response" | `ai-co-pilot-incident` |

## Why ≤4 words

Five-word-plus slugs are unreadable in directory listings and break in shell completion. Four words preserves enough signal to recognize the file at a glance while staying terse. The 50-char hard cap is a backstop for unusual cases.

## Why a date prefix

Ideation artifacts accumulate. Sorting `ls` chronologically (filesystem date-order is unreliable across moves/clones) requires the date in the filename. `{YYYY-MM-DD}_` is the same convention `/feature-sdlc` uses for feature folders.
