# Context Loading Instructions

Reference document for pipeline skills. Follow these steps at the START of every pipeline skill, before any other work.

---

## Step 1: Determine docs_path

1. Check if `.pmos/settings.yaml` exists in the current repo
2. **If found:** read `docs_path` from it. If `docs_path` is not specified, default to `.pmos`
3. **If not found:** use `docs/` as the default (backward compatible — preserves existing behavior)

Use `{docs_path}` everywhere the skill references artifact directories (requirements/, specs/, plans/, session-log.md, changelog.md). Create subdirectories under `docs_path` as needed on first write.

---

## Step 2: Load Workstream Context

If `.pmos/settings.yaml` exists:

1. Read the `workstream` field
2. Load `~/.pmos/workstreams/{workstream}.md`
3. Parse the frontmatter — if `type` is `charter` or `feature` AND has a `product` field, also load `~/.pmos/workstreams/{product}.md` as read-only parent context
4. Inject the workstream content as context preamble — use it to inform the skill's work (brainstorming, technical decisions, solution direction, etc.)

If `.pmos/settings.yaml` does NOT exist, run the fallback (Step 3).

---

## Step 3: Fallback Behavior

When no `.pmos/settings.yaml` exists:

1. Check if `~/.pmos/workstreams/` directory has any `.md` files
2. **If workstreams exist** — list them with options:
   ```
   I found these workstreams:

     1. My Fintech App (product)
     2. Payments Redesign (charter)
     3. Search V2 (feature)
     4. Create a new workstream

   Which one is this repo related to? (or 'none' to skip)
   ```
   Read each workstream file's frontmatter to get the name and type for display.

   - **User picks an existing workstream:** Create `.pmos/settings.yaml` with `workstream: {slug}` and `docs_path: .pmos`, then load context per Step 2
   - **User picks "Create a new workstream":** Run `/context init`, then continue with the pipeline skill
   - **User picks "none" / skips:** Proceed without context, using `docs/` as docs_path

3. **If no workstreams exist** — ask:
   > "No workstream context found. Want to set one up? (This helps pipeline skills produce more relevant output.)"

   - **Yes:** Run `/context init`, then continue
   - **No:** Proceed without context, using `docs/` as docs_path

This fallback is a one-time prompt per repo — once `.pmos/settings.yaml` is created, it never triggers again.

---

## Step 4: Workstream Enrichment (at session end)

Run this AFTER the skill's main work is complete, before the final commit.

**Skip if:** no workstream was loaded in Step 2, or the user skipped context in the fallback.

1. Re-read the current workstream file
2. Compare the artifact produced in this session against the workstream sections
3. Look for signals that map to empty or thin workstream sections:

   | Skill | Signals to capture |
   |-------|-------------------|
   | `/requirements` | User segments, problem statements, metrics, value prop |
   | `/spec` | Tech stack decisions, architectural constraints, key decisions |
   | `/plan` | Technical dependencies, infrastructure details |
   | `/execute` | Key implementation decisions |
   | `/session-log` | Decisions with reasoning, gotchas |

4. If new signals found, draft concrete additions as a diff:
   ```
   Based on this session, I'd update your workstream context:

     ## User Segments
     + Small business owners (1-50 employees) managing        ← new
       invoices manually                                       ← new

     ## Key Metrics
     + Target: 40% reduction in manual invoice processing      ← new

   Apply these updates? (y/n)
   ```

5. **If approved:** Apply edits to `~/.pmos/workstreams/{workstream}.md` and bump the `updated` timestamp in frontmatter
6. **If declined:** Move on — nothing changes

**Rules:**
- Only propose additions for sections that are empty or clearly missing the new information
- Never replace existing content — append or expand
- Show the exact text that would be added, not a summary
- Keep proposals concise — 1-5 additions per session, not a full rewrite
