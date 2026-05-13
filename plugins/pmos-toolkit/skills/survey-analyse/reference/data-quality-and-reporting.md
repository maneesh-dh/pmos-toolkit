# data-quality-and-reporting.md — cleaning checklist + report skeleton

Reference loaded by `/survey-analyse` Phase 3 (cleaning) and Phase 7 (reporting). Two parts: pre-analysis data quality rules (what to flag, how to handle), and the structure / writing rules for the final HTML report.

## Table of contents

- [Part A — pre-analysis cleaning](#part-a)
  - [Straightlining](#straightlining)
  - [Speeders](#speeders)
  - [Incompletes / breakoffs](#incompletes)
  - [Duplicates](#duplicates)
  - [Attention checks](#attention)
  - [Numeric outliers](#outliers)
  - ["Don't know" / "N/A" / "Prefer not to say"](#dont-know)
  - [Bots / fraud (briefly)](#fraud)
- [Part B — synthesis & reporting](#part-b)
  - [Report skeleton](#skeleton)
  - [Executive summary writing rules](#exec)
  - [Findings → insights → recommendations](#funnel)
  - [The "so what" test](#so-what)
  - [Chart hygiene](#chart-hygiene)
  - [Ethical / honest reporting](#ethics)

## Part A — pre-analysis cleaning

Run these *before* analysis; document each rule + the number of records it removes; record everything in `cleaning.json`.

### Straightlining

**Signal:** zero (or near-zero) variance in responses across a matrix / grid block — e.g., all "3"s down a 10-item grid.

**Helper:** `clean.detect_straightliners(rows, matrix_cols)` — `matrix_cols` is a list of column-groups; flags a respondent if any one group has variance < threshold (default: 0).

**Disposition:** flag for review; exclude when present in ≥2 matrix blocks; mark in cleaning.json with `rule: straightlining, threshold, flagged, removed`.

### Speeders

**Signal:** completion time far below typical. Cutoff: **<0.5 × median completion time** (configurable via the schema's `speeder_threshold_ratio`). Compute the median **after** all responses are loaded — not on a running sample.

**Helper:** `clean.detect_speeders(rows, duration_col, threshold_ratio=0.5)`.

**Disposition:** flag; exclude when threshold met AND a second indicator (e.g., straightlining or attention-check fail) also fires; exclude alone only when threshold_ratio < 0.33 (a true outlier).

### Incompletes / breakoffs

**Signal:** respondent did not reach the last "must-have" question OR completed less than `min_completion_ratio` (default 0.80) of non-skip columns.

**Helper:** `clean.detect_incompletes(rows, must_have_cols, min_completion_ratio=0.80)`.

**Disposition:** exclude from analysis; analyse breakoff point separately (a spike at one question signals a question problem).

### Duplicates

**Signal:** same key column value (email if present; else IP; else a fingerprint of `[response_pattern_hash, timestamp_bucket]`).

**Helper:** `clean.detect_duplicates(rows, key_cols)`.

**Disposition:** keep the first by timestamp; drop the rest. Investigate fraud / bots if >5% of responses dupe.

### Attention checks

**Signal:** explicit attention-check questions in the survey ("Select 'Strongly agree' for this item"). The schema flags these via `meta["attention_check"]: {expected: "..."}`.

**Helper:** `clean.detect_failed_attention(rows, attention_checks)`.

**Disposition:** require **≥2 failed checks** to exclude; one failed check is a false-positive risk (people miss things).

### Numeric outliers

**Signal:** values beyond 1.5×IQR; implausible entries (age 200, "100" on a 1–10 scale).

**Helper:** `numeric.numeric_stats(...)` returns `outliers_iqr: [row_indices]`.

**Disposition:** review case-by-case; the skill flags but does not auto-exclude statistical outliers (legitimate extremes happen). Implausible-by-schema values (out-of-range) get excluded with a note.

### "Don't know" / "N/A" / "Prefer not to say"

**Disposition:** **exclude from the analysis base for that item by default** (don't lump with substantive answers, don't treat as a scale midpoint). **But report the rate** — a high DK% means the question was unclear or the topic unfamiliar. The methodology section MUST surface DK rates for every closed question where DK > 10%.

For "prefer not to say" on demographics: **keep the case** but treat as a category in cross-tabs (don't drop respondents from the survey for refusing a demographic).

### Bots / fraud (briefly)

Catch via: gibberish open-ends, copy-pasted text across respondents, impossible demographic combos, suspiciously uniform timing. Out of scope for the helpers in v1 — flag manually if you spot it.

## Part B — synthesis & reporting

### Report skeleton

`<run_folder>/report.html` in this section order (each a `<section id="..."`):

1. **`executive-summary`** — first read; ½–1 page.
2. **`methodology`** — sample composition, mode, dates, cleaning, weighting, Holm note, PII warning summary, small-N caveats, limitations.
3. **`key-findings`** — 3–5 most important findings, descending importance.
4. **`per-question`** — one `<h3>` per analysed question, in survey order; rendered with the right chart per `question-type-analysis.md`.
5. **`open-end-themes`** — one `<h3>` per open-text column, theme cards per `text-analysis.md`.
6. **`cross-tab-appendix`** — full cross-tabs with raw + Holm-adjusted p; base sizes.
7. **`data-quality-log`** — cleaning rules + counts table.

### Executive summary writing rules

In order, max ½–1 page:

1. **Headline finding** + its business / decision implication (one sentence each).
2. **2–4 supporting findings** in descending order of significance. Each = the insight stated plainly + the single most load-bearing data point (not a table dump).
3. **Brief "why"** context (1–2 sentences) — what's likely driving the headline.
4. **Recommended actions** — explicit, unhedged; tie each to the supporting findings. (If the user provided a "decisions sought" in Phase 2, format the recommendations against those decisions.)

Decision-makers may read only this. Make it self-contained.

### Findings → insights → recommendations

- A **finding** = what the data shows ("62% of detractors cited onboarding friction").
- An **insight** = the "so what" — why the finding matters.
- A **recommendation** = the action implied.

Every finding gets all three. Don't ship a finding without the "so what".

### The "so what" test

Apply to every finding before it goes into the report: if you can't articulate what changes because of it, it's a fact, not an insight — drop it or fold it into an appendix.

### Chart hygiene

- One chart per point; well-labeled.
- The takeaway goes in the chart title / caption — not buried in the surrounding prose.
- Multi-select bars always carry "(multiple answers allowed)" in the chart label.
- Likert charts use diverging stacked bars; neutral is centered.
- NPS shows the integer score large + the distribution stack.
- Don't use a chart where a sentence would do.
- Inline SVG only; no external chart libraries; no embedded fonts.

### Ethical / honest reporting

- **No cherry-picking.** Surface results that contradict the hypothesis — call them out.
- **Sample caveats prominent**, not buried — small-N flags inline; non-probability framing in the methodology section.
- **Distinguish "respondents said X" from "X is true of the population".** Probability vs. non-probability sample changes how strong a claim can be.
- **Separate description from interpretation.** The numbers are description; the "what does this mean for us" is interpretation — label it.
- **Disclose** sample size, MoE (if probability), weighting, full question wording (Methodology section), survey sponsor (if the user knows / discloses).
- **Don't imply precision the data can't support.** Don't report a mean to 4 decimal places on n=14; helpers cap precision sensibly.

## Sources

- AAPOR Best Practices — https://aapor.org/standards-and-ethics/best-practices/
- Chattermill, Survey results report — https://chattermill.com/blog/survey-results-report
- WPForms, How to write a summary of survey results — https://wpforms.com/how-to-write-summary-survey-results/
- SurveyMonkey, Survey data cleaning — https://www.surveymonkey.com/curiosity/survey-data-cleaning-7-things-to-check-before-you-start-your-analysis/
- Qualtrics, Response Quality — https://www.qualtrics.com/support/survey-platform/survey-module/survey-checker/response-quality/
- CloudResearch, Identify & handle invalid survey responses — https://www.cloudresearch.com/resources/guides/ultimate-guide-to-survey-data-quality/how-to-identify-handle-invalid-survey-responses/
- Leiner (2019), Too Fast, Too Straight, Too Weird — https://www.researchgate.net/publication/258997762_Too_Fast_Too_Straight_Too_Weird_Post_Hoc_Identification_of_Meaningless_Data_in_Internet_Surveys
- Dillman, Smyth & Christian, *Internet, Phone, Mail, and Mixed-Mode Surveys*, 4th ed. (Wiley, 2014).
