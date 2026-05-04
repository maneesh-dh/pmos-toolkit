# Spec: `/polish` skill

**Status:** Draft v3 (post-grill round 2)
**Owner:** Maneesh
**Date:** 2026-05-04
**Skill location (final):** `~/Desktop/Projects/agent-skills/skills/polish/SKILL.md`
**Plugin namespace:** `pmos-toolkit:polish`

---

## 1. Problem

Drafts written by humans (or AI-assisted) frequently suffer from the same prose pathologies: clutter, hedging, throat-clearing intros, em-dash overuse, AI-vocabulary tells, weak ledes, bullet abuse where prose would flow. Existing tools (Hemingway, Grammarly) catch some of these but don't:

- Operate inside the agent loop where drafts live
- Respect the author's voice (most tools flatten everything to a single style)
- Distinguish "violation worth fixing" from "stylistic choice"
- Surface findings as actionable, per-finding decisions rather than a wall of suggestions

`/polish` fills this gap: a markdown-aware, voice-preserving prose critic-and-refactorer that runs inside the pmos-toolkit and can be invoked on any document — PRDs, blogs, READMEs, ADRs, session-logs, emails, even SKILL.md files.

## 2. Goals & non-goals

**Goals**
- Diagnose any markdown document against a binary pass/fail rubric of well-established writing principles + AI-slop tells
- Refactor failing principles into a polished version, preserving author voice unless a target style preset is chosen
- Present findings as per-finding decisions for high-risk fixes (Fix as proposed / Modify / Skip / Defer); auto-apply low-risk mechanical fixes with a count
- Scale to any doc type via four built-in style presets + voice-preservation mode
- Allow user-defined custom checks and threshold overrides that survive plugin updates

**Non-goals**
- Not a grammar checker (typos, agreement errors are out of scope — assume the user has spell-check)
- Not a fact-checker (technical/factual claims are flagged, never silently rewritten)
- Not a content critic (won't argue with the doc's thesis or completeness)
- Not a SEO/marketing optimizer
- Won't touch code blocks, frontmatter, links, footnotes, table data

## 3. User experience

### Invocation

```
/polish path/to/doc.md
/polish https://example.com/post           # WebFetch
/polish "paste your text here"             # inline
/polish notion://<page-id>                 # Notion MCP if available (read-only)
```

Optional flags:
- `--preset <preserve|concise|narrative|technical>` — skip detect-and-ask
- `--dry-run` — diagnose only, no rewrite
- `--checks <path>` — point at a custom checks file (otherwise auto-loads `~/.pmos/polish/custom-checks.yaml`)

There is intentionally **no `--in-place` flag**. After a successful polish, the skill prompts whether to replace the original with the polished version (see §4.7).

### Flow at a glance

```
Phase 0: Load context, custom checks, threshold overrides
Phase 1: Ingest + classify (doc type, voice sample, lock zones, size bucketing + chunking)
Phase 2: Pick preset (detect + ask, unless --preset)
Phase 3: Run binary eval rubric → list of failed checks with cited spans
Phase 4: Estimate budget + confirm; targeted refactor passes for failed checks
Phase 5: Auto-apply low-risk fixes; surface high-risk findings via Findings Presentation Protocol
Phase 6: Apply approved patches → re-run rubric → optional 2nd iteration (hard cap)
Phase 7: Write output (stitch chunks if applicable) + before/after metrics; offer to replace original
Phase 8: Capture learnings
```

Each phase is tracked as a `TodoWrite` task at runtime so the user sees live progress (see §4.0).

### Output

By default, writes `<original>.polished.md` next to the source plus a console summary:

```
Polish complete: doc.md → doc.polished.md

Voice: Detected → applied "preserve voice"
Findings: 14 checks run, 6 failed, 4 auto-fixed, 1 user-fixed, 1 deferred
Iterations: 1 of 2 (max)

Before → After:
  Words:                 1,842 → 1,310  (-29%)
  Avg sentence length:   24.1  → 16.8
  Passive voice:         18%   → 7%
  AI-vocab hits:         11    → 0
  Em-dashes:             34    → 8
  Hedging stack hits:    9     → 2

Replace doc.md with the polished version? [y/N]
```

## 4. Architecture

### 4.0 Cross-cutting: progress tracking

`/polish` has 9 phases — well above the 3-phase threshold for progress tracking per pmos-toolkit conventions. At skill startup, the agent MUST create one task per phase using `TodoWrite` (or platform equivalent), mark each task `in-progress` when it begins, and `completed` when it finishes — no batching. Long phases (Phase 4 patch generation across many findings) get sub-tasks per finding so the user sees concrete progress.

### 4.0.1 Cross-cutting: large document handling

**Size only governs CHUNKING, not iteration count.** Iteration count is governed by the convergence loop (§4.7) and is independent of doc size — a dense 800-word essay can need the full 2-iteration polish, while a 6,000-word README that's already clean may converge in iteration 1.

**Chunking thresholds** (measured on polishable prose only — locked zones excluded from word count):

| Polishable words | Chunking behavior                                                                |
|-------------------|----------------------------------------------------------------------------------|
| < 4,000           | No chunking — process whole doc as one unit (still runs full 2-iteration loop)  |
| 4,000 – 25,000    | Section-chunked patch generation; global checks always run on whole doc         |
| > 25,000          | Refuse with split-and-retry guidance (hard ceiling, see below)                  |

The 4,000-word threshold is about **context-window efficiency for the patch model**, not about how much polish the doc deserves. Small/dense docs get the same iteration treatment as large ones.

**Chunking strategy (when triggered):**

1. **Chunk boundaries** = H1/H2 headings. Never split mid-paragraph or mid-list. If a single section exceeds 4,000 words, fall back to splitting on H3, then on paragraph boundaries with a 200-word overlap window between chunks (overlap is read-only context, not patched twice).
2. **Voice markers are sampled ONCE from the whole doc** (Phase 1) and shared across chunks — no per-chunk re-sampling.
3. **Local checks (1, 5, 6a, 6b, 8, 9, 10, 13)** run per-chunk in parallel where possible; results aggregated.
4. **Global checks (2, 3, 4, 7, 11, 12, 14)** ALWAYS run on the whole doc — never per-chunk — because they need full-doc context (lede, header structure, density-per-N-words). This applies even to sub-4,000-word docs (trivial case: one chunk = whole doc).
5. **Patch generation** is per-chunk; patches from different chunks never overlap by construction.
6. **Stitch-back**: chunks reassembled in original order; chunk boundaries verified byte-identical to original (boundary lines themselves are not patched).
7. **Budget estimate** (§4.5) accounts for chunking — `calls = chunks × per-chunk-calls + global-check-calls`. For sub-4,000-word docs, `chunks = 1`.

**Hard ceiling.** If polishable prose exceeds 25,000 words, /polish refuses with: *"Doc too large for a single polish run. Split into sections and polish individually, or use `--dry-run` to get a rubric report only."* Avoids unbounded runtime.

**Iteration depth is uniform across all sizes.** The 2-iteration convergence cap (§4.7) applies to every run, regardless of word count. A complex 500-word memo gets the same chance to converge as a 10,000-word PRD.

### 4.1 Phase 0 — Context, custom checks, thresholds

- Read `~/.pmos/learnings.md` if present, scan `## /polish` section
- Resolve checks file with this precedence:
  - If `--checks <path>` was passed → load ONLY that file; ignore the default
  - Otherwise → load `~/.pmos/polish/custom-checks.yaml` if present
- Validate the loaded file against `schemas/custom-checks.schema.json` (shipped with the skill)
  - On schema error: print the offending entries and continue with built-ins only — do NOT silently skip

(There is no workstream-context load. `/polish` operates on derivatives and doesn't need workstream state.)

### 4.2 Phase 1 — Ingest + classify

**Input handlers:**

| Source              | Method                                                          |
|---------------------|------------------------------------------------------------------|
| Local `.md`         | `Read` tool                                                      |
| URL                 | `WebFetch` → strip HTML → markdown                               |
| Inline text         | Treat argument as the content                                    |
| Notion page         | `mcp__plugin_Notion_notion__*` (read-only flatten to markdown; non-prose blocks become labeled placeholders; skip with note if MCP missing) |

**Lock zones.** Record byte ranges that must remain byte-identical post-polish:
- Fenced code blocks (```` ``` ````), inline code (`` `…` ``), HTML blocks
- YAML/TOML frontmatter
- Link URLs (`[text](url)` — text is polishable, url is locked)
- Footnote references (`[^id]`) and footnote definitions
- Table cells with **fewer than 8 words** (treated as data; column headers, short labels). Cells with **8 or more words** are polishable prose.
- Notion non-prose block placeholders (see §5.2 format)

Patches that intersect a locked zone are rejected before review. **Detection also skips locked zones** — the rubric never fires on text inside a code fence, frontmatter, link URL, footnote ref, short table cell, or Notion placeholder. No false positives that the user can't act on.

**Voice sample (specified):**

Extract a 200-word contiguous passage from the densest prose region of the doc (skip headings, lists, tables, code). Compute and store:

| Marker                         | How extracted                                                          |
|--------------------------------|------------------------------------------------------------------------|
| `avg_sentence_length`          | Word count ÷ sentence count                                            |
| `sentence_length_stddev`       | StdDev across sentences                                                |
| `register`                     | LLM tag: `formal | conversational | technical | casual`                |
| `person`                       | Dominant pronoun: `first | second | third`                             |
| `idiomatic_phrases`            | LLM extracts up to 5 distinctive author phrases (verbatim, ≤6 words ea)|
| `contraction_rate`             | Contractions ÷ total verbs (proxy for casual/formal)                   |

The full marker block is serialized as JSON and prepended to every patch prompt in Phase 4.

**Short-doc handling.** If less than 200 words of polishable prose exist, sample whatever is available and set `low_confidence: true` on the marker block. Patch prompts receive the markers with a "low-confidence reference" caveat. `PRESERVE_VOICE_CONFLICT` emissions during low-confidence runs do NOT count toward the 30% abort cap (§4.5).

**Doc-type classifier:**

Cheap signals first:
- Filename: `README*` / `CHANGELOG*` / `*.adr.md` / `runbook*` → **technical**
- Filename: `PRD*` / `spec*` / `*_requirements.md` / `memo*` → **concise**
- Filename: `*.blog.md` / `posts/*` / `essay*` → **narrative**
- Frontmatter `type:` field overrides everything

If no signal matches, invoke a single LLM classifier call returning `{type, confidence}`. If confidence < 0.6, default recommendation = **preserve voice**.

### 4.3 Phase 2 — Pick preset (detect + ask)

Recommend a preset based on the classifier, surface via `AskUserQuestion`:

```
Detected: Technical doc (README-style)
Recommended preset: Technical
Options: [Technical (Recommended) | Concise | Narrative | Preserve voice | Other]
```

Skip this phase if `--preset` was passed.

**Preset semantics:**

| Preset       | Sentence target | Voice                                | Keep         |
|--------------|------------------|--------------------------------------|--------------|
| Preserve     | Match author     | Mirror author's register             | Idiosyncrasies, varied rhythm |
| Concise      | <18 words avg    | BLUF, definition-dense               | Specifics, tables, lists      |
| Narrative    | Varied (8–28)    | Conversational, single thesis        | Anecdotes, rhythm             |
| Technical    | <20 words avg    | Imperative, second person ("you")    | Code-first, decisions upfront |

### 4.4 Phase 3 — Binary eval rubric

Each check returns **pass** or **fail** plus cited line numbers / spans. No subjective scoring.

**LLM-judge determinism contract.** Every llm-judge call MUST:
- Use `temperature: 0`
- Return structured output matching the schema `{verdict: "pass" | "fail", cited_spans: [{line, excerpt}], rationale: string}`
- Cite at least one `cited_spans` entry on `fail`. A `fail` verdict with no cited evidence is treated as `pass` (the judge couldn't ground the failure → don't act on it)

This contract is the determinism guarantee. Custom `prompt`-mode checks (§4.4 custom checks) reuse the same schema.

**Implementation modes:**

| Mode         | Used for checks                                       | Notes                                                 |
|--------------|--------------------------------------------------------|-------------------------------------------------------|
| `regex`      | 1, 5, 6-hardbans, 8, 9, 10                            | Deterministic; literal pattern match                  |
| `llm-judge`  | 2, 3, 4, 6-softflags, 7, 11, 12, 13, 14               | Strict pass/fail prompt with cited evidence required  |

**Built-in checks (14):**

| #  | Check                       | Mode      | Fail condition                                                                                  |
|----|-----------------------------|-----------|--------------------------------------------------------------------------------------------------|
| 1  | Clutter words               | regex     | Doc contains any of: *very, really, just, quite, actually, basically, simply, in order to, the fact that, due to the fact that, at this point in time*  |
| 2  | Passive voice ratio         | llm-judge | Passive constructions exceed preset's `passive_max_pct`                                          |
| 3  | Sentence length variance    | llm-judge | StdDev of sentence length below preset's `sentence_stddev_min` across any 200-word window        |
| 4  | Throat-clearing intro       | llm-judge | First paragraph contains throat-clearing OR runs >3 sentences before lede                        |
| 5  | Em-dash overuse             | regex     | Em-dashes exceed preset's `em_dash_per_200w_max`                                                  |
| 6a | AI-vocabulary (hard-bans)   | regex     | Any of: *delve, tapestry, navigate the landscape, embark on a journey, in the realm of, intricate tapestry* |
| 6b | AI-vocabulary (soft-flags)  | llm-judge | Context-metaphorical use of: *robust, foster, ecosystem, holistic, leverage, seamless, intricate, multifaceted* (concrete uses pass) |
| 7  | Tricolon overuse            | llm-judge | More than `tricolon_max_per_500w` rhetorical "X, Y, and Z" constructions                         |
| 8  | "Not just X, it's Y"        | regex     | Any occurrence of the *not just X, [it's/but] Y* rhetorical pattern                              |
| 9  | Hedging stack               | regex     | Any sentence contains 2+ of: *might, could, perhaps, possibly, may, somewhat, fairly, rather*    |
| 10 | Empty transitions           | regex     | Paragraph opens with: *Furthermore, Moreover, Additionally, In addition, That said* (>1 occurrence) |
| 11 | Header inflation            | llm-judge | Heading depth >3, or section averages below `section_min_words_per_heading`                      |
| 12 | Bullet abuse                | llm-judge | A bulleted list where >50% of bullets are full sentences flowing into each other                 |
| 13 | Vague abstractions          | llm-judge | Any paragraph asserting a claim without a concrete noun, number, name, or example within 3 sentences |
| 14 | Weak / buried lede          | llm-judge | First paragraph does not state the doc's central claim (BLUF check)                              |

Plus: any user-defined checks loaded from `~/.pmos/polish/custom-checks.yaml`.

**Per-preset threshold defaults:**

| Threshold key                       | preserve | concise | narrative | technical |
|-------------------------------------|----------|---------|-----------|-----------|
| `passive_max_pct`                   | 25       | 15      | 25        | 15        |
| `sentence_stddev_min`               | 4        | 4       | 6         | 4         |
| `em_dash_per_200w_max`              | 2        | 1       | 3         | 1         |
| `tricolon_max_per_500w`             | 3        | 2       | 3         | 2         |
| `section_min_words_per_heading`     | 30       | 50      | 40        | 30        |

These are starting-point defaults; calibrate after first real-world use. Users override per-preset in `custom-checks.yaml` under a `thresholds:` block.

**Custom checks file format** (`~/.pmos/polish/custom-checks.yaml`):

```yaml
thresholds:
  technical:
    em_dash_per_200w_max: 0
    passive_max_pct: 10

checks:
  - id: no-marketing-speak
    fail_when: regex
    pattern: "(?i)\\b(unlock|empower|revolutionize|game-changing|cutting-edge)\\b"
    rationale: "Marketing verbs"

  - id: no-first-person-singular
    fail_when: regex
    pattern: "(?i)\\b(I|me|my|mine)\\b"
    rationale: "Team docs should say 'we' not 'I'"
    applies_to_presets: [technical, concise]

  - id: no-emoji-bullets
    fail_when: prompt
    prompt_text: "Do any bullet lists in this doc start with emoji decorations?"
    rationale: "Emoji bullets read as low-effort"
```

JSON schema is shipped at `schemas/custom-checks.schema.json` and validated at Phase 0.

**`prompt`-mode evaluation.** The user writes only the question (`prompt_text`). /polish wraps it in a system prompt enforcing the LLM-judge determinism contract (temp 0, structured output, cited evidence). Users do not have to handle parsing or output formatting.

### 4.5 Phase 4 — Targeted refactor passes

**Check categorization (drives auto-apply vs. ask):**

| Risk     | Checks                                                  | Phase 5 behavior                                         |
|----------|---------------------------------------------------------|----------------------------------------------------------|
| Low-risk | 1, 5, 6a, 6b, 8, 9, 10                                  | Auto-apply silently; report aggregate count in summary   |
| High-risk| 2, 3, 4, 7, 11, 12, 13, 14                              | Surface as individual findings via `AskUserQuestion`     |

Custom checks default to **high-risk** unless they declare `risk: low` in the YAML.

**Voice markers are anchored to the ORIGINAL doc.** They are sampled once in Phase 1 and reused for every patch in every iteration. Iter-2 patches reference the same markers as iter-1 — no re-sampling. This prevents iterative voice drift and gives tests a single baseline to assert against.

**Local vs global checks (drives per-patch QA scope):**

| Scope  | Checks                                  | Reason                                                                |
|--------|-----------------------------------------|------------------------------------------------------------------------|
| Local  | 1, 5, 6a, 6b, 8, 9, 10, 13              | Fire on a span; can be re-evaluated on the patched span alone          |
| Global | 2, 3, 4, 7, 11, 12, 14                  | Aggregate over whole doc (counts per N words, document structure, lede) |

**Patch generation contract.** For each failed check:

1. Locate the offending span(s)
2. Generate a rewrite. The patch prompt MUST include:
   - The voice marker JSON from Phase 1 (with `low_confidence` flag if applicable)
   - The full active threshold set for the chosen preset
   - The cited violation
   - Instruction: "If preserving the voice markers conflicts with fixing the violation, output the literal token `PRESERVE_VOICE_CONFLICT` followed by JSON `{conflicting_marker: <one of the marker keys>, reason: <one-sentence justification>}`. Do not silently flatten voice."
3. Verify the rewrite doesn't intersect a locked zone (reject if it does)
4. **Per-patch QA (LOCAL checks only):** re-run the LOCAL checks on the patched span. If a new local check fails:
   - Regenerate the patch with the new failure cited as an additional constraint
   - Cap at 2 retries. If still failing, mark the patch "partial fix — introduces X" and surface to user even if the original check was low-risk
5. **Global checks are NOT re-run per patch.** They are re-run once after all iteration patches are applied (Phase 6). If a global check fails after iteration 1, it surfaces in the optional iteration-2 round (within the 2-iteration cap).
6. If the model emitted `PRESERVE_VOICE_CONFLICT`:
   - Validate the JSON justification; reject malformed responses (treat as patch failure, retry once)
   - Do NOT auto-apply; promote the finding to high-risk and surface to user
   - Track conflict count for the run; if conflicts exceed **30% of attempted patches**, abort the run with: *"Voice constraints too strict for this doc — re-run with `--preset concise` or `--preset narrative`."* (Low-confidence runs do not count toward this cap.)

**Budget estimate.** After Phase 3 produces the failed-check list, before generating any patches, print:

```
Rubric run: 6 of 14 checks failed
Estimated work: ~22 LLM calls, ~45 seconds
Continue? [Y / Downscope / Dry-run only]
```

If estimate exceeds 30 LLM calls, the prompt becomes mandatory (not a default-Y).

**Estimator formula** (documented so users can sanity-check):

```
calls = (llm_judge_failures × 1.3 avg retries)        # patch generation + retries
      + (failed_checks × 0)                            # auto-applied regex patches are free
      + (global_check_count)                           # Phase 6 final rubric re-run
      + (iteration_2 if triggered: same again)

time_seconds = calls × ~2s avg
```

Cost is intentionally NOT shown — model pricing varies and per-call token counts aren't reliably predictable. Calls + time give the user enough signal.

### 4.6 Phase 5 — Findings Presentation Protocol

**Auto-applied (low-risk):** apply silently in a single batch. Record in summary as e.g. *"Auto-fixed: 8 clutter words, 3 em-dashes, 2 hedging stacks"*.

**Surfaced (high-risk + voice-conflict + partial-fix):** group by check category, batch ≤4 per `AskUserQuestion` call.

For each finding:

```
question: "Lede is buried at line 12. Move 'X is Y because Z' to paragraph 1?"
header: "Weak lede"
options:
  - Fix as proposed (Recommended)
  - Modify
  - Skip — keep as-is
  - Defer — leave a comment for me
```

If "Modify" → follow-up open-ended ask for the user's preferred wording.
If "Defer" → insert an HTML comment on the line **directly above** the deferred span:
```
<!-- POLISH: <check-id> kept by user — "<one-line excerpt of the deferred prose>" -->
```
No line numbers (they'd go stale immediately). The excerpt makes the comment self-locating even after subsequent edits or other patches shift surrounding text.

**Structural changes** (lede moves, paragraph merges) are ALWAYS surfaced individually as high-risk findings. They are never auto-applied and never bundled with other finds in a single approval.

**Platform fallback** (no `AskUserQuestion`): print a numbered findings table with a disposition column; do not silently apply high-risk fixes.

**Anti-pattern to avoid:** dumping all findings as prose ending in "let me know what you'd like to fix."

### 4.7 Phase 6 — Apply, re-run, optional 2nd iteration

1. Apply auto-fixes + approved patches to a working copy
2. Compute before/after metrics (word count, avg sentence length, passive %, AI-vocab hits, em-dash count, hedging hits)
3. **Re-run the full rubric** on the polished output
4. If NEW failures appear (excluding ones the user explicitly Skipped/Deferred):
   - Surface them as a 2nd findings round (auto-apply + ask split, same protocol)
   - Apply approved 2nd-round patches
5. **Hard cap: 2 polish iterations total.** If the 2nd run still finds failures, write the file and list remaining failures in the summary — do NOT iterate further.

### 4.8 Phase 7 — Write output + offer replace

- Write to `<original>.polished.md`
- Print summary block (see §3 Output)
- If input was a local file, prompt: `Replace <original> with the polished version? [y/N]`
  - On `y`: if file is in a git repo, simply `mv` polished over original (git is the safety net). If not in a repo, first move original to `<original>.bak`, then write polished to original path
  - On `N`: leave both files in place
- If input was URL / inline / Notion: skip the replace prompt — there's nothing to replace

(There is no separate workstream-enrichment phase. `/polish` operates on derivatives; the source doc is what belongs in the workstream index, and that's `/product-context`'s job.)

### 4.9 Phase 8 — Capture learnings

Mandatory phase per pmos-toolkit conventions. Reflect on whether the session surfaced anything reusable (false-positive checks, pet phrases that should be added to user custom checks, preset misclassifications, threshold drift). Follow `learnings/learnings-capture.md`.

## 5. Interfaces

### 5.1 SKILL.md frontmatter

```yaml
---
name: polish
description: Critique and refactor any markdown document for clarity, concision, voice, and de-AI-slop — runs a binary pass/fail rubric of writing principles, auto-applies safe mechanical fixes, surfaces high-risk changes per-finding, and writes a polished version preserving author voice. Use when the user says "polish this draft", "tighten this prose", "remove the AI slop", "make this more concise", "critique my writing", or wants to clean up a PRD/blog/README/email before sharing.
user-invocable: true
argument-hint: "<file-path | URL | 'inline text' | notion://<id>> [--preset <name>] [--dry-run] [--checks <path>]"
---
```

### 5.2 File system contracts

| Path                                              | Purpose                                                  |
|---------------------------------------------------|----------------------------------------------------------|
| `~/.pmos/polish/custom-checks.yaml`               | User-defined binary checks + per-preset threshold overrides (survives plugin updates). Loaded only if `--checks` is NOT passed. |
| `<plugin>/schemas/custom-checks.schema.json`      | JSON schema validating the above                         |
| `~/.pmos/learnings.md` (`## /polish` section)     | Learnings the skill reads at startup                     |
| `<input>.polished.md`                             | Default output location                                  |
| `<input>.bak`                                     | Created on replace if NOT in a git repo                  |

**`--checks` precedence.** `--checks <path>` fully replaces the default `~/.pmos/polish/custom-checks.yaml` for that run — there is no merge. User intent ("use exactly this set") wins.

**Notion non-prose block placeholder format.** When ingesting from Notion, every non-prose block (databases, embeds, toggles, callouts containing structured data) is replaced inline with:

```html
<!-- NOTION_BLOCK type=<database|embed|toggle|callout|...> id=<uuid> -->
```

These placeholders are added to the lock-zone set — never detected, never patched. They preserve the structural skeleton so the user can splice the original blocks back into Notion if they want to round-trip.

### 5.3 Tool dependencies

| Tool                  | Required? | Fallback                                          |
|-----------------------|-----------|----------------------------------------------------|
| `Read`, `Write`, `Edit` | Yes      | None                                               |
| `AskUserQuestion`     | No        | Numbered findings table, user replies in prose; high-risk fixes never auto-applied |
| `WebFetch`            | No        | Skip URL input mode with note                      |
| `Notion MCP`          | No        | Skip Notion input mode with note                   |
| `TodoWrite`           | No        | Sequential phase prose                             |

## 6. Out of scope (explicit)

- **Code blocks** (fenced + inline) — locked, byte-identical
- **Factual / technical claims** — never silently rewritten; flagged as "verify" findings only
- **Frontmatter, link URLs, footnote refs, table data** — locked
- **Grammar/spelling** — assume external tools handle this
- **Translation, localization, tone change beyond preset selection** — separate skill if needed
- **Writing back to Notion** — Notion is read-only input; output is always a local file
- **Workstream enrichment** — handled by `/product-context`, not `/polish`

## 7. In scope but bounded

- **Structural reorganization** is allowed only when a check (e.g. weak lede, redundant adjacent paragraphs) requires it, and ONLY via individual high-risk findings with explicit per-finding approval. The skill never silently re-outlines. Any structural change beyond moving a single sentence (lede) or merging two adjacent paragraphs is deferred with a suggestion comment rather than applied.

## 8. Risks & mitigations

| Risk                                            | Mitigation                                                                                  |
|-------------------------------------------------|---------------------------------------------------------------------------------------------|
| Voice flattening                                | Voice markers injected into every patch prompt; `PRESERVE_VOICE_CONFLICT` escape; per-finding approval on conflicts |
| Rubric gaming (passes checks but reads bad)     | Binary checks are necessary-not-sufficient; user approves high-risk fixes; final rubric re-run with 2-iteration cap |
| False positives (legit em-dash, "robust", etc.) | "Skip" option per finding; AI-vocab two-tier with LLM judge for soft-flags; learnings capture |
| Touching locked zones                           | Pre-flight zone check on every patch; reject patches that intersect                         |
| Custom checks lost on plugin update             | Stored at `~/.pmos/polish/`, NOT inside the plugin directory; YAML + JSON schema            |
| LLM "improving" technical claims                | Phase 4 patch contract excludes claim-rewrites; technical content emits "verify" findings only |
| Patch introducing new violations                | Per-patch LOCAL-rubric re-check on the patched span, reject-and-retry up to 2x; GLOBAL checks re-run end-of-iteration; "partial fix" surfaced if still failing |
| LLM-judge stochasticity                         | Determinism contract: temp 0, structured JSON output, evidence required on fail (no evidence → pass) |
| `PRESERVE_VOICE_CONFLICT` lazy abuse            | Structured `{conflicting_marker, reason}` justification required; >30% conflict rate aborts run with a "preset too strict" message |
| Iterative voice drift across iterations         | Voice markers anchored to ORIGINAL doc; never re-sampled                                    |
| Stale defer-comment line numbers                | Defer comments live above the deferred span with a self-locating excerpt; no line numbers   |
| Notion non-prose blocks lost or mangled         | Placeholder comments preserve block IDs; treated as locked zones; round-trip-friendly       |
| Short docs producing nonsense voice markers     | Sample what's available; mark `low_confidence: true`; conflicts during low-confidence don't count toward 30% cap |
| Large docs (>4k words) blowing context window   | H1/H2 chunking for patch generation; global checks always whole-doc; hard ceiling at 25k polishable words. Iteration count NOT gated by size — small complex docs still get full 2-iteration loop |
| User can't see what /polish is doing at runtime | One `TodoWrite` task per phase; long phases (patch generation across many findings) get one sub-task per finding |
| Convergence loop / runaway cost                 | Hard 2-iteration cap; budget estimate + confirm prompt before patches generated             |
| Destructive in-place writes                     | No `--in-place` flag; default writes `.polished.md`; replace is a post-success prompt with `.bak` (or git) safety net |
| Custom-checks YAML validation errors            | Validated against shipped JSON schema at Phase 0; bad entries surfaced loudly, not silently skipped |

## 9. Test plan

Property-based tests, no golden outputs (LLM rewrites are non-deterministic).

A `tests/` directory with paired fixtures:

```
tests/
  fixtures/
    ai-slop-blog.md           → expected: ≥6 failed checks across [1, 5, 6a, 6b, 9, 14]
    clean-readme.md           → expected: 0 failed checks, no rewrite proposed
    pr-description.md         → expected: failures on [4, 9, 14]
    locked-zones.md           → multiple code/frontmatter/link/footnote zones
    custom-check-test.md      → uses sample ~/.pmos/polish/custom-checks.yaml
    voice-preserve.md         → distinctive voice; assert voice markers preserved post-polish
    large-doc-12k.md          → 12,000 polishable words; assert chunking, stitch-back integrity, global-check correctness
    huge-doc-30k.md           → exceeds 25k ceiling; assert refusal message
    small-but-dense.md        → 800 words, multiple cascading findings; assert iteration 2 triggers (size does NOT short-circuit iteration)
```

For each fixture, assert:
1. **Detection contract** — exact set of expected failed checks is detected (no more, no less)
2. **Locked-zone contract** — every locked-zone byte range is byte-identical pre and post polish; locked-zone content is NEVER cited as a finding
3. **Convergence contract** — post-polish output passes the full rubric within 2 iterations (or remaining failures are surfaced in summary)
4. **Word-count delta** — within an expected range (e.g., ai-slop-blog reduces by 20–40%)
5. **Voice contract (preserve preset)** — post-polish voice markers (avg sentence length, contraction rate) within ±20% of original
6. **Custom-checks schema** — invalid YAML produces clear errors at Phase 0; valid YAML loads and fires correctly
7. **`--checks` precedence** — passing `--checks` ignores the default file
8. **Voice-conflict abort** — synthetic fixture forcing >30% conflicts triggers the abort message

Plus unit tests for the regex checks (deterministic, can be exhaustive). LLM-judge unit tests use a **mocked LLM** returning fixed structured verdicts — they test the surrounding plumbing (parsing, threshold application, cited-span handling), not the judge's semantic accuracy. **No real-LLM calibration suite in v1**; the temp-0 + JSON-schema + evidence-required contract is the determinism guarantee. If field reports show judge regressions post-launch, add a calibration suite then.

## 10. Open questions

None blocking. To revisit after v1 lands:

1. Should `/polish` integrate with `/artifact` as an auto-final-pass once stable?
2. Should we add a `--diff` mode that writes a unified diff alongside the polished output?
3. Threshold defaults need real-world calibration — collect data from first month of usage and tune.

## 11. Pipeline position

Standalone — does not sit inside the `requirements → spec → plan → execute → verify` pipeline. Can be invoked at any point on any markdown artifact, including artifacts produced by other pmos-toolkit skills.

## 12. Implementation checklist (for /plan)

- [ ] Skill scaffolding with all 9 phases as numbered sections
- [ ] Platform Adaptation section
- [ ] Progress tracking via `TodoWrite` (one task per phase + sub-tasks per finding in Phase 4)
- [ ] Large-document handling (4k chunking threshold, H1/H2 chunking, stitch-back, 25k-word ceiling) — iteration count independent of size
- [ ] Findings Presentation Protocol section with auto-apply / surface split
- [ ] Built-in 14-check rubric module (regex + llm-judge modes)
- [ ] Per-preset threshold table with override loader
- [ ] Custom checks loader + JSON schema + schema validator
- [ ] Voice sampler (200-word extraction + marker JSON serializer)
- [ ] Doc-type classifier (filename/frontmatter signals + LLM fallback)
- [ ] Four preset definitions with semantic + threshold differences
- [ ] Lock-zone tracker (code, frontmatter, links, footnotes, tables)
- [ ] Patch generator with voice-marker injection + structured `PRESERVE_VOICE_CONFLICT` protocol + 30% abort cap
- [ ] Per-patch LOCAL-rubric re-check with 2-retry cap; GLOBAL checks deferred to end-of-iteration
- [ ] LLM-judge determinism contract (temp 0, JSON schema, evidence-required-on-fail)
- [ ] Notion non-prose block placeholder ingestion + locking
- [ ] `--checks` precedence (replaces default, no merge)
- [ ] Defer-comment format (above span, no line numbers, with excerpt)
- [ ] Short-doc voice handling (low_confidence flag, conflict-cap exemption)
- [ ] Budget estimator + confirm prompt (calls + time only, no cost)
- [ ] Convergence loop with 2-iteration hard cap
- [ ] Metrics computer (before/after deltas)
- [ ] Replace-original prompt with git/bak safety
- [ ] Capture learnings phase (terminal-gate language)
- [ ] Property-based test suite + fixtures
- [ ] Anti-patterns section in SKILL.md
