---
task_number: 20
status: done
commit_sha: f63fa5283a63161f9edad85316857776d9013ecf
deviations: []
inline_verification: PASS
---

# T20 — cross-file-rules.md

Authored `plugins/pmos-toolkit/skills/readme/reference/cross-file-rules.md`
(177 lines) covering R1–R4 + the A9 design-time clarity-test results per
FR-CF-1..5 of the spec.

ToC sits in the first 16 lines. Per-rule sections give the rule statement,
output decision shape, A9 result, tier-on-fail, and the fixture used. R1/R2/R4
are binary PASS; R3 is 3-valued PASS (legitimately divergent), with the third
branch captured in `.pmos/readme.config.yaml :: package_variance`. Methodology
section documents the 4-step A9 procedure and cites kubernetes/kubernetes +
babel/babel as real-world R3 case-(b) cases, plus 01_pnpm / 02_npm-workspaces
/ 03_lerna for R1/R4/R2 respectively. Summary table closes the file.

Inline verification: `head -15` shows the ToC; `grep -c "R1\|R2\|R3\|R4\|A9"`
returned 36 (≥5).
