---
task_number: 22
status: done
commit_sha: d482f7141bdbec7ed42524c44ad1763d62aa108a
deviations: []
inline_verification: PASS
p11_removed_lines: 0
closes_residuals: [phase-3-r2, phase-4-r1, phase-4-r2, phase-5-r1, phase-5-r4]
---

T22 appends `### §10: Monorepo audit-all flow` to SKILL.md ## Implementation,
closing the monorepo integration contract begun in §9 (T21). §10 wraps
§1/§6/§7 into a workspace-scope flow when `workspace-discovery.sh` reports
composition=monorepo.

Content delivered: (1) `--scope` argv parsing paragraph documenting the
non-interactive surface (FR-MODE-3, closes phase-5-r4); (2) workspace-scope
AskUserQuestion with audit-all/audit-one/scaffold-missing/root-only options
plus conditional MS01 multi-stack option; (3) per-pkg iteration contract
loading rubric variant per repo_type and invoking §9 cross-file pass; (4)
severity-grouped findings roll-up with per-pkg drill-down follow-up prompt;
(5) D15 unified diff with `=== package: <name> (audit|scaffold) ===`
headers and atomic multi-write rollback contract (FR-OUT-1); (6) single
final approval gate; (7) composition-wiring paragraph linking §10 back to
§1/§6/§7 as the monorepo overlay.

Verifications: grep returned 10 matches for `FR-OUT-1|audit-all|workspace-scope`
(≥3 required); P11 append-only check returned 0 removed lines vs commit
374de27; SKILL.md is 465 lines (≤480 cap). No deviations.
