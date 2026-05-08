---
name: design-crit
description: Critique an existing application, wireframes, or prototype on overall user experience — identifies journeys, captures flow screenshots via packaged Playwright script, evaluates against a Nielsen + WCAG 2.2 + visual-hierarchy + Gestalt + journey-friction rubric, then runs a PSYCH/MSF pass and synthesises prioritized UX recommendations. Standalone utility — does not require the requirements→spec→plan pipeline. Use when the user says "critique this UI", "design review", "audit this app", "UX review", "review the wireframes", "evaluate this prototype", "what's wrong with this UX", or provides a URL/HTML files and asks for a design crit.
user-invocable: true
argument-hint: "<URL or path-to-wireframes-folder or path-to-prototype-folder> [--feature <slug>] [--journeys <id1,id2>] [--storage-state <path>] [--out <dir>]"
---

# Design Crit

Critique an existing user experience — application, wireframes, or prototype — and produce a concise, prioritized UX recommendations report.

The skill is **standalone**. It works on three source types:

1. **Live application URL** (with optional auth via Playwright `storageState` or basic-auth)
2. **Wireframes folder** (HTML files produced by `/wireframes` or hand-authored)
3. **Prototype folder** (HTML files produced by `/prototype` or any single-file React prototype)

It captures screenshots, applies a hybrid rubric (`reference/eval.md`), runs a lightweight PSYCH + MSF pass on captured journeys, and writes a single recommendations report.

```
                          (standalone utility — runs independently of the pipeline)
/requirements → [/wireframes] → [/prototype] → /spec → /plan → /execute → /verify
                                              ↑
                                         /design-crit  ← can review any of these artifacts or a live app
```

**Announce at start:** "Using design-crit to evaluate the source, capture flow screenshots, and produce a UX recommendations report."

## Platform Adaptation

These instructions use Claude Code tool names. In other environments:

- **No `AskUserQuestion`:** State your assumption (default = critique top 3 inferred journeys), document it in the report, and proceed. Findings dispositions fall back to a numbered table the user reviews after.
- **No subagents:** Run the heuristic eval, PSYCH pass, and friction pass sequentially in the main agent rather than dispatching parallel reviewers.
- **No Playwright:** If `playwright` is missing on the host (`assets/capture.mjs` exits with code 3), instruct the user to install via `npm i -g playwright && npx playwright install chromium`, then resume. If install isn't possible, ask the user to take screenshots manually and place them in the screenshots folder; proceed with eval-only mode and label the report accordingly.

## Track Progress

This skill has multiple phases. Create one task per phase using your agent's task-tracking tool (e.g., `TaskCreate` in Claude Code, `TodoWrite` in older harnesses, equivalent elsewhere). Mark each task in-progress when you start it and completed as soon as it finishes — do not batch completions.

## Load Learnings

Read `~/.pmos/learnings.md` if it exists. Note any entries under `## /design-crit` and factor them into your approach for this session.

---

## Phase 0: Load workstream context (optional)

If the user has linked a workstream for this repo via `/product-context`, load it. Specifically resolve `docs_path` — the report will be written to `{docs_path}/{YYYY-MM-DD}_{feature_slug}/design-crit/`.

Fallback when no workstream is linked: write to `./docs/{YYYY-MM-DD}_{feature_slug}/design-crit/` in the current repo root. If the user passed `--out <path>`, honour that and skip workstream resolution.

If `--feature <slug>` is not provided, propose a slug from the source (URL hostname or folder name) and confirm with the user via `AskUserQuestion`.

---

## Phase 1: Identify and access the source

Determine the source type from the argument:

- Starts with `http://` or `https://` → **URL mode**
- Path containing `index.html` or multiple `*.html` files at the root → **wireframes/prototype mode** (treat both the same — they're just static HTML)
- Path with `runtime.js` + `*-device.html` at root → **prototype mode** (subset of static HTML; use the device files as the screen list)

Validate access:

- **URL mode:** `curl -sSI <url> | head -1` to confirm reachability. If 401/403, ask the user via `AskUserQuestion` for auth method (storage-state JSON / basic-auth / cookies). If unreachable, abort with a clear message.
- **HTML mode:** confirm the folder exists and contains at least one HTML file. List the discovered files for the user.

Save what you found to `{out_dir}/source.md`:

```markdown
# Source
- Type: <url | wireframes | prototype>
- Location: <url-or-path>
- Files / routes discovered: <count + list>
- Auth: <none | storage-state | basic-auth>
```

---

## Phase 2: Discover and approve journeys

Identify candidate user journeys to critique. The strategy depends on source type:

### 2a. URL mode — try inference, fall back to user-described

Run an exploratory crawl with `assets/capture.mjs --mode crawl --depth 1 --max 20` against the entry URL. Inspect the resulting `manifest.json` and dump the page titles + URL paths. If at least 5 distinct routes were captured AND no auth wall was hit, propose 3-5 candidate journeys grouped by intent (e.g., "browse → detail → action", "auth → onboarding → first task").

If the crawl returns < 5 routes, hits a redirect loop to a login page, or lands on a single-page app where everything routes through `/`, **fall back** to asking the user to describe journeys plus any auth steps in plain language. Capture their description in `{out_dir}/journeys.md`.

### 2b. Wireframes / prototype mode — read the artifact

For wireframes, read each HTML file's `<title>` and any annotation layer / state-switcher tabs to infer screen purpose. For prototypes, read `runtime.js` for the route table.

Cross-reference with the workstream's `req-doc.md` if available — pull declared journeys directly. Otherwise propose 3-5 inferred journeys grouped by user intent.

### 2c. User approval of journey set

Present candidates and capture which to critique:

```
AskUserQuestion (multiSelect):
  question: "Which journeys should I critique? (Pick up to 5 — more produces shallow output.)"
  header: "Journeys"
  options:
    - <journey-1 label> — <one-line description>
    - <journey-2 label> — <one-line description>
    - ...
```

If `--journeys <id1,id2>` was passed, skip the question and use those.

**Cap: 5 journeys per session.** More dilutes the rubric pass.

For each selected journey, define the step-by-step click path (URL or selector per step). For URL mode this becomes a journey-config JSON consumed by the capture script in Phase 3; for HTML mode it's just the ordered list of files.

Save to `{out_dir}/journeys.md` with one section per chosen journey, including step path and entry context (cold visitor / signed-in user / error recovering).

---

## Phase 3: Capture flow screenshots

Run the packaged Playwright script `assets/capture.mjs` (full usage in the file header). Output goes to `{out_dir}/screenshots/`.

### 3a. URL mode

Build a journey config from Phase 2c and run:

```
node {skill_dir}/assets/capture.mjs \
  --mode journey \
  --config {out_dir}/journeys.json \
  --out {out_dir}/screenshots \
  [--storage-state <path>] [--basic-auth user:pass] \
  --viewport 1440x900
```

Repeat per device variant if multi-device crit is requested (default: desktop only; ask the user via `AskUserQuestion` if mobile should be added).

### 3b. Wireframes / prototype mode

```
node {skill_dir}/assets/capture.mjs \
  --mode files \
  --files <comma-separated absolute paths from journeys.md> \
  --out {out_dir}/screenshots \
  --viewport 1440x900
```

### 3c. Verify capture quality

Read `{out_dir}/screenshots/manifest.json`. Check:

- One PNG per declared step (no missing journey steps)
- No fatal errors recorded
- File sizes > 5 KB (a 1 KB PNG usually means the page didn't render)

If anything failed, surface the error to the user and decide together: retry with adjusted selectors, skip the journey, or proceed with partial coverage and note the gap in the report.

---

## Phase 4: Heuristic evaluation against the rubric

Read `reference/eval.md` (canonical rubric) into context.

Dispatch a **reviewer subagent** (or run inline if subagents unavailable) per scope:

1. **Per-screen pass** — one subagent receives all screenshots + the rubric, returns the JSON array described in `eval.md`. Cap output at 12 high+medium findings; low findings go in an "unsurfaced" appendix.
2. **Per-component pass** — one subagent identifies recurring components (button, card, input, modal) across all screens and scores once per component class.
3. **Per-journey pass** — one subagent per journey walks the screenshot sequence step-by-step, counts clicks / keystrokes / decisions / modal interrupts, and applies J1 thresholds.

Save raw output to `{out_dir}/eval-findings.json`.

### 4a. Findings Presentation Protocol

**Do not dump findings as prose.** Group findings by category and present each via `AskUserQuestion` so the user can disposition each one structurally.

For every batch of up to 4 findings (the `AskUserQuestion` per-call cap):

```
AskUserQuestion:
  question: "<one-sentence finding> — proposed fix: <one-sentence concrete fix>"
  header: "<short category — e.g., 'A1 contrast'>"
  options:
    - "Apply as proposed" — recommendation enters the report as a high-confidence fix
    - "Modify" — recommendation enters with the user's edit; capture in notes
    - "Skip" — finding is marked "won't-fix" and excluded from the report's recommendations
    - "Defer" — finding moves to a "Deferred" section as known-but-not-now
```

Issue multiple sequential `AskUserQuestion` calls until all high+medium findings are dispositioned. Cap dispositions at 12 per session — anything beyond that is logged in `eval-findings.json` as unsurfaced.

**Platform fallback** (no `AskUserQuestion`): emit a numbered findings table with `disposition` column blank, save to `{out_dir}/eval-findings-review.md`, and ask the user to fill it in. Do NOT silently auto-apply.

**Anti-pattern:** A wall of prose ending in "Let me know what you'd like to fix." Always structure the ask.

---

## Phase 5: PSYCH and MSF pass

Apply a lightweight psychology + Motivation/Satisfaction/Friction pass to the captured journeys. Format mirrors `/wireframes` and `/prototype`:

### 5a. PSYCH walkthrough

For each chosen journey, assign each visible element an integer in [+1..+10] or [-10..-1] indicating its psychological pull. Sum to a screen Δ; track cumulative from an entry-context default (40 = medium-intent). Use the table format in `/wireframes/reference/psych-output-format.md` if you have access; otherwise:

```markdown
## Journey: <name> (start: 40, Medium-intent)

| Step | Screen          | Previous | Δ   | Cumulative | Severity | Top 2 Drivers                  |
| ---- | --------------- | -------- | --- | ---------- | -------- | ------------------------------ |
| 1    | 01-landing      | 40       | -3  | 37         | OK       | -3 (form density)              |
| 2    | 02-signup       | 37       | -8  | 29         | Watch    | -8 (5 required fields)         |
```

Severity legend: cumulative `< 0` → Bounce risk; `< 20` → Watch; single-step Δ `< -20` → Cliff.

### 5b. MSF pass

For each journey, score on a 1-5 scale:

- **Motivation** — does the entry point clearly answer "why am I here, why now"?
- **Satisfaction** — does the journey deliver a clear payoff, with confirmation moments?
- **Friction** — interaction (clicks/keystrokes), cognitive (decisions/jargon), emotional (interruptions/mode switches). Quote the click/keystroke totals from Phase 4's per-journey pass.

Save both passes to `{out_dir}/psych-msf.md`. Apply Phase 4a's Findings Presentation Protocol to any "Watch", "Cliff", or score ≤ 2 finding.

---

## Phase 6: Synthesise the recommendations report

Write `{out_dir}/design-crit.md` — the single-source report. Keep it concise; recommendations are the deliverable, raw findings are appendices.

Structure:

```markdown
# Design Crit — <feature slug>

Generated: YYYY-MM-DD
Source: <url-or-path> (<type>)
Journeys reviewed: <count>
Screens captured: <count>

## TL;DR (top 5 recommendations)

1. **[high] <one-line headline>** — <one-line "why" tied to evidence>. <one-line concrete fix>.
2. ...

## Recommendations by journey

### Journey: <name>

- **[high] <finding> ([N5])** — <evidence>. Fix: <concrete fix>.
- **[medium] <finding> ([V1])** — <evidence>. Fix: <concrete fix>.
- ...

(Friction stats: clicks=N, keystrokes=N, decisions=N, est. time=Ns, threshold breach=<yes/no>)

## Recommendations by component

- **Primary button** — <finding(s)>. Fix: <concrete fix>.
- ...

## Cross-cutting patterns

Findings that recur across ≥ 2 journeys / screens (highest leverage).

## Deferred

Findings the user chose to defer; logged for future review.

## Appendix A — PSYCH journey scores

(Tables from psych-msf.md)

## Appendix B — Raw findings

Pointer to `eval-findings.json`.
```

Each recommendation must:

- Cite the rubric ID it came from (e.g., `[N5]`, `[A1]`, `[J1]`)
- Reference observable evidence (region of a screenshot, click count, contrast value)
- Propose a concrete fix, not a vague direction

Cap the body at ~400 lines; if there are more findings than that, push the long tail into the appendix with a count.

---

## Phase 7: Workstream Enrichment

**Skip if no workstream was loaded in Phase 0.** Otherwise, follow `_shared/pipeline-setup.md` Section C. For this skill, the signals to look for are:

- Recurring high-severity heuristic IDs across journeys → workstream `## Known UX Friction`
- Validated journeys + their entry contexts → workstream `## Journeys` (extend, don't replace)
- Component classes flagged for rework → workstream `## Design System Debt`
- PSYCH/MSF "Cliff" or "Bounce risk" steps → workstream `## Drop-off Risks`

This phase is mandatory whenever Phase 0 loaded a workstream — do not skip it just because the report is written.

---

## Phase 8: Capture Learnings

**This skill is not complete until the learnings-capture process has run.** Read and follow `learnings/learnings-capture.md` (relative to the skills directory) now. Reflect on whether this session surfaced anything worth capturing — surprising behaviors, repeated corrections, non-obvious decisions about journey selection, capture failures, or rubric blind spots. Proposing zero learnings is a valid outcome for a smooth session; the gate is that the reflection happens, not that an entry is written.

---

## Anti-patterns

- **Skipping the capture step** because "I can read the HTML." The rubric explicitly grades visual hierarchy, contrast, and Gestalt — those need pixels, not source.
- **Critiquing a single screenshot in isolation.** Per-journey J-checks and friction thresholds need the full step sequence; per-component C-checks need cross-screen comparison.
- **Padding the findings list.** An empty heuristic finding is fine — pad-to-look-thorough produces noise the user has to triage.
- **"Improve hierarchy" / "make it cleaner" / "consider better UX"** — vague recommendations the user can't act on. Every recommendation must reference the offending element/region and propose a concrete change.
- **Dumping findings as prose.** Always structure dispositions via `AskUserQuestion` (Phase 4a); prose dumps force the user to hand-write triage and lose structure.
- **Inventing measurements.** If you didn't compute the contrast ratio or click count, don't state one. Cite "Stark says 3.2:1" only if Stark actually returned that value.
- **Critiquing > 5 journeys.** Output dilutes; rubric becomes shallow. Cap at 5 per session.
- **Treating analytical-only friction as live-walk friction.** If Playwright capture failed and you're inferring friction from the HTML alone, label the report accordingly and warn the user the numbers are estimates.
