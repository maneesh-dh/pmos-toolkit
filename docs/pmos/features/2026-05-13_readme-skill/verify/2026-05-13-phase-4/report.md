# /verify --scope phase-4 — readme-skill

## Verdict
**PASS**

Combined per-task (T11 + T12 + T13) + Phase 4 boundary review. Phase 4 ran Wave 1 (T11 + T12 parallel, disjoint files: `reference/simulated-reader.md` vs. `SKILL.md`) then Wave 2 (T13 solo, touches `SKILL.md` + new test files). All three FRs in scope (FR-SR-1..6) are covered in doc + impl; the env-var-gated stub contract harness exercises the FR-SR-3 happy/hard-fail paths end-to-end.

## Deterministic evidence

**Contract harness (T13):**
```
PASS: evaluator quote substring-matches README
PASS: adopter empty friction (theater-check trigger)
PASS: contributor altered quote does NOT match (parent will hard-fail FR-SR-3)
All 3 contract assertions pass.
```
exit 0.

**Shellcheck (stub + harness):** clean (exit 0, no warnings, no info).

**Line budgets (P8):**
```
219 plugins/pmos-toolkit/skills/readme/SKILL.md             (≤480 ✓)
167 plugins/pmos-toolkit/skills/readme/reference/simulated-reader.md  (≤200 ✓)
```

**SKILL.md token coverage (T12 + T13):**
- `grep -c 'Task.*parallel\|3 concurrent\|FR-SR-3' SKILL.md` → **7** (≥1 required) ✓
- `grep -c 'skip-simulated-reader\|theater-check\|bounce-suffix' SKILL.md` → **7** (≥3 required) ✓

**simulated-reader.md token coverage (T11):**
- `grep -c 'evaluator\|adopter\|contributor'` → **8** (≥3 required) ✓
- `grep -c '≥40-char\|substring-grep'` → **4** (≥1 required) ✓

## T11 spec-compliance (FR-SR-1, FR-SR-2, FR-SR-3, FR-SR-4)

`reference/simulated-reader.md` (167 lines, plain MD) authored against spec §7.7 + §9.2.1. ToC in first 15 lines (anchor links to §1.1/1.2/1.3, §2, §3, §4). §1 documents the three personas with FR-SR-2 task framing, persona-specific anti-script extending the common "you are NOT a reviewer" preamble, and 4–5 bounce triggers each. §2 carries the FR-SR-1 return-shape JSON block field-for-field from spec §9.2.1 (`persona`, `friction[].quote/.line/.severity/.message`), the FR-SR-3 ≥40-char + substring-grep contract with the verbatim hard-fail message, and the FR-SR-4 severity vocabulary + dedupe rule. §4 cites `grill/SKILL.md` § Input Contract and tabulates FR-50/51/52 → /readme parent actions. All 6 FR-SR IDs cited at point-of-use. No drift.

## T12 spec-compliance (FR-SR-1, FR-SR-2, FR-SR-3, D13, P3)

SKILL.md `## Implementation §2: Simulated-reader pass` documents D13 + P3 verbatim: **(a)** 3 `Task` calls in ONE assistant response (one per persona — `evaluator`/`adopter`/`contributor`), per-call body inlines the persona prompt from `reference/simulated-reader.md §1` + the un-stripped README markdown + the FR-SR-1 return-shape contract; **(b)** 120s per-call timeout with NFR-4 graceful degradation (`simulated-reader: persona <name> timed out (120s); skipping`); **(c)** FR-SR-3 hard-gate triple (quote-length ≥40, substring-grep against un-stripped README, persona-label match) with the spec-mandated hard-fail message; **(d)** FR-SR-4 merge + dedupe (tag `source: simulated-reader/<persona>`, dedupe when `abs(Δline)≤2` ∧ same section heading via `reference/section-schema.yaml`, ties favour deterministic rubric.sh entry). One-level-deep pointer to `reference/simulated-reader.md` per skill-patterns.md §C. Sequential dispatch explicitly forbidden ("Sequential dispatch is forbidden (P3)").

## T13 spec-compliance (FR-SR-5, FR-SR-6, P9)

SKILL.md §3 (22 lines, between §2 and `## Anti-Patterns`) lands the **FR-SR-5 theater-check** (empty `friction[]` ∧ rubric ≥3 → single-shot re-dispatch with bounce-suffix prompt, single-retry cap, log line `simulated-reader: theater-check re-dispatched persona <P> (rubric≥3, empty friction)`), the **FR-SR-6 `--skip-simulated-reader` flag** (mutex with `--selftest`, emits `simulated-reader: skipped via --skip-simulated-reader`, aggregator pass receives ONLY rubric.sh stream), and the **P9 `READMER_PERSONA_STUB` env-var stub contract** for testing. Stub at `tests/mocks/simulated_reader_stub.sh` (~40 lines, `set -euo pipefail`) emits canned JSON for the three personas: evaluator (valid ≥40-char substring of the ripgrep T8 fixture), adopter (empty `friction[]` to trigger theater-check), contributor (1-char casing slip `Ripgrep` vs `ripgrep` to exercise FR-SR-3 hard-fail). Contract harness `tests/integration/simulated_reader_contract.sh` runs three assertions: (1) evaluator quote substring-matches README, (2) adopter empty friction parseable, (3) contributor altered quote does NOT match. 3/3 PASS. Fixture deviation (acme-cli spec example → ripgrep real T8 fixture) declared in task log; preserves spec intent (verbatim substring vs 1-char slip).

## Code quality

- **SKILL.md** — 219 / 480 lines; readability clean; no broken cross-refs; the four T1-authored `### Subsection N — TBD` placeholders survive untouched above §2 (deliberate — T14+ will fill); `<!-- pipeline-setup-block -->` and `<!-- non-interactive-block -->` regions unchanged (8 markers in HEAD = 8 markers at T7 commit `66efe39`).
- **Stub Bash** — `set -euo pipefail`, single arg switch on persona name, heredoc-emitted JSON; shellcheck-clean.
- **Contract harness** — `set -euo pipefail`, locates stub via `$BASH_SOURCE` dirname (no cwd assumption), three assertions verify the three contract conditions named in spec §7.7 (substring-match positive, empty-friction parseable, altered-quote rejected); shellcheck-clean.

## P11 append-only invariant

`git diff 66efe39 d718646 -- SKILL.md | grep '^-' | grep -v '^---'` → **0 removed lines** (T7 → T12). `git diff d718646 3bf8620 -- SKILL.md | grep '^-' | grep -v '^---'` → **0 removed lines** (T12 → T13). §1 (Single-file audit flow) byte-identical to T3 introduction; §2 inserted between §1 and `## Anti-Patterns` (T12); §3 inserted between §2 and `## Anti-Patterns` (T13). Inlined `<!-- pipeline-setup-block -->` and `<!-- non-interactive-block -->` regions byte-identical to T1 authoring (8 markers preserved). P11 fully satisfied.

## Phase 4 done-when

Plan rationale: "Demoable after T13: invoking /readme on a fixture README dispatches 3 Tasks in parallel, gets persona-friction JSON back, validates quotes, merges into rubric stream."

- **3 Tasks in parallel** — PARTIAL (by design per P9). SKILL.md §2 step 1 documents the parallel-dispatch protocol verbatim; live `Task`-tool dispatch is NOT exercised in this phase (no harness can fake the Claude Code Task tool). The env-var-gated stub path (`READMER_PERSONA_STUB=1`) is the contract-test surface; live wiring is verified at T22+ SKILL.md final integration.
- **Persona-friction JSON back** — PASS. Stub emits the FR-SR-1 return shape; contract harness reads + parses successfully.
- **Validates quotes** — PASS. Contract assertion 1 (substring match) + assertion 3 (1-char slip rejected) cover the FR-SR-3 happy + hard-fail paths.
- **Merges into rubric stream** — PARTIAL (documented, not exercised). §2 step 4 documents merge + dedupe; end-to-end merge is exercised only after T17+ aggregator lands.

## Coverage gaps / residuals

- **[phase-4-r1]** Live Task-tool parallel dispatch unexercised — by design per P9; verified via env-var stub. Closed-out at T22+ when SKILL.md final integration lands.
- **[phase-4-r2]** FR-SR-5 theater-check re-dispatch has stub-level coverage (empty-friction trigger fixture) but no end-to-end re-dispatch test — by design; re-dispatch is a Task-tool call, same constraint as r1.
- **[phase-4-r3]** FR-SR-4 dedupe rule documented in §2 step 4 but only exercised end-to-end once T17+ aggregator + section-schema lookup wire together.

No new blocking residuals. Phase 3's 4 carried residuals unaffected by this phase.

## Recommendation

**PROCEED_TO_PHASE_5** — T14-T16 scaffold mode + repo-miner.
