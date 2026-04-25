# Type Inference Heuristics

For `/backlog add <text>`, infer `type` by scanning the text (case-insensitive) for these keywords. First-match wins; check in this order:

| Order | Type | Trigger keywords / patterns |
|------:|------|-----------------------------|
| 1 | `bug` | `bug`, `broken`, `fails`, `failing`, `flaky`, `crash`, `error`, `regression`, `incorrect`, `wrong output`, `should not`, `doesn't work`, `not working`, `500`, `404` |
| 2 | `tech-debt` | `refactor`, `cleanup`, `clean up`, `tech debt`, `technical debt`, `legacy`, `deprecated`, `tightly coupled`, `hardcoded`, `temporary`, `hack`, `TODO:`, `FIXME:` |
| 3 | `feature` | `add`, `we should`, `let's build`, `support for`, `new`, `enable`, `expose`, `allow users to`, `implement`, `introduce` |
| 4 | `idea` | (fallback — no match in 1-3) |

## Rules

1. **First match wins.** Order matters: a "refactor to fix the bug" sentence matches `bug` first because rule 1 is checked first. If you want it classified as `tech-debt`, correct it post-capture with `/backlog set <id> type=tech-debt`.
2. **Never ask.** If multiple keywords match, pick the first by order. If none match, fall through to `idea`.
3. **Always note the fallback.** When `type: idea` is assigned by fallback (rule 4), the capture output MUST include the notice: `type inferred as 'idea' (no strong signal); use /backlog set <id> type=... to correct.`
4. **No clarifying questions.** Capture must be one round-trip. Wrong inference is acceptable; capture friction is not.
