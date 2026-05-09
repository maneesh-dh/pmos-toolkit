# Per-skill HTML-rewrite runbook

> **The cross-cutting recipe each pipeline skill follows to switch its feature-folder artifact from `<NN>_<artifact>.md` to `<NN>_<artifact>.html`.** Decision Log P1 picked the runbook-as-SSOT pattern over a pure code mod: each affected SKILL.md cites this file by relative path and applies §§2–6 as `Edit` operations to its own write phase.

Authored as part of T8 (pilot: `/requirements`); rolled out across the remaining 9 skills in T9; applied to the `/feature-sdlc` orchestrator artifacts (`00_pipeline.html`, `00_open_questions_index.html`) in T10.

**Spec refs:** FR-10, FR-10.1, FR-10.2, FR-10.3, FR-12, FR-12.1, FR-13, FR-14, FR-15 (wireframes/prototype unmodified), FR-27, FR-71, FR-90, FR-03.1, FR-33.

---

## 1. Pre-edit checks

Before applying §§2–6 to a skill:

1. **Confirm SKILL.md write-phase line numbers.** `/spec` Subagent A's per-skill scan produces the canonical line ranges; verify them with a fresh `Read` of the SKILL.md (line numbers drift across releases). The /spec scan output is in §7.5 of `02_spec.md`.
2. **Verify no upstream `output_format` reference yet.** `grep -nE 'output_format' plugins/pmos-toolkit/skills/<skill>/SKILL.md` should return nothing under §§2–6 boundaries (otherwise the skill was already partially rewritten — see "Edge cases per-skill" below).
3. **Verify the existing snapshot-commit pattern is intact** (§6). Almost every skill already has it; if missing, that is a pre-existing defect to flag, not a runbook-introduced regression.
4. **Identify upstream reads.** `grep -nE '\.md\b' plugins/pmos-toolkit/skills/<skill>/SKILL.md | grep -vE 'workstream|learnings|pipeline-setup|backlog|legacy|sidecar'` enumerates the candidate sites for §5 (resolver) edits. The first-stage skill (`/requirements`) typically has zero such sites; downstream skills (`/spec`, `/plan`, `/simulate-spec`, etc.) have at least one.

---

## 2. Settings + flag block (Phase 0 addition)

Each affected skill gains an `output_format` honouring rule in its Phase 0. Mirror the existing `--non-interactive` precedence pattern.

**Placement (important — discovered in T8 pilot).** Skills that inline the canonical `<!-- pipeline-setup-block -->` region must NOT add the `output_format` step inside that block — the block is auto-managed and would clobber per-skill edits on a future re-inline. Instead, insert a small Phase 0 **addendum** *between* the `<!-- pipeline-setup-block:end -->` marker and the `<!-- non-interactive-block:start -->` marker. The addendum is owned by the skill body (skill-body-wins-on-conflict precedent).

**Insert** the following block in that addendum slot:

```markdown
### Phase 0 addendum: output_format resolution (FR-12)

7. **Resolve `output_format`.** Read `output_format` from `.pmos/settings.yaml` (default: `html`; valid values: `html`, `md`, `both`). A `--format <html|md|both>` argument-string flag overrides settings (last flag wins on conflict, per FR-12). Print to stderr exactly: `output_format: <value> (source: <cli|settings|default>)` once at Phase 0 entry. The numbering continues from the pipeline-setup-block above (which ends at step 6).
```

If the skill's argument-hint frontmatter does not yet include `[--format <html|md|both>]`, append it (FR-12 release-prerequisite mirror).

---

## 3. Write phase rewrite (the meat)

Locate the skill's "Save to `<NN>_<artifact>.md`" sentence (or equivalent) and **replace it** with the canonical block below. Substitute `<NN>_<artifact>` with the skill's actual artifact stem (e.g., `01_requirements`, `02_spec`, `03_plan`, `msf-findings`, etc.).

### Canonical write-phase prose

```markdown
Save to `{feature_folder}/<NN>_<artifact>.html` per the substrate at `${CLAUDE_PLUGIN_ROOT}/skills/_shared/html-authoring/`.

**Atomic write (FR-10.2):** write `<NN>_<artifact>.html` and the companion `<NN>_<artifact>.sections.json` via temp-then-rename — never serve a half-written file.

**Asset substrate (FR-10):** copy `assets/*` from `${CLAUDE_PLUGIN_ROOT}/skills/_shared/html-authoring/assets/` to `{feature_folder}/assets/` if not already present. The substrate currently includes `style.css`, `viewer.js`, `serve.js`, `html-to-md.js`, `turndown.umd.js`, `turndown-plugin-gfm.umd.js`, and `LICENSE.turndown.txt`; new substrate files added in future releases ride along automatically without per-skill prose updates. Idempotent — `cp -n` (no-clobber) or `rsync --update` skips identical files; on initial setup an unconditional `cp assets/* feature_folder/assets/` is fine.

**Asset prefix (FR-10.1):** compute the per-folder relative asset prefix. For top-level feature-folder artifacts the prefix is `assets/`; for nested-folder artifacts (`wireframes/`, `prototype/`, `grills/`, `simulate-spec/`, `verify/<scope>/`) the prefix is `../assets/` (one level up).

**Cache-bust (FR-10.3):** append `?v=<plugin-version>` to all asset URL references emitted into the HTML (the substrate `template.html` already does this for the loader pair; skill-emitted inline `<link>` / `<script>` references must follow suit).

**Heading IDs (FR-03.1):** every `<h2>` and `<h3>` MUST carry a stable kebab-case `id`. See §4 below.

**Index regeneration (FR-22, §9.1):** after the artifact write completes, regenerate `{feature_folder}/index.html` by inlining the manifest per `_shared/html-authoring/index-generator.md` (no on-disk `_index.json` is written; the manifest is inlined as `<script type="application/json" id="pmos-index">`, FR-41). Honour the §9.1 phase-rank ordering policy.

**Mixed-format sidecar (FR-12.1):** when `output_format` resolves to `both`, also emit `<NN>_<artifact>.md` by piping the freshly-written HTML through `bash node {feature_folder}/assets/html-to-md.js <NN>_<artifact>.html > <NN>_<artifact>.md`. The MD sidecar is read-only — never the source of truth (FR-33).
```

### Argument-hint update

If the skill writes its own argument hint, ensure `[--format <html|md|both>]` is present.

---

## 4. Heading-id rule (authoring guidance)

Insert into the skill's "Templates" or "Authoring guidance" section the following one-paragraph block (FR-03.1):

```markdown
**Heading IDs (FR-03.1, enforced by `/verify`).** Every `<h2>` and `<h3>` carries a stable kebab-case `id`. Compute via `_shared/html-authoring/conventions.md` §3 — lowercase the heading text, replace every non-alphanumeric run with a single `-`, trim leading/trailing `-`, dedupe collisions with `-2`/`-3`/... suffixes. Stable IDs let cross-doc anchors (`02_spec.html#fr-10`, `03_plan.html#t8`) resolve deterministically across regenerations. `assert_heading_ids.sh` (T22) blocks any artifact missing an id.
```

The `<h1>` is emitted by `template.html` and never appears inside `{{content}}` — do NOT add an id-rule line for `<h1>`.

---

## 5. Read-upstream resolver calls (FR-33)

Replace every direct `Read` of an upstream artifact at a hard-coded `.md` path with a `_shared/resolve-input.md` resolver call. Canonical wording in the skill body:

```markdown
**Locate the upstream <name>.** Follow `_shared/resolve-input.md` with `phase=<requirements|spec|plan|msf-findings|grills|simulate-spec|verify>`, `label="<human-readable label for error messages>"`. Use the returned absolute path with the `Read` tool.
```

Sites to rewrite:

| Skill | Upstream | Resolver phase argument |
|---|---|---|
| `/spec` | requirements | `phase=requirements` |
| `/plan` | spec | `phase=spec` |
| `/msf-req` | requirements | `phase=requirements` |
| `/msf-wf` | wireframes index | (NA — resolver covers single-artifact paths; msf-wf reads a directory) |
| `/simulate-spec` | spec | `phase=spec` |
| `/grill` | the targeted artifact | `phase=<requirements\|spec\|plan>` per the user's `/grill` argument |
| `/verify` | spec + plan | two calls: `phase=spec`, `phase=plan` |
| `/design-crit` | wireframes/prototype | (NA — directory-scoped, not single-artifact) |

**Skills with no upstream `.md` reads:** `/requirements` (first-stage), `/artifact` (template-store, separate carve-out). For these, §5 is a no-op — verify by `grep`.

**MUST NOT** bypass the resolver by `Read`-ing a hard-coded `<NN>_<artifact>.md` path. T20 (`assert_no_md_to_html.sh`) catches these as a per-skill grep gate.

---

## 6. Snapshot-commit pattern (preserved)

Most skills already carry a snapshot-commit block:

```bash
git add {feature_folder}/<NN>_<artifact>.<ext>
git commit -m "snapshot: pre-/<skill>-rewrite"
```

The runbook does **not** modify this block beyond updating the file extension referenced in `git add` to `.html` (and, when `output_format: both`, adding the `.md` sidecar to the same `git add` line). Idempotent and back-compat — legacy folders with a `.md` primary still get snapshotted because `git add` on a non-existent path is a no-op rather than a failure.

---

## 7. Verification (per-skill)

Run after applying §§2–6 to a skill:

```bash
# T20 (lands in Phase 4): per-skill grep gate.
bash tests/scripts/assert_no_md_to_html.sh plugins/pmos-toolkit/skills/<skill>/

# T20 inline-substitute (until T20 lands): single grep that approximates the gate.
! grep -rEn '<NN>_<artifact>\.md\b' plugins/pmos-toolkit/skills/<skill>/SKILL.md \
  | grep -vE 'legacy|sidecar|resolve-input|backlog/items|workstream'

# T22 (lands in Phase 4): heading-id assertion against a fixture artifact.
bash tests/scripts/assert_heading_ids.sh <feature_folder>/<NN>_<artifact>.html
```

Pre-T20/T22 runs use the inline grep substitute. Once T20/T22 land, callers cut over to the canonical assertions.

---

## 8. Open Questions accumulation (unchanged)

The cross-cutting non-interactive contract's OQ buffer (`<!-- non-interactive-block:start -->` region) is **not modified by this runbook**. The OQ flush rule (FR-03) writes either to the artifact's frontmatter (legacy MD primary) or to the artifact's `## Open Questions (Non-Interactive Run)` section (HTML primary, in a `<section id="open-questions">`). Each affected skill's existing OQ buffer block already inlines the contract; runbook authors do not touch it.

---

## Per-skill edge cases

Append rows to this section as T8 step 5 (post-pilot) and T9 fanout discover skill-specific quirks.

| Skill | Edge case | Mitigation |
|---|---|---|
| `/wireframes`, `/prototype` | Wireframes and prototypes are **already HTML** (the substrate uses `wf-` classes + standalone HTML files). The runbook does NOT apply to these skills' artifact-emission paths. | Skip. T9 explicitly excludes `/wireframes` and `/prototype` from the rollout table. The `/msf-wf` skill writes a `wireframes/msf-findings.md` sidecar — apply the runbook to that path, not to the wireframes themselves. |
| `/simulate-spec` (F3 review-loop fix) | `/simulate-spec` writes the trace artifact (`simulate-spec/<date>-trace.html` under runbook); spec patches via the `Edit` tool are **unchanged** because the spec is already HTML by the time `/simulate-spec` runs. The runbook applies only to the trace-write phase. | Apply §§2–6 only to the trace-write site; leave `Edit`-tool spec-patching paragraphs untouched. |
| `/feature-sdlc` (T10) | The orchestrator emits `00_pipeline.html` (Phase 1 init-state) and `00_open_questions_index.html` (Phase 11 final summary). Both follow the runbook. The orchestrator does NOT emit a sections.json companion for `00_pipeline.html` — it has no `<h2>`-anchored TOC. | Skip the `<NN>_<artifact>.sections.json` line for orchestrator artifacts. Keep the heading-id rule (`/verify` smoke still asserts it). |
| `/artifact` (FR-11 carve-out) | Template store at `~/.pmos/artifacts/templates/<slug>/template.md` retains MD shape. The runbook applies only to the **feature-folder write phase** (R7 in T9 rollout). | Scope the §3 rewrite to the feature-folder emission site; leave the `~/.pmos/artifacts/` template-store paths as `.md`. |
| Wireframe screen affordances (F1 review-loop fix, FR-27) | `wireframes/01_index-default_desktop-web.html` ships with a `Search ⌘K` placeholder button. The runbook does NOT modify wireframes, but T8 step 6 removes that affordance to align with FR-27. Any skill that references "the wireframes" should NOT assume `⌘K` is present — base behavior on the spec, not the wireframe. | Author note: skills citing wireframe screens by ID should reference the wireframe's `data-pmos-section` ids, not visual affordances that may shift. |
| `/grill` argument shape | `/grill` accepts a target-artifact argument (e.g., `/grill 01_requirements`). The §5 resolver call requires the caller to pass `phase=<requirements\|spec\|plan>` derived from that argument. | Inline the derivation explicitly in `/grill`'s SKILL.md edit (R6 in T9 rollout); a switch/case based on the user-supplied target-artifact stem. |
| Auxiliary sidecars / read-back-edited fallbacks | Some skills emit auxiliary tracking files alongside the primary artifact: `/plan` writes `03_plan_review.md`, `03_plan_skip-list.md`, `03_plan_auto.md`, `03_plan_blocked.md`. `/design-crit` writes `eval-findings-review.md` as a platform-fallback the user fills in by hand. These are NOT the skill's primary artifact — the runbook governs only the primary. | Keep these as `.md`. The holistic T20 substitute filter excludes `_review\|_skip-list\|_auto\|_blocked\|eval-findings-review`. Discovered during T9 holistic post-R9 grep gate. |

---

## Idempotence

Re-running any §§2–6 procedure on an already-edited SKILL.md is **idempotent**: the canonical write-phase prose contains the substrings `<NN>_<artifact>.html`, `_shared/html-authoring/`, `FR-10.2`, etc., which a `grep` can detect. Skills that have been rewritten satisfy `! grep -rE '<NN>_<artifact>\.md\b' SKILL.md` (modulo legacy-citation excepts) — the gate is the absence of MD primary references, which a re-run preserves.
