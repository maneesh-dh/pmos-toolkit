# /wireframes — Style Extraction & Screenshot Input

**Date:** 2026-04-30
**Skill:** `pmos-toolkit/wireframes`
**Status:** Spec

## Problem

Two gaps in `/wireframes`:

1. **Existing-repo style ignorance.** When the skill runs inside a repo that already has one or more frontends, generated wireframes use a generic neutral palette/typography. They drift from the host app's visual language, which makes review harder and forces rework at /spec time.
2. **No screenshot input.** Users frequently want to extend or rework an existing flow ("here are screenshots of today's onboarding, redesign step 3"). The skill has no path to ingest these — users either describe screens in prose or skip the skill.

## Goals

- Detect and surface the host repo's design tokens (colors, typography, spacing) and component library so generated wireframes look like they belong in that app.
- Accept screenshots (image paths or a directory) as a seed input alongside or instead of inline text descriptions; use them to anchor "extend this flow" wireframes.
- Both features are **opt-in** and **skippable** — they should not slow down clean-slate sessions.

## Non-Goals

- Pixel-perfect style matching. Wireframes remain mid-fi; we extract a "house style" hint, not a full design system.
- OCR or pixel-level image diffing. Rely on the model's native vision; no separate vision pipeline.
- Multi-repo style merging. If multiple frontends exist, pick one (user-selected) — do not blend.
- Replacing `/requirements`. Screenshots seed visual context, not problem definition.

## Design

### 1. Style Extraction (new Phase 2.5)

Insert between Phase 2 (component breakdown) and Phase 3 (generation), since the matrix is confirmed before we know what visual language to apply.

**Trigger:** Skill runs inside a git repo (`.git` exists) AND a frontend is detectable (any of: `package.json` with React/Vue/Svelte/Next/Nuxt deps; `tailwind.config.{js,ts,cjs,mjs}`; `**/*.css` with `:root` custom properties; `index.html` with `<style>` blocks).

**If no frontend detected:** skip silently, proceed with default neutral palette. Log "No host frontend detected — using default style" to the user.

**If frontend(s) detected:**

1. **Enumerate candidate frontends.** A "frontend" = a directory containing one of the trigger signals above. Common cases: monorepo with `apps/web`, `apps/admin`; single-app repo at root.
2. **If >1 candidate:** ask via `AskUserQuestion` (single-select) which frontend the wireframes should mirror. Options: each candidate path + "None — use default style". Platform fallback: pick the largest by file count and announce the assumption.
3. **Extract a "house style" summary.** Use a single subagent (or inline if no subagents) that reads:
   - `tailwind.config.*` → theme.extend.colors, fontFamily, spacing overrides
   - Top-level CSS files (`globals.css`, `app.css`, `index.css`, `styles/**/*.css`) → `:root` and `:root.dark` custom properties
   - `package.json` → component library hint (shadcn/ui, MUI, Chakra, Mantine, Radix, Headless UI, custom)
   - 2–3 representative page/component files (heuristic: largest `.tsx`/`.vue` files in `app/` or `pages/` or `src/components/`) → infer common component shapes (button radius, card style, nav pattern)

   Output as a **structured `house-style.json`** at `{feature_folder}/wireframes/assets/house-style.json`:

   ```json
   {
     "source": "apps/web",
     "tokens": {
       "colors": { "primary": "#…", "background": "#…", "foreground": "#…", "muted": "#…", "border": "#…", "destructive": "#…" },
       "radius": "0.5rem",
       "fontFamily": { "sans": "Inter, …", "mono": "…" }
     },
     "componentLibrary": "shadcn/ui",
     "patterns": {
       "button": "rounded-md, primary fills, ghost on hover",
       "card": "rounded-lg, border, p-6",
       "nav": "top horizontal, logo-left, links-right"
     },
     "notes": ["Dark mode supported via .dark class", "Uses lucide-react for icons"]
   }
   ```

4. **Generate `assets/house-style.css`** alongside the JSON — a small CSS file that overrides the relevant CSS variables in `wireframe.css` with the extracted token values. Each wireframe will link both `wireframe.css` AND (if present) `house-style.css` after it. This keeps the base vocabulary intact and just re-skins it.

5. **Show the user the extracted summary** and confirm via `AskUserQuestion`:
   - Options: **Use as extracted** / **Edit before applying** (opens the JSON in the editor — platform fallback: print path) / **Discard, use default style**.

6. **Generator subagents in Phase 3 receive `house-style.json`** as part of their context and are instructed to: (a) link `./assets/house-style.css` after `./assets/wireframe.css`, (b) match component shapes to the `patterns` hints (e.g., if `button: "rounded-md"`, use `rounded-md` not `rounded-full`).

**Failure modes:**
- Token extraction returns nothing useful → write an empty `house-style.json` with `"source": null` and skip the override CSS. Wireframes use the default theme.
- Conflicting tokens (e.g., dark+light both present) → prefer light mode tokens; note in `house-style.json.notes`.

### 2. Screenshot Input (extends Phase 1)

**Argument additions:**
- `--screenshots <path>`: file or directory of images. Multiple `--screenshots` flags allowed.
- Inline: if the user's prompt includes image attachments (Claude Code multimodal), treat those as screenshots.

**Phase 1 changes:**

1. **Detect screenshots.** Either flag-supplied paths or attached images in the conversation.
2. **Ingest.** For each screenshot:
   - `Read` the image (model vision describes it).
   - Extract: visible screen name/purpose, layout structure (header/sidebar/content/footer regions), key components, copy/labels visible, apparent state (empty / loaded / error / etc.), apparent device (desktop vs mobile from aspect ratio).
   - Append to a `{feature_folder}/wireframes/assets/source-screens.md` doc with one section per screenshot: filename, inferred name, structure, notes. Save the original images to `{feature_folder}/wireframes/assets/source-screens/` (copy, do not move).
3. **Use screenshots as journey anchors.** In Phase 1's journey confirmation, if screenshots map onto specific journey steps, surface that mapping to the user: "Screenshot `onboarding-step-2.png` looks like step 2 of the 'New user signup' journey. Use as the anchor for that step?" via `AskUserQuestion`. Options: **Yes, anchor to step 2** / **Different step** (free-form) / **Standalone reference, don't anchor**.
4. **Generator subagents in Phase 3 receive anchored screenshots' descriptions** for the components they're regenerating. Instruction: "Match the layout structure and IA of this source screen; you may improve states, accessibility, and copy, but do not redesign the IA without explicit user direction."

**Style extraction interaction:** if screenshots are provided AND no host frontend is detected, the Phase 2.5 extractor should *also* try to infer tokens from the screenshots themselves (dominant brand color, header style) and write those to `house-style.json` with `"source": "screenshots"`. This is best-effort — if the model isn't confident, leave it empty.

**Failure modes:**
- Unreadable image → log warning, skip that screenshot, continue.
- Screenshot doesn't map to any journey → keep as standalone reference; do not force a mapping.

### 3. Skill metadata changes

- **`description`** add: "Optional: extracts house style from an existing repo frontend and accepts screenshots (`--screenshots`) as flow anchors."
- **`argument-hint`** add `[--screenshots <path>]`.

### 4. Anti-pattern additions

- Do NOT blend tokens from multiple host frontends — pick one.
- Do NOT use screenshots as the sole journey source; they augment the req doc, they don't replace it.
- Do NOT redesign IA away from an anchored screenshot without explicit user direction.

## Artifacts produced

- `{feature_folder}/wireframes/assets/house-style.json` (always written when extraction runs, even if empty)
- `{feature_folder}/wireframes/assets/house-style.css` (when tokens extracted)
- `{feature_folder}/wireframes/assets/source-screens.md` (when screenshots provided)
- `{feature_folder}/wireframes/assets/source-screens/<original-files>` (when screenshots provided)

## Test / verification plan

Manual, since wireframes output is visual:

1. **No-host repo:** run `/wireframes` against a backend-only repo with a feature description → confirm Phase 2.5 silently skips, no `house-style.*` files written, default theme applied.
2. **Single-frontend repo:** run inside a Next.js + Tailwind + shadcn repo → confirm `house-style.json` populated with reasonable tokens, `house-style.css` linked in generated wireframes, visual delta vs default theme is visible.
3. **Multi-frontend repo:** confirm `AskUserQuestion` lists candidates and only the chosen one is read.
4. **Screenshot input via flag:** `--screenshots ./mocks/` with 3 PNGs → confirm `source-screens.md` written, anchoring prompt fires for matching journey steps, generated wireframes for anchored steps preserve IA.
5. **Screenshot + no host frontend:** confirm token-from-screenshot fallback runs and writes `house-style.json` with `"source": "screenshots"`.
6. **Discard path:** at the confirmation prompt, choose "Discard" → confirm `house-style.css` is removed/not linked and wireframes use default theme.

## Risks

- **Token extraction is fuzzy.** Mitigation: always show the extracted summary and let the user discard.
- **Subagent context bloat.** Each generator already gets pattern files + req excerpts; adding `house-style.json` is small (~1KB), but anchored screenshot descriptions can be ~500 tokens each. Mitigation: only pass the screenshot description for the *anchored* component, not all screenshots.
- **`AskUserQuestion` 4-option cap.** If >4 candidate frontends, batch with sequential calls. Rare in practice.
