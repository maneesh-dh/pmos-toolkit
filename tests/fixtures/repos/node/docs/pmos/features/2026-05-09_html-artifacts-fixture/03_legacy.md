# Legacy markdown sibling

This file exists to exercise the mixed-state resolver path: a feature folder
containing both `.html` artifacts (modern) and a `.md` artifact (legacy
fallback per FR-22 / FR-30).

## Why

Some pre-2.32.0 feature folders shipped only `.md`. The resolver in
`_shared/resolve-input.md` must still pick this up when no `.html` sibling
exists.

## Notes

- This file is intentionally **not** wrapped in HTML chrome.
- It is intentionally **not** referenced by `_index.json`'s primary listing —
  the index generator (T11) is HTML-only.
