---
task_id: 23
status: done
commits: [7c9ecd3e237ae226a3a50c4becf1b73ef7429ba5]
verify_status: PASS
fr_refs: [FR-V-1, FR-V-4]
---

# T23 — voice-diff.sh + voice fixtures + --selftest

## Summary

Created the `/readme` skill's voice-preservation gate substrate:

- **`plugins/pmos-toolkit/skills/readme/scripts/voice-diff.sh`** (211 lines, executable, Bash 3.2-safe, shellcheck-clean). Computes `sentence_len_delta_pct` and `jaccard_new_tokens` between two markdown files. Tokenisation + math done in a single `awk` BEGIN block (no associative bash arrays, no `mapfile`, no `<<<` array reads). Strips markdown chrome (fenced code, headings, bullets, links, inline code) before tokenisation. JSON emitted as a single line on stdout.
- **`--selftest`** flag runs the script against the two hand-crafted fixtures and asserts `sentence_len_delta_pct ∈ [-25, 25]` AND `jaccard_new_tokens ≥ 0.5`. Returns `selftest: PASS` exit 0 on success.
- **FR-V-4 graceful-detect:** walks up from the script's own directory looking for a `plugins/pmos-toolkit/skills/polish/` sibling; emits the required stderr warn line when no `voice*` artifact is present. Does not source the substrate (the built-in tokenizer is canonical either way).
- **`pre.md` / `post.md`** — ~7-sentence project-setup blurbs sharing substantive content, differing only in voice (post.md tighter, more varied syntax). Designed to land inside the gate thresholds.

TDD order followed: fixtures first → confirmed missing-script fail (exit 127) → implemented → selftest PASS → manual JSON parse confirmed via `python3 -c "import json,sys; json.load(sys.stdin)"`.

R9/P11: SKILL.md untouched (`git diff 7bd324ac -- SKILL.md | grep '^-' | grep -v '^---' | wc -l` = 0); T24 owns SKILL.md in parallel.

## Verification

```text
$ wc -l plugins/pmos-toolkit/skills/readme/scripts/voice-diff.sh
     211 plugins/pmos-toolkit/skills/readme/scripts/voice-diff.sh

$ bash plugins/pmos-toolkit/skills/readme/scripts/voice-diff.sh --selftest
selftest: PASS

$ bash plugins/pmos-toolkit/skills/readme/scripts/voice-diff.sh \
    plugins/pmos-toolkit/skills/readme/tests/fixtures/voice/pre.md \
    plugins/pmos-toolkit/skills/readme/tests/fixtures/voice/post.md
{"sentence_len_delta_pct": -10.4, "jaccard_new_tokens": 0.75}

$ shellcheck plugins/pmos-toolkit/skills/readme/scripts/voice-diff.sh
(no findings; exit 0)

$ ls plugins/pmos-toolkit/skills/readme/tests/fixtures/voice/
post.md
pre.md

$ python3 -c "import json,sys; print(json.load(sys.stdin))" \
    < <(bash plugins/pmos-toolkit/skills/readme/scripts/voice-diff.sh \
        plugins/pmos-toolkit/skills/readme/tests/fixtures/voice/pre.md \
        plugins/pmos-toolkit/skills/readme/tests/fixtures/voice/post.md)
{'sentence_len_delta_pct': -10.4, 'jaccard_new_tokens': 0.75}
```

Jaccard 0.75 ≥ 0.7 FR-V-3 gate threshold; delta -10.4% within ±25 selftest envelope. JSON parses with `json.load`.

## Deviations

None. Plan called for `find … -maxdepth 3 -name 'voice*'` substrate probe — implemented inside an upward directory walk (max 6 levels) so the probe works regardless of which subdirectory the script is invoked from, then runs the `find` against the discovered polish dir. Behaviour identical: emit one stderr warn line when no `voice*` artifact is found, never abort.
