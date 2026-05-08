# Pipeline-Setup — Expected Outcomes per Fixture

Reference for manual verification of `_shared/pipeline-setup.md` Section 0 + Sections A/B/C/D. After each fixture run, compare actual outcome against the expected outcome below. Used by implementer (and `/verify`) to confirm correctness.

These fixtures describe **state**, not test files — to verify, manually construct a sample repo matching the fixture state, then invoke `/requirements` (or any pipeline skill) and observe.

---

## Fixture (a) — Fresh repo

**State:**
- No `.pmos/`
- No `docs/`

**Invoke:** `/requirements "I want to add bulk-edit to the agent dashboard"`

**Expected:**
1. Section 0 step 1 detects missing `settings.yaml` → MUST `Read` Section A.
2. Section A.1 detects no legacy state.
3. Section A.2 emits **one** `AskUserQuestion` with 3 batched questions:
   - Q1 default: `docs/pmos/`
   - Q2: list of `~/.pmos/workstreams/*.md` or "None"
   - Q3 default: `bulk-edit-dashboard` (derived from input)
4. After user accepts defaults, `.pmos/settings.yaml` written with:
   ```yaml
   version: 1
   docs_path: docs/pmos
   workstream: <chosen-or-null>
   current_feature: 2026-MM-DD_bulk-edit-dashboard
   ```
5. Folder created at `docs/pmos/features/2026-MM-DD_bulk-edit-dashboard/`.
6. Echo: `Pipeline setup complete: docs_path=docs/pmos, workstream=<...>, feature=2026-MM-DD_bulk-edit-dashboard`.
7. Skill proceeds with normal `/requirements` flow.

---

## Fixture (b) — Pointer-only legacy

**State:**
- `.pmos/current-feature` exists, contains `2026-04-30_search-bug`
- `docs/pmos/features/2026-04-30_search-bug/` exists with prior `01_requirements.md`
- No `.pmos/settings.yaml`
- No legacy `docs/{requirements,specs,plans,features}/` at root

**Invoke:** `/requirements "improve the error handling"`

**Expected:**
1. Section 0 step 1 detects missing `settings.yaml` → `Read` Section A.
2. Section A.1 detects pointer file with value `2026-04-30_search-bug`. Captures for migration.
3. Section A.1 finds no legacy `docs/` layout → `docs_path` default = `docs/pmos/`.
4. Section D migration runs **silently** before A.2 prompt:
   - Constructs `settings.yaml` with `docs_path: docs/pmos`, `current_feature: 2026-04-30_search-bug`, `workstream: null`.
   - `git rm .pmos/current-feature`.
   - Logs migration block to user.
5. Section A.2 prompt is **skipped** entirely if migration produced a complete settings.yaml. Skill proceeds with `current_feature` set.
6. `/requirements` recognizes update path (existing `01_requirements.md`); proceeds with delta brainstorm.

---

## Fixture (c) — Legacy `docs/` layout

**State:**
- `docs/specs/`, `docs/plans/`, `docs/requirements/` exist (legacy locations for type-grouped artifacts)
- No `.pmos/`
- No `docs/features/` yet

**Invoke:** `/requirements "build the user dashboard"`

**Expected:**
1. Section 0 step 1 detects missing `settings.yaml` → `Read` Section A.
2. Section A.1 detects legacy layout → `docs_path` prompt default = `docs/`.
3. Section A.2 emits 3-question prompt; Q1 default is `docs/` (legacy), Q3 default is `user-dashboard`.
4. After user accepts, `.pmos/settings.yaml` written with `docs_path: docs/`.
5. Folder created at `docs/features/2026-MM-DD_user-dashboard/`.
6. Skill proceeds normally.
7. **NOT** auto-moved to `docs/pmos/` — that's an opt-in user cleanup per Section D.6.

---

## Fixture (d) — Fully migrated

**State:**
- `.pmos/settings.yaml` exists with all fields populated:
  ```yaml
  version: 1
  docs_path: docs/pmos
  workstream: my-fintech-app
  current_feature: 2026-05-01_face-tagging
  ```
- `docs/pmos/features/2026-05-01_face-tagging/01_requirements.md` exists
- `~/.pmos/workstreams/my-fintech-app.md` exists

**Invoke:** `/requirements "add a confidence score"` (no `--feature` flag)

**Expected:**
1. Section 0 step 1 reads settings.yaml successfully — no `Read` of Section A needed.
2. Step 2: `{docs_path}` = `docs/pmos`.
3. Step 3: workstream `my-fintech-app` loaded as preamble.
4. Step 4: `--feature` not passed; `settings.current_feature = 2026-05-01_face-tagging`; folder exists → use it.
5. No prompts during setup. Skill proceeds directly to Phase 1 intake.

---

## Fixture (e) — Mid-pipeline drift

**State:**
- Same as (d), but feature folder also contains `02_spec.md` and `03_plan.md`.

**Invoke:** `/requirements "rethink the journey"` (re-running with existing pipeline downstream)

**Expected:**
1. Section 0 step 1–4 succeed; setup is silent.
2. `/requirements` Phase 1 step 3 detects existing `01_requirements.md` AND downstream `02_spec.md` + `03_plan.md`.
3. Drift warning issued via `AskUserQuestion`:
   > Updating requirements will desync 02_spec.md and 03_plan.md. Continue / cancel / run /verify after?
4. If user picks Continue → Phase 4 commits dirty `01_requirements.md` first (snapshot), then proceeds with update path.
5. If user picks Cancel → skill exits cleanly, no changes.

---

## Fixture (f) — Slug collision

**State:**
- Fixture (d) state, plus user invokes `/requirements --feature face-tagging` AND there are 2 folders:
  - `docs/pmos/features/2026-05-01_face-tagging/`
  - `docs/pmos/features/2026-04-15_face-tagging/`

**Expected:**
1. Section 0 step 4 globs for `*_face-tagging/` → 2 matches.
2. Section 0 step 5 fires → MUST `Read` Section B.
3. Section B.3 echoes error: `Multiple feature folders match 'face-tagging': 2026-05-01_face-tagging, 2026-04-15_face-tagging`.
4. Skill stops. No write. No partial state.

---

## Fixture (g) — Migration abort (uncommitted changes to pointer file)

**State:**
- `.pmos/current-feature` exists, has uncommitted local edit (`git status` shows it modified).
- No `.pmos/settings.yaml`.

**Invoke:** any pipeline skill.

**Expected:**
1. Section A.1 detects pointer.
2. Section D.5 abort condition triggers (working tree dirty in conflicting way).
3. Skill emits abort message:
   > Pipeline migration aborted: uncommitted local changes to .pmos/current-feature would conflict with git rm. Repo state unchanged. Resolve the issue and re-invoke the skill.
4. No file written, no `git rm` executed.
5. Skill exits cleanly.

---

## Verification checklist

After implementation, walk each fixture (a)–(g) and confirm actual matches expected. Document any divergence as a follow-up ticket.
