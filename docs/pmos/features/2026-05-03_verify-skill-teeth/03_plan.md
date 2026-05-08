# /verify Skill — Give Manual Verification Teeth — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure the `/verify` skill so Phase 4 verification and Phase 5 compliance cannot be silently skipped — replace prose warnings with structural gates (TodoWrite enumeration, three-state outcomes, evidence-type allowlists) and eliminate the linguistic escape hatches around the word "manual."

**Architecture:** Six targeted edits to `plugins/pmos-toolkit/skills/verify/SKILL.md` plus a plugin version bump. Each edit is self-contained and committable independently. No code changes — this is a skill-authoring task, so "tests" are structural verifications (grep for residual old language, read-through for coherence) rather than unit tests.

**Tech Stack:** Markdown skill file, JSON plugin manifest. Tools: `Read`, `Edit`, `Bash` (for grep verifications), `git`.

**Target file:** `/Users/maneeshdhabria/Desktop/Projects/agent-skills/plugins/pmos-toolkit/skills/verify/SKILL.md`

**Prerequisite read for implementer:** Before starting Task 1, read the full current skill file once so every Edit's `old_string` is unambiguous in context.

---

## Task 1: Language overhaul — remove "manual" ambiguity and the offload license

**Why:** The word "manual" is overloaded in the current skill — it sometimes means "interactive via Playwright MCP" (which the agent owns) and sometimes means "a human does it" (which licenses offloading). Line 21 actively tells the agent to offload browser verification to the user when Playwright MCP is unavailable, which is the exact rationalization that caused the skipped-verification incidents. This task kills the ambiguity at the source.

**Files:**
- Modify: `plugins/pmos-toolkit/skills/verify/SKILL.md` (4 distinct regions: line 3 frontmatter, line 21 Platform Adaptation, lines 197+206 Phase 4 3e, line 229 example cell)

- [ ] **Step 1: Edit the frontmatter description (line 3)**

Replace the word "manual" with "interactive" in the skill description.

```
Edit tool:
old_string: "Lint, test, deploy, spec compliance, multi-agent code review, manual QA, and regression test hardening."
new_string: "Lint, test, deploy, spec compliance, multi-agent code review, interactive QA, and regression test hardening."
```

- [ ] **Step 2: Rewrite the Platform Adaptation "No Playwright MCP" bullet (line 21)**

This is the critical behavioral change — the current line licenses offloading; the new line forbids it unless setup is genuinely blocked.

```
Edit tool:
old_string: "- **No Playwright MCP:** Note browser-based verification as a manual step for the user."
new_string: "- **No Playwright MCP:** State the specific blocker and the setup the user must complete before browser-based verification can run. Do NOT mark any UI-surface FR verified without either Playwright evidence or an explicitly declared alternative (a specific test file that covers the rendered output). Offloading verification to the user is not a valid completion state — it resolves to `Unverified — action required` on the Phase 5 compliance tables, and Phase 4 stays open."
```

- [ ] **Step 3: Rename Phase 4 3e heading and fix line 206**

Two edits in the 3e section. First the heading:

```
Edit tool:
old_string: "### 3e. Manual Spot Checks"
new_string: "### 3e. Interactive Spot Checks"
```

Then the body line:

```
Edit tool:
old_string: "**Do NOT rely only on automated tests.** Manual verification catches issues that tests miss (rendering glitches, confusing UX, wrong copy, timing issues)."
new_string: "**Do NOT rely only on automated tests.** Interactive verification (Playwright MCP driving real user journeys) catches issues that tests miss: rendering glitches, confusing UX, wrong copy, timing issues. \"Interactive\" means you operate the browser via MCP — not that a human operates it for you."
```

- [ ] **Step 4: Fix the example cell on line 229**

This cell example still says "manual verification" and will be further reshaped in Task 4, but this task's job is purely the language fix — keep the cell structure, change the word.

```
Edit tool:
old_string: "| FR-01 | [From spec] | Pass/Fail | [Test name or manual verification] |"
new_string: "| FR-01 | [From spec] | Pass/Fail | [Test name or interactive verification artifact] |"
```

Note: Task 4 will replace this entire row with the three-state format. That's fine — consecutive edits on the same region are safe because each Edit operates on the current file state.

- [ ] **Step 5: Verify language overhaul is complete**

Grep to confirm no stray occurrences of the old phrasing remain:

```bash
grep -n "manual QA\|manual step for the user\|Manual Spot Checks\|Manual verification catches\|manual verification" /Users/maneeshdhabria/Desktop/Projects/agent-skills/plugins/pmos-toolkit/skills/verify/SKILL.md
```

Expected output: empty (no matches), OR the only match is within the Anti-Patterns section (line 337 `Do NOT skip manual verification` — that bullet is handled in Task 5). Any other match means an edit was missed.

Note: The word "manual" will legitimately still appear in `After manual implementation` (line 42) and `Also run after manual coding` (line 3) — those mean "code written by a human without /execute," which is the correct usage. Leave them alone.

- [ ] **Step 6: Commit**

```bash
git add plugins/pmos-toolkit/skills/verify/SKILL.md
git commit -m "$(cat <<'EOF'
refactor(pmos-toolkit/verify): rename 'manual' → 'interactive' verification; forbid offloading when Playwright MCP unavailable

The word 'manual' was overloaded: sometimes 'interactive via Playwright MCP'
(agent-owned), sometimes 'a human does it' (user-owned). The Platform
Adaptation line explicitly licensed offloading, which became the escape
hatch for skipping Phase 4 verification.

Rename to 'interactive' everywhere the agent owns the action. Rewrite
the no-Playwright fallback to require a declared blocker or alternative
evidence — not a handoff.
EOF
)"
```

---

## Task 2: Add Phase 4 entry gate — TodoWrite enumeration + evidence-type allowlist

**Why:** The skill already has an FR compliance table in Phase 5 (4b), but its `Pass/Fail` status has no slot for "I didn't try." Without a pre-Phase-4 enumeration, skipping is invisible — the agent writes the final report from the tests it happened to run. This gate forces every runtime-surface requirement onto a `TodoWrite` list before Phase 4 starts, so unchecked items are structurally visible at completion time. The evidence-type allowlist tells the agent what counts as evidence for each sub-step, closing the "I'll figure out evidence later" loophole.

**Files:**
- Modify: `plugins/pmos-toolkit/skills/verify/SKILL.md` — insert new section between `## Phase 4: Deploy & Integration Verification` heading and `### 3a. Database Migrations` heading.

- [ ] **Step 1: Read the current Phase 4 opening to confirm the insertion point**

The new entry gate goes immediately after the `## Phase 4: Deploy & Integration Verification` line and before `### 3a. Database Migrations (if applicable)`. Re-read lines 155–165 to confirm the exact surrounding text. The Edit below uses `## Phase 4: Deploy & Integration Verification\n\n### 3a. Database Migrations (if applicable)` as the anchor — verify that anchor is unique.

```bash
grep -c "## Phase 4: Deploy & Integration Verification" /Users/maneeshdhabria/Desktop/Projects/agent-skills/plugins/pmos-toolkit/skills/verify/SKILL.md
```

Expected: `1`

- [ ] **Step 2: Insert the entry gate section**

```
Edit tool:
old_string: |
  ## Phase 4: Deploy & Integration Verification

  ### 3a. Database Migrations (if applicable)
new_string: |
  ## Phase 4: Deploy & Integration Verification

  ### Phase 4 Entry Gate — Enumerate the Verification Surface

  Before running any Phase 4 sub-step, enumerate every upstream requirement that has a runtime surface and create one `TodoWrite` task per item. This list is the gate — Phase 4 is not complete until every todo is closed with evidence or explicitly resolved to `Unverified — action required` with a named blocker. A plain bullet list in prose does not substitute for `TodoWrite` todos; the todos are the structural enforcement.

  **How to build the list:**

  1. Read the spec's FR-IDs and edge cases. For each, classify the runtime surface:
     - **UI surface** (user sees, clicks, enters something) → todo required
     - **API surface** (new or modified endpoint) → todo required
     - **Data surface** (migration, schema change, background job output) → todo required
     - **Pure internal logic** (algorithm verified by unit test only) → NOT on the list; cite the test in Phase 5 compliance instead
  2. Read the requirements doc's user journeys. Every end-to-end journey with UI or API touchpoints gets one todo.
  3. For each enumerated item, create a `TodoWrite` task formatted as:
     `Verify <FR-ID or Journey-ID>: <one-line description> [evidence: <type from table below>]`

  **Evidence-type allowlist by sub-step:**

  | Sub-step | Acceptable evidence |
  |----------|--------------------|
  | 3a. Database Migrations | Migration command output + DB schema query confirming the new shape |
  | 3b. Docker Deployment | Service health check output + startup log snippet showing no errors |
  | 3c. API Smoke Tests | `curl` response body compared row-by-row to the spec's API contract |
  | 3d. Frontend Verification | Playwright MCP screenshot, `browser_evaluate` DOM assertion, or a specific test file covering the rendered output |
  | 3e. Interactive Spot Checks | Playwright MCP interaction trace covering a user journey end-to-end, including at least one error/edge path |

  **Every enumerated todo resolves to exactly one of three outcomes:**

  1. **Verified** — evidence produced and cited. The evidence type must match the allowlist row for the sub-step. Close the todo.
  2. **NA — alternative evidence cited** — the runtime surface doesn't exist for this item (e.g., FR is a pure calculation change). Cite the alternative (e.g., `test_pricing.py::test_discount_applied`) or the specific reason tied to the FR text. Bare "NA" is not valid. Close the todo with the alternative recorded.
  3. **Unverified — action required** — you attempted verification and were blocked. State the specific blocker and the user action needed (e.g., "user must run `make seed-dev-db` before 3e can proceed"). Leave the todo OPEN and surface it in the Phase 8 final report.

  **Setup is part of Phase 4, not a prerequisite.** Starting the dev server, seeding the DB, running migrations, authenticating — all Phase 4 work. If setup is complex, write down the exact commands, execute them, and proceed. Only escalate to the user when a genuine decision is required (e.g., "which dev DB to use"), not to offload execution. "Setup would take too long" is a Phase 4 red flag, not a reason.

  ### 3a. Database Migrations (if applicable)
```

- [ ] **Step 3: Verify the insertion**

```bash
grep -n "Phase 4 Entry Gate\|Evidence-type allowlist\|Setup is part of Phase 4" /Users/maneeshdhabria/Desktop/Projects/agent-skills/plugins/pmos-toolkit/skills/verify/SKILL.md
```

Expected: three matching lines, all inside the Phase 4 section (line numbers in the 150–210 range).

Also confirm 3a is still present:

```bash
grep -n "### 3a. Database Migrations" /Users/maneeshdhabria/Desktop/Projects/agent-skills/plugins/pmos-toolkit/skills/verify/SKILL.md
```

Expected: one match, appearing AFTER the entry gate section.

- [ ] **Step 4: Commit**

```bash
git add plugins/pmos-toolkit/skills/verify/SKILL.md
git commit -m "$(cat <<'EOF'
feat(pmos-toolkit/verify): Phase 4 entry gate — TodoWrite enumeration + evidence-type allowlist

Text-only warnings against skipping verification were ignored in practice
because the agent had no structural trigger to enumerate work upfront.
The FR compliance table in Phase 5 came too late — by then the final
report was already being drafted.

Add a Phase 4 entry gate that requires one TodoWrite task per
runtime-surface FR/journey, each with a declared evidence type from an
allowlist per sub-step. Three-state outcome (Verified / NA-with-alt-
evidence / Unverified-action-required) closes the 'Pass/Fail' escape
hatch at the enumeration layer. Setup (dev server, seed data) is
declared part of Phase 4, not a prerequisite.
EOF
)"
```

---

## Task 3: Add Phase 4 Red Flags table

**Why:** The post-mortem identified six specific rationalizations the agent used to skip Phase 4 ("tests passed, close it out", "out of scope for /verify", "user can verify at desk", etc.). Naming them in the agent's own voice — following the `using-superpowers` pattern — makes the rationalization recognizable in-flight. This complements the structural gate in Task 2 (which tells the agent WHAT to do) by telling it WHAT THOUGHTS signal it's about to NOT do it.

**Files:**
- Modify: `plugins/pmos-toolkit/skills/verify/SKILL.md` — insert immediately after the entry gate section from Task 2 and before `### 3a. Database Migrations`.

- [ ] **Step 1: Insert the Red Flags table**

This edit anchors on the closing line of Task 2's entry gate and the 3a heading that follows it. The anchor text below must match exactly what Task 2 produced.

```
Edit tool:
old_string: |
  "Setup would take too long" is a Phase 4 red flag, not a reason.

  ### 3a. Database Migrations (if applicable)
new_string: |
  "Setup would take too long" is a Phase 4 red flag, not a reason.

  ### Phase 4 Red Flags — rationalizations that mean you're about to skip

  If any of these thoughts surface during Phase 4, stop and re-read the entry gate. Each is a rationalization the skill has seen and named:

  | Thought | Reality |
  |---------|---------|
  | "Automated tests already pass — good enough" | Automated tests miss UX, rendering, timing, and copy issues. The entry gate still applies. Every enumerated todo still needs evidence. |
  | "This is out of scope for /verify" | Phase 4 is a numbered phase in this skill. Verification cannot be out of scope for the verification skill. |
  | "The user can verify this at their desk" | Playwright MCP, `curl`, and DB queries are agent-owned tools. Offloading interactive verification to the user resolves to `Unverified — action required`, not `Verified`. |
  | "Setup would take too long" | Setup is Phase 4 work. If you have time to write the final report, you have time to start the server. |
  | "The happy path worked; good enough" | The spec's edge cases are explicit. Test at least one error/edge path per affected flow — the entry gate names this in 3e's evidence row. |
  | "I'll note it as a gap" | A gap you could have verified but didn't is not a gap — it's a skip. Either produce evidence (close as Verified), cite alternative evidence (close as NA), or name the blocker (leave open as Unverified-action-required). There is no fourth state. |

  ### 3a. Database Migrations (if applicable)
```

- [ ] **Step 2: Verify the insertion**

```bash
grep -n "Phase 4 Red Flags\|rationalization the skill has seen" /Users/maneeshdhabria/Desktop/Projects/agent-skills/plugins/pmos-toolkit/skills/verify/SKILL.md
```

Expected: two matching lines.

Structural sanity check — Phase 4 section order should now be:

```bash
grep -n "^## Phase 4\|^### Phase 4 Entry Gate\|^### Phase 4 Red Flags\|^### 3a\. Database" /Users/maneeshdhabria/Desktop/Projects/agent-skills/plugins/pmos-toolkit/skills/verify/SKILL.md
```

Expected: four lines in this exact order — `## Phase 4`, `### Phase 4 Entry Gate`, `### Phase 4 Red Flags`, `### 3a. Database Migrations`.

- [ ] **Step 3: Commit**

```bash
git add plugins/pmos-toolkit/skills/verify/SKILL.md
git commit -m "$(cat <<'EOF'
feat(pmos-toolkit/verify): Phase 4 Red Flags table names the skip rationalizations

Named rationalizations are harder to rationalize through than unnamed
instincts. The six rows come from a real post-mortem of a session where
Phase 4 was skipped despite anti-pattern warnings — 'tests passed',
'out of scope', 'user can verify', 'setup takes too long', 'happy path
worked', 'I'll note as gap'. Each is paired with the specific resolution
from the entry gate's three-state model.
EOF
)"
```

---

## Task 4: Three-state outcome model + Evidence column for Phase 5 compliance tables (4a, 4b, 4c)

**Why:** The current Phase 5 tables use `Pass/Fail`, `Pass/Fail/Partial`, and `Complete/Partial/Missing` as status columns — all binary-ish and none with a slot for "I didn't actually verify this." The agent can mark a row "Pass" based on a unit test passing without the UI or runtime surface ever being exercised. Scope extension per user request: apply the three-state model to 4a (Requirements) and 4c (Plan) in addition to 4b (Spec). The states differ slightly between "requirement verification" (4a, 4b) and "plan task completion" (4c), but the principle — no completion claim without evidence or explicit blocker — is identical.

**Files:**
- Modify: `plugins/pmos-toolkit/skills/verify/SKILL.md` — add a Phase 5 preamble, then replace three tables.

- [ ] **Step 1: Add a three-state preamble to Phase 5**

Insert a shared three-state model definition immediately after the `## Phase 5: Spec Compliance Check` section intro line and before `### 4a. Requirements Compliance`.

```
Edit tool:
old_string: |
  ## Phase 5: Spec Compliance Check

  This is the most important phase. Re-read each upstream document and verify every requirement is implemented.

  ### 4a. Requirements Compliance
new_string: |
  ## Phase 5: Spec Compliance Check

  This is the most important phase. Re-read each upstream document and verify every requirement is implemented.

  **Three-state outcome model (applies to 4a, 4b, 4c):**

  Every row in every compliance table resolves to exactly one of three outcomes. Bare "Pass", "Fail", "Complete", or "Partial" are not valid — they collapse into the three below, and every row's `Evidence` column must cite a concrete artifact.

  | Outcome | Meaning | Required in Evidence column |
  |---------|---------|----------------------------|
  | **Verified** | Requirement/task met; evidence produced during Phase 2–4. | Test file + function, screenshot path, `curl` output excerpt, DB query result, or commit SHA. The evidence type must match what was declared in the Phase 4 entry gate allowlist if the row has a runtime surface. |
  | **NA (alt-evidence)** | No runtime surface for this row, OR the row was intentionally out of scope and covered indirectly. | Named alternative: e.g., "covered by `test_pricing.py::test_discount_applied`", or the specific reason tied to the requirement text (e.g., "FR narrative change only — no code path"). Bare "NA" or "N/A" is not valid. |
  | **Unverified — action required** | Verification was attempted and blocked. The row is NOT resolved. | The specific blocker and the user action needed to unblock (e.g., "Playwright MCP unavailable in this environment — user must install; re-run 3d after"). Unverified rows must also appear in the Phase 8 final report as open items. |

  Every row also cross-references the todo it closed (or left open) from the Phase 4 entry gate, if applicable. If no Phase 4 todo was created (pure internal logic), the Evidence column names the unit test that covered it.

  ### 4a. Requirements Compliance
```

- [ ] **Step 2: Update the 4a Requirements table**

```
Edit tool:
old_string: |
  Read `{docs_path}/requirements/<file>`. For every goal, user journey, and acceptance criterion:

  | # | Requirement | Status | Evidence |
  |---|-------------|--------|----------|
  | Goal 1 | [From requirements] | Pass/Fail/Partial | [Test name, screenshot, or curl output] |
  | Journey 1, Step 3 | [Specific step] | Pass/Fail | [How verified] |
new_string: |
  Read `{docs_path}/requirements/<file>`. For every goal, user journey, and acceptance criterion:

  | # | Requirement | Outcome | Evidence |
  |---|-------------|---------|----------|
  | Goal 1 | [From requirements] | Verified / NA / Unverified | [Per the three-state model: test file, screenshot path, curl excerpt, DB query, alt-evidence citation, or blocker + user action] |
  | Journey 1, Step 3 | [Specific step] | Verified / NA / Unverified | [e.g., `screenshots/j1-s3.png` from Phase 4 3d, or `Unverified — dev server wouldn't start; user must run docker compose up`] |
new_string note: use exact indentation from the file
```

Note for implementer: the above `old_string` must match the file's current exact indentation (two leading spaces on each content line inside the table). If the Edit fails on non-unique match, use the Read tool to confirm the exact whitespace and retry.

- [ ] **Step 3: Update the 4b Spec table**

```
Edit tool:
old_string: |
  Read `{docs_path}/specs/<file>`. For every FR-ID and edge case:

  | ID | Requirement | Status | Evidence |
  |----|-------------|--------|----------|
  | FR-01 | [From spec] | Pass/Fail | [Test name or interactive verification artifact] |
  | FR-02 | ... | ... | ... |
  | E1 | [Edge case] | Pass/Fail | [How verified] |
new_string: |
  Read `{docs_path}/specs/<file>`. For every FR-ID and edge case:

  | ID | Requirement | Outcome | Evidence |
  |----|-------------|---------|----------|
  | FR-01 | [From spec] | Verified / NA / Unverified | [Per the three-state model — e.g., `test_orders.py::test_checkout_flow`, or `screenshots/fr-01-checkout.png`, or `Unverified — Stripe webhook endpoint requires live deploy`] |
  | FR-02 | ... | ... | ... |
  | E1 | [Edge case] | Verified / NA / Unverified | [Evidence for the edge case specifically, not the happy path] |
```

Note: the Task 1 edit left the cell text as `[Test name or interactive verification artifact]`; Task 4 replaces that entire row format. If the file state has drifted, Read first to confirm.

- [ ] **Step 4: Update the 4c Plan table**

Plan task completion is different from requirement verification — the three states adapt accordingly but preserve the principle (no unexamined completion claims).

```
Edit tool:
old_string: |
  Read `{docs_path}/plans/<file>`. For every task:

  | Task | Status | Notes |
  |------|--------|-------|
  | T1: [Name] | Complete/Partial/Missing | [Any issues] |
  | T2: ... | ... | ... |
new_string: |
  Read `{docs_path}/plans/<file>`. For every task:

  | Task | Outcome | Evidence |
  |------|---------|----------|
  | T1: [Name] | Verified-complete / NA-skipped-with-reason / Unverified | [Commit SHA(s) implementing the task + at least one test or Phase 4 verification artifact; OR the decision record for an intentional skip (e.g., "merged into T3 during execution"); OR the blocker + user action] |
  | T2: ... | ... | ... |

  **For plan-task outcomes:**
  - `Verified-complete` requires BOTH a commit reference AND a verification artifact (test, screenshot, curl excerpt). A commit alone is not evidence of correctness — only of existence.
  - `NA-skipped-with-reason` requires naming the decision AND where it was recorded (plan update, session log, commit message). "NA" without a reason is not valid.
  - `Unverified` means the task was claimed done but the verification couldn't be produced. This is a gap — surface it in the 4d Gap Report.
```

- [ ] **Step 5: Verify all three tables updated consistently**

```bash
grep -n "Pass/Fail\|Complete/Partial/Missing" /Users/maneeshdhabria/Desktop/Projects/agent-skills/plugins/pmos-toolkit/skills/verify/SKILL.md
```

Expected: empty output. Any match means a compliance table still uses the old binary status.

```bash
grep -n "Verified / NA / Unverified\|Verified-complete / NA-skipped-with-reason / Unverified" /Users/maneeshdhabria/Desktop/Projects/agent-skills/plugins/pmos-toolkit/skills/verify/SKILL.md
```

Expected: at least three matches (one per table). The preamble does NOT need to contain this exact string — it describes the states in its own table format.

- [ ] **Step 6: Commit**

```bash
git add plugins/pmos-toolkit/skills/verify/SKILL.md
git commit -m "$(cat <<'EOF'
feat(pmos-toolkit/verify): three-state outcome + evidence citations for Phase 5 4a/4b/4c compliance tables

Pass/Fail/Complete/Partial let the agent claim completion without ever
exercising the runtime surface — the status column had no slot for 'I
didn't actually verify this'.

Replace with Verified / NA-with-alt-evidence / Unverified-action-required
across all three compliance tables (Requirements, Spec, Plan). Evidence
column becomes mandatory — bare NA and bare Complete are no longer valid
states. Plan table adapts the model for task-completion semantics while
preserving the no-unexamined-claims principle.
EOF
)"
```

---

## Task 5: Consolidate the Anti-Patterns section

**Why:** The existing Anti-Patterns list on line 337 contains `Do NOT skip manual verification` — the exact warning that was read and ignored in the incident that motivated this plan. That bullet is now structurally superseded by the Phase 4 entry gate (Task 2) and Red Flags table (Task 3). Leaving it in place creates drift (two places saying similar things, neither authoritative). The "known gaps" bullet also needs updating to reference the three-state model.

**Files:**
- Modify: `plugins/pmos-toolkit/skills/verify/SKILL.md` — rewrite the Anti-Patterns section (lines 335–346).

- [ ] **Step 1: Rewrite the Anti-Patterns section**

```
Edit tool:
old_string: |
  ## Anti-Patterns (DO NOT)

  - Do NOT skip manual verification — automated tests miss UX issues, rendering bugs, and timing problems
  - Do NOT mark failing tests as skip to make the suite pass
  - Do NOT claim "tests pass" without showing the output
  - Do NOT skip the spec compliance check — this is the most valuable phase
  - Do NOT leave discovered issues as "known gaps" — fix them and add regression tests
  - Do NOT commit debug logging, TODOs, or temporary workarounds
  - Do NOT verify only the happy path — test at least one error/edge case
  - Do NOT assume the previous verification run is still valid — re-run after every fix
  - Do NOT skip the hardening phase — converting bugs to tests is what prevents regressions
new_string: |
  ## Anti-Patterns (DO NOT)

  For Phase 4 skip rationalizations specifically, see the **Phase 4 Red Flags** table — those six thoughts are the most common skips and are named individually there. This section covers general-purpose anti-patterns that apply across phases.

  - Do NOT mark failing tests as skip to make the suite pass
  - Do NOT claim "tests pass" without showing the output
  - Do NOT skip the Phase 5 spec compliance check — this is the most valuable phase
  - Do NOT leave discovered issues as "known gaps" — every item resolves to one of the three Phase 5 states (Verified, NA-with-alt-evidence, or Unverified-action-required with a named blocker). There is no fourth state.
  - Do NOT commit debug logging, TODOs, or temporary workarounds
  - Do NOT verify only the happy path — every affected flow gets at least one error/edge case per the Phase 4 entry gate's 3e evidence row
  - Do NOT assume the previous verification run is still valid — re-run after every fix
  - Do NOT skip the Phase 6 hardening phase — converting bugs to tests is what prevents regressions
```

- [ ] **Step 2: Verify the rewrite**

```bash
grep -n "^## Anti-Patterns\|Do NOT skip manual\|Phase 4 Red Flags\|no fourth state" /Users/maneeshdhabria/Desktop/Projects/agent-skills/plugins/pmos-toolkit/skills/verify/SKILL.md
```

Expected matches:
- One `## Anti-Patterns (DO NOT)` heading
- Zero `Do NOT skip manual` matches (the superseded bullet is removed)
- At least two `Phase 4 Red Flags` matches (one from Task 3 section heading, one from this section's cross-reference)
- One `no fourth state` match (the rewritten known-gaps bullet)

If `Do NOT skip manual` still returns a match, the old bullet was not removed — re-run Step 1.

- [ ] **Step 3: Commit**

```bash
git add plugins/pmos-toolkit/skills/verify/SKILL.md
git commit -m "$(cat <<'EOF'
refactor(pmos-toolkit/verify): consolidate Anti-Patterns — remove superseded 'skip manual verification' bullet

The 'Do NOT skip manual verification' bullet is now structurally
superseded by the Phase 4 entry gate (TodoWrite enumeration) and the
Phase 4 Red Flags table (named rationalizations). Keeping it created
drift between prose warnings and structural gates — and prose warnings
are the ones that got ignored.

Rewrite 'known gaps' bullet to reference the three-state model. Add a
pointer from Anti-Patterns to Phase 4 Red Flags so agents reading the
end of the file find the structural guidance.
EOF
)"
```

---

## Task 6: Version bump

**Why:** This set of changes is a material behavioral upgrade to the `/verify` skill (new entry gate, new outcome model, new Red Flags table). Plugin versions should reflect material changes so users reading the commit log or release notes can tell what happened. The last release was 1.4.0; this warrants a minor bump to 1.5.0.

**Files:**
- Modify: `plugins/pmos-toolkit/.claude-plugin/plugin.json`

- [ ] **Step 1: Bump plugin.json version**

```
Edit tool:
file: /Users/maneeshdhabria/Desktop/Projects/agent-skills/plugins/pmos-toolkit/.claude-plugin/plugin.json
old_string: "  \"version\": \"1.4.0\","
new_string: "  \"version\": \"1.5.0\","
```

- [ ] **Step 2: Verify the bump**

```bash
grep '"version"' /Users/maneeshdhabria/Desktop/Projects/agent-skills/plugins/pmos-toolkit/.claude-plugin/plugin.json
```

Expected: `"version": "1.5.0",`

- [ ] **Step 3: Final structural read-through**

Before committing, read the full modified SKILL.md top-to-bottom one time and confirm:
- The Phase 4 section reads in this order: intro heading → Entry Gate → Red Flags → 3a → 3b → 3c → 3d → 3e.
- The Phase 5 section reads: intro + three-state preamble → 4a table (three states) → 4b table (three states) → 4c table (adapted three states) → 4d Gap Report (unchanged — it already fits).
- "Manual" only appears in legitimate senses ("manual implementation" / "manual coding" = code written by a human without /execute). No stray "manual verification" or "manual step for the user."
- The Anti-Patterns section no longer contains the superseded bullet and contains the cross-reference to Phase 4 Red Flags.
- Line 21 in the Platform Adaptation section is the rewritten version forbidding offloading.

If any check fails, fix it inline before committing and re-run the read-through.

- [ ] **Step 4: Commit**

```bash
git add plugins/pmos-toolkit/.claude-plugin/plugin.json
git commit -m "$(cat <<'EOF'
chore(pmos-toolkit): bump to v1.5.0 for /verify skill structural upgrade

/verify now has structural enforcement against silent skipping:
- Phase 4 entry gate with TodoWrite enumeration + evidence-type allowlist
- Phase 4 Red Flags table naming six specific skip rationalizations
- Phase 5 compliance tables use Verified / NA-with-alt-evidence /
  Unverified-action-required across 4a (Requirements), 4b (Spec), and
  4c (Plan)
- 'Manual' verification language replaced with 'interactive' to kill
  the offload ambiguity; Platform Adaptation no longer licenses
  offloading to the user when Playwright MCP is unavailable
EOF
)"
```

---

## Final verification (after all six tasks commit)

Run these checks from the repo root and confirm each expectation:

```bash
# 1. No stray 'manual' in verification contexts
grep -n "manual verification\|manual step for the user\|Manual Spot Checks\|Manual verification catches" plugins/pmos-toolkit/skills/verify/SKILL.md
```

Expected: empty.

```bash
# 2. No binary status labels in compliance tables
grep -n "Pass/Fail\|Complete/Partial/Missing" plugins/pmos-toolkit/skills/verify/SKILL.md
```

Expected: empty.

```bash
# 3. Entry gate, Red Flags, three-state preamble all present
grep -c "Phase 4 Entry Gate\|Phase 4 Red Flags\|Three-state outcome model" plugins/pmos-toolkit/skills/verify/SKILL.md
```

Expected: `3`.

```bash
# 4. Commit log shows six focused commits
git log --oneline -n 7 | head -6
```

Expected: six commits titled along the lines of rename-manual, entry-gate, red-flags, three-state, consolidate-anti-patterns, bump-v1.5.0 — in that order.

```bash
# 5. Plugin version bumped
grep '"version"' plugins/pmos-toolkit/.claude-plugin/plugin.json
```

Expected: `"version": "1.5.0",`.

If every check passes, the plan is complete. Report back to the user with the commit log and a one-line summary of each commit's behavioral change.

---

## Self-review notes (for the plan author, not the implementer)

Checked against the agreed scope in the prior turn:
- ✅ Language fix: "manual" → "interactive" + line 21 offload license rewrite → Task 1
- ✅ Phase 4 entry gate via TodoWrite → Task 2
- ✅ Evidence-type allowlist per sub-step → Task 2 (folded into entry gate, single location)
- ✅ Phase 4 Red Flags table → Task 3
- ✅ Three-state + evidence for 4b → Task 4
- ✅ Scope extension: three-state + evidence for 4a and 4c → Task 4
- ✅ Anti-Patterns consolidation (remove superseded bullet, cross-ref Red Flags) → Task 5
- ✅ Version bump → Task 6

Placeholder scan: no "TBD", "implement later", "similar to Task N", or vague "add appropriate X" instructions. Every Edit shows the full old_string and new_string. Commit messages are fully written.

Type/name consistency check:
- "Verified / NA / Unverified" is used consistently in 4a and 4b.
- "Verified-complete / NA-skipped-with-reason / Unverified" is the adapted form for 4c (intentionally different because plan tasks are not requirements — preserved in the preamble).
- "Phase 4 Entry Gate" heading text is identical in Tasks 2, 3, 5, and the final verification.
- "Phase 4 Red Flags" heading text is identical in Tasks 3, 5, and the final verification.
- Evidence-type table rows (3a–3e) align with the existing Phase 4 sub-step numbering.

Known minor risk: Task 2's entry gate section is large (~40 lines inserted in one Edit). If the implementer's Edit tool balks at the multi-line `old_string`, the fallback is to split into two Edits: first insert a placeholder heading under `## Phase 4`, then Edit the placeholder into the full section. Flagged here so the implementer isn't surprised.
