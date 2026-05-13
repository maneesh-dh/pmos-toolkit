# /verify --scope phase 1 — readme-skill

## Verdict
**PASS_WITH_RESIDUALS**

## Deterministic evidence

```
$ bash plugins/pmos-toolkit/skills/feature-sdlc/tools/skill-eval-check.sh --target claude-code plugins/pmos-toolkit/skills/readme/
a-frontmatter-present	pass	frontmatter closes at line 6
a-name-present	pass	name=readme
a-name-lowercase-hyphen	pass	name=readme
a-name-len	pass	6 chars
a-name-matches-dir	pass	name == dir (readme)
a-desc-present	pass	description present (442 chars)
a-desc-len	pass	442 chars
c-body-size	pass	170 body lines (<=500)
c-portable-paths	pass	no hard-coded absolute bundle paths
c-asset-layout	pass	no loose non-doc files in skill root
d-platform-adaptation	pass	## Platform Adaptation present
d-learnings-load-line	pass	learnings.md load line present
d-capture-learnings-phase	pass	numbered Capture Learnings phase present
d-progress-tracking	pass	## Track Progress present (3 phases)
e-scripts-dir	pass	scripts under scripts/
f-cc-user-invocable	pass	user-invocable: true + argument-hint present
EXIT_SKILL_EVAL=0

$ bash scripts/rubric.sh --selftest                        → EXIT=0, [/readme] selftest: PASS
$ bash tests/integration/tracer_audit.sh                   → EXIT=0, tracer_audit: PASS
$ shellcheck -x scripts/rubric.sh scripts/_lib.sh          → EXIT=1 (SC1091 info-level only; runtime PASS)
$ wc -l SKILL.md                                            → 176 (≤480)
$ grep -c "^name: readme$"                                  → 1
$ trigger phrases (unique)                                  → 5/5
```

## "Done when" criteria assessment

| # | Criterion | Verdict | Evidence |
|---|---|---|---|
| 1 | SKILL.md path + frontmatter + line count | PASS | canonical path, 176 lines, name=readme, user-invocable=true, argument-hint enumerates all flags, 5/5 trigger phrases |
| 2 | Canonical blocks inlined byte-for-byte | PASS | pipeline-setup-block markers L26/L35, non-interactive-block markers L41/L124 with full awk extractor (function emit_pending L77, END L115); only `${CLAUDE_PLUGIN_ROOT}` paths |
| 3 | rubric.sh `--selftest` | PASS | strong → PASS, slop → FAIL with TSV, selftest exit 0 |
| 4 | ## Implementation §1 contract | PASS | `### Single-file audit flow` L132; covers mode-resolver, rubric shell-out, aggregator, batched AskUserQuestion, atomic temp+rename, close-out; FR refs cited |
| 5 | tracer_audit.sh integration | PASS | exit 0, exercises rubric → atomic-write contract end-to-end |
| 6 | skill-eval-check.sh --target claude-code | PASS | 16/16 deterministic checks pass, exit 0 |
| 7 | P11 append-only invariant | PASS | `git diff d070a70 1bb1ee8 -- SKILL.md` empty; `git diff 1bb1ee8 3106439 -- SKILL.md` +27/-1 (removes only "Subsection 1 — TBD" placeholder); subsections 2–5 placeholders + frontmatter untouched |

## Deviation review

- **T1 (canonical block source override)** — **ACCEPT.** Loader-canonical 84-line block from verify/SKILL.md is the binding contract (24/27 pmos skills carry it identically). Marker count 3 is structural to the block.
- **T2 (hero-line awk hardened, shellcheck -x)** — **ACCEPT.** Plan's verbatim awk would have let a bullet pass as a hero line, inverting the gate. Strengthened pattern matches plan intent.
- **T3 (tracer atomic-write rewritten)** — **ACCEPT.** Plan's verbatim snippet asserted .tmp.42 absent without ever removing it. Rewrite to real temp+rename matches the FR-OUT-4 contract T3 just documented in SKILL.md.

## Residuals / open concerns

1. **shellcheck SC1091 (info).** `_lib.sh` not statically followable by shellcheck — runtime works. Track for /verify Phase 7 — either add `# shellcheck source=./_lib.sh` directive or run shellcheck from `scripts/` cwd.
2. **One rubric check wired.** Only `hero-line-presence`. Plan-intentional Phase 1 minimum; remaining 14 land Phase 2+ (T4, T7).
3. **4× `### Subsection N — TBD`** placeholders intact in `## Implementation`. P11 append-only slots reserved for T12 / T14-T16 / T18 / T19 / T21 / T22 / T24.

## Recommendation
**PROCEED_TO_PHASE_2** at next /execute --resume.
