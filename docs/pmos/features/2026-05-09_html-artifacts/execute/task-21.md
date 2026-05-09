---
task_number: 21
task_name: "lint-no-modules-in-viewer + assert_no_es_modules_in_viewer"
task_goal_hash: t21-viewer-no-modules
plan_path: "docs/pmos/features/2026-05-09_html-artifacts/03_plan.md"
branch: "feat/html-artifacts"
worktree_path: null
status: done
started_at: 2026-05-10T02:13:00Z
completed_at: 2026-05-10T02:16:00Z
files_touched:
  - plugins/pmos-toolkit/tools/lint-no-modules-in-viewer.sh
  - tests/scripts/assert_no_es_modules_in_viewer.sh
---

## T21 — viewer ES-modules lint + assert wrapper

**Outcome:** done. Tool + wrapper assert both PASS on current viewer.js.
Negative test (synthetic `import x from 'y'` appended) FAILs as expected.

### Inline verification

```
$ bash tests/scripts/assert_no_es_modules_in_viewer.sh
PASS: lint-no-modules-in-viewer (...viewer.js)   ✅

$ # negative
$ echo "import x from 'y';" >> viewer.js
$ bash tests/scripts/assert_no_es_modules_in_viewer.sh
FAIL: ES-module pattern in ...viewer.js
336:import x from 'y';
exit=1   ✅ (revert applied)
```

### Deviation

Plan T21 Step 5: "Wire into `tools/audit-recommended.sh`-style invocation
(append a line that calls the new lint)." `audit-recommended.sh` is
purpose-specific (AskUserQuestion call-site marking audit) and not a
multi-lint runner. No suitable meta-runner exists yet; the tool +
wrapper-assert pair is independently invokable. Deferred multi-lint
aggregator wiring to a future cleanup pass — flagged as ADV-T21 below.

### Spec compliance

| FR | Requirement | Satisfied by |
|---|---|---|
| FR-05.1 | viewer.js is a classic script (no `import`/`export`/`type=module`) | grep -nE pattern detection in lint tool; positive PASS on current viewer.js; negative FAIL on synthetic mod |

### Advisories

- **ADV-T21** (non-blocking): wire `lint-no-modules-in-viewer.sh` into a
  multi-lint runner once one exists. For now, callable via tools/ path
  directly or via tests/scripts/ wrapper.

T21 complete.
