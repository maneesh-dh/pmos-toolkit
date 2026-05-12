---
task_number: 11
task_name: "Add the Phase 0 subcommand dispatch + mode resolution to feature-sdlc/SKILL.md"
status: done
started_at: 2026-05-12T00:00:00Z
completed_at: 2026-05-12T00:00:00Z
files_touched:
  - plugins/pmos-toolkit/skills/feature-sdlc/SKILL.md
tdd: "no — prose; verification is grep"
---

## What changed

`plugins/pmos-toolkit/skills/feature-sdlc/SKILL.md`:

- **`### Phase 0 Subcommand Dispatch`** rewritten to cover FR-01/02/03/04/05 (was FR-L01 / `list`-only):
  - FR-02 token-1 disambiguation rule (token 1 is the subcommand selector only when it's exactly `skill`/`list` AND sole-token / next-token-is-a-known-flag / remainder-is-one-quoted-arg; otherwise it's the first word of a feature seed; never infer mode from seed text).
  - Dispatch table: `--resume` → mode from `state.yaml` (+ `subcommand ignored on --resume; mode read from state.yaml` warn if a subcommand token is also present); `list` → short-circuit (unchanged); `skill` with no description → `usage: /feature-sdlc skill <description> | /feature-sdlc skill --from-feedback <text|path|--from-retro>` exit 64 (FR-03); `skill --from-feedback <source>` → `skill-feedback` (`--from-retro` resolves newest /retro artifact; none → `no /retro artifact found; pass feedback text or a file path` exit 64; neither source nor `--from-retro` → the FR-03 usage error) (FR-04); `skill <description>` → `skill-new`; bare → `feature`.
  - NFR-07 `pipeline_mode: <m> (source: cli|state)` chat log line on Phase 0 entry, alongside the existing `mode: …` line.
  - Explicit note that `pipeline_mode` is independent of the `mode ∈ {interactive,non-interactive}` resolution in the non-interactive block.
- **`### Tier resolution`** precedence list: inserted the Phase-0d (`/skill-tier-resolve`) matrix result as source #2 (skill modes only; runs before `/requirements`; `--tier N` still overrides, logging an E19 divergence note).

## Preserve regions — untouched (verified)

- The `<!-- non-interactive-block:start --> … :end -->` region (incl. the awk extractor) — `git diff` shows no hunks inside it.
- The `### \`list\` logic` subsection (lines unchanged).

## Verification

- `grep -c 'skill-new\|skill-feedback\|pipeline_mode' SKILL.md` → 8 (hits).
- `grep -ci 'Token 1 of the argument' SKILL.md` → 1 (FR-02 rule present).
- `grep -cF 'usage: /feature-sdlc skill' SKILL.md` → 1; `grep -cF 'subcommand ignored on --resume' SKILL.md` → 1; `grep -cF 'no /retro artifact found' SKILL.md` → 1 (the three exit-64 / warn strings present).
- NI block byte-unchanged (no diff hunks touch it).

## Note carried to T12 / phase-3 log

`bash plugins/pmos-toolkit/tools/audit-recommended.sh plugins/pmos-toolkit/skills/feature-sdlc/SKILL.md` exits 1 with **10 unmarked AskUserQuestion call sites — but this is pre-existing**: identical (same 10 calls, by content) at HEAD `c5a4a29` AND in the released `pmos-toolkit 2.36.0` skill. Cause: feature-sdlc writes AskUserQuestion calls as `` `AskUserQuestion`: `` followed by a blank line then a fenced ` ``` question:…options:… ``` ` block; the awk extractor closes the pending call on the blank line, so the `(Recommended)` inside the fence is never associated. T11 added no new AskUserQuestion calls, so the count is unchanged. T12 will (a) add the new phases' calls properly tagged AND (b) collapse the blank line before each fenced options block so the audit passes (a behaviour-preserving cleanup).
