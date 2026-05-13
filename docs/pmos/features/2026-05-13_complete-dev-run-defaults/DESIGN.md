# complete-dev-run-defaults — design note

**Status:** in implementation
**Branch:** feat/complete-dev-run-defaults
**Scope:** /complete-dev only
**Tier:** 2 (enhancement)
**Date:** 2026-05-13

This is a lean design note in place of the usual requirements.html / spec.html / plan.html ceremony — per user feedback that drove this feature ("reduce questions, less friction"), running the heavyweight artifact ritual to fix the heavyweight prompt ritual was self-defeating. The /skill-eval rubric + /verify multi-agent review + /complete-dev remain as the real quality gates.

## Findings

| # | Finding | Class | Fix |
|---|---------|-------|-----|
| F1 | No "lastrun" memory — every /complete-dev re-asks the same run-shaping questions from scratch. | new-capability | Persist run-shaping answers to `.pmos/complete-dev.lastrun.yaml` (gitignored). |
| F2 | ~12 separate AskUserQuestion gates across 19 phases makes ceremony heavyweight. | ux-friction | New Phase 0.5 "Confirm run defaults" — one consolidated prompt seeded from lastrun (or built-in defaults); downstream phases consume it and skip their own non-destructive prompts. |
| F3 | Worktree removed at Phase 4 (right after merge, before push). Severs the /feature-sdlc resume contract: state.yaml lives in `<worktree>/.pmos/feature-sdlc/`, so a Phase 15 push failure leaves no worktree AND no resumable state. | bug / ux-friction | Move worktree cleanup to Phase 16.5 — after push tag (Phase 16) succeeds. Update Anti-pattern #4. |

## F1 — lastrun schema

Path: `.pmos/complete-dev.lastrun.yaml` (gitignored; per-developer)

```yaml
version: 1
last_updated: 2026-05-13T14:23:00Z
defaults:
  verify_already_ran: true               # Phase 1
  merge_style: rebase-then-ff            # Phase 3 — rebase-then-ff | merge-ff-or-noff | branch-only
  worktree_disposition: remove           # Phase 16.5 — remove | keep
  deploy_path: skip-ci-handles           # Phase 5 — skip-ci-handles | run-local-deploy | run-uv-publish | skip-deploy
  version_bump: minor                    # Phase 9 — patch | minor | major | skip
  changelog_disposition: accept          # Phase 8 — accept | edit | rerun | skip
  push_target: all-remotes               # Phase 14 — all-remotes | origin-only
detected_signals:
  deploy: ["plugin manifests (push to remotes)"]
```

Read at Phase 0; if malformed → stderr warn, fall through to builtin defaults; never error out (FR-LR03).

Written at the end of Phase 17 (final verification, after success) — only the answers chosen this run.

## F2 — Phase 0.5 contract

After Phase 0 (sanity & state), before Phase 1 (/verify gate):

1. Load `.pmos/complete-dev.lastrun.yaml`; merge with built-in defaults; apply CLI-flag overrides (`--skip-changelog`, `--skip-deploy`, `--no-tag`).
2. Present a single AskUserQuestion: "Proceed with these defaults?" with options [Confirm all (Recommended) / Edit one or more / Cancel].
3. On Confirm: set `run_defaults` in memory; downstream phases consult and skip their own non-destructive prompts.
4. On Edit: multiSelect which fields to change → per-field re-prompt → consolidated re-confirm.

**Anti-pattern guard — phases that STILL prompt even when defaults are confirmed:**
- Phase 3 if shared-branch guard FAILs and default is rebase → safer Recommended (merge) is re-surfaced (destructive).
- Phase 6 learnings — per-finding content review, not run-shape; still prompts.
- Phase 9 stale-bump recovery — destructive; re-prompt.
- Phase 11 commit message draft — free-form input; still prompt.
- Phase 13 tag-exists collision — destructive; re-prompt.
- Phase 15 push failure — destructive; re-prompt.

Phases collapsed into the Phase 0.5 confirm: 1 (/verify gate), 3 (merge style — guard-PASS only), 5 (deploy path), 8 (changelog accept), 9 step 5 (bump type), 14 (push target). ~6 prompts → 1.

Phase 0.5 only fires in interactive mode (the non-interactive block already AUTO-PICKs each `(Recommended)`, which is equivalent).

## F3 — Phase ordering

Old: Phase 4 worktree cleanup → 5-17 release work → push.
New: Phase 4 deleted (replaced with a stub note); Phase 16.5 worktree cleanup inserted after Phase 16 push-tag success.

Cleanup logic itself (FR-CD01–CD06: dirty-check excluding `.pmos/feature-sdlc/`, `--force-cleanup` handling, `ExitWorktree`, fallback chat line) is preserved verbatim — only the call site moves.

Anti-pattern #4 rewords from "Removing the worktree before merge succeeds" to "Removing the worktree before **push** succeeds", with explicit reference to the resume-contract dependency.

## Test plan (TDD)

1. **F1 schema round-trip** — write a `.pmos/complete-dev.lastrun.yaml` with all fields, parse + re-emit, byte-equal.
2. **F1 missing-file fallback** — when file absent, defaults dict matches built-in.
3. **F1 malformed-file fallback** — when YAML is malformed, defaults dict matches built-in + stderr carries warning.
4. **F2 prompt count** — grep the revised SKILL.md for `AskUserQuestion` calls in phases 1, 3, 5, 8, 9, 14 — each must reference `run_defaults` short-circuit logic.
5. **F3 ordering** — grep for "Phase 16.5 — Worktree cleanup" + assert it appears AFTER "## Phase 16" header and BEFORE "## Phase 17"; assert "## Phase 4" body is a deferral stub (no `git worktree remove` in Phase 4's region).
6. **Skill-eval** — run `feature-sdlc/tools/skill-eval-check.sh` against the revised SKILL.md — all `[D]` checks pass.

(1)-(3) live in `tests/lastrun_roundtrip.sh`. (4)-(5) live in `tests/phase_structure.sh`. (6) is the skill-eval gate.

## Release prerequisites

- Manifest version-sync bump 2.40.0 → 2.41.0 (minor; additive UX change).
- README update: /complete-dev row description tweak to mention "lastrun memory".
- CLAUDE.md: no change (canonical paths unaffected).
- learnings.md: optional /complete-dev entry on the worktree-removal-timing bug if surfaced during verify.
