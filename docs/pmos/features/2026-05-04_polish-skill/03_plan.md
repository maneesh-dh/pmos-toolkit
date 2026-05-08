# Plan: Implement `/polish` skill

**Spec:** `docs/specs/polish-skill.md` (v3)
**Skill location:** `skills/polish/`
**Plugin namespace:** `pmos-toolkit:polish`

## Approach

The skill is an instruction-set (markdown), not executable code. The runtime is Claude executing SKILL.md. So "implementation" means writing the SKILL.md orchestrator + supporting reference files + schemas + test fixtures.

SKILL.md must stay under 500 lines per pmos-toolkit conventions. Detailed content (rubric definitions, judge prompts, preset specs, chunking algorithm, patch contract) is extracted to `reference/`.

## Task breakdown

| # | Task | Output | Verification |
|---|------|--------|--------------|
| 1 | Skill directory scaffold | `skills/polish/` with subdirs | Directory tree exists |
| 2 | SKILL.md orchestrator (9 phases + cross-cutting) | `skills/polish/SKILL.md` | Under 500 lines; all phases present; learning hooks present; AskUserQuestion gates documented |
| 3 | JSON schema for custom checks | `skills/polish/schemas/custom-checks.schema.json` | Valid draft-07 schema; supports thresholds + checks (regex + prompt modes) |
| 4 | Rubric reference | `skills/polish/reference/rubric.md` | All 14 checks documented with mode, regex/prompt, fail condition |
| 5 | Presets reference | `skills/polish/reference/presets.md` | 4 presets with semantics + threshold defaults table |
| 6 | Voice sampling reference | `skills/polish/reference/voice-sampling.md` | Marker extraction algorithm, JSON format, short-doc handling |
| 7 | Chunking reference | `skills/polish/reference/chunking.md` | Threshold table, H1/H2 algorithm, stitch-back contract, hard ceiling |
| 8 | Patch contract reference | `skills/polish/reference/patch-contract.md` | Prompt template, voice-marker injection, PRESERVE_VOICE_CONFLICT schema, retry/abort logic |
| 9 | Findings protocol reference | `skills/polish/reference/findings-protocol.md` | Low/high-risk split, AskUserQuestion shape, defer-comment format, platform fallback |
| 10 | Test fixtures (9 docs) | `skills/polish/tests/fixtures/*.md` | Each fixture demonstrates the expected pathology |
| 11 | Test contracts | `skills/polish/tests/expected.yaml` | Per-fixture: expected failed checks, locked-zone byte ranges, word-count delta range |
| 12 | Example custom-checks file | `skills/polish/example/custom-checks.yaml` | Valid against schema; shows regex, prompt, threshold overrides |
| 13 | Final verification | — | `MEMORY.md` updated; SKILL.md line count check; spec checklist (§12) all green |

## Anti-patterns to avoid

- Don't make SKILL.md a wall of prose — keep it scannable; details go in `reference/`
- Don't hard-depend on Python or Node — the skill is markdown instructions only
- Don't invent verification commands — instruction-driven skills are verified by Claude reading and following them
- Don't write a second copy of the spec — SKILL.md is the runtime contract; spec is the design doc
