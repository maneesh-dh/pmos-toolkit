# text-analysis.md — Phase 5 subagent contract + thematic-coding playbook

Reference loaded by `/survey-analyse` Phase 5. Specifies how open-end verbatims are coded into themes — the verbatim subagent prompt template, the return shape the skill validates, the Braun & Clarke 6-phase contract the subagent follows, the PII detect-and-warn protocol, and the theme-reporting card used in the final HTML report.

## Table of contents

- [Why Braun & Clarke](#why-bc)
- [The 6-phase contract (what the subagent runs internally)](#six-phase)
- [The verbatim subagent prompt template](#prompt-template)
- [Return-shape validation](#return-shape)
- [Chunking for large N](#chunking)
- [Consolidation across columns (optional second pass)](#consolidation)
- [PII detect-and-warn protocol](#pii)
- [Theme-reporting card (the final-HTML shape)](#theme-card)
- [Pitfalls](#pitfalls)

## Why Braun & Clarke

Inductive (reflexive) thematic analysis — the canonical method for qualitative survey analysis. Source: Braun, V. & Clarke, V., "Using thematic analysis in psychology", *Qualitative Research in Psychology* 3(2):77–101 (2006), DOI 10.1191/1478088706qp063oa. Themes are **constructed by the analyst, not emergent** — the subagent owns the construction; the skill validates the construction matches the verbatims.

## The 6-phase contract

The subagent runs these six phases internally before returning:

1. **Familiarise.** Read every verbatim end-to-end before coding; note first impressions.
2. **Generate initial codes.** Short descriptive code per meaningful unit; a verbatim may receive multiple codes.
3. **Search for themes.** Cluster related codes into candidate themes; collapse near-duplicates; split overloaded ones.
4. **Review themes.** Check each theme is internally coherent and distinct; re-read source verbatims; merge / drop themes that don't hold up.
5. **Define & name themes.** One-sentence definition (what's in / what's out) + crisp 3–5 word name.
6. **Write up.** Pick 1–3 representative quotes per theme (lightly cleaned for typos, never for meaning).

The output structure (below) makes phases 5–6 inspectable; phases 1–4 are internal.

## The verbatim subagent prompt template

The skill substitutes `{QUESTION_TEXT}`, `{N}`, `{VERBATIMS_BLOCK}`, and `{MODE_MARKER}` at dispatch time. Use the template **verbatim** — changes to the contract here ripple through every report.

```
{MODE_MARKER}
You are a qualitative-research analyst running Braun & Clarke reflexive
thematic analysis on a single survey open-end column. Your output is
machine-read by the survey-analyse skill; structure matters.

Question wording: {QUESTION_TEXT}
Verbatims (n={N}, one per line, prefixed with response_id):
{VERBATIMS_BLOCK}

Internally run the six-phase TA contract:
1. Familiarise. 2. Generate initial codes. 3. Search for themes.
4. Review themes. 5. Define & name themes. 6. Write up.

Rules:
- A verbatim MAY belong to multiple themes; double-counting is allowed
  (report it; the skill aggregates).
- Theme names: 3–5 words, crisp, descriptive (no jargon).
- Theme definitions: one sentence stating what's in AND what's out.
- Representative quotes: 1–3 verbatim response_ids per theme — pick
  representative, not just colourful; include a dissenting quote when
  the theme has internal polarity.
- Mark themes with <5 mentions on n<50 as "preliminary".
- Sentiment lean per theme: one of positive | neutral | negative | mixed.
- Anything that doesn't fit any theme goes in `uncoded_response_ids` —
  don't force-fit.

Return EXACTLY this JSON (no commentary before or after):

{
  "themes": [
    {
      "name": "<3–5 word name>",
      "definition": "<one sentence>",
      "preliminary": <true | false>,
      "response_ids": [<int ids that touch this theme>],
      "representative_quote_ids": [<1–3 ids drawn from response_ids>],
      "sentiment_lean": "positive" | "neutral" | "negative" | "mixed"
    }
  ],
  "uncoded_response_ids": [<int ids>],
  "themes_meta": {
    "verbatims_counted": {N},
    "verbatims_in_at_least_one_theme": <int>,
    "verbatims_in_multiple_themes": <int>,
    "double_counting_disclosed": true
  }
}
```

## Return-shape validation

After the subagent returns, the skill MUST assert (errors → re-dispatch once with the validation error appended; second failure → log to `themes.json` with `error: "<reason>"` and continue):

1. Top-level keys exactly `{themes, uncoded_response_ids, themes_meta}`.
2. Every `response_ids[*]` is a valid id from the input verbatim list.
3. Every `representative_quote_ids[*]` is a subset of that theme's `response_ids`.
4. `uncoded_response_ids` is disjoint from the union of all themes' `response_ids`.
5. Every theme has 1–3 representative quotes (zero means the theme doesn't get rendered).
6. `themes_meta.verbatims_counted == N`.

## Chunking for large N

For `n > 200` verbatims:

1. Split into chunks of 200 (preserve response_ids — they're absolute, not chunk-local).
2. Dispatch one subagent call per chunk with `Continuation chunk i of K` in the prompt prefix and the running themes-so-far passed in as `prior_themes: [...]`.
3. The subagent merges its new themes into the prior list (collapsing duplicates by name).
4. Final consolidation pass on the merged set if `themes_count > 12` after merging — too many themes is a coding miss.

## Consolidation across columns (optional second pass)

When two open-text columns share the survey's "why?" framing (typical: NPS detractor reason + a generic "what would you change?"), the skill optionally dispatches a consolidation subagent that takes both columns' theme lists and collapses obvious cross-column duplicates. Disabled when columns have unrelated semantics.

## PII detect-and-warn protocol

For each `representative_quote_id`, the skill runs `pii.detect_pii(text)` over the verbatim text:

- `email_matches`: regex `[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}`
- `phone_matches`: regex `(\+?\d{1,3}[-.\s]?)?\(?\d{2,4}\)?[-.\s]?\d{3,4}[-.\s]?\d{3,4}`
- `name_matches`: regex `\b(Mr|Mrs|Ms|Dr|Prof)\.?\s+[A-Z][a-z]+(\s+[A-Z][a-z]+)?\b`

If **any** representative quote matches **any** pattern across all themes, surface a chat-side warning **before** Phase 7 renders:

```
survey-analyse: <N> verbatim quotes contain potential PII
  (emails: <a>, phones: <b>, names: <c>) — review report.html
  before sharing externally. (No auto-redaction.)
```

The skill **does not** rewrite the quote. The methodology section of the report carries the same count. User is responsible for scrubbing before external sharing — by design (Non-Goals; user-confirmed).

## Theme-reporting card

In `report.html`'s `open-end-themes` section, each theme renders as:

```html
<article class="pmos-theme">
  <h4 id="theme-<slug>">{name} <span class="pmos-theme-count">{count} ({pct}% of n={n_open_responders})</span></h4>
  <p class="pmos-theme-def"><em>{definition}</em></p>
  <ul class="pmos-theme-quotes">
    <li>"<verbatim quote 1>"</li>
    <li>"<verbatim quote 2>"</li>
  </ul>
  <p class="pmos-theme-sentiment">Sentiment lean: {sentiment_lean}</p>
  {if preliminary}<p class="pmos-theme-flag">⚠ preliminary (fewer than 5 mentions on small N)</p>{/if}
</article>
```

## Pitfalls

- **Over-fitting many themes on a small N.** Rule of thumb: don't report a theme that's 1–2 mentions unless it's strikingly important — and label it preliminary. The subagent enforces; the skill validates.
- **Double-counting confusion.** Theme percentages sum to >100% when verbatims touch multiple themes. State this explicitly in the report's theme intro.
- **Selection bias in quotes.** Pick representative quotes, not just colourful ones. Include dissenting quotes when the theme has internal polarity.
- **Coder subjectivity.** Reflexive TA is the analyst's construction — different subagent runs will produce different themes. That's part of the reproducibility-narrative-non-deterministic contract; lean on the run-folder audit trail.
- **Anonymity vs. PII.** Detect-and-warn only; the skill does NOT auto-redact (see PII section).
- **Quoting style.** Verbatim with light typo cleanup; NEVER paraphrase. If a quote is unusable raw (typos illegible), drop it and pick another.
