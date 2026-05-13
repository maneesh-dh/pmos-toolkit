# question-type-analysis.md — per-question-type playbook

Reference loaded by `/survey-analyse` Phase 4. For every question type, lists: the helper function to call, the stats the helper returns, the chart shape to use, the #1 pitfall to avoid, and one worked example. The LLM never recomputes these numbers — the helper does.

## Table of contents

- [Quick reference](#quick-reference)
- [Single-select / categorical](#single-select)
- [Multi-select](#multi-select)
- [Likert / rating (ordinal)](#likert)
- [NPS](#nps)
- [Ranking](#ranking)
- [Matrix / grid](#matrix)
- [Numeric](#numeric)
- [Open-end free text](#open-text)
- [`analysis.py` template](#analysis-py-template)

## Quick reference

| Type | Helper | Central tendency | Headline | Chart | #1 pitfall |
|---|---|---|---|---|---|
| `single_select` | `categorical.freq_table` | mode | top option % | bar / horizontal bar | wrong base on item-non-response |
| `multi_select` | `multi_select.multi_select_table` | mode | top option % of respondents | horizontal bar | dividing by response count, not respondents |
| `likert` | `likert.likert_stats` | median | T2B − B2B (net) | diverging stacked bar | reporting mean as if interval |
| `nps` | `nps.nps` | n/a | NPS integer | distribution stack + big number | averaging the 0–10 scores |
| `ranking` | `ranking.ranking_stats` | avg rank | item with lowest avg rank | ordered bar of avg rank | mixing up the two scoring conventions |
| `matrix` | `matrix.matrix_stats` | per-row median | row league table by T2B | heatmap or row-bars | straightlining inflates everything |
| `numeric` | `numeric.numeric_stats` | median | median + IQR | histogram + boxplot | mean dragged by outliers |
| `open_text` | (Phase 5 subagent) | n/a | theme count + % | theme cards | over-fitting many themes on small N |

## Single-select / categorical

**Helper:** `categorical.freq_table(rows, col)` → `{n, responses, percent, mode}`. `percent` is computed on the respondent base (non-null responses for `col`).

**Stats to report:** count + % per category; mode. No mean/median (no order).

**Chart:** bar (vertical if ≤6 short labels, horizontal if more or long labels). Pie/donut only if ≤4 mutually exclusive slices summing to 100% — generally prefer bar.

**Pitfalls:** computing % on the wrong base when there's item non-response; "Other (specify)" answers left uncoded — back-code into existing or new categories before reporting; tiny categories crowding the chart (collapse into "Other").

**Worked example:**

```
Q: Which plan are you on? (n=489 non-null)
  Free       212  43.4%
  Pro        178  36.4%
  Team        67  13.7%
  Enterprise  32   6.5%
  Mode: Free
```

## Multi-select

**Helper:** `multi_select.multi_select_table(rows, col, delimiter="|")` → `{n_respondents, option_counts, option_percent_of_respondents, mean_selected_per_respondent}`.

**Stats:** for each option, **% of respondents who selected it** — percentages **will sum to >100%**. Also mean number of options selected per respondent.

**Chart:** horizontal bar sorted by frequency, label "% of respondents (multiple answers allowed)". Never a 100% stacked bar.

**Pitfalls:** the **base/percentage confusion** — dividing by total responses (selections) understates each option; readers misreading bars as a 100% breakdown (label fixes this); "None of the above" should be exclusive (the helper warns if "none" co-occurs with other picks); co-occurrence patterns are interesting (top pairs).

**Worked example:**

```
Q: Which features do you use? (n=489 respondents; multiple answers allowed)
  Reports          312  63.8%
  Integrations     268  54.8%
  Mobile app       201  41.1%
  API              154  31.5%
  Mean selected per respondent: 1.91
```

## Likert / rating (ordinal)

**Helper:** `likert.likert_stats(rows, col, scale_size=5, reverse_scored=False)` → `{distribution, median, mode, t2b_percent, b2b_percent, net_score, mean_with_ordinal_caveat}`. `reverse_scored` flips before aggregating.

**Stats:** full distribution (count + %); median + mode; **T2B** (top-2 most-favorable %); **B2B** (bottom-2 most-unfavorable %); net = T2B − B2B; the mean is returned with the explicit caveat (use it only as a convenience summary, not as if interval).

**Chart:** **diverging stacked bar** — neutral centered, favorable to one side, unfavorable to the other — best for comparing many items. Single-item: simple 100%-stacked bar.

**Pitfalls:** treating ordinal as interval (mean/SD/t-test on raw 1–5 codes assumes equal spacing; not given); inconsistent scale polarity across items; reverse-scored items not re-coded; comparing 5-pt to 7-pt scales without rescaling; ignoring "N/A" in the base.

**Worked example:**

```
Q: How satisfied are you with onboarding? (1=very dissat, 5=very sat; n=489)
  1   12   2.5%
  2   28   5.7%
  3   84  17.2%
  4  198  40.5%
  5  167  34.2%
  Median: 4   T2B: 74.7%   B2B: 8.2%   Net: +66.5
  (Mean 3.98 reported with ordinal caveat.)
```

## NPS

**Helper:** `nps.nps(rows, col)` → `{n, promoter_percent, passive_percent, detractor_percent, nps_score}`. Auto-detected when a 0–10 numeric column has "recommend" in its header text; user can confirm/override at Phase 2.

**Stats:** classify 0–10 → Promoters (9–10), Passives (7–8), Detractors (0–6). **NPS = %P − %D**, reported as an **integer** in [-100, +100]. **Never an average of the 0–10 scores.**

**Chart:** stacked bar (Detractor red / Passive grey / Promoter green); big number for NPS itself; trend line if comparing waves.

**Pitfalls:** treating NPS as an average (it discards Passives by design); over-interpreting small NPS swings on small N (a couple of detractors moves it a lot at low n); benchmarking across industries naively; redefining the 9–10 / 0–6 cutoffs silently. Pair NPS with the open-end "why?" follow-up.

**Worked example:**

```
Q: How likely are you to recommend us? (0–10; n=489)
  Promoters (9–10):    188  38.4%
  Passives (7–8):      207  42.3%
  Detractors (0–6):     94  19.2%
  NPS = 38 − 19 = +19
```

## Ranking

**Helper:** `ranking.ranking_stats(rows, items_cols)` — `items_cols` maps item-name → its rank-column. Returns `{items: {<item>: {avg_rank, weighted_points}}, convention}`.

**Stats:** **average rank** (lower = more preferred) AND **weighted points** (rank-1 of k gets k points; sum / n; higher = more preferred). Both are returned; the report uses the one stated as `convention` in the helper output.

**Chart:** ordered horizontal bar of avg rank (or weighted points); a stacked-bar showing the distribution of positions per item.

**Pitfalls:** mixing the two scoring conventions (and the resulting "best item" flip); partial rankings — decide and disclose how unranked items are handled (excluded vs. assigned worst rank; helper default = exclude); ranking is forced-choice, so a low average doesn't mean an item is disliked, just less preferred; not all platforms compute it the same way — the helper recomputes from raw ranks, not platform "scores".

## Matrix / grid

**Helper:** `matrix.matrix_stats(rows, row_cols, scale_size=5)` — `row_cols` maps row-label → its column. Returns `{rows: {<row>: <likert_stats>}, straightlining: [<respondent_indices>]}`.

**Stats:** treat each row as its own Likert question. Per-row distribution, median, mode, T2B, B2B. Plus a **respondent-level straightlining flag** — zero-variance across `row_cols` for that respondent.

**Chart:** diverging stacked bars, one row per matrix row, sorted by T2B. Or a heatmap.

**Pitfalls:** straightlining contaminates rows toward the bottom of long grids — surface the flag count; grid fatigue lowers quality toward the bottom rows; per-row mean as if interval (use median); on mobile, large grids degrade.

## Numeric

**Helper:** `numeric.numeric_stats(rows, col)` → `{n, mean, median, sd, min, max, p25, p50, p75, outliers_iqr, histogram}`.

**Stats:** n + mean + **median** (lead with median when skewed) + SD + min/max + 25/50/75 percentiles + a binned histogram; outliers per 1.5×IQR are flagged but not auto-excluded.

**Chart:** histogram + median line; box plot for spread + outliers.

**Pitfalls:** mean dragged by outliers / fat tails (income, counts, durations need median + maybe log-transform view); fat-fingered entries (age 200); zero vs. blank vs. "don't know" conflated; reporting a mean to false precision.

## Open-end free text

**Not analysed by a synchronous helper.** See [`text-analysis.md`](./text-analysis.md) for the Phase 5 subagent-per-question contract.

## `analysis.py` template

The skill writes this once per run to `<run_folder>/analysis.py`. The skill resolves the absolute path to `${CLAUDE_PLUGIN_ROOT}/skills/survey-analyse/scripts` at write time.

```python
"""survey-analyse — per-run analysis script.
Auto-generated; re-runs of /survey-analyse overwrite. Helpers are bundled
with the skill at the path injected below."""

import csv, json, sys

sys.path.insert(0, "<HELPERS_DIR>")  # resolved at write time
from helpers import categorical, multi_select, likert, nps, ranking, matrix, numeric, stats

with open("cleaned_responses.csv", newline="") as f:
    ROWS = list(csv.DictReader(f))
with open("schema.json") as f:
    SCHEMA = json.load(f)

per_q = {}
for col, meta in SCHEMA["columns"].items():
    if meta.get("skip"):
        continue
    t = meta["type"]
    if t == "single_select":   per_q[col] = categorical.freq_table(ROWS, col)
    elif t == "multi_select":  per_q[col] = multi_select.multi_select_table(ROWS, col, meta.get("delimiter", "|"))
    elif t == "likert":        per_q[col] = likert.likert_stats(ROWS, col, scale_size=meta.get("scale_size", 5), reverse_scored=meta.get("reverse_scored", False))
    elif t == "nps":           per_q[col] = nps.nps(ROWS, col)
    elif t == "numeric":       per_q[col] = numeric.numeric_stats(ROWS, col)
    elif t == "ranking":       per_q[col] = ranking.ranking_stats(ROWS, meta["items_cols"])
    elif t == "matrix":        per_q[col] = matrix.matrix_stats(ROWS, meta["row_cols"], scale_size=meta.get("scale_size", 5))
    # open_text handled in Phase 5

# Phase 6 cross-tabs go here when segments are non-empty — see cross-survey-stats.md

with open("per_question.json", "w") as f:
    json.dump({"per_question": per_q}, f, indent=2)
print("survey-analyse: wrote per_question.json")
```
