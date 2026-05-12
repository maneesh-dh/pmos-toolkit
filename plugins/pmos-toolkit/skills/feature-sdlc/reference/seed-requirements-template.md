# Seed requirements brief — handed to /requirements per skill (skill-feedback mode)

In `/feature-sdlc skill --from-feedback` runs, this is the brief that drives `/requirements`.
When more than one skill is in scope, `/requirements` receives **one combined doc with a
per-skill section** (one copy of the block below per skill). **Each per-skill section must
be self-contained** — do not write "see the triage doc". `/requirements` should be able to
run from this text alone. (Lifted from the now-archived `/update-skills` skill; the only
changes on move were generalising the `/update-skills`-, `/execute`-, and `/push`-specific
framing.)

```markdown
# Update brief: /<skill-name>

**Source:** /feature-sdlc skill --from-feedback — approved findings from {feature_folder}/0c_feedback_triage.html
**Triage findings approved for this skill:** {N}
**Per-skill tier:** Tier <1 | 2 | 3>  ·  **Run tier (= max across skills):** Tier <1 | 2 | 3>

## Approved findings (verbatim from triage)

### Finding 1 — [<severity>] <one-line>
- **Evidence:** <≤2 lines from input>
- **Proposed fix (verbatim or modified):** <text>
- **Classification:** <bug | UX-friction | new-capability | nit>
- **Scope hint:** <small | medium | large>

### Finding 2 — …

## Current SKILL.md excerpts (sections to change)

For each finding above, paste the relevant section(s) of the current SKILL.md so /requirements can see what is being changed. Cite by phase heading or by reference file path. Trim aggressively — the goal is enough context to design the change, not a full re-read.

### Excerpt for Finding 1
> from `plugins/pmos-toolkit/skills/<skill-name>/SKILL.md`, "## Phase X: …"
>
> <verbatim block>

### Excerpt for Finding 2
> from `plugins/pmos-toolkit/skills/<skill-name>/reference/<file>.md`, section "…"
>
> <verbatim block>

## Proposed direction (one paragraph)

In one paragraph, describe the change shape: which phases gain/lose, which conventions apply (Findings Protocol, Pipeline Awareness, etc.), what stays untouched. This is a hint to /requirements — it can override after its own brainstorm.

## Out-of-scope for this run

List anything findings touched on but the user explicitly skipped or deferred. /requirements should NOT design for these.

## Constraints

- Skill must remain backwards-compatible with its current `argument-hint`/contract unless a finding explicitly removes it.
- Reference paths resolve relative to the skill's own directory (per the host repo's layout — see `repo-shape-detection.md`; in this repo that means siblings under `plugins/pmos-toolkit/skills/`).
- Version bump at /complete-dev: <patch | minor | major>.
```

## Notes for the implementer

- Trim SKILL.md excerpts to the smallest unit that conveys the section being changed. A 200-line phase is fine; the entire SKILL.md is not.
- For findings that span multiple phases or files, include one excerpt per location, each clearly headed.
- If a finding's "proposed fix" is vague ("improve clarity"), translate it into one concrete sentence in the **Proposed direction** paragraph rather than passing the vagueness downstream.
- Tier-1 briefs can omit the "Proposed direction" paragraph if the change is a literal one-line edit; in that case the brief functions more like a one-line task description for /execute.
- When multiple skills are in scope, emit one per-skill section per skill in a single combined doc; `/requirements` designs each skill's change set in its own section and tiers the run at `max` of the per-skill tiers.
