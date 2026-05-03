---
name: grill
description: Adversarially interview the user about a plan, spec, requirements doc, ADR, design, or code change to surface unresolved decisions and shaky assumptions. Walks the decision tree branch by branch — one question at a time, each with a recommended answer. Use when the user says "grill me", "stress-test this plan", "poke holes in my design", "interview me about X", or wants an adversarial review before committing to a direction.
user-invocable: true
argument-hint: "[<path-to-artifact-or-topic>] [--depth=quick|standard|deep] [--save|--no-save]"
---

# Grill

Adversarial interrogation of a plan, design, or artifact. Walks the decision tree one branch at a time, asks one question per turn, and proposes a recommended answer for each. The goal is to expose unstated assumptions, unresolved branches, and weak rationale **before** the user commits to a direction.

This is **orthogonal to the pipeline** — not a stage. Use it on any artifact at any time: a half-formed idea, a `01_requirements.md`, a draft `02_spec.md`, an ADR, a code diff, a Slack proposal.

**Announce at start:** "Using the grill skill to stress-test {artifact}."

## Platform Adaptation

- **No `AskUserQuestion`:** fall back to numbered-choice plain-text per `_shared/interactive-prompts.md`. One question per turn — never batch.
- **No subagents:** skip the optional codebase-exploration subagent and grep directly.

---

## Phase 0: Intake & Scope

1. **Resolve the target.**
   - If argument is a file path → read it.
   - If argument is a URL or topic name → ask the user to paste the content or point to a file.
   - If no argument → use `AskUserQuestion`: "What are we grilling? (a) most recent artifact in this conversation, (b) a file path, (c) a topic I'll describe inline."

2. **Pick depth.** Default `standard`. Use `AskUserQuestion`:
   | Depth | Branches walked | Approx questions |
   |---|---|---|
   | quick | top-level decisions only | 3–5 |
   | standard | top-level + immediate sub-branches | 6–12 |
   | deep | full decision tree to leaves | 15+ (stop on user's call) |

3. **Summarize what you read** in 3–5 bullets so the user can confirm you've understood the artifact correctly. If the summary is wrong, fix it before grilling — interrogating a misread is wasted turns.

---

## Phase 1: Build the Decision Tree

Before asking anything, internally enumerate the decisions embedded in the artifact. For each one, classify:

| Class | Action |
|---|---|
| **Stated and justified** | Skip. Don't grill what's already defended. |
| **Stated but unjustified** | Grill — "Why this and not X?" |
| **Implied / unstated** | Grill — "I noticed you assume Y; is that intentional?" |
| **Missing entirely** | Grill — "I don't see how this handles Z." |
| **Answerable from code/docs** | Do NOT ask the user — explore the codebase, then report findings. |

Order branches by leverage: questions whose answers gate other questions go first. Don't grill leaves before the root.

---

## Phase 2: Grill Loop

For each branch, in order:

1. **Try to answer from the codebase first.** If the question is "what does the existing auth middleware do?", grep — don't ask.

2. **Compose one `AskUserQuestion` call per question.** Shape:
   - `question`: the challenge in one sentence. Be sharp, not hedged. "Why are you handling retries client-side instead of in the gateway?" not "Have you thought about retries?"
   - `options` (up to 4):
     - **[Recommended]** `<your proposed answer>` — what you'd argue for, with the reasoning compressed into the option label
     - 1–2 plausible alternatives (with their tradeoff in the label)
     - **Elaborate** — user types a free-form answer next turn
     - **Skip / not relevant** — user judges the question doesn't apply

3. **One question per turn.** Wait for the answer. Do NOT batch.

4. **Branch based on the answer:**
   - If the answer opens a sub-branch, queue it and ask next.
   - If the answer closes the branch, mark it resolved and move to the next sibling.
   - If the answer reveals a gap not in your tree, insert it and re-prioritize.

5. **Track findings** in a running internal table:
   | # | Branch | Question | Disposition | New gap? |
   |---|---|---|---|---|

6. **Stop conditions** (any one):
   - All branches at the chosen depth are resolved.
   - User says "stop" / "enough" / "wrap it up".
   - You've hit the depth's question budget and the next branch is low-leverage.

---

## Phase 3: Grill Report

Emit a compact report at the end. The report always goes in the chat. Persisting to a file is **opt-in** (see Phase 3b).

```markdown
# Grill Report — <artifact>

**Depth:** <quick|standard|deep>  •  **Questions asked:** N

## Resolved
- [decision] → [answer + 1-line rationale]

## Open / Deferred
- [question] — needs [info / stakeholder] before [event]

## Gaps surfaced
- [thing the artifact doesn't address] — recommend [action]

## Recommended next step
- [e.g., "Update §3 of spec to capture the retry decision" / "Run /simulate-spec to pressure-test the revised design"]
```

If the artifact is a pipeline doc (`01_requirements.md`, `02_spec.md`, `03_plan.md`), suggest the right follow-up skill in **Recommended next step** — but do not auto-invoke it.

---

## Phase 3b: Optional Save

After emitting the chat report, offer to persist it.

1. **Skip the prompt** if the user passed `--no-save` (do nothing) or `--save` (save without asking).

2. **Resolve the save path** in this order:
   - Target is inside a pipeline feature dir (matches `.../NN_<slug>/` where `NN` is two digits) → `<feature_dir>/grills/{YYYY-MM-DD}_{slug}.md`
   - Target is a repo file outside the pipeline → `<repo_root>/.pmos/grills/{YYYY-MM-DD}_{slug}.md`
   - Target is an inline topic or has no file → `~/.pmos/grills/{YYYY-MM-DD}_{slug}.md`

3. **Build the slug** from the artifact filename (without extension) or, for inline topics, the first 4–5 meaningful words of the topic. Lowercase, hyphenated, ASCII only. If a file already exists at the resolved path, append `-2`, `-3`, … until unique.

4. **Prompt** (unless `--save`/`--no-save` was passed): "Save grill report to `<resolved_path>`? [Y/n]" — single yes/no question per `_shared/interactive-prompts.md`.

5. **On save:** create parent directories as needed, write the same markdown report shown in chat, and confirm the path back to the user.

---

## Anti-Patterns (DO NOT)

- Do NOT batch questions. One `AskUserQuestion` call = one question.
- Do NOT ask questions answerable from the codebase. Grep first.
- Do NOT hedge the recommended option ("maybe consider X?"). Take a position; the user can override.
- Do NOT grill stated-and-justified decisions just to fill the quota. Stop when the leverage runs out.
- Do NOT write the Grill Report to a file silently — always show it in chat first, then offer to persist (Phase 3b).
- Do NOT segue into implementing the fixes you surface. The terminal state is the Grill Report.

---

## Phase 4: Capture Learnings

Read and follow `learnings/learnings-capture.md`. Reflect on whether this session surfaced anything worth capturing under `## /grill` — repeated friction (e.g., users overriding the Recommended option in the same way), question-tree shapes that worked well, depth-budget miscalibration. Zero learnings is a valid outcome.
