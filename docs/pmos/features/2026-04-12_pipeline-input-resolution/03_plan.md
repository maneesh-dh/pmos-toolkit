# Pipeline Input Resolution Implementation Plan

**Goal:** Add three-tier input resolution (explicit arg → session history → numbered picker) across pmos-toolkit pipeline skills via a shared procedure file.

**Architecture:** One new shared file (`.shared/resolve-input.md`) documents the procedure. Six skills reference it from their "locate input" step. No executable code — this is skill-prompt documentation.

**Tech Stack:** Markdown skill files. No tests (skill prompts are not unit-testable); verification is by re-reading each edited skill to confirm the pointer is correct.

**Spec:** `docs/specs/2026-04-12-pipeline-input-resolution-design.md`

---

### Task 1: Create shared resolver procedure

**Files:**
- Create: `plugins/pmos-toolkit/skills/.shared/resolve-input.md`

- [ ] **Step 1: Write the file**

Content:

```markdown
# Resolve Pipeline Input

Shared procedure for pipeline skills that consume a prior-phase document. Callers pass:
- `phase` — the subdirectory under `{docs_path}` to search (e.g., `requirements`, `specs`, `plans`)
- `label` — human-readable name for prompts (e.g., "requirements doc", "spec", "plan")

Try resolution steps in order. Stop at the first hit. Always echo the resolved path on a single line before proceeding — this is the user's only chance to catch a wrong pick.

## Step 1: Explicit argument

If the user passed an argument to the slash command:
- If it resolves to an existing file path, use it. Echo: `Using: <path>`
- Otherwise treat the argument as inline content. Echo: `Using inline <label> from argument`

Proceed. Skip remaining steps.

## Step 2: Conversation history

Scan this session for any file under `{docs_path}/{phase}/` that was written, edited, or read earlier. If one or more exist, pick the most recently touched. Echo: `Using from this session: <path>`

Proceed. Skip remaining steps. Do not prompt — the echo is the confirmation; the user can interrupt if wrong.

## Step 3: Numbered picker

List files in `{docs_path}/{phase}/` sorted by mtime (newest first), keeping up to 3.

- **0 files:** Report `No {label} found in {docs_path}/{phase}/` and ask the user to provide a path or inline content. Do not proceed until provided.
- **1 file:** Skip the list. Echo: `Using: <path>` and proceed.
- **2–3 files:** Present a numbered list:

  ```
  Recent {label}s in {docs_path}/{phase}/:
    [1] <path>  (modified <mtime>)
    [2] <path>  (modified <mtime>)
    [3] <path>  (modified <mtime>)
  Pick one [default 1]:
  ```

  On confirmation (including empty input → 1), echo: `Using: <path>` and proceed.
```

- [ ] **Step 2: Commit**

```bash
git add plugins/pmos-toolkit/skills/.shared/resolve-input.md
git commit -m "feat(pmos-toolkit): add shared pipeline input resolver"
```

---

### Task 2: Wire `/spec` to shared resolver

**Files:**
- Modify: `plugins/pmos-toolkit/skills/spec/SKILL.md:38`

- [ ] **Step 1: Replace the locate line**

Replace:
```
1. **Locate the requirements.** If the user passed an argument, use it. Otherwise check `{docs_path}/requirements/` for a recent file. If nothing found, ask.
```

With:
```
1. **Locate the requirements.** Follow `../.shared/resolve-input.md` with `phase=requirements`, `label="requirements doc"`.
```

- [ ] **Step 2: Commit**

```bash
git add plugins/pmos-toolkit/skills/spec/SKILL.md
git commit -m "feat(spec): use shared input resolver"
```

---

### Task 3: Wire `/plan` to shared resolver

**Files:**
- Modify: `plugins/pmos-toolkit/skills/plan/SKILL.md:38`

- [ ] **Step 1: Replace the locate line**

Replace:
```
1. **Locate the spec.** If the user passed an argument, use it. Otherwise check `{docs_path}/specs/` for a recent file. If nothing found, ask.
```

With:
```
1. **Locate the spec.** Follow `../.shared/resolve-input.md` with `phase=specs`, `label="spec"`.
```

- [ ] **Step 2: Commit**

```bash
git add plugins/pmos-toolkit/skills/plan/SKILL.md
git commit -m "feat(plan): use shared input resolver"
```

---

### Task 4: Wire `/execute` to shared resolver

**Files:**
- Modify: `plugins/pmos-toolkit/skills/execute/SKILL.md:34`

- [ ] **Step 1: Replace the locate line**

Replace:
```
1. **Locate the plan.** If the user passed an argument, use it. Otherwise check `{docs_path}/plans/` for the most recent file. If nothing found, ask.
```

With:
```
1. **Locate the plan.** Follow `../.shared/resolve-input.md` with `phase=plans`, `label="plan"`.
```

- [ ] **Step 2: Commit**

```bash
git add plugins/pmos-toolkit/skills/execute/SKILL.md
git commit -m "feat(execute): use shared input resolver"
```

---

### Task 5: Wire `/verify` to shared resolver (multi-doc)

**Files:**
- Modify: `plugins/pmos-toolkit/skills/verify/SKILL.md:57-59`

`/verify` resolves three documents. Each resolution follows the shared procedure independently.

- [ ] **Step 1: Replace the locate block**

Replace:
```
1. **Locate upstream documents.** Find the spec, requirements, and plan:
   - Check user argument first
   - Then search `{docs_path}/specs/`, `{docs_path}/requirements/`, `{docs_path}/plans/` for the most recent matching files
```

With:
```
1. **Locate upstream documents.** Resolve each of the three inputs by following `../.shared/resolve-input.md`:
   - Spec: `phase=specs`, `label="spec"` (user argument, if passed, applies to the spec)
   - Requirements: `phase=requirements`, `label="requirements doc"`
   - Plan: `phase=plans`, `label="plan"`
```

- [ ] **Step 2: Commit**

```bash
git add plugins/pmos-toolkit/skills/verify/SKILL.md
git commit -m "feat(verify): use shared input resolver"
```

---

### Task 6: Add locate step to `/msf`

**Files:**
- Modify: `plugins/pmos-toolkit/skills/msf/SKILL.md` (insert after the "Load Learnings" section, before "Phase 1")

- [ ] **Step 1: Insert new section**

After the "Load Learnings" section and its trailing `---`, insert:

```markdown
## Locate Requirements

Follow `../.shared/resolve-input.md` with `phase=requirements`, `label="requirements doc"`. Read the resolved file end-to-end before Phase 1.

---
```

- [ ] **Step 2: Commit**

```bash
git add plugins/pmos-toolkit/skills/msf/SKILL.md
git commit -m "feat(msf): locate requirements via shared resolver"
```

---

### Task 7: Add locate step to `/creativity`

**Files:**
- Modify: `plugins/pmos-toolkit/skills/creativity/SKILL.md` (insert after the "Load Learnings" section, before "Phase 1")

- [ ] **Step 1: Insert new section**

After the "Load Learnings" section and its trailing `---`, insert:

```markdown
## Locate Requirements

Follow `../.shared/resolve-input.md` with `phase=requirements`, `label="requirements doc"`. Read the resolved file end-to-end before Phase 1.

---
```

- [ ] **Step 2: Commit**

```bash
git add plugins/pmos-toolkit/skills/creativity/SKILL.md
git commit -m "feat(creativity): locate requirements via shared resolver"
```

---

### Task 8: Final verification

- [ ] **Step 1: Grep for stale locate-input text**

```bash
grep -rn "If the user passed an argument" plugins/pmos-toolkit/skills/
```

Expected: no results (all replaced).

- [ ] **Step 2: Confirm shared file is referenced everywhere**

```bash
grep -rn ".shared/resolve-input.md" plugins/pmos-toolkit/skills/ | wc -l
```

Expected: at least 7 references (one per wired skill + `/verify` has 3 bullets, so actually ≥9).
