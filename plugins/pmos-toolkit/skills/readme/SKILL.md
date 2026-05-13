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

### Subsection 1 — TBD (mode resolver)

### Subsection 2 — TBD (rubric runner)

### Subsection 3 — TBD (workspace discovery)

### Subsection 4 — TBD (simulated reader)

### Subsection 5 — TBD (atomic write)

## Anti-Patterns

- **Do NOT auto-commit.** /readme writes to the working tree (or stdout for audit); /complete-dev owns the release commit. Auto-committing breaks the user's ability to review the patch before it lands.
- **Do NOT skip the simulated-reader pass** except via the explicit `--skip-simulated-reader` flag (advisory, not silent). The 3-persona pass catches gaps the rubric misses — skipping it is a user choice, never a default.
- **Do NOT bypass /polish for voice work.** /readme produces structural output; voice, tone, and prose-tightening are /polish's job. If the user asks for "make this README sound better", invoke /polish on the output rather than rewriting in-skill.

## Phase N: Capture Learnings

This skill is not complete until learnings-capture has run. Read `learnings/learnings-capture.md` (relative to this skill's directory) and reflect on whether this session surfaced anything worth capturing — new rubric checks, manifest-discovery edge cases, simulated-reader persona refinements, or platform-adaptation gotchas. Append entries to `~/.pmos/learnings.md` under `## /readme` only when the lesson generalizes; skill-body wins on conflict.
