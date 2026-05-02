---
name: retro
description: Generate a paste-back retrospective for every pmos-toolkit skill invoked in the current session. Reads the session transcript (not the skill's source) to identify what went wrong, where the user pushed back, what got skipped, and where friction surfaced — emits one markdown block per skill, severity-tagged (blocker / friction / nit), ready to paste to the skill author. Use when the user says "/retro", "what went wrong this session", "give feedback to the skill authors", "how did the pmos skills hold up", or "produce a session retro".
user-invocable: true
argument-hint: "[skill-name to filter, optional]"
---

# Retro

Produce a transcript-grounded retrospective on every `pmos-toolkit:*` skill that ran this session. The output is markdown the user can paste back to the skill author for improvement. **Critique is grounded in observed behavior — never in reading the skill's implementation.**

**Announce at start:** "Using retro to analyze pmos skill invocations in this session from the transcript."

## Platform Adaptation

These instructions use Claude Code tool names. In other environments:
- **No `AskUserQuestion`:** State your assumption, document it in the output, and proceed. The user reviews after completion.
- **No subagents:** Perform analysis sequentially as a single agent.
- **No transcript access:** If you cannot find a session transcript file, fall back to the in-context conversation and note the limitation in the output header.

## Track Progress

This skill has multiple phases. Create one task per phase using your agent's task-tracking tool (e.g., `TodoWrite` in Claude Code, equivalent in other agents). Mark each task in-progress when you start it and completed as soon as it finishes — do not batch completions.

## Phase 0: Load Learnings

Read `~/.pmos/learnings.md` if it exists. Note any entries under `## /retro` and factor them into your approach for this session.

## Phase 1: Locate the Session Transcript

The transcript is the source of truth — read it directly rather than relying on summarized in-context history (compaction may have dropped detail).

1. Resolve the project slug: replace `/` with `-` in the current working directory's absolute path (e.g., `/Users/maneeshdhabria/Desktop/Projects/agent-skills` → `-Users-maneeshdhabria-Desktop-Projects-agent-skills`).
2. List `~/.claude/projects/<slug>/*.jsonl` (sorted by mtime, newest first). The newest file is almost always the current session.
3. If multiple recent files exist or the slug doesn't resolve, ask the user via `AskUserQuestion` which file to use, or accept a path argument.
4. **Fallback:** if no jsonl is found, use the in-context conversation as the corpus and put a note at the top of the output: `> Note: transcript file not found — analysis based on in-context conversation only; older turns may have been compacted.`

## Phase 2: Detect pmos Skill Invocations

Scan the transcript for skill activations. Signals to look for:
- `<command-name>pmos-toolkit:*</command-name>` tags (slash invocation)
- `Skill` tool calls with `skill: "pmos-toolkit:*"` or `skill: "<name>"` where `<name>` matches a pmos skill
- Inline announcements like `Using <skill> to ...`
- `SkillStart` system messages naming a pmos-toolkit skill

Build an ordered list of `(skill_name, start_marker, end_marker)` tuples. The end marker is the next user turn after the skill claims completion, or the next skill invocation. If the same skill ran multiple times, treat each run as a separate entry.

If the user passed a skill name argument, filter to that skill only.

**If zero pmos skills were invoked:** print `No pmos-toolkit skills were invoked in this session.` and exit. Do not fabricate findings.

## Phase 3: Peek at Skill Frontmatter Only

For each unique skill name detected, read **only the YAML frontmatter** of `plugins/pmos-toolkit/skills/<name>/SKILL.md` (or wherever the plugin is installed). You need:
- `name`
- `description`
- `argument-hint` (if present)

**Do not read the body of the skill.** The body would bias the critique toward rationalizing the skill's design. The frontmatter gives you the skill's claimed contract — that is enough to judge "claimed X, did Y."

If frontmatter cannot be located, note the skill name and proceed without the contract reference.

## Phase 4: Analyze Each Invocation

For each invocation, scan the transcript window (start → end) for these signals:

1. **User corrections / pushback** — phrases like "no", "don't", "stop", "that's wrong", "redo", "you missed X", "why did you", or any user turn that re-directs the skill mid-flight.
2. **Repeated retries / loops** — refinement loops that hit max iterations, the agent re-running a phase, or the user having to repeat an instruction.
3. **Skipped phases or checklist items** — the skill's frontmatter promises behavior X (or the transcript shows the skill announcing phases) but the run ended without that phase appearing. Common offenders: Capture Learnings, Workstream Enrichment, self-review loops.
4. **Off-spec output shape** — output didn't match what the description promised (missing sections, wrong format, didn't write the file it claimed to write).
5. **Friction-but-worked** — skill ultimately produced acceptable output, but had awkward UX: unclear prompts, unnecessary back-and-forth, prose-dump findings instead of structured asks, surprising defaults, redundant confirmations.

For each signal you find, capture: the transcript quote (≤2 lines), what you infer happened, and a concrete proposed change to the skill.

## Phase 5: Emit Retro Blocks

For each invoked skill, emit one markdown block in this exact shape, printed inline in the conversation (no file written):

````markdown
### Retro: /<skill-name>  ·  <run-count> run(s)

**Claimed contract (from description):** <one-line paraphrase of frontmatter description>

**What happened:** <2-4 sentence neutral summary of how the run(s) actually went.>

**Findings:**

- **[blocker]** <one-line finding> — *Evidence:* "<short quote or paraphrased turn>" — *Proposed fix:* <concrete change to the skill, e.g., "add a Phase N that …", "tighten the description trigger phrase to …", "replace prose-dump review with AskUserQuestion batch …">
- **[friction]** <one-line finding> — *Evidence:* … — *Proposed fix:* …
- **[nit]** <one-line finding> — *Evidence:* … — *Proposed fix:* …

**Net assessment:** <one sentence: did the skill deliver on its claimed contract this session?>
````

Severity definitions:
- **blocker** — skill produced wrong/missing output, user had to redo it, or a promised phase was silently skipped
- **friction** — skill worked but UX was rough enough to slow the user down or require repeated guidance
- **nit** — minor polish item; safe to defer

If a skill ran multiple times with different outcomes, fold them into one block and note "Run 1: …, Run 2: …" inside *What happened*.

If a skill had **zero** signals worth reporting, still emit a one-line block: `### Retro: /<name> — clean run, no findings.` Do not invent issues.

After all blocks, print a one-paragraph **Session summary** that lists the skills with the most blockers/friction in priority order, so the user knows where to paste-back first.

## Phase 6: Capture Learnings

**This skill is not complete until the learnings-capture process has run.** Read and follow `learnings/learnings-capture.md` (relative to the skills directory) now. Reflect on whether this session surfaced anything worth capturing about `/retro` itself — e.g., transcript-resolution edge cases, signals that turned out to be false positives, output shapes that didn't paste cleanly. Proposing zero learnings is a valid outcome for a smooth session; the gate is that the reflection happens, not that an entry is written.

## Anti-Patterns

- **Reading the skill body to form the critique.** The whole point of `/retro` is a black-box, transcript-grounded view. Reading SKILL.md will bias you toward rationalizing the existing design ("ah, the skill does X because phase 3 says Y") instead of noticing that X was missing from this session. Frontmatter only.
- **Manufacturing findings to fill space.** A clean run is a valid outcome. Emit the one-line "clean run" block and move on. Pretending you found three nits per skill makes the paste-back useless.
- **Vague proposed fixes.** "Improve clarity" is not a fix. "Replace the prose dump in Phase 4 with an `AskUserQuestion` batch using Fix / Modify / Skip / Defer options" is a fix.
- **Treating every user message as a correction.** A clarifying question or a "looks good" is not pushback. Only count turns that re-direct, reject, or repeat instruction.
- **Severity inflation.** A surprising default is a *friction*, not a *blocker*. Reserve **blocker** for things that broke the skill's claimed contract.
- **Writing to disk.** Output is inline markdown for paste-back. No retro file unless the user explicitly asks.
- **Over-quoting the transcript.** Two lines max per finding. Paraphrase if needed. The author wants the diagnosis, not a transcript dump.
