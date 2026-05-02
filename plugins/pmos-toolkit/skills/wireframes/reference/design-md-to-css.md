# DESIGN.md → `design-overlay.css`

Converts a merged DESIGN.md (after `x-extends` cascade) into a CSS variable overlay that re-skins the wireframe vocabulary defined in `assets/wireframe.css`.

This is the bridge between the spec file (portable, tool-agnostic) and the wireframe rendering layer.

---

## Inputs

- The merged DESIGN.md object from `design-md-resolver.md`.
- Output path: `{feature_folder}/wireframes/assets/design-overlay.css`.

## Output

A single CSS file that overrides `wireframe.css`'s `:root` variables with values derived from DESIGN.md. Linked **immediately after** `wireframe.css` in every wireframe HTML file.

---

## Variable mapping

`wireframe.css` declares the variable namespace (the `--wf-*` family). DESIGN.md provides values. Mapping:

| DESIGN.md path | `--wf-*` variable | Notes |
|---|---|---|
| `colors.background` | `--wf-bg` | Primary canvas. |
| `colors.surface` | `--wf-surface` | Card / surface layer. Falls back to `colors.background` if missing. |
| `colors.surface2` or `colors.muted` | `--wf-surface-2` | Secondary surface (sidebars, alt rows). Falls back to a -3% lightness of `--wf-surface`. |
| `colors.border` | `--wf-border` | Default border. |
| `colors.borderMuted` or `colors.border` | `--wf-border-2` | Secondary border. Falls back to `colors.border` at 50% opacity. |
| `colors.text` | `--wf-text` | Body text. |
| `colors.textMuted` | `--wf-muted` | Secondary text. |
| `colors.textFaint` or `colors.textMuted` | `--wf-faint` | Tertiary text (timestamps, helper). Falls back to a lightened `--wf-muted`. |
| `colors.primary` | `--wf-accent` | Brand action color. |
| `colors.primaryHover` | `--wf-accent-2` | Hover/pressed state. |
| `colors.success` | `--wf-success` | Status color (only emit if defined). |
| `colors.warning` | `--wf-warning` | Status color. |
| `colors.destructive` | `--wf-error` | Status color. |
| `rounded.md` | `--wf-radius` | Default radius. |
| `rounded.lg` | `--wf-radius-lg` | Larger radius (cards, modals). |
| `typography.body.fontFamily` | `--wf-font-sans` | Body type stack. |
| `typography.mono.fontFamily` or detected mono | `--wf-font-mono` | Mono stack (only emit if defined). |

Shadows are not derived from DESIGN.md (the spec doesn't carry them in a portable form). Leave `--wf-shadow` to its `wireframe.css` default.

---

## Reference resolution

DESIGN.md tokens may use `{path.to.token}` references. Resolve them before emitting CSS:

1. Walk the merged YAML object to build a flat lookup table (`colors.primary` → `"#2563EB"`, etc.).
2. For each token value, recursively expand `{…}` references against the table.
3. Cycles → emit warning, leave the variable unset (falls back to `wireframe.css` default).
4. Missing references → same; warn.

---

## Generation procedure

1. Build the flat lookup table.
2. For each `--wf-*` variable in the mapping table:
   - Look up the source path (or fallback chain).
   - If found and resolvable, emit `--wf-X: <hex>;`.
   - If not found, **omit the line** entirely (don't emit `unset` or empty values — the `wireframe.css` default takes over).
3. Wrap all variables in a single `:root { … }` block.
4. Add a one-line provenance comment at the top.

---

## Output format

```css
/* Generated from DESIGN.md (apps/web/DESIGN.md @ 4af3e83). Do not edit by hand. */
:root {
  --wf-bg:        #ffffff;
  --wf-surface:   #f8fafc;
  --wf-border:    #e2e8f0;
  --wf-text:      #0f172a;
  --wf-muted:     #64748b;
  --wf-accent:    #2563eb;
  --wf-accent-2:  #1d4ed8;
  --wf-error:     #dc2626;
  --wf-radius:    8px;
  --wf-font-sans: Inter, ui-sans-serif, system-ui, sans-serif;
}
```

---

## Dark mode

If DESIGN.md declares both light and dark color sets (e.g. via a non-standard `colors.dark.*` extension), v1 emits **light only** and notes the omission in a CSS comment. Dark-mode wireframes are out of scope for this generator until DESIGN.md upstream defines a portable color-mode story.

---

## Idempotency

The overlay is fully derived from DESIGN.md — same input, same output. Always overwrite the file; never patch. Each `/wireframes` run regenerates it.

---

## Failure modes

| Failure | Behavior |
|---|---|
| `colors` block missing or empty | Emit a header-only file with a warning comment. Wireframe defaults stand. |
| All references unresolvable | Same as above. |
| Output path unwritable | Hard error — tell user, abort phase. |
| Contrast warning (text-on-surface < 4.5:1) | Emit the value but add a `/* WCAG AA contrast warning */` comment beside it. |

---

## See also

- `assets/wireframe.css` — the variable namespace this overlay overrides.
- `design-md-spec.md` — token paths referenced above.
- `design-md-resolver.md` — produces the merged DESIGN.md object that's input here.
