---
task_number: 4
task_name: "Author assets/serve.js"
task_goal_hash: t4-serve-js
plan_path: "docs/pmos/features/2026-05-09_html-artifacts/03_plan.md"
branch: "feat/html-artifacts"
worktree_path: null
status: done
started_at: 2026-05-09T19:08:00Z
completed_at: 2026-05-09T19:12:00Z
files_touched:
  - plugins/pmos-toolkit/skills/_shared/html-authoring/assets/serve.js
  - tests/scripts/assert_serve_js.sh
---

## T4 — `assets/serve.js`

### Outcome

129-line zero-deps Node static server. Built-in `require()` only (`http`, `fs`, `path`, `url`). 13-entry MIME map per FR-06. Port-fallback over a 10-port range starting at 8765. 5/5 smoke checks pass.

### Inline verification (all PASS)

- `bash tests/scripts/assert_serve_js.sh` → exit 0 (5 cases: html 200 + html ctype, json 200 + json ctype, svg 200 + svg ctype, txt fallback 200 + text/plain, 404 path) ✓
- `grep "require(" serve.js` → 4 lines, all Node built-ins (`http`, `fs`, `path`, `url`) ✓

### Key decisions

- **`--port-file` flag** for the test harness (writes the bound port to a file so the assert script can pick it up race-free). Doesn't bloat the production path; default usage prints to stdout only.
- **`safeJoin` traversal guard** — decode-then-normalize-then-`startsWith(root)` rejects `../` escapes. Standard pattern, ~5 lines.
- **`Cache-Control: no-store`** on every response — these are dev-loop artifacts; a stale browser cache during /verify smoke would mask drift between HTML and sections.json. Cheap, no downside.
- **Directory request → `index.html` fallback** — matches typical static-server UX so `http://localhost:<port>/` opens the viewer without `/index.html` typed.
- **Port range** 8765..8774. Picked 8765 to match the spec FR-06 example. Range of 10 is wide enough to recover from typical port collisions; beyond that, fails loud rather than silent-binding port 0.

### Deviations from plan

None.

### Open follow-ups

- T11's `index.html` generator will rely on this server for the iframe-routing path during dev. For prod use, users open file:// directly — handled by FR-40 fallback in viewer.js (T3).
- The `url` builtin is required-but-unused; benign. If the no-modules pre-push lint (FR-05.1) runs on this file in the future, it should pass — the regex is `^(import|export)\b|type=["']module["']`, none of which appear here.
