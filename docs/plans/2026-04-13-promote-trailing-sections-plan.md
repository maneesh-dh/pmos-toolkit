# Promote Trailing Sections to Numbered Phases — Implementation Plan

**Goal:** Eliminate the "unnumbered trailing section = skipped" failure mode by promoting Workstream Enrichment and Capture Learnings to numbered phases in all 7 pipeline skills, adding the missing Workstream Enrichment to `/verify`, and bumping pmos-toolkit to `1.2.0`.

**Rationale:** `docs/` contains prior analysis. Numbered phases get executed; trailing unnumbered sections read as appendices and are routinely skipped. Fix: structural, not exhortational.

**Tech Stack:** Markdown skill files. No tests (skill prompts are not unit-testable); verification is a grep-based structural check after edits.

---

## Per-Skill Phase Changes

| Skill | Current last phase | Add phase(s) | New last phase |
|---|---|---|---|
| requirements | Phase 6: Final Review | Phase 7 Workstream Enrichment, Phase 8 Capture Learnings | Phase 8 |
| spec | Phase 7: Final Review | Phase 8 Workstream Enrichment, Phase 9 Capture Learnings | Phase 9 |
| plan | Phase 5: Final Review | Phase 6 Workstream Enrichment, Phase 7 Capture Learnings | Phase 7 |
| msf | Phase 6: Consistency Pass | Phase 7 Capture Learnings | Phase 7 |
| creativity | Phase 6: Consistency Pass | Phase 7 Capture Learnings | Phase 7 |
| execute | Phase 5: Commit & Report | Phase 6 Workstream Enrichment, Phase 7 Capture Learnings | Phase 7 |
| verify | Phase 8: Commit & Report | Phase 9 Workstream Enrichment (NEW), Phase 10 Capture Learnings | Phase 10 |

`msf` and `creativity` have no Phase 0 workstream load, so they don't get a Workstream Enrichment phase.

## Template for the Two New Phases

**Workstream Enrichment phase body** (conditional):

```markdown
## Phase N: Workstream Enrichment

**Skip if no workstream was loaded in Phase 0.** Otherwise, follow the enrichment instructions in `product-context/context-loading.md` Step 4. For this skill, the signals to look for are:

- [skill-specific signals carried over from existing section]

This phase is mandatory whenever Phase 0 loaded a workstream — do not skip it just because the core deliverable is complete.
```

**Capture Learnings phase body** (terminal gate):

```markdown
## Phase N: Capture Learnings

**This skill is not complete until learnings are captured.** Read and follow `learnings/learnings-capture.md` (relative to the skills directory) now. Record anything that will help a future invocation of this skill go better — surprising behaviors, repeated corrections, non-obvious decisions.
```

Existing body bullets from each skill's current section are preserved verbatim (only the heading, ordering, and gate language change).

## Verify Addition

`/verify` currently has no Workstream Enrichment section. Add one with signals:

- Implementation gaps discovered vs spec → workstream `## Key Decisions`
- New constraints or scars uncovered during verification → workstream `## Constraints & Scars`

---

### Task 1: Update `requirements`

**Files:** Modify `plugins/pmos-toolkit/skills/requirements/SKILL.md:415-430`

- [ ] **Step 1: Replace `## Workstream Enrichment (after final review)` heading with `## Phase 7: Workstream Enrichment`** and prepend the skip-gate sentence. Keep the signal bullets as-is.

- [ ] **Step 2: Replace `## Capture Learnings (after workstream enrichment)` heading with `## Phase 8: Capture Learnings`** and replace the body with the terminal-gate template above.

---

### Task 2: Update `spec`

**Files:** Modify `plugins/pmos-toolkit/skills/spec/SKILL.md:522-537`

- [ ] **Step 1:** Heading → `## Phase 8: Workstream Enrichment`, add skip-gate sentence, keep signals.
- [ ] **Step 2:** Heading → `## Phase 9: Capture Learnings`, replace body with terminal-gate template.

---

### Task 3: Update `plan`

**Files:** Modify `plugins/pmos-toolkit/skills/plan/SKILL.md:370-384`

- [ ] **Step 1:** Heading → `## Phase 6: Workstream Enrichment`, add skip-gate sentence, keep signals.
- [ ] **Step 2:** Heading → `## Phase 7: Capture Learnings`, replace body with terminal-gate template.

---

### Task 4: Update `msf`

**Files:** Modify `plugins/pmos-toolkit/skills/msf/SKILL.md:187-192`

- [ ] **Step 1:** Heading → `## Phase 7: Capture Learnings`, replace body with terminal-gate template. (No Workstream Enrichment — msf has no Phase 0 workstream load.)

---

### Task 5: Update `creativity`

**Files:** Modify `plugins/pmos-toolkit/skills/creativity/SKILL.md:154-159`

- [ ] **Step 1:** Heading → `## Phase 7: Capture Learnings`, replace body with terminal-gate template.

---

### Task 6: Update `execute`

**Files:** Modify `plugins/pmos-toolkit/skills/execute/SKILL.md:224-237`

- [ ] **Step 1:** Heading → `## Phase 6: Workstream Enrichment`, add skip-gate sentence, keep signals.
- [ ] **Step 2:** Heading → `## Phase 7: Capture Learnings`, replace body with terminal-gate template.

---

### Task 7: Update `verify`

**Files:** Modify `plugins/pmos-toolkit/skills/verify/SKILL.md:283-323`

- [ ] **Step 1:** Insert new section `## Phase 9: Workstream Enrichment` after Phase 8, with skip-gate sentence and signals:
  - Implementation gaps discovered vs spec → workstream `## Key Decisions`
  - New constraints or scars uncovered during verification → workstream `## Constraints & Scars`

- [ ] **Step 2:** Heading `## Capture Learnings (after commit & report)` → `## Phase 10: Capture Learnings`, replace body with terminal-gate template.

---

### Task 8: Version bump

**Files:**
- Modify `plugins/pmos-toolkit/.claude-plugin/plugin.json`
- Modify `plugins/pmos-toolkit/.codex-plugin/plugin.json`

- [ ] **Step 1:** Bump `"version": "1.1.0"` → `"1.2.0"` in both files.

---

### Task 9: Structural verification

- [ ] **Step 1:** Grep for unnumbered trailing sections — should return 0 matches:

```bash
grep -rEn '^## (Workstream Enrichment|Capture Learnings)\b' plugins/pmos-toolkit/skills/
```

- [ ] **Step 2:** Grep for the terminal-gate phrase — should appear in every skill:

```bash
grep -rln "This skill is not complete until learnings are captured" plugins/pmos-toolkit/skills/ | wc -l
```

Expected: 7.

---

### Task 10: Commit and push

- [ ] **Step 1:** One commit covering all edits + version bump. Push — pre-push hook should accept the bump.
