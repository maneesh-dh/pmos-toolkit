---
name: readme
description: Audit, scaffold, or update READMEs against a 15-check rubric and 3-persona simulated reader. Use this whenever the user asks to "audit my README", "scaffold a README", "fix my README", "generate a README", "review my README structure", or invokes /readme. Three modes share one substrate (--audit, --scaffold, --update <commit-range>); monorepo-aware (8 workspace manifests + multi-stack); voice work delegated to /polish; never auto-commits.
user-invocable: true
argument-hint: "[--audit|--scaffold|--update <commit-range>] [--audit-all|--audit-one <pkg>|--scaffold-missing|--root-only] [--format md] [--skip-simulated-reader] [--non-interactive|--interactive] [<repo-path>]"
---

# /readme

Using /readme to audit, scaffold, or update a repository's README against a binary 15-check rubric and a 3-persona simulated reader pass — surfacing exactly which sections are missing, stale, or weak so the user (or /polish) can close the gap.

## When to Use

Three modes share a single substrate. **`--audit`** runs the rubric (and optionally the simulated-reader pass) against an existing README and reports findings without writing — use this when the user asks to "review my README" or "is my README any good". **`--scaffold`** generates a fresh README skeleton driven by repo discovery (manifests, languages, scripts, top-level structure) — use when there is no README, or when starting over. **`--update <commit-range>`** diffs the commit range, locates README-affecting changes (new commands, new env vars, new dependencies, removed features), and produces a targeted patch proposal — use when the user asks "what does the README need given these commits". All three modes are monorepo-aware: they discover workspaces across 8 manifest types (`package.json` workspaces, `pnpm-workspace.yaml`, `turbo.json`, `lerna.json`, Cargo workspaces, Go modules, Python `pyproject.toml`/`setup.py`, Maven `pom.xml`) and can target the root only, a single package, or all workspaces.

## Platform Adaptation

Claude Code is the primary target platform. The canonical non-interactive contract (inlined below) governs how this skill behaves under `--non-interactive` invocation, including on platforms where AskUserQuestion is not available — the classifier defers any question without a `(Recommended)` option and auto-picks otherwise, so the same SKILL.md works across Claude Code, Codex, and headless CI agents without per-platform branching.

## Track Progress

For multi-task runs (e.g., audit-all across a monorepo, or update-mode producing N patches), use the agent's task-tracking tool (`TaskCreate` in Claude Code; equivalent on other platforms) to surface progress to the user — one task per workspace or per patch.

## Phase 0: Pipeline setup

<!-- pipeline-setup-block:start -->
1. **Read `.pmos/settings.yaml`.**
   - If missing → you MUST invoke the `Read` tool on `_shared/pipeline-setup.md` Section A and run first-run setup before proceeding. (Skipping this Read is the most common cause of folder-naming defects.)
2. Set `{docs_path}` from `settings.docs_path`.
3. If `settings.workstream` is non-null → load `~/.pmos/workstreams/{workstream}.md` as context preamble; if frontmatter `type` is `charter` or `feature` and a `product` field exists, also load `~/.pmos/workstreams/{product}.md` read-only.
4. Resolve `{feature_folder}`:
   - If `--feature <slug>` was passed → glob `{docs_path}/features/*_<slug>/`. **Exactly 1 match required**; on 0 or 2+ → you MUST `Read` `_shared/pipeline-setup.md` Section B before acting.
   - Else if `settings.current_feature` is set AND `{docs_path}/features/{current_feature}/` exists → use it.
   - Else → ask user (offer: create new with derived slug, pick existing from folder list, or specify via Other...).
5. **Edge cases — you MUST `Read` `_shared/pipeline-setup.md` Section B before acting:** slug collision, slug validation failure, legacy date-less folder encountered, ambiguous `--feature` lookup, any folder creation.
6. Read `~/.pmos/learnings.md` if present; note entries under `## /<this-skill-name>` and factor them into approach (skill body wins on conflict; surface conflicts to user before applying).
<!-- pipeline-setup-block:end -->

## Phase 0b: Non-interactive contract

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

## Core Pattern

Three modes share a single substrate: a 15-check rubric, a workspace-discovery scanner, and a simulated-reader pass. /readme audits or scaffolds the README; voice rewriting is delegated to /polish; commits happen only via /complete-dev.

## Implementation

### Single-file audit flow

This subsection documents the procedure /readme follows when invoked at a repo with an existing `README.md` and no monorepo signal. Mode-resolver wiring for `--scaffold` and `--update <range>` lands in T14 / T18; cross-file rules for monorepo workspaces in T21. T3 owns the audit mode's tracer path end-to-end.

**1. Argv parsing — mode resolver.** Parse `--audit | --scaffold | --update <range>` as **mutually exclusive**. If two are present, refuse with platform-aware error: `Modes are mutually exclusive: --audit / --scaffold / --update <range>. Pick one.` (FR-MODE-1.) If none is passed and `README.md` exists at the resolved repo-path → default to `--audit` and log: `mode: audit (existing README detected)`. If none is passed and no `README.md` exists → default to `--scaffold` and log: `mode: scaffold (no README found)`. (FR-MODE-4.)

**2. Shell the rubric.** From SKILL.md, invoke the bundled rubric script via the portable plugin root:
```
bash "${CLAUDE_PLUGIN_ROOT}/skills/readme/scripts/rubric.sh" "${repo_path}/README.md"
```
Capture stdout (TSV: `check-id\tverdict\tcommit\tline\tmessage` per row) and exit code. Exit 0 ⇒ all pass; exit 1 ⇒ ≥1 fail; exit 2 ⇒ script error (refuse with `rubric.sh exited 2 — see stderr above. Aborting audit.`).

**3. Aggregate findings.** Tally `PASS` / `FAIL` rows from the TSV. Emit one summary line to chat: `rubric: <P> pass / <F> fail`. (FR-OUT-1.) Empty `FAIL` set ⇒ no diff preview, no AskUserQuestion: close with `README clean against rubric. Nothing to fix.` (FR-OUT-5 — no findings, no diff path.)

**4. Batched AskUserQuestion for findings.** If `<F> > 0`, group failing findings into batches of ≤4 per `AskUserQuestion` call (FR-OUT-2). Each finding presents one question with options **Apply suggested fix (Recommended)** / **Modify** / **Skip — leave as-is** / **Defer**. Question shape: `[<check-id>] <message>. Suggested fix: <one-line>.` Pass canonical (Recommended) labelling per the non-interactive contract.

**5. Atomic write.** For every Apply-or-Modify disposition, compute the proposed README content in memory, then write via temp + rename:
```
tmp="${target}.tmp.$$"
printf '%s' "${new_content}" > "${tmp}"
mv -- "${tmp}" "${target}"
```
Never write to `${target}` directly. (FR-OUT-4.) On any write error, refuse with `Atomic write failed: ${err}. Original README preserved at ${target}.` and exit 1 without modifying the file. The integration test at `tests/integration/tracer_audit.sh` exercises this contract end-to-end.

**6. Close-out.** Emit final line to chat: `README written to ${target}. Run /complete-dev to include it in the release commit.` (FR-OUT-4 — never auto-commit.)

All script paths use `${CLAUDE_PLUGIN_ROOT}/skills/readme/scripts/…` — no absolute paths. (FR-C1.)

### Subsection 2 — TBD (rubric runner)

### Subsection 3 — TBD (workspace discovery)

### Subsection 4 — TBD (simulated reader)

### Subsection 5 — TBD (atomic write)

### §2: Simulated-reader pass

This subsection documents the protocol /readme follows after `rubric.sh` returns its findings (§1 step 3) and before the AskUserQuestion batching (§1 step 4). It implements FR-SR-1 / FR-SR-2 / FR-SR-3 and decision-log entries D13 + P3. Skip entirely when `--skip-simulated-reader` is set (advisory log: `simulated-reader: skipped via --skip-simulated-reader`).

**1. Parallel Task dispatch (FR-SR-1, P3 — 3 concurrent calls).** Issue **3 `Task` tool calls in ONE assistant response** — one per persona: `evaluator`, `adopter`, `contributor`. Sequential dispatch is forbidden (P3); the parallel-scheduling requirement is what makes the 120s-per-call wall budget tractable. Each `Task` prompt body inlines, in order:
   - The persona-specific prompt block from `reference/simulated-reader.md §1` (load the file and paste the matching persona section verbatim — do not re-author).
   - The full **un-stripped** README markdown source (the user-supplied input file, byte-for-byte — required for FR-SR-3 substring grep to be sound).
   - The return-shape contract from `reference/simulated-reader.md §2` (JSON schema: `persona`, `friction[]` with `quote`/`line`/`section`/`severity`/`rationale`).
   - A per-call timeout of **120s**. On timeout, emit to chat: `simulated-reader: persona <name> timed out (120s); skipping` (NFR-4) and proceed with whichever of the other 2 personas returned in time.

**2. Substring validation on return (FR-SR-3).** For each returned JSON payload, parse `friction[]` and validate every entry against the un-stripped README source:
   - **Quote length:** if `len(quote) < 40` → hard-fail with `simulated-reader returned quote shorter than 40 chars: <quote>` and pause with the failure dialog.
   - **Substring grep:** if `quote NOT IN readme_source_text` (exact substring, byte-for-byte) → hard-fail with `simulated-reader returned quote not found in README: <prefix-30>…` and pause with the failure dialog.
   - **Persona label match:** the returned `persona` field MUST exactly equal the dispatched persona label (one of `evaluator|adopter|contributor`). Mismatch → hard-fail with `simulated-reader persona label mismatch: dispatched=<X>, returned=<Y>`.

**3. Merge into rubric stream.** Every entry from a persona that passes all FR-SR-3 checks merges into the rubric findings as a severity-tagged item — using the `severity` field from the persona return (default `friction` when omitted). Annotate each merged entry with `source: simulated-reader/<persona>` so the §1 step-3 aggregator and the §1 step-4 AskUserQuestion batcher can distinguish persona findings from `rubric.sh` checks.

**4. Dedupe near-duplicates.** After merge, dedupe across the combined findings list. Two findings are duplicates iff `abs(line_a - line_b) ≤ 2` AND they target the same section heading (use the parsed section spine from `reference/section-schema.yaml`). Keep the higher-severity entry; drop the lower. On equal severity, keep the `rubric.sh` entry over the persona entry (rubric findings are deterministic; persona findings are probabilistic).

> See [reference/simulated-reader.md](reference/simulated-reader.md) for the full persona prompts and return-shape JSON schema (per §C "references one level deep" of skill-patterns.md).

### §3: Theater-check + skip flag

**FR-SR-5 — Theater-check.** After §2's parallel dispatch + substring validation completes, examine the returns per persona:

- If persona `P` returned `friction[]` is **empty** AND the rubric.sh pass (§1) scored **≥3 findings**, treat this as suspected theater (the persona may have rubber-stamped the README to avoid friction). **Re-dispatch persona P ONCE** with the same body as §2 but appending this bounce-suffix to the prompt:
  > "You have alternatives and 90 seconds. What makes you bounce?"
- Re-dispatch is **single-shot**: even if the second-pass still returns empty, accept it as a genuine pass (a persona that bounces on nothing twice has earned the empty return).
- Re-dispatch validation: still subject to FR-SR-3 substring-grep + persona-label match. Hard-fail on miss, same dialog as §2.
- Log to chat: `simulated-reader: theater-check re-dispatched persona <P> (rubric≥3, empty first-pass)`.

**FR-SR-6 — Skip flag.** The CLI flag `--skip-simulated-reader` short-circuits §2 + §3 entirely:

- When present, skip the 3 Task dispatches; emit chat log `simulated-reader: skipped (--skip-simulated-reader)`; the aggregator pass receives ONLY rubric.sh findings.
- The flag is parsed by §1's argv loop alongside `--variant`, `--auto-apply`, etc. (mutex with `--selftest`).
- Intended use: speed up CI runs against pre-vetted READMEs; not the default user path.

**Contract-test escape (P9).** The `READMER_PERSONA_STUB` environment variable, if set to a path, REPLACES the Task-tool dispatch with a shell invocation of that path:
- The script receives `--persona=<name>` and the README path as args.
- Stdout = the per-persona JSON return (same shape as a real Task return).
- Used exclusively by `tests/mocks/simulated_reader_stub.sh` for the FR-SR-3 contract test (verifies the parent substring-grep correctly hard-fails on a deliberately altered quote).
- DO NOT use in production — the env var is unset in the default skill prompt.

## Anti-Patterns

- **Do NOT auto-commit.** /readme writes to the working tree (or stdout for audit); /complete-dev owns the release commit. Auto-committing breaks the user's ability to review the patch before it lands.
- **Do NOT skip the simulated-reader pass** except via the explicit `--skip-simulated-reader` flag (advisory, not silent). The 3-persona pass catches gaps the rubric misses — skipping it is a user choice, never a default.
- **Do NOT bypass /polish for voice work.** /readme produces structural output; voice, tone, and prose-tightening are /polish's job. If the user asks for "make this README sound better", invoke /polish on the output rather than rewriting in-skill.

## Phase N: Capture Learnings

This skill is not complete until learnings-capture has run. Read `learnings/learnings-capture.md` (relative to this skill's directory) and reflect on whether this session surfaced anything worth capturing — new rubric checks, manifest-discovery edge cases, simulated-reader persona refinements, or platform-adaptation gotchas. Append entries to `~/.pmos/learnings.md` under `## /readme` only when the lesson generalizes; skill-body wins on conflict.
