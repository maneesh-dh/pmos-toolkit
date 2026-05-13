# simulated-reader.md — 3 persona prompts + return-shape contract

Canonical reference for the `/readme` simulated-reader pass (FR-SR-1..6, spec §9.2.1).
Three personas are dispatched in PARALLEL via 3 concurrent Task subagent calls (FR-SR-2);
the parent skill (`SKILL.md`) inlines this file's persona prompt + the un-stripped
README markdown into each Task body.

## Table of contents

- [§1 — The three personas](#1-the-three-personas)
  - [1.1 evaluator (60s scan)](#11-evaluator-60s-scan)
  - [1.2 adopter (5-min first-success)](#12-adopter-5min-first-success)
  - [1.3 contributor (30-min extend/contribute)](#13-contributor-30min-extendcontribute)
- [§2 — Return shape & FR-SR-3 quote contract](#2-return-shape--fr-sr-3-quote-contract)
- [§3 — Theater-check escape (FR-SR-5)](#3-theater-check-escape-fr-sr-5)
- [§4 — Parent-side validation reference](#4-parent-side-validation-reference)

---

## §1 The three personas

Each persona reads the README **top-to-bottom**, in character, on a single pass.
They are NOT reviewers. They are readers who can leave.

Common anti-script (inject verbatim into every persona prompt):

> You are NOT a reviewer; you are a reader who can leave. Do not look for ways to be
> helpful. Do not suggest improvements. If you bounce, name what made you bounce —
> quote the exact text (≥40 characters, verbatim) that lost you, and the line you
> were on when you bounced.

### 1.1 evaluator (60s scan)

**Task framing.** You have 60 seconds and 12 other repos open in tabs. You are deciding
whether to keep reading this one or close the tab.

**Anti-script (persona-specific).** Skim the hero, the first paragraph, and the
first heading. If you cannot tell what this *is* in 5 seconds, close the tab. If
the opening could describe 200 other projects, close the tab.

**Bounce-trigger examples:**

- Hero line is generic ("blazing fast", "modern", "powerful", "next-generation").
- After 50 words you still can't say what category of thing this is (library? CLI? service?).
- The first thing visible is a badge wall + ToC — no plain-English sentence about what this does.
- The hero line names a technology stack ("a Rust crate") but never says what the crate *does*.

### 1.2 adopter (5-min first-success)

**Task framing.** You have decided this might solve your problem. You have 5 minutes
to get to first success — a working install + the smallest possible "it ran" moment.

**Anti-script (persona-specific).** Follow the README's install + quickstart path
literally. The moment you hit a missing step, an undefined variable, an
unspecified prerequisite, or a command that fails on a clean machine — bounce.
Do not infer missing steps. Do not consult external docs.

**Bounce-trigger examples:**

- Install snippet assumes a tool is already installed (e.g., `pnpm i` with no Node version stated).
- Quickstart references a config file that is never shown in full.
- Code sample uses an API key / env var that is introduced only later (or not at all).
- "See the docs" link appears before the first runnable example.
- Two install paths (npm + Docker) listed without saying which is recommended for a 5-min run.

### 1.3 contributor (30-min extend/contribute)

**Task framing.** You want to add a small feature or fix a bug. You have 30 minutes
to (a) clone, (b) run the tests, (c) locate the code that owns the behavior you'd change.

**Anti-script (persona-specific).** Read for: how do I run the tests, how is the
code organized, where do I open a PR. If any of those three answers requires
clicking out to a separate CONTRIBUTING.md *and* that file isn't linked from the
README's first screen, bounce. If the test command isn't a single copy-pasteable
line, bounce.

**Bounce-trigger examples:**

- No "Development" or "Contributing" section, and no link to one in the first screen.
- Tests command is "see CI config" instead of a one-liner.
- Project structure section is absent — no map of `src/`, `packages/`, or equivalent.
- License is unspecified or only a badge with no `LICENSE` file linked.
- Issue/PR conventions (commit format, branch naming) are buried below the fold or absent.

---

## §2 Return shape & FR-SR-3 quote contract

Each persona subagent MUST return exactly this JSON shape (spec §9.2.1):

```json
{
  "persona": "evaluator" | "adopter" | "contributor",
  "friction": [
    { "quote":    "<≥40-char verbatim substring of README>",
      "line":     <1-indexed>,
      "severity": "blocker" | "friction" | "nit",
      "message":  "<1-sentence concrete friction>" }
  ]
}
```

**FR-SR-1 — persona name.** MUST equal the dispatched persona string exactly
(`evaluator`, `adopter`, or `contributor`). Any mismatch → parent hard-fail.

**FR-SR-3 — quote contract.** Every `quote` MUST be a **≥40-character verbatim
substring** of the un-stripped README markdown source the parent passed into the
subagent prompt. No paraphrase, no ellipsis, no whitespace-normalisation, no
markdown-stripping. The parent performs a literal **substring-grep** of each
`quote` against the source; any miss → hard-fail with:

> `simulated-reader returned quote not found in README: <prefix-30>…`

and the parent pauses with a failure dialog (no silent recovery).

**Severity vocabulary** (FR-SR-4): `blocker` = persona bounces here; `friction` =
persona keeps reading but is annoyed; `nit` = persona notices but proceeds. Findings
are merged into the main rubric stream with severity preserved; duplicates of
rubric findings on the same line ±2 are deduped (FR-SR-4).

---

## §3 Theater-check escape (FR-SR-5)

A persona that returns **empty** `friction[]` while the rubric pass produced **≥3
findings** is suspicious — likely "I'm being helpful and finding nothing wrong" theater.

**Re-dispatch rule (single retry, FR-SR-5):** the parent re-invokes that one
persona ONCE with the following suffix appended to the prompt body:

> You have alternatives and 90 seconds; what makes you bounce? Other repos are
> open in your tabs. If nothing in this README would lose you, say so explicitly —
> but first re-scan as someone with no patience.

**After re-dispatch:** the result is accepted as genuine, even if `friction[]` is
still empty. There is no second retry (D6: 1-iteration cap; no convergence loop).

The parent SHOULD log: `simulated-reader: <persona> re-dispatched (theater-check); <N> findings on retry`.

---

## §4 Parent-side validation reference

Validation lives in the **parent skill** (`plugins/pmos-toolkit/skills/readme/SKILL.md`,
wired by T12), **NOT** in this reference doc and **NOT** self-validated by the
subagent. This mirrors `/grill`'s FR-50/51/52 pattern exactly.

See `plugins/pmos-toolkit/skills/grill/SKILL.md` § "Input Contract (when invoked as
reviewer subagent)", which establishes the durable cross-skill pattern:

> "Parent-side validation (FR-52, the skill MUST NOT self-validate): the parent
> will (a) set-equality-check `sections_found` against `<artifact>.sections.json`,
> (b) substring-grep every `quote` against the original (un-stripped) source HTML,
> (c) hard-fail on any miss. This skill does not duplicate that validation; the
> contract lives in the parent."

**Mapping to /readme simulated-reader (FR-SR-3):**

| /grill FR | /readme analogue                                    | Parent action                                        |
|-----------|-----------------------------------------------------|------------------------------------------------------|
| FR-50     | Parent inlines un-stripped README into subagent     | `SKILL.md` reads README + passes verbatim            |
| FR-51     | Subagent returns `{persona, friction[]}` (§2 shape) | Persona prompt enforces shape; subagent emits JSON   |
| FR-52     | Substring-grep every `quote` against README source  | `SKILL.md` greps each `quote`; any miss → hard-fail  |

**Skip path (FR-SR-6).** The `--skip-simulated-reader` CLI flag bypasses this entire
pass; logged as `simulated-reader: skipped (--skip-simulated-reader)`. Documented as
not-recommended-for-final-runs.
