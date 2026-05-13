# /verify --scope phase-8 — readme-skill

## Verdict

**PASS_WITH_RESIDUALS** — Phase 8 Wave 1 (T23 + T24, parallel disjoint-files) landed clean. No new residuals from this phase; 11 prior residuals carried forward.

## Deterministic evidence

```
$ wc -l plugins/pmos-toolkit/skills/readme/SKILL.md
477

$ wc -l plugins/pmos-toolkit/skills/readme/scripts/voice-diff.sh
211

$ grep -cE "FR-V-[1234]" plugins/pmos-toolkit/skills/readme/SKILL.md
4

$ grep -cE "voice-diff\.sh|/polish" plugins/pmos-toolkit/skills/readme/SKILL.md
9

$ grep -nE "^### §11" plugins/pmos-toolkit/skills/readme/SKILL.md
457:### §11: Voice delegation

$ ls plugins/pmos-toolkit/skills/readme/tests/fixtures/voice/
post.md  pre.md

$ bash plugins/pmos-toolkit/skills/readme/scripts/voice-diff.sh --selftest
selftest: PASS

$ bash plugins/pmos-toolkit/skills/readme/scripts/voice-diff.sh \
    plugins/pmos-toolkit/skills/readme/tests/fixtures/voice/pre.md \
    plugins/pmos-toolkit/skills/readme/tests/fixtures/voice/post.md
{"sentence_len_delta_pct": -10.4, "jaccard_new_tokens": 0.75}

$ git diff 7bd324a 9f7e7e4 -- plugins/pmos-toolkit/skills/readme/SKILL.md | grep '^-' | grep -v '^---' | wc -l
0

$ git diff 7bd324a 7c9ecd3 -- plugins/pmos-toolkit/skills/readme/SKILL.md | grep '^-' | grep -v '^---' | wc -l
0

$ git log --oneline 7bd324a..HEAD
dc0e3ca execute(T24): log
3f267dd execute(T23): log
9f7e7e4 T24 SKILL.md §11 voice delegation (FR-V-2, FR-V-3, FR-V-4)
7c9ecd3 T23 voice-diff.sh + voice fixtures + --selftest (FR-V-1, FR-V-4)

$ ls plugins/pmos-toolkit/skills/readme/scripts/voice-diff.sh
plugins/pmos-toolkit/skills/readme/scripts/voice-diff.sh   # path resolves; selftest PASS confirms executability
```

All thresholds met: SKILL.md 477 ≤ 480; voice-diff selftest PASS; FR-V grep = 4 (≥3); voice-diff.sh|/polish grep = 9 (≥3); §11 H3 appears exactly once at line 457; both P11 diff counts = 0; JSON output parses (single-line object with numeric fields); pre.md + post.md fixtures present.

## T23 / T24 spec-compliance

**T23 — voice-diff.sh + fixtures + selftest (commits 7c9ecd3, 3f267dd).** Adds `plugins/pmos-toolkit/skills/readme/scripts/voice-diff.sh` (211 lines, Bash 3.2-safe), `tests/fixtures/voice/pre.md`, `tests/fixtures/voice/post.md`, plus `--selftest` mode. Covers FR-V-1 (sentence-length delta % + Jaccard new-tokens computed in pure POSIX/awk) and FR-V-4 (`--selftest` exits 0 with `selftest: PASS`). JSON output `{"sentence_len_delta_pct": -10.4, "jaccard_new_tokens": 0.75}` parses cleanly. Touches only `scripts/` + `tests/` — disjoint from T24's SKILL.md. Verdict: PASS.

**T24 — SKILL.md §11 voice delegation (commits 9f7e7e4, dc0e3ca).** Appends §11 "Voice delegation" at line 457 (H3, single occurrence). Covers FR-V-2 (Suggest-line contract for /polish handoff), FR-V-3 (voice-diff threshold gating), and FR-V-4 (forward-cite to `scripts/voice-diff.sh --selftest` for harness validation). Append-only on SKILL.md (P11 removed-lines = 0 across both Wave 1 commit pairs). FR-V grep count = 4 (one per FR-V-1..4 reference). Verdict: PASS.

## P11 append-only

Both diff checks confirm zero removed lines on SKILL.md across Wave 1:

- `git diff 7bd324a 9f7e7e4 -- SKILL.md | grep '^-' | grep -v '^---' | wc -l` → **0**
- `git diff 7bd324a 7c9ecd3 -- SKILL.md | grep '^-' | grep -v '^---' | wc -l` → **0** (T23 doesn't touch SKILL.md)

R9/P11 invariant holds: SKILL.md is strict append-only across the phase.

## Residuals carried forward

No new residuals added by Phase 8. All 11 prior residuals carried unchanged:

1. [phase-2-r1] rubric.yaml pass_when doc-impl drift on install-or-quickstart-presence (Download)
2. [phase-2-r2] _lib.sh header still says Bash >= 4; code is 3.2-safe
3. [phase-2-r3] badges-not-stale lacks slop fixture
4. [phase-2-r4] plugin-manifest-mentioned warn-and-skip — T21 will implement
5. [phase-1-r1] shellcheck SC1091 info on _lib.sh source — runtime PASS
6. [phase-3-r1] repo_type binary at workspace-discovery layer; full FR-WS-5 taxonomy deferred to T17+ rubric/commit-affinity
7. [phase-3-r3] Long-tail fallback triggers on no-manifest alone; plugin-marketplace signal combination at T17+
8. [phase-3-r4] MS01 overlap-secondary alias path lacks dedicated negative fixture; add 21st alias fixture in T26 dogfood
9. [phase-4-r3] FR-SR-4 dedupe rule documented in SKILL.md §2 step 4; end-to-end exercise deferred to T17+
10. [phase-5-r2] FR-MODE-2 truth-table runtime enforcement is doc-as-contract; runner script consumption lands T17+
11. [phase-7-r1] R3 forward-cite anchor-drift in SKILL.md §9 (cosmetic; T26 dogfood polish)

## Phase 8 done-when

Done-when: *Demoable: /readme voice delegation wires through end-to-end (Suggest line + voice-diff gate).*

**Status: PARTIAL by design (P9).** SKILL.md §11 documents the voice-delegation contract and forward-cites `scripts/voice-diff.sh`; voice-diff.sh runs standalone and produces the JSON metrics §11 specifies for the gate threshold. Live `/polish` invocation cannot be exercised at this phase (unmockable subagent boundary). Live end-to-end wiring is the explicit responsibility of T26 dogfood (Phase 9). This is the expected demoability profile for skill-pipeline phases where the consumer is another skill — declared as a Phase 9 dependency, not a Phase 8 gap.

## Recommendation

**PROCEED_TO_PHASE_9** — T25 integration tests + T26 dogfood.
