# Skill Spec Template

Used by `/create-skill` Phase 4 (Tier 2+). Write the spec to:

```
~/.pmos/skill-specs/<skill-name>/YYYY-MM-DD_<slug>.md
```

Where `<slug>` is a short kebab-case label for the spec iteration (e.g., `initial`, `post-grill`, `post-review`). Multiple files can accumulate over a skill's lifetime.

The spec is the input to Phase 6 (implement) and, at Tier 3, to Phase 5 (`/grill` adversarial review). It is NOT the SKILL.md — it is the design contract that produces the SKILL.md.

---

## Spec structure

```markdown
# Spec: /<skill-name>

Tier: <1 | 2 | 3>
Generated: YYYY-MM-DD
Status: <draft | grilled | approved | implemented>

## 1. One-line description

<What the skill does, who it's for, when it triggers — will become the frontmatter `description` field. Must include natural trigger phrases.>

## 2. Argument hint

`<what the skill expects as the slash argument, including flags>`

## 3. Source / inputs

What does the skill consume?

- Input type(s) (URL / file path / free-form text / workstream / artifact from another skill)
- Where it's resolved from (CLI arg, AskUserQuestion, workstream context, repo state)
- What "no input" / partial input means (default behavior or refusal)

## 4. Output

What does the skill produce?

- File(s) written, with paths
- In-conversation deliverables (reports, summaries, structured asks)
- Side effects (workstream enrichment, learnings capture, git state)
- One sentence on the "happy path" output the user sees at the end

## 5. Phases

Numbered phase list. For each phase: name, one-sentence purpose, gate (none / user approval / refinement loop / external skill invocation).

| # | Phase | Purpose | Gate |
|---|-------|---------|------|
| 0 | Load workstream + learnings | Pull context | none |
| 1 | … | … | AskUserQuestion |
| N | Capture Learnings | Reflection | terminal |

Tier 1 skills may collapse to 1-2 phases; Tier 3 skills typically have 6-10.

## 6. Tier classification rationale

Cite the auto-tier signals that justify the chosen tier (number of phases, has eval rubric, has assets, workstream-aware, multi-source). If user overrode via `--tier`, note that.

## 7. Asset inventory

Files to ship under `assets/`. For each: filename, purpose, language/format, who invokes it (skill phase X, user, external).

| File | Purpose | Format | Invoked by |
|------|---------|--------|------------|
| capture.mjs | Take screenshots | Node + Playwright | Phase 3 via Bash |

Empty table is valid — many skills have no assets.

## 8. Reference inventory

Files under `reference/` — content the skill reads into context at runtime (eval rubrics, prompts, schemas, templates).

| File | Purpose | Loaded by phase |
|------|---------|-----------------|
| eval.md | Heuristic rubric | Phase 4 |

## 9. Pipeline / workstream integration

- Pipeline position: `standalone | optional enhancer | bridge | core stage`. If pipeline-fit, draw the diagram with `(this skill)` marked.
- Workstream awareness: does Phase 0 load workstream? If yes, list the enrichment signals (Phase N: Workstream Enrichment).
- Cross-skill dependencies: does this skill invoke or depend on output from other skills? Name them.

## 10. Findings Presentation Protocol applicability

If the skill has any review/refinement loop, specify:

- Which phase(s) present findings
- Disposition options (Apply/Modify/Skip/Defer or domain equivalents)
- Findings cap per session
- Platform fallback (numbered table) when AskUserQuestion is unavailable

If no review loops, state "N/A".

## 11. Platform fallbacks

For each platform-specific tool the skill uses, note the fallback:

- AskUserQuestion → ?
- Subagents → ?
- Playwright / MCP → ?
- TaskCreate / TodoWrite → ?

## 12. Anti-patterns

Concrete failure modes the implementer should call out in the SKILL.md `## Anti-patterns` section. Aim for 4-8.

## 13. Release prerequisites

- README section the new row goes under (Pipeline / Enhancers / Artifacts & docs / Tracking & context / Utilities)
- Standalone-line update needed? (yes/no)
- Version bump type expected at next /push (patch / minor / major)
- Any one-time bootstrap steps (e.g., schema registration, plugin.json arrays, learnings file scaffold)

## 14. Open questions

Anything genuinely unresolved at spec-write time. These become inputs to /grill at Tier 3, or are flagged for the user to resolve before Phase 6 at Tier 2.

---

## Spec lifecycle

1. **Draft** — Phase 4 produces the first version. Status: `draft`.
2. **Grilled** (Tier 3 only) — Phase 5 runs `/grill` against the spec; dispositions are applied; spec is rewritten. Status: `grilled`. The pre-grill version is preserved as `YYYY-MM-DD_<slug>_pre-grill.md` for diff visibility.
3. **Approved** — User signs off via AskUserQuestion. Status: `approved`. Phase 6 cannot start until status is `approved`.
4. **Implemented** — After Phase 6 completes successfully. Status: `implemented`. The spec stays on disk as documentation; future skill changes can be specced as `YYYY-MM-DD_<slug>_v2.md`.
```
