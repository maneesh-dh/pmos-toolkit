# Spec: /update-skills

Tier: 3
Generated: 2026-05-08
Status: draft

## 1. One-line description

Ingest feedback (raw text or `/retro` paste-back), summarize and critique proposed changes per affected pmos-toolkit skill, get user approval on the keep/drop set, then run the requirements -> spec -> plan -> execute -> verify pipeline (auto-tiered per skill) sequentially. Use when the user says "update these skills based on feedback", "process this retro output", "fix the issues from /retro", "run the pipeline on this skill feedback", or pastes retro/feedback text and wants the updates implemented end-to-end.

## 2. Argument hint

`<feedback text or path to feedback file> [--from-retro] [--skill <name>]`

- Bare invocation with no arg → prompt user to paste feedback (interactive fallback).
- Path detection: if arg resolves to a readable file, treat as file input; else treat as inline text.
- `--from-retro`: pull the most recent /retro output from this session's transcript instead of arg.
- `--skill <name>`: filter parsed feedback to one skill only.

## 3. Source / inputs

- **Raw free-form text**: any prose feedback. Parser extracts skill names by scanning for `/<skill-name>` references and `pmos-toolkit:<skill-name>` mentions; if none found, asks user which skill(s) the feedback applies to.
- **`/retro` paste-back**: structured markdown (`### Retro: /<skill-name>` blocks with `**Findings:**` lists tagged `[blocker]` / `[friction]` / `[nit]`). Parsed deterministically.
- **File path**: same content, read from disk.
- **No input**: AskUserQuestion prompt for paste; if user declines, exit with no-op.
- **Skill source context**: for each affected skill detected, read `plugins/pmos-toolkit/skills/<name>/SKILL.md` and any `reference/*` files to inform critique ("already handled" detection).
- **Scope**: pmos-toolkit skills only. If feedback names a skill outside this plugin, log it in the triage doc as out-of-scope and skip.

## 4. Output

- **Triage doc** (always written): `<docs_root>/update-skills/<YYYY-MM-DD>_update_summary_<slug>.md` where `<docs_root>` resolves to `docs/pmos/features/<YYYY-MM-DD>_update-skills-<slug>/` if `docs/pmos/features/` exists in repo, else `~/.pmos/skill-updates/`. The doc contains: parsed findings table, per-finding critique (already-handled / classification / keep-drop recommendation / one-line rationale), user disposition, final approved-changes set grouped by skill, per-skill tier assignment, and a running pipeline status section updated as runs complete.
- **Per-skill pipeline artifacts**: requirements, spec, plan, code changes, verify reports — produced by the invoked pipeline skills, not by /update-skills directly.
- **In-conversation**: triage summary, AskUserQuestion batches for keep/drop, per-skill tier confirmation, pipeline progress markers.
- **Side effects**: dropped findings logged in triage doc with reason. No /backlog enqueue, no workstream enrichment.
- **Happy path output**: "Processed N findings across M skills → K approved → pipeline complete. Triage doc: <path>. Per-skill changes: <list of feature folders>."

## 5. Phases

| #  | Phase                          | Purpose                                                                                       | Gate                          |
|----|--------------------------------|-----------------------------------------------------------------------------------------------|-------------------------------|
| 0  | Load Learnings                 | Read `~/.pmos/learnings.md` `## /update-skills` entries                                       | none                          |
| 1  | Resolve input                  | Parse arg / file / `--from-retro` / interactive paste; detect format                          | none                          |
| 2  | Parse findings                 | Extract `(skill, severity, finding, evidence, proposed-fix)` tuples; deterministic for /retro, LLM-extraction for raw | none                          |
| 3  | Read affected skill sources    | Load SKILL.md + reference/ for each affected skill                                            | none                          |
| 4  | Critique each finding          | Per finding: already-handled? classify (bug/UX/new-cap/nit), recommend Apply/Modify/Skip/Defer with one-line rationale | none                          |
| 5  | Write triage doc (draft)       | Persist parsed findings + critique to triage path                                             | none                          |
| 6  | Triage approval (Findings Protocol) | Present findings via AskUserQuestion (≤4 per call, batched), capture dispositions; Skip/Defer go to triage doc with reason | user approval per finding     |
| 7  | Group + auto-tier per skill    | Group approved changes by skill; auto-tier each group via /create-skill rules; surface tier per skill via AskUserQuestion (recommended option pre-selected) | user approval per skill       |
| 8  | Pipeline dispatch (sequential per skill) | For each skill group: invoke /requirements with seed brief, then /spec, then /grill (Tier 3 only), then /plan, then /execute, then /verify. Update triage doc pipeline-status section after each phase. | external skill invocations    |
| 9  | Final summary                  | Print processed/approved/completed counts and triage doc path                                 | none                          |
| 10 | Capture Learnings              | Reflect on session and capture entries under `## /update-skills`                              | terminal                      |

## 6. Tier classification rationale

Tier 3 selected. Auto-tier signals present:

- 11 phases (>5 threshold).
- Multi-source input (raw text, /retro paste, file).
- Pipeline integration — orchestrates the full requirements -> spec -> plan -> execute -> verify pipeline.
- Cross-skill dependencies — invokes /requirements, /spec, /grill, /plan, /execute, /verify; reads SKILL.md of arbitrary pmos skills.
- Structured findings/critique loop with per-item user dispositions (Findings Presentation Protocol applicable).

User confirmed Tier 3 explicitly via AskUserQuestion in Phase 1 of /create-skill.

## 7. Asset inventory

| File | Purpose | Format | Invoked by |
|------|---------|--------|------------|
| (none) | — | — | — |

No executable assets. All logic lives inline in SKILL.md plus a reference template.

## 8. Reference inventory

| File | Purpose | Loaded by phase |
|------|---------|-----------------|
| `reference/triage-doc-template.md` | Markdown skeleton for the triage doc (findings table, critique table, disposition log, pipeline status section) | Phase 5 |
| `reference/retro-parser.md` | Regex/parser snippet for extracting findings from `/retro` paste-back blocks; shared between Phase 2 and any audit step | Phase 2 |
| `reference/seed-requirements-template.md` | Template for the seed brief handed off to `/requirements` per skill group, listing approved findings, current SKILL.md excerpts, and proposed direction | Phase 8 |

## 9. Pipeline / workstream integration

- **Pipeline position**: standalone orchestrator that drives the existing pipeline. Diagram:

```
/retro  ->  /update-skills (this skill)  ->  /requirements -> /spec -> [/grill] -> /plan -> /execute -> /verify
                                              (per affected skill, sequential)
```

- **Workstream awareness**: NO. Phase 0 does not load workstream; skill-update work is infra-level. No Workstream Enrichment phase.
- **Cross-skill dependencies**: invokes `/requirements`, `/spec`, `/grill` (Tier 3 only), `/plan`, `/execute`, `/verify`. Optionally consumes `/retro` output. Reads but does not modify other skills' SKILL.md (modification happens through the pipeline's `/execute` phase).

## 10. Findings Presentation Protocol applicability

Phase 6 (triage approval) and Phase 7 (per-skill tier confirmation) both present findings via AskUserQuestion.

**Phase 6 protocol:**

- One question per parsed finding.
- `question`: severity tag + skill + one-sentence finding + recommended disposition (e.g., "[friction] /spec: prose-dump review violates Findings Protocol. Recommend: Apply with proposed fix from feedback.").
- `options`: **Apply as recommended** / **Modify** / **Skip (drop with reason)** / **Defer to backlog**.
- Batch ≤4 questions per AskUserQuestion call; issue multiple sequential calls when more findings.
- Free-form follow-up only when "Modify" is chosen — ask the user the new disposition inline.
- Findings cap: no hard cap; if >20 findings, prompt user once whether to filter to blockers/friction only.

**Phase 7 protocol:**

- One question per affected skill.
- `question`: skill name + summary of approved changes + recommended tier with one-line rationale.
- `options`: **Recommended tier (Tier N)** / **Tier above** / **Tier below** / **Skip this skill**.

**Platform fallback** (no AskUserQuestion): emit a numbered findings table with columns `# | severity | skill | finding | recommended | your-disposition`, ask user to reply with disposition list (`1=Apply, 2=Skip(reason), ...`). Same fallback shape for tier decisions. Do NOT silently self-fix.

## 11. Platform fallbacks

- **AskUserQuestion → numbered table**: Phase 6/7 fall back to a markdown table with a disposition column the user fills in inline. State assumption + document in triage doc when proceeding without explicit per-finding disposition.
- **Subagents → sequential single-agent execution**: Phase 8 dispatches /requirements/etc as inline skill invocations one at a time per skill group; no parallel subagent fan-out. Sequential execution is the explicit user choice.
- **Playwright / MCP → not used**: this skill needs neither.
- **TaskCreate / TodoWrite → platform-neutral phrasing**: instruction in SKILL.md says "use your agent's task-tracking tool".
- **Transcript access for `--from-retro`**: if transcript jsonl unavailable, prompt user to paste the /retro output; document the limitation in the triage-doc header.

## 12. Anti-patterns

1. **Treating raw feedback as already-structured.** Skipping the parse + critique steps and dumping every sentence into /requirements as a finding — produces noise that the user has to triage downstream instead of upstream where it's cheap.
2. **Self-approving the keep/drop set.** Phase 6 must use AskUserQuestion (or the table fallback). Auto-applying every "[blocker]" finding without user sign-off violates the contract.
3. **Skipping the "already handled" check.** Proposing a change that's literally in the current SKILL.md wastes a pipeline run. Phase 4 must read the skill source for every affected skill.
4. **Cross-skill spec contamination.** Bundling /spec changes and /plan changes into one /requirements doc because they "feel related". Group strictly by skill (Phase 7); only the user can opt to merge.
5. **Running the pipeline on Skip/Defer items.** Once dropped in Phase 6, a finding never reaches Phase 8. Verify by checking the triage doc's "approved changes" section is the source of truth handed to /requirements.
6. **Vague seed briefs to /requirements.** The seed must include verbatim findings, current-skill excerpts, and a proposed direction — not "see the triage doc". Phase 8 hands a self-contained brief per skill.
7. **Inferring severity from tone.** A user calling something "annoying" is not automatically [blocker]. Severity comes from the parsed input or is asked, not guessed.
8. **Continuing the pipeline after a Tier 3 /grill rewrites the spec materially.** If /grill changes the approved-findings scope, return to Phase 6 for re-approval before /plan.
9. **Skipping /verify because /execute looked clean.** /verify is part of the pipeline contract per skill; no opt-out.

## 13. Release prerequisites

- README row under **Pipeline enhancers** (it orchestrates pipeline runs but is not itself a pipeline stage). Description paraphrases SKILL.md description with trigger phrases. Add to "standalone — invoke them at any point" line under the pipeline-flow diagram.
- Version bump: **minor** (`X.Y+1.0`) in both `plugins/pmos-toolkit/.claude-plugin/plugin.json` and `plugins/pmos-toolkit/.codex-plugin/plugin.json`. Performed during /push; mention so user is not surprised.
- One-time bootstrap: none. No new schemas, no new directories the user must seed. Triage doc paths are created lazily.
- Reference paths to verify resolve from save location: `learnings/learnings-capture.md` and (if any used) `_shared/*` siblings under `plugins/pmos-toolkit/skills/`.

## 14. Open questions

(All to be resolved by /grill in Phase 5 of /create-skill.)

1. **Scope of /retro auto-pull from transcript** — does `--from-retro` need to disambiguate when /retro ran multiple times in one session? Default to most-recent or AskUserQuestion?
2. **Triage doc resolution** — exact precedence: does `docs/pmos/features/` always win when present, or only when current working directory is the agent-skills repo? What about when the user runs /update-skills from a different repo that also has `docs/features/`?
3. **Modify disposition payload** — when the user chooses "Modify" in Phase 6, how is the new finding text captured? Free-form follow-up question in same AskUserQuestion call (not supported), or sequential second call?
4. **Re-grilling after spec rewrite** — Anti-pattern 8 says return to Phase 6 if /grill materially changes scope. What's the threshold for "material"? Any new finding? Any dropped finding? Up to user?
5. **Multi-skill cross-cutting findings** — if a single finding affects 3 skills (e.g., "all three skills should use the new Findings Protocol"), does Phase 7 group it once with 3 skills as targets, or fan it into 3 separate per-skill changes?
6. **Sequential pipeline failure recovery** — if /verify fails for skill A, does /update-skills halt and ask, or continue to skill B and report at the end?
7. **Reading reference/ for affected skills** — Phase 3 says "read reference/ files". For skills with large reference sets (e.g., /spec, /artifact), is there a cap or selection rule?
8. **Triage doc updates after pipeline runs** — concrete schema for the "pipeline status" section: a table per skill with phase + status + artifact path, or a free-form log?
9. **Out-of-scope skills** — feedback referencing non-pmos-toolkit skills: log in triage doc and skip silently, or surface a one-time warning to the user before triage?
10. **Resuming an interrupted run** — if the user aborts after Phase 6 approval but before all pipeline runs complete, does re-invoking /update-skills with the triage doc path resume from where it stopped?
