---
name: polish
description: Critique and refactor any markdown document for clarity, concision, voice, and de-AI-slop — runs a binary pass/fail rubric of writing principles, auto-applies safe mechanical fixes, surfaces high-risk changes per-finding, and writes a polished version preserving author voice. Use when the user says "polish this draft", "tighten this prose", "remove the AI slop", "make this more concise", "critique my writing", or wants to clean up a PRD/blog/README/email before sharing.
user-invocable: true
argument-hint: "<file-path | URL | 'inline text' | notion://<id>> [--preset <name>] [--dry-run] [--checks <path>]"
---

# /polish

**Announce at start:** "Using /polish to critique and refactor this document."

## Platform Adaptation

These instructions use Claude Code tool names. In other environments:
- **No `AskUserQuestion`:** Print a numbered findings table with a disposition column. NEVER silently auto-apply high-risk fixes — they require explicit user input. For preset selection, state your assumption and proceed; the user reviews the polished output.
- **No `TodoWrite`:** Print phase headers as you progress (`## Phase 3: Running rubric…`). Do not batch.
- **No `WebFetch`:** Refuse URL input mode with a note; ask the user to paste the content.
- **No Notion MCP:** Refuse `notion://` input with a note; ask the user to export the page first.
- **No subagents:** Run all phases sequentially in the main agent.

## Track Progress

This skill has 9 phases. At startup, create one `TodoWrite` task per phase. Mark each task `in_progress` when you start it, `completed` when it finishes — never batch completions. Phase 4 (patch generation) gets one sub-task per surfaced finding so the user sees concrete progress.

## Load Learnings

Read `~/.pmos/learnings.md` if it exists. Note any entries under `## /polish` and factor them into your approach for this session (e.g., known false-positive checks, user-preferred preset for a doc type, custom phrases).

---

## Phase 0 — Context, custom checks, thresholds

1. Load `~/.pmos/learnings.md` `## /polish` section if present.
2. Resolve checks file:
   - If `--checks <path>` was passed → load ONLY that file. Ignore the default.
   - Otherwise → load `~/.pmos/polish/custom-checks.yaml` if it exists.
3. Validate the loaded file against `schemas/custom-checks.schema.json`. On schema error: print the offending entries and continue with built-ins only — do NOT silently skip.
4. Merge user threshold overrides on top of preset defaults from `reference/presets.md`.

There is no workstream load. `/polish` operates on derivatives.

## Phase 1 — Ingest + classify

**Resolve input source from argument:**

| Argument shape       | Handler                                                     |
|----------------------|-------------------------------------------------------------|
| Local file path      | `Read` tool                                                  |
| `http(s)://...`      | `WebFetch` → strip HTML to markdown                          |
| `notion://<id>`      | Notion MCP `mcp__plugin_Notion_notion__*` (read-only)        |
| Quoted inline text   | Treat the argument as the document content                   |

If a required tool isn't available, refuse the input mode with a one-line note.

**Compute lock zones.** Per `reference/chunking.md` lock-zone rules: code fences, inline code, HTML blocks, frontmatter, link URLs, footnote refs/defs, table cells with <8 words, Notion non-prose placeholders. Patches that intersect locked zones are rejected; the rubric never fires inside them.

**Voice sample.** Follow `reference/voice-sampling.md`. Extract the marker JSON (avg sentence length, stddev, register, person, idiomatic phrases, contraction rate). Set `low_confidence: true` if <200 polishable words.

**Doc-type classifier.** Cheap signals first (filename prefix, frontmatter `type:`). Only fall back to a single LLM classifier call if no signal matches.

**Size bucketing + chunking.** Apply `reference/chunking.md` thresholds:
- <4,000 polishable words → no chunking
- 4,000–25,000 → H1/H2 chunked patch generation
- >25,000 → refuse with split-and-retry guidance

**Iteration count is independent of size.** A small dense doc gets the same 2-iteration loop as a large one.

## Phase 2 — Pick preset (detect + ask)

Skip if `--preset` was passed.

Otherwise, surface preset options via `AskUserQuestion`. Preset semantics live in `reference/presets.md`. The recommended option is the classifier output; if classifier confidence <0.6, recommend **preserve voice**.

```
Detected: <classifier output>
Recommended preset: <name>
Options: [<recommended> (Recommended) | <alternative 1> | <alternative 2> | Preserve voice]
```

## Phase 3 — Run binary eval rubric

Follow `reference/rubric.md` — runs all 14 built-in checks plus any user-defined checks. Each check returns `pass | fail` with cited spans (line + excerpt). Detection skips locked zones.

**LLM-judge determinism contract** (mandatory for every llm-judge call):
- `temperature: 0`
- Structured output schema: `{verdict: "pass" | "fail", cited_spans: [{line, excerpt}], rationale: string}`
- A `fail` verdict with no `cited_spans` is treated as `pass` (no evidence → no action)

**Output of this phase:** a list of failed checks, each with cited spans, classified as **local** or **global** (per `reference/rubric.md` table).

## Phase 4 — Estimate budget + targeted refactor passes

**Budget estimate first.** Print to user before generating any patches:

```
Rubric run: <N> of 14 checks failed
Estimated work: ~<calls> LLM calls, ~<seconds>s
Continue? [Y / Downscope / Dry-run only]
```

Formula: `calls = (llm_judge_failures × 1.3 retries avg) + global_check_count + (×2 if iter-2 likely)`. Cost intentionally NOT shown — pricing varies. If estimate >30 calls, prompt is mandatory (no default-Y).

If `--dry-run`, stop here and print the rubric report. Do not generate patches.

**Patch generation.** Per failed check (per chunk if chunked), follow `reference/patch-contract.md`:

1. Locate offending span(s)
2. Generate rewrite via patch prompt (voice markers injected, threshold set included)
3. Reject if patch intersects a locked zone
4. **Per-patch QA — LOCAL checks only.** Re-run local checks on patched span. New local failure → regenerate with the new failure cited. Cap 2 retries; mark "partial fix — introduces X" if still failing
5. If model emits `PRESERVE_VOICE_CONFLICT` → validate JSON `{conflicting_marker, reason}`; promote to high-risk finding; track conflict count
6. **Global checks NOT re-run per patch.** They run once at end of iteration (Phase 6)

**Voice-conflict abort.** If conflicts >30% of attempted patches in a non-low-confidence run → abort with: *"Voice constraints too strict for this doc — re-run with `--preset concise` or `--preset narrative`."*

## Phase 5 — Findings Presentation Protocol

Follow `reference/findings-protocol.md`. Summary:

**Auto-apply (low-risk: checks 1, 5, 6a, 6b, 8, 9, 10):** apply silently in a single batch. Record aggregate counts in summary.

**Surface (high-risk: checks 2, 3, 4, 7, 11, 12, 13, 14, plus voice-conflict + partial-fix):** group by check category, batch ≤4 per `AskUserQuestion` call. Each finding offers: **Fix as proposed (Recommended)** / **Modify** / **Skip** / **Defer**. Structural changes are always individually surfaced.

**Defer comment format:** insert immediately above the deferred span:
```
<!-- POLISH: <check-id> kept by user — "<one-line excerpt>" -->
```
No line numbers (they go stale).

**Anti-pattern to avoid:** dumping all findings as prose ending in "let me know what you'd like to fix."

## Phase 6 — Apply, re-run, optional 2nd iteration

1. Apply auto-fixes + approved patches to a working copy (per chunk if chunked)
2. **Re-run the FULL rubric on the polished output** (both local and global checks, whole doc)
3. Compute before/after metrics: word count, avg sentence length, passive %, AI-vocab hits, em-dash count, hedging hits
4. If NEW failures appear (excluding user-Skipped/Deferred):
   - Surface as a 2nd findings round (same auto-apply + ask split)
   - Apply approved 2nd-round patches
5. **Hard cap: 2 polish iterations total.** If iter-2 still finds failures, write the file and list remaining failures in the summary — do NOT iterate further.

## Phase 7 — Write output + offer replace

1. Stitch chunks back together if chunked. Verify chunk boundary lines are byte-identical to original.
2. Write to `<original>.polished.md` (or print polished text if input was inline/URL/Notion).
3. Print summary block:

```
Polish complete: <input> → <output>

Voice: <detected> → applied "<preset>"
Findings: 14 checks run, <N> failed, <auto> auto-fixed, <user> user-fixed, <deferred> deferred
Iterations: <N> of 2 (max)

Before → After:
  Words:                 1,842 → 1,310  (-29%)
  Avg sentence length:   24.1  → 16.8
  Passive voice:         18%   → 7%
  AI-vocab hits:         11    → 0
  Em-dashes:             34    → 8
  Hedging stack hits:    9     → 2

Replace <original> with the polished version? [y/N]
```

4. **Replace prompt** (only if input was a local file):
   - On `y`: if file is in a git repo (check via `git -C <dir> rev-parse --is-inside-work-tree`), `mv` polished over original (git is the safety net). If NOT in a repo, first move original to `<original>.bak`, then write polished to original path.
   - On `N`: leave both files in place.
   - URL/inline/Notion inputs: skip the replace prompt.

## Phase 8 — Capture Learnings

**This skill is not complete until the learnings-capture process has run.** Read and follow `~/.pmos/learnings/learnings-capture.md` (if available) or these inline steps:

Reflect on whether this session surfaced anything reusable:
- False positives (legit uses flagged as violations) → candidate for soft-flag promotion or threshold adjustment
- Repeated user `Skip` on the same check → candidate for preset-specific tuning
- Words/phrases the user repeatedly flags themselves → candidate for the user's `~/.pmos/polish/custom-checks.yaml`
- Preset misclassification → candidate for classifier signal expansion
- Threshold drift (user repeatedly overrides the same threshold) → recommend they persist it in custom-checks.yaml

Append new entries to `~/.pmos/learnings.md` under `## /polish`. Proposing zero learnings is a valid outcome for a smooth session — the gate is that the reflection happens.

---

## Anti-Patterns (DO NOT)

- Do NOT silently apply high-risk fixes. They require user approval (or platform-fallback printed disposition).
- Do NOT touch locked zones — code, frontmatter, link URLs, footnote refs, short table cells, Notion placeholders.
- Do NOT rewrite technical/factual claims. Flag as "verify" findings; never auto-rewrite.
- Do NOT re-sample voice markers between iterations. Anchor to the original doc.
- Do NOT skip the budget estimate when failed_checks > 0. The user needs to see the cost before patches generate.
- Do NOT re-outline the document. Structural changes are limited to lede moves and adjacent-paragraph merges, always individually approved.
- Do NOT write line numbers into defer comments — they go stale immediately.
- Do NOT iterate beyond 2 polish iterations. The cap is hard.
- Do NOT batch findings into prose dumps ending in "let me know what to fix." Use AskUserQuestion or the platform fallback table.
- Do NOT charge ahead if the model emits `PRESERVE_VOICE_CONFLICT` — promote it to a high-risk finding for the user.
- Do NOT exceed the 25,000 polishable-word ceiling. Refuse with split-and-retry guidance.
- Do NOT skip Phase 8. Learning capture is mandatory; zero learnings is fine, but the reflection must happen.

---

## File map

- `SKILL.md` — this orchestrator
- `schemas/custom-checks.schema.json` — JSON schema for user check overrides
- `reference/rubric.md` — 14 built-in checks: regex patterns + LLM-judge prompts
- `reference/presets.md` — preset semantics + per-preset threshold defaults
- `reference/voice-sampling.md` — voice marker extraction algorithm
- `reference/chunking.md` — chunking algorithm + lock-zone rules + size buckets
- `reference/patch-contract.md` — patch prompt template, conflict protocol, retry logic
- `reference/findings-protocol.md` — categorization, AskUserQuestion shape, defer format
- `tests/fixtures/` — 9 fixtures with paired `expected.yaml` contracts
- `example/custom-checks.yaml` — example user can copy to `~/.pmos/polish/`
