---
name: update-skills
description: Ingest feedback (raw text or /retro paste-back), summarize and critique proposed changes per affected pmos-toolkit skill, get user approval on the keep/drop set, then run the requirements -> spec -> plan -> execute -> verify -> complete-dev pipeline (auto-tiered per skill, with /complete-dev invoked once for the batch) sequentially. Optional pipeline enhancer / orchestrator. Use when the user says "update these skills based on feedback", "process this retro output", "fix the issues from /retro", "run the pipeline on this skill feedback", "turn this feedback into changes", or pastes retro/feedback text and wants the updates implemented end-to-end.
user-invocable: true
argument-hint: "<feedback text | path to feedback file | path to existing triage doc> [--from-retro] [--skill <name>] [--non-interactive | --interactive]"
---

# Update Skills

Take feedback about pmos-toolkit skills (free-form text or `/retro` paste-back), triage what to fix vs. drop with the user, then drive the requirements → spec → (grill) → plan → execute → verify pipeline per affected skill.

**Announce at start:** "Using update-skills — parsing feedback, triaging changes, then running the per-skill pipeline."

## Pipeline position

```
/retro  ->  /update-skills (this skill)  ->  /requirements -> /spec -> [/grill] -> /plan -> /execute -> /verify -> /complete-dev
                                              (per affected skill, sequential)
```

Optional pipeline enhancer / orchestrator. Standalone — invoke at any point you have skill feedback to process.

## Platform Adaptation

These instructions use Claude Code tool names. In other environments:

- **No interactive prompt tool:** Triage, tier, and failure dialogues degrade to a numbered markdown table with a disposition column the user fills in inline. State assumption + log in the triage doc when proceeding without explicit per-finding disposition. Do NOT silently self-fix.
- **No subagents:** Pipeline dispatch (Phase 8) runs sequentially as a single agent — invoke each pipeline skill inline, one at a time per skill group.
- **No transcript access (for `--from-retro`):** Prompt the user to paste the `/retro` output instead; document the limitation in the triage-doc header.
- **No Playwright / MCP:** Not needed by this skill.
- **`.pmos/settings.yaml` missing:** Run `_shared/pipeline-setup.md` Section A first-run setup before resolving the triage-doc path. Do not silently default a path.

## Track Progress

This skill has multiple phases. Create one task per phase using your agent's task-tracking tool (e.g., `TaskCreate` in Claude Code, `TodoWrite` equivalent in older harnesses). Mark each task in-progress when you start it and completed as soon as it finishes — do not batch completions.

## Phase 0: Pipeline setup + Load Learnings

Inline `_shared/pipeline-setup.md` (relative to the skills directory) to:

1. Read `.pmos/settings.yaml`. If missing → run Section A first-run setup before proceeding.
2. Set `{docs_path}` from `settings.docs_path`.
<!-- defer-only: ambiguous -->
3. Resolve `{feature_folder}` for this run: `{docs_path}/features/{YYYY-MM-DD}_update-skills-<slug>/`. The `<slug>` is derived from the first parsed-skill name plus a short topic (e.g., `findings-protocol`); ask the user via `AskUserQuestion` if ambiguous (or a free-form prompt in environments without an interactive prompt tool, recording the answer in the triage-doc header).
4. Read `~/.pmos/learnings.md` if present; note any entries under `## /update-skills` and factor them into your approach. Skill body wins on conflict; surface conflicts to user before applying.

Workstream is NOT loaded. This is an infra-level skill.

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

## Phase 1: Resolve input

Determine input type from the slash arg:

<!-- defer-only: ambiguous -->
1. **No arg** → `AskUserQuestion`: "Paste the feedback or `/retro` output." (Or a free-form prompt in environments without an interactive prompt tool.) If user declines, exit no-op.
2. **`--from-retro`** → locate the most-recent `/retro` output in the session transcript (per `/retro` Phase 1 logic: `~/.claude/projects/<slug>/*.jsonl`). If multiple `/retro` runs exist, default to most-recent and record which run in the triage-doc header. If no transcript → fall back to interactive paste.
3. **Path** → if the file's first 200 bytes match the triage-doc header marker (`<!-- pmos:update-skills-triage v=1 -->`), enter **resume mode** (skip to Phase 8 using the existing pipeline-status table to find the next `pending` row). Otherwise treat as a feedback file.
4. **Inline text** → use the arg verbatim.
5. **`--skill <name>`** → record as a filter applied during Phase 2.

## Phase 2: Parse findings

Extract `(skill, severity, finding, evidence, proposed-fix)` tuples.

- **`/retro` paste-back**: deterministic parse via `reference/retro-parser.md`. The parser is the single source of truth — inline its regex/extractor verbatim, do not reimplement.
<!-- defer-only: ambiguous -->
- **Raw free-form text**: LLM extraction. Scan for `/<skill-name>` and `pmos-toolkit:<skill-name>` references to attribute findings to skills. If no skill is named, `AskUserQuestion`: "Which skill(s) does this feedback apply to?" with the parsed pmos-toolkit skill list as options + Other.
- **Severity**: take from `[blocker]`/`[friction]`/`[nit]` tags when present. For raw text without tags, default to `[friction]` and surface "severity inferred — confirm?" inline. Never infer severity from tone alone.
- **Filter**: if `--skill <name>` was passed, drop tuples for other skills (log dropped count).
- **Out-of-scope**: tuples whose skill is not in `plugins/pmos-toolkit/skills/` go to a separate out-of-scope list. Show a one-time warning before Phase 6.

**If 0 findings parsed:** print `No actionable findings detected in <input>. Exiting.` and exit. Do not write an empty triage doc.

## Phase 3: Read affected skill sources

For each unique affected skill:

1. Read `plugins/pmos-toolkit/skills/<name>/SKILL.md`.
2. For any reference file cited by name in the feedback (e.g., `reference/eval-rubric.md`), read that file too. Do NOT bulk-read the entire `reference/` directory — large skills (e.g., `/spec`, `/artifact`) will blow context.

If the user warned of out-of-scope skills in Phase 2, surface that warning now (before triage starts) so they can choose to abort.

## Phase 4: Critique each finding

For each finding, produce four critique fields:

1. **Already handled?** — does the cited skill source already implement this? If yes, mark `already-handled` and recommend `Skip`.
2. **Classification** — one of: `bug`, `UX-friction`, `new-capability`, `nit`.
3. **Recommendation** — `Apply` / `Modify` / `Skip` / `Defer`, with one-line rationale.
4. **Scope hint** — small / medium / large, used to seed the auto-tier in Phase 7.

These four fields go into the triage doc's critique table.

## Phase 5: Write triage doc (draft)

Resolve the path from Phase 0 and write the triage doc using `reference/triage-doc-template.md` as the skeleton. Sections:

- Header marker (so Phase 1 resume detection works): `<!-- pmos:update-skills-triage v=1 -->`
- Source note (raw / file / `--from-retro` with which retro run, when applicable)
- Out-of-scope skill mentions
- Findings table (parsed tuples)
- Critique table (Phase 4 output)
- Disposition log (filled in Phase 6)
- Approved-changes-by-skill (filled in Phase 6)
- Per-skill tier table (filled in Phase 7)
- Pipeline-status table per skill: `skill | phase | status | artifact path | timestamp` (filled in Phase 8)

## Phase 6: Triage approval (Findings Presentation Protocol)

Present findings via the interactive prompt tool. **Do NOT dump prose and wait for free-form reply.**

1. **One question per finding**, batched ≤4 per call:
   - `question`: severity + skill + one-sentence finding + recommended disposition (e.g., `[friction] /spec: prose-dump review violates Findings Protocol. Recommend: Apply with proposed fix from feedback.`)
   - `options`: **Apply as recommended** / **Modify** / **Skip (drop with reason)** / **Defer to backlog**
2. **Findings cap**: if >20 findings parsed, prompt once whether to filter to blockers + friction only.
3. **Modify disposition** → sequential second interactive-prompt call (or free-form prompt) capturing the modified finding text.
4. **Skip** → ask the user the reason via a sequential follow-up interactive-prompt call (or free-form prompt); record in disposition log.
5. **Defer** → log to triage doc; no /backlog write unless user explicitly says so.
6. After all batches, write the approved-changes-by-skill section in the triage doc.

**Platform fallback**: emit a numbered findings table with a `your-disposition` column; user replies with `1=Apply, 2=Skip(reason), ...`.

## Phase 7: Group + auto-tier per skill

1. **Group** approved changes by skill. **Cross-cutting findings** (one finding affecting N skills) fan into N per-skill entries; the parent finding is referenced by id in the triage doc.
2. **Auto-tier each group** using `/create-skill` rules — base on aggregated scope:
   - Tier 1 if all changes are `nit`/small bug fixes; no new phases; no new reference/ files.
   - Tier 2 if any change adds/modifies a phase or reference file.
   - Tier 3 if any change touches eval rubrics, pipeline integration, or multi-source behavior.
<!-- defer-only: ambiguous -->
3. **Surface tier per skill** via `AskUserQuestion`:
   - `question`: skill + summary of approved changes + recommended tier with one-line rationale
   - `options`: **Recommended tier (Tier N)** / **Tier above** / **Tier below** / **Skip this skill**
4. Write the per-skill tier table in the triage doc.

## Phase 8: Pipeline dispatch (sequential per skill)

For each skill group, in order, invoke the pipeline:

1. **`/requirements`** — hand off a seed brief built from `reference/seed-requirements-template.md`. The seed must include: verbatim approved findings, current SKILL.md excerpts (the sections to change), proposed direction. Do NOT pass "see the triage doc" — the brief is self-contained.
2. **`/spec`** (Tier 2+).
3. **`/grill`** (Tier 3 only). **If grill changes the approved-finding set** (any added or dropped approved finding), **return to Phase 6** for re-approval of the changed subset before continuing.
4. **`/plan`** (Tier 2+).
5. **`/execute`**.
6. **`/verify`** — non-skippable per skill, regardless of how clean `/execute` looked.

After all skill groups have passed `/verify`, run **`/complete-dev`** ONCE for the batch (not per-skill — version bump, changelog, deploy, and push are once-per-batch operations). If any skill failed `/verify`, prompt the user before invoking `/complete-dev` so failed skills can be excluded or retried first.

After **each phase**, `Edit` the pipeline-status table row for this skill: `phase | status (pending|in-progress|completed|failed) | artifact path | timestamp`. Add a final batch-level row for `/complete-dev`.

<!-- defer-only: ambiguous -->
**On any failure**, halt and `AskUserQuestion`:
- **Continue to next skill** — log failure in triage doc, move on.
- **Retry this phase** — re-invoke the failed pipeline skill.
- **Abort all remaining** — stop, leave triage doc as-is for later resume.

**Resume mode** (Phase 1 detected an existing triage doc): scan the pipeline-status table for the next row with status `pending` or `failed`; restart from there. Skip Phases 2–7.

## Phase 9: Final summary

Print:

```
Processed N findings across M skills.
Approved: K. Skipped: S. Deferred: D. Out-of-scope: O.
Pipeline complete for: <skill list>. Failed: <skill list>. Pending: <skill list>.
Triage doc: {feature_folder}/00_triage.md
Per-skill feature folders: <list of paths>
```

## Phase 10: Capture Learnings

**This skill is not complete until the learnings-capture process has run.** Read and follow `learnings/learnings-capture.md` (relative to the skills directory) now. Reflect on whether this session surfaced anything worth capturing about `/update-skills` itself — parser misses, critique false-positives, tier auto-pick mistakes, places the user had to override the recommendation. Proposing zero learnings is a valid outcome; the gate is that the reflection happens, not that an entry is written.

## Release prerequisites

(Surfaced here per Convention 13 so the next `/complete-dev` is not surprising.)

- README row added under **Pipeline enhancers**; standalone line updated.
- Next `/complete-dev` will require a **minor** version bump in BOTH `plugins/pmos-toolkit/.claude-plugin/plugin.json` and `plugins/pmos-toolkit/.codex-plugin/plugin.json` (versions must stay in sync — pre-push hook enforces).
- No new schemas, no learnings-file scaffolding, no plugin-manifest array changes required.

## Anti-Patterns

1. **Treating raw feedback as already-structured.** Skipping parse + critique and dumping every sentence into `/requirements` produces noise the user has to triage downstream where it's expensive.
2. **Self-approving the keep/drop set.** Phase 6 must use the interactive prompt tool (or table fallback). Auto-applying every `[blocker]` finding without explicit user sign-off violates the contract.
3. **Skipping the "already handled" check.** Proposing a change that's literally in the current SKILL.md wastes a pipeline run. Phase 4 must read skill source for every affected skill.
4. **Cross-skill spec contamination.** Bundling `/spec` changes and `/plan` changes into one `/requirements` doc because they "feel related". Group strictly by skill (Phase 7); only the user can opt to merge.
5. **Running the pipeline on Skip/Defer items.** Once dropped in Phase 6, a finding never reaches Phase 8. The triage doc's approved-changes section is the single source of truth handed to `/requirements`.
6. **Vague seed briefs.** The seed handed to `/requirements` must include verbatim findings, current-skill excerpts, and a proposed direction — not "see the triage doc".
7. **Inferring severity from tone.** A user calling something "annoying" is not automatically `[blocker]`. Severity comes from the parsed input or is explicitly asked, never guessed.
8. **Continuing the pipeline after `/grill` rewrites the approved-finding set.** Any added or dropped finding triggers re-approval at Phase 6 for the changed subset before `/plan`.
9. **Skipping `/verify` because `/execute` looked clean.** `/verify` is part of the per-skill pipeline contract; no opt-out.
10. **Hard-coding the triage-doc path.** Always resolve via `_shared/pipeline-setup.md`. Bypassing the resolver breaks repos with custom `docs_path` and fresh repos that need first-run setup.
11. **Bulk-reading every reference file for every affected skill.** Read SKILL.md plus only the reference files cited by name in the feedback. Bulk reads of large reference sets blow context.
