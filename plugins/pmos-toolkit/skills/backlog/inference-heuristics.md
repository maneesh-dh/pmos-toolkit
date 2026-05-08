# Type Inference Heuristics

For `/backlog add <text>`, infer `type` by scanning the text (case-insensitive) for these keywords. First-match wins; check in this order:

| Order | Type | Trigger keywords / patterns |
|------:|------|-----------------------------|
| 1 | `bug` | `bug`, `broken`, `fails`, `failing`, `flaky`, `crash`, `error`, `regression`, `incorrect`, `wrong output`, `should not`, `doesn't work`, `not working`, `500`, `404` |
| 2 | `tech-debt` | `refactor`, `cleanup`, `clean up`, `tech debt`, `technical debt`, `legacy`, `deprecated`, `tightly coupled`, `hardcoded`, `temporary`, `hack`, `TODO:`, `FIXME:` |
| 3 | `chore` | `rename`, `reorganize`, `tidy`, `move file`, `housekeeping`, `bump version`, `pin dependency` |
| 4 | `docs` | `doc`, `docs`, `documentation`, `readme`, `comment`, `document`, `explain in writing`, `update CLAUDE.md`, `changelog entry` |
| 5 | `spike` | `spike`, `investigate`, `research`, `explore`, `prototype`, `proof of concept`, `POC`, `time-box` |
| 6 | `enhancement` | `improve`, `polish`, `tune`, `extend`, `streamline`, `make smoother`, `make faster`, `make easier` |
| 7 | `feature` | `add`, `we should`, `let's build`, `support for`, `new`, `enable`, `expose`, `allow users to`, `implement`, `introduce` |
| 8 | `idea` | (fallback — no match in 1-7) |

## Rules

1. **First match wins.** Order matters: a "refactor to fix the bug" sentence matches `bug` first because rule 1 is checked first. If you want it classified as `tech-debt`, correct it post-capture with `/backlog set <id> type=tech-debt`.
2. **Never ask.** If multiple keywords match, pick the first by order. If none match, fall through to `idea`.
3. **Always note the fallback.** When `type: idea` is assigned by fallback (rule 4), the capture output MUST include the notice: `type inferred as 'idea' (no strong signal); use /backlog set <id> type=... to correct.`
4. **No clarifying questions.** Capture must be one round-trip. Wrong inference is acceptable; capture friction is not.
