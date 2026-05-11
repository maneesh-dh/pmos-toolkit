---
name: survey-design
description: Design a methodologically sound survey from a rough intent, or refine an existing one — generates a sectioned survey.json, runs a reviewer-critique pass and a simulated-respondent friction walk, renders a fillable preview, and emits import files for Typeform / SurveyMonkey / Google Forms. Triggers on "design a survey", "create a survey", "build a questionnaire", "review my survey", "refine this survey", "make a survey ready to field", "/survey-design".
user-invocable: true
argument-hint: "<survey intent | path to an existing survey> [--export <platform[,platform]>] [--skip-export] [--format html|md|both] [--non-interactive | --interactive]"
---

# Survey Design

Turn a rough research intent (or an existing survey) into a fielded-ready survey: a structured `survey.json`, a human-readable `survey.html`, a fillable `preview.html`, a reviewer critique, a simulated-respondent friction walk, a viewer, and platform import files. The skill bakes in survey-methodology best practices and an anti-pattern catalog so the generated questions don't have the usual defects.

**Announce at start:** "Using the survey-design skill to design and pressure-test a survey."

## Platform Adaptation

These instructions use Claude Code tool names. In other environments:
- **No interactive prompt tool (`AskUserQuestion`):** degrade every gate to a numbered free-form prompt per `_shared/interactive-prompts.md`; the non-interactive auto-pick contract still applies (the `(Recommended)` option is auto-picked).
- **No subagents (`Task`/`Agent` tool):** run the Phase-4 reviewer pass and the Phase-6 simulated-respondent pass *sequentially inline* — same prompts, same return contracts, just no fresh-context isolation.
- **No browser automation:** `preview.html` is meant for the user to open by double-click; the skill does not drive it.
- **`TaskCreate`/`TodoWrite` missing:** announce phase transitions verbally; the survey folder's `index.html` is the canonical progress artifact.

This skill is a **standalone utility** — it is not a pipeline stage. It writes into `{docs_path}/survey-design/{YYYY-MM-DD}_<slug>/`, never into the `/feature-sdlc` feature folders, and it does **not** run `_shared/pipeline-setup.md` first-run setup (see Phase 0).

## Reference files (loaded on demand)

The skill loads these from its own `reference/` directory only when the relevant phase needs them — keep them out of working context otherwise (progressive disclosure):

- `reference/survey-best-practices.md` — the methodological backbone applied in Phase 3 generation and Phase 4 critique (structure/flow, question types, scales, length/burden, generative-vs-evaluative, bias reduction, question-writing rules, accessibility, ethics/PII).
- `reference/question-antipatterns.md` — the A1–E6 anti-pattern catalog, each entry with a concrete detection signal; the generator (Phase 3) must produce none of these, the reviewer (Phase 4) walks every question against the catalog.
- `reference/platform-export.md` — per-platform import mechanisms, artifact schemas, and the full type-mapping tables the Phase-8 transformer recipes cite.

---

## Phase 0 — Setup

1. **Read `.pmos/settings.yaml`.** Take `docs_path` from it. If the file or the key is absent, default `docs_path = docs/pmos/` and print one warning to stderr (`survey-design: no .pmos/settings.yaml; using docs_path=docs/pmos/`). **Do NOT run `_shared/pipeline-setup.md` Section A first-run setup** — this skill is not a pipeline stage and must work in any repo (E13, FR-07).
2. **Parse flags** from the argument string: `--export <platform[,platform]>` (pre-select export targets), `--skip-export` (skip Phase 8), `--format <html|md|both>` (only affects any feature-folder doc the skill writes — it normally writes none; the runtime survey folder is always HTML + JSON), `--non-interactive` / `--interactive` (the mode contract below).
3. **`output_format` note.** Resolve `output_format` from `.pmos/settings.yaml :: output_format` (default `html`), `--format` overrides (last flag wins); print to stderr once: `output_format: <value> (source: <cli|settings|default>)`. It governs only feature-folder docs (none here); the survey folder's artifacts are always `survey.json` + `survey.html` (substrate-compliant) + `preview.html` (standalone) + the eval/simulation markdown.
4. **Resolve the run folder.** Derive `<slug>` (lowercase-hyphenated, ASCII) from the survey title or intent; the run folder is `{docs_path}/survey-design/{YYYY-MM-DD}_<slug>/`. If that folder already exists, append `-2`, `-3`, … until unique — **never overwrite** an existing survey folder (E4, FR-24).
5. **Phase tracking.** If `TaskCreate`/`TodoWrite` is available, create one task per phase (0–9); otherwise announce each phase verbally (FR-08).
6. **Learnings.** Read `~/.pmos/learnings.md` if present; note any entries under `## /survey-design` and factor them in (skill body wins on conflict; surface conflicts before applying).

<!-- non-interactive-block:start -->
1. **Mode resolution.** Compute `(mode, source)` with precedence: `cli_flag > parent_marker > settings.default_mode > builtin-default ("interactive")` (FR-01).
   - `cli_flag` is `--non-interactive` or `--interactive` parsed from this skill's argument string. Last flag wins on conflict (FR-01.1).
   - `parent_marker` is set if the original prompt's first line matches `^\[mode: (interactive|non-interactive)\]$` (FR-06.1).
   - `settings.default_mode` is `.pmos/settings.yaml :: default_mode` if present and one of `interactive`/`non-interactive`. Unknown values → warn on stderr `settings: invalid default_mode value '<v>'; ignoring` and fall through (FR-01.3).
   - If `.pmos/settings.yaml` is malformed (not parseable as YAML, or missing `version`): print to stderr `settings.yaml malformed; fix and re-run` and exit 64 (FR-01.5).
   - On Phase 0 entry, always print to stderr exactly: `mode: <mode> (source: <source>)` (FR-01.2).

2. **Per-checkpoint classifier.** Before issuing any `AskUserQuestion` call, classify it (FR-02):
   - Use the awk extractor below to find the line of this call's `question:` key in the live SKILL.md (FR-02.6).
   - The defer-only tag, if present, is the literal previous non-empty line: `<!-- defer-only: <reason> -->` where `<reason>` ∈ {`destructive`, `free-form`, `ambiguous`} (FR-02.5).
   - Decision (in order): tag adjacent → DEFER; multiSelect with 0 Recommended → DEFER; 0 options OR no option label ends in `(Recommended)` → DEFER; else AUTO-PICK the (Recommended) option (FR-02.2).

3. **Buffer + flush.** Maintain an append-only OQ buffer in conversation memory. On each AUTO-PICK or DEFER classification, append one entry per the schema in spec §11.2. At end-of-skill (or in a caught error before exit), flush (FR-03):
   - Primary artifact is single Markdown → append `## Open Questions (Non-Interactive Run)` section with one fenced YAML block per entry; update prose frontmatter (`**Mode:**`, `**Run Outcome:**`, `**Open Questions:** N` where N counts deferred only — see FR-03.4) (FR-03.1).
   - Skill produces multiple artifacts → write a single `_open_questions.md` aggregator at the artifact directory root; primary artifact's frontmatter `**Open Questions:** N — see _open_questions.md` (FR-03.5).
   - Primary artifact is non-MD (SVG, etc.) → write sidecar `<artifact>.open-questions.md` (FR-03.2).
   - No persistent artifact (chat-only) → emit buffer to stderr at end-of-run as a single block prefixed `--- OPEN QUESTIONS ---` (FR-03.3).
   - Mid-skill error → flush partial buffer under heading `## Open Questions (Non-Interactive Run — partial; skill errored)`; set `**Run Outcome:** error`; exit 1 (E13).

4. **Subagent dispatch.** When dispatching a child skill via Task tool or inline invocation, prepend the literal first line: `[mode: <current-mode>]\n` to the child's prompt (FR-06).

5. **Awk extractor.** The classifier and `tools/audit-recommended.sh` MUST both use the function below. Loaded at script init time; sourcing differs per consumer.

<!-- awk-extractor:start -->
```awk
# Find AskUserQuestion call sites and their adjacent defer-only tags.
# Input: a SKILL.md file (stdin or argv).
# Output (TSV): <line_no>\t<has_recommended:0|1>\t<defer_only_reason or "-">
# A "call site" is a line referencing `AskUserQuestion` in the SKILL's own prose
# (backtick mentions, prose instructions, multi-line invocation hints).
# `(Recommended)` is detected on the call site line OR any subsequent non-blank
# line (the option-list block) until a blank line, defer-only tag, or another
# AskUserQuestion call closes the pending call. Lines inside the inlined
# `<!-- non-interactive-block:... -->` region are canonical contract text and
# never count as call sites.
function emit_pending() {
  if (pending_call > 0) {
    out_tag = (pending_call_tag != "") ? pending_call_tag : "-";
    printf "%d\t%d\t%s\n", pending_call, pending_has_recc, out_tag;
    pending_call = 0;
    pending_has_recc = 0;
    pending_call_tag = "";
  }
}
/^<!-- non-interactive-block:start -->$/ { in_inlined=1; next }
/^<!-- non-interactive-block:end -->$/   { in_inlined=0; next }
in_inlined { next }
/^[[:space:]]*<!--[[:space:]]*defer-only:[[:space:]]*([a-z-]+)[[:space:]]*-->/ {
  emit_pending();
  match($0, /defer-only:[[:space:]]*[a-z-]+/);
  pending_tag = substr($0, RSTART + 12, RLENGTH - 12);
  sub(/^[[:space:]]+/, "", pending_tag);
  pending_line = NR;
  next;
}
/^[[:space:]]*$/ {
  emit_pending();
  pending_tag = "";
  next;
}
/AskUserQuestion/ {
  emit_pending();
  pending_call = NR;
  pending_has_recc = ($0 ~ /\(Recommended\)/) ? 1 : 0;
  pending_call_tag = (pending_tag != "" && NR == pending_line + 1) ? pending_tag : "";
  pending_tag = "";
  next;
}
{
  if (pending_call > 0 && $0 ~ /\(Recommended\)/) {
    pending_has_recc = 1;
  }
}
END { emit_pending() }
```
<!-- awk-extractor:end -->

6. **Refusal check.** If this SKILL.md contains a `<!-- non-interactive: refused; ... -->` marker (regex: `<!--[[:space:]]*non-interactive:[[:space:]]*refused`), and `mode` resolved to `non-interactive`: emit refusal per Section A and exit 64 (FR-07).

7. **Pre-rollout BC.** If the `--non-interactive` argument is present BUT this SKILL.md does NOT contain the `<!-- non-interactive-block:start -->` marker (i.e., this skill hasn't been rolled out yet): emit `WARNING: --non-interactive not yet supported by /<skill>; falling back to interactive.` to stderr; continue in interactive mode (FR-08).

8. **End-of-skill summary.** Print to stderr at exit: `pmos-toolkit: /<skill> finished — outcome=<clean|deferred|error>, open_questions=<N>` (NFR-07).
<!-- non-interactive-block:end -->

---

## Phase 1 — Intake

The argument is one of: a free-text research intent; a path to an existing survey (`.html` / `.md` / `.txt` / `.json`); or nothing.

- **Nothing** → before doing anything else, use `AskUserQuestion`: ask the research **purpose** and the **audience**. Options for each: a `(Recommended)` first option only when a default genuinely makes sense; for the audience there is no sensible default — tag that one `<!-- defer-only: free-form -->`. (E1, FR-10.) Do not invent a purpose.
- **A path** → read the file and best-effort parse it into a `survey.json` skeleton: titles/headings → sections; recognizable question text + options → questions (guess the `type` from the option shape). If nothing recognizable comes out, report that, show what *was* extracted, and offer to treat the file's text as free-text intake instead (E3, FR-11).
- **Free text** → use it directly as the research brief.

Summarize back what you understood (purpose, audience, any platform mentioned, any time hint) before moving on.

---

## Phase 2 — Variable interpretation

Infer the design variables from the brief / existing survey / conversation:

- `audience` — who's being surveyed (role, tenure, usage, plan tier, recruitment source).
- `time_budget_min` — target completion minutes; if the brief gives a range, take the **upper** bound; default ~5 min for a general audience.
- `mode` — `generative` (understand / discover, open-ended-heavy), `evaluative` (validate / measure, closed-ended-heavy), or `hybrid` (a generative section then an evaluative section).
- `max_questions` — an optional hard cap on the question count; default: no cap.

Present what you inferred back to the user. For each variable that is **not** confidently inferable, ask via a single batched `AskUserQuestion` (one question per missing variable, at most 4 in the call):
- `mode` — options: `Hybrid — understand and validate (Recommended)`, `Generative — understand / discover`, `Evaluative — validate / measure`.
- `time_budget_min` — options: `~5 minutes (Recommended)`, `~3 minutes`, `~10 minutes`, free-form.
- `max_questions` — options: `No cap (Recommended)`, `Cap at 10`, `Cap at 15`, free-form.
- `audience` — no recommended default; this question, if it must be asked, is the one free-form gate.
<!-- defer-only: free-form -->
If the audience is still unclear after the inferences above, ask it on its own via `AskUserQuestion` (free-form answer; no auto-pickable default).

**Hard stop:** if the user cannot articulate a research goal / purpose even after asking, state plainly that a survey can't be designed without one, and stop — do not guess a purpose (E2, FR-14).

Record the resolved `{purpose, audience, time_budget_min, mode, max_questions}` — they go into `survey.json` and into the Phase-4 / Phase-6 subagent prompts.

---

## Phase 3 — Generate the initial design

### 3.1 The `survey.json` schema (authoritative — the skill writes exactly this shape)

```json
{
  "schema_version": 1,                         // (req) int
  "title": "Trial conversion — exit survey",   // (req) string
  "purpose": "Understand why recent trial users did not upgrade.",  // (req) string — the research goal
  "mode": "generative",                        // (req) "generative" | "evaluative" | "hybrid"
  "audience": "People who started a trial in the last 30 days and did not upgrade.",  // (req) string
  "time_budget_min": 3,                        // (req) int — target completion minutes
  "estimated_minutes": 2.7,                    // (req) number — the skill's estimate (time constants below)
  "max_questions": null,                       // int | null
  "intro": {                                   // (req)
    "text": "Thanks for trying <Product>. A few quick questions — about 3 minutes. Your answers are confidential and help us improve.",  // (req) string
    "consent_required": false,                 // bool — if true, an explicit "I agree" gate precedes Q1
    "anonymous": false,                        // bool — MUST be false if any PII question exists
    "estimated_seconds": 15,                   // number
    "thankyou": "Thanks — your feedback helps."  // string | null — shown on the final screen
  },
  "sections": [                                // (req) array, >= 1
    {
      "id": "screening",                       // (req) kebab id, unique
      "title": "First, a quick check",         // (req) string
      "description": null,                     // string | null — signpost text
      "randomize_questions": false,            // bool — never true for screening / ordinal-dependent sections
      "questions": [ /* question objects, see 3.2 */ ]   // (req) array, >= 1
    }
  ]
}
```

### 3.2 The question object

```json
{
  "id": "q-hoped-to-do",            // (req) kebab id, unique across the whole survey
  "type": "open_long",              // (req) one of the type enum below
  "stem": "What were you hoping to accomplish when you started the trial?",  // (req) string
  "help_text": null,                // string | null — shown under the stem
  "required": false,                // (req) bool
  "reference_period": null,         // string | null — e.g. "in the past 7 days"; REQUIRED for retrospective/frequency questions
  "screening": false,               // bool — true => the answer drives skip logic; screening questions come first
  "skip_logic": null,               // null | { "on_value": <choice-value or [values]>, "action": "skip_to" | "end_survey", "target_section_id": <id|null> }
  "randomize_options": false,       // bool — true only for nominal (unordered) option lists; never for ordinal scales

  "options": [                      // for single_select / multi_select / forced_choice_grid (rows live in `rows`) / ranking
    { "value": "price", "label": "The price was too high" }
  ],
  "other_option": false,            // bool — appends an "Other (please specify)" free-text option
  "opt_out_options": [],            // array of {value,label} appended & visually separated, e.g. [{"value":"na","label":"Not applicable"},{"value":"dk","label":"Don't know"},{"value":"pnts","label":"Prefer not to say"}]

  "scale": {                        // for rating / nps
    "points": 5,                    // int — 5 or 7 default; NPS implies 11 (0..10)
    "min": 1, "max": 5,             // ints — NPS: 0..10
    "labels": { "min": "Not at all satisfied", "mid": "Neither", "max": "Extremely satisfied" },  // pole labels; "mid" only for odd scales
    "balanced": true                // bool — equal #positive/#negative around the midpoint (MUST be true unless `purpose` forces a forced-choice even scale)
  },

  "rows": [ { "id": "r-ease", "label": "Ease of use" } ],   // for forced_choice_grid / matrix — the items being rated
  "columns": [ { "value": "poor", "label": "Poor" } ],      // for matrix — the shared scale columns

  "constant_sum_total": 100         // for constant_sum
}
```

**`type` enum:** `single_select` (radio, pick one — MECE options, ~4–5 for attitudinal, `opt_out_options` recommended); `multi_select` (checkboxes — discouraged where per-item prevalence matters; if used, `randomize_options: true`); `forced_choice_grid` (Yes/No per item; the recommended replacement for "select all that apply"; columns implicitly Yes/No, optionally + "N/A"); `rating` (Likert / unipolar scale — construct-specific labels, *not* agree/disagree; balanced, poles labeled, opt-out separate); `nps` (0–10 recommend-likelihood; the skill SHOULD add an open follow-up automatically); `dichotomous` (Yes/No single — add a "Don't know" opt-out when uncertainty is plausible; don't force a binary on a continuum); `open_short` (single-line free text — `help_text` SHOULD hint the expected length); `open_long` (multi-line free text — the generative workhorse, keep to a few per survey); `ranking` (rank a short list — ≤ 5–7 items; for longer lists emit a "top-3 pick" `multi_select` instead); `matrix` (rate many items on a shared scale — ≤ ~7 rows, consider splitting, randomize rows, per-item on mobile); `constant_sum` (allocate N points across items — cognitively heavy, small item count); `statement` (display-only — section intro / instructions; not a question; `required` ignored; not counted toward `max_questions` or the time estimate).

**Schema invariants** (the skill enforces these on write, and any consumer may re-check): all `id`s kebab-case and unique across the whole survey; `intro.anonymous: true` forbids any PII question; rating/nps scales `balanced: true` unless `purpose` explicitly justifies a forced even scale; ordinal types (`rating`, `nps`, `matrix` with an ordinal scale) never have `randomize_options: true`; `skip_logic.target_section_id` (when `action` is `skip_to`) MUST reference an existing **later** section — if a generated or parsed survey has a backward jump, rewrite it forward or drop it and note the change (E14); retrospective/frequency stems MUST set `reference_period`; `required: true` on a sensitive item (income, health, demographics, politics, anything PII-adjacent) MUST be accompanied by an `opt_out_options` entry.

### 3.3 Time-cost constants (for `estimated_minutes`; FR-21 — tunable)

Per-question seconds: `open_short` / `open_long` = 30; `single_select` / `multi_select` / `dichotomous` = 8; `rating` / `nps` = 6; `matrix` / `forced_choice_grid` = 5 **per row**; `ranking` = 5 per item; `constant_sum` = 8 per item; `statement` = 5 (read time). Plus the intro/consent screen = `intro.estimated_seconds` (default 15). `estimated_minutes` = (Σ of the above) ÷ 60, rounded to one decimal.

### 3.4 Build `survey.json`

Apply `reference/survey-best-practices.md` (load it now):
- An **intro/consent block** (sponsor, purpose, accurate time estimate, what's collected / how used, anonymous vs. confidential stated honestly, voluntary; `consent_required: true` for research contexts).
- **Sections in funnel order** (general → specific). **Screening / qualifying questions first** (mark `screening: true`); wire their `skip_logic` to bypass downstream sections for non-qualifiers. **Demographics / sensitive items last** (unless used for routing). Warm-up: an easy, non-sensitive item early. Signpost section transitions via `description` and/or `statement` items.
- **Mode-appropriate type mix:** `generative` → mostly `open_long` / `open_short` + a few broad closed items; `evaluative` → mostly closed/comparable (`single_select`, `rating`, `nps`, `forced_choice_grid`); `hybrid` → a generative section ("what happened, in your own words") then an evaluative section ("structured read on the usual suspects"). Always end with an optional open catch-all ("Anything else?").
- **Scales:** balanced, poles (and midpoint on odd scales) labeled, a separate visually-offset opt-out (`opt_out_options`); construct-specific labels (never agree/disagree); 5-point default, 7-point for nuanced/employee research. For every `nps` question, add an `open_short` follow-up ("What's the main reason for your score?").
- **Generate NONE of the `reference/question-antipatterns.md` patterns** — self-check every stem and option set against that catalog's detection signals before committing (FR-22).

### 3.5 Trim to budget

Compute `estimated_minutes`. If it exceeds `time_budget_min` (or the question count exceeds `max_questions`, if set): trim — keep screening + the highest-value items, cut nice-to-haves, prefer shorter question types, collapse near-duplicate items — *before* rendering. Record the final `estimated_minutes` in `survey.json`. If the user has explicitly insisted on keeping items that push it over budget, leave them and flag the over-run prominently in the Phase-9 summary (E10).

### 3.6 Render the artifacts

Write all of these into the run folder:

- **`survey.json`** — the object above; pretty-printed (2-space indent) and deterministic key order.
- **`survey.html`** — substrate-compliant (uses the `_shared/html-authoring/template.html` shape: a toolbar with Copy-Markdown / Copy-link, a `<main>` body, a footer). Body: `<section id="intro">` rendering the intro/consent block; one `<section id="<section-id>">` per survey section with `<h2>` = section title; within each, every question is an `<h3 id="<question-id>">` = stem, help text a `<p>`, options a `<ul>` (opt-out items after a `<hr>` rule), scales/matrix/grid as a small `<table>`; a metadata line `Mode: <mode> · Target: ~<n> min · Estimated: <m> min · <k> questions`. **No inline `<script>` or `<style>` in `<main>`**; assets referenced as `assets/style.css?v=<plugin-version>` and `assets/viewer.js?v=<plugin-version>` (`<plugin-version>` = the `version` from `plugins/pmos-toolkit/.claude-plugin/plugin.json`). Companion **`survey.sections.json`** enumerating `{id, level, title, parent_id}` for every `<section>`, `<h2>`, and `<h3>`.
- **`preview.html`** — a standalone page (intentionally **not** a pmos artifact — D4): a minimal HTML page with `<div id="survey-root">`, a small inline `<style>` (mobile-first; label-adjacent controls; ≥ 4.5:1 contrast; visible focus; text "Question X of Y"; no graphical-only progress bar), an inline `<script type="application/json" id="survey-data">` holding the **full** `survey.json`, and `<script src="survey-preview.js"></script>`. No `fetch()`, no CDN, no external refs — it must work on double-click (`file://`).
- **`survey-preview.js`** — `cp -n` the skill's `assets/survey-preview.js` into the run folder's root (sibling to `preview.html`). Do not regenerate it.
- **`assets/`** in the run folder — `cp -n` `style.css`, `viewer.js`, and `serve.js` from `_shared/html-authoring/assets/` (idempotent; only the ones `survey.html` references plus `serve.js` for the viewer).
- **`index.html`** — seed it via the `_shared/html-authoring/index-generator.md` pattern (a manifest inlined as `<script type="application/json" id="pmos-index">`), listing the artifacts present so far (`survey.html`, `preview.html`); later phases regenerate it to add the eval/simulation/export entries.

### 3.7 Commit

`git add` the run folder and `git commit -m "survey-design: initial draft for <slug>"`. If the cwd isn't a git repo or `git commit` fails, print one warning and continue (E11, FR-24, D9).

**Re-render policy:** later phases (5, 6, 8) mutate `survey.json` and then **re-derive** `survey.html` / `survey.sections.json` / `preview.html` / `index.html` from it. Never hand-edit the rendered files (D5).

---

<!-- continued in Phases 4–9 below (T8) -->
