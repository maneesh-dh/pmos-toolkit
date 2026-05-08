---
task_number: 10
task_name: "Editorial theme.yaml + style.md + 5 atoms"
status: done
started_at: 2026-05-06T13:36:30Z
completed_at: 2026-05-06T13:46:00Z
files_touched:
  - plugins/pmos-toolkit/skills/diagram/themes/_schema.json
  - plugins/pmos-toolkit/skills/diagram/themes/editorial/theme.yaml
  - plugins/pmos-toolkit/skills/diagram/themes/editorial/style.md
  - plugins/pmos-toolkit/skills/diagram/themes/editorial/atoms/eyebrow-mono.svg
  - plugins/pmos-toolkit/skills/diagram/themes/editorial/atoms/dashed-container.svg
  - plugins/pmos-toolkit/skills/diagram/themes/editorial/atoms/pastel-chip-stack.svg
  - plugins/pmos-toolkit/skills/diagram/themes/editorial/atoms/computation-block.svg
  - plugins/pmos-toolkit/skills/diagram/themes/editorial/atoms/return-loop-arrow.svg
  - plugins/pmos-toolkit/skills/diagram/tests/test_editorial_theme.py
---

## DEVIATIONS
**accent-emphasis: #D9421C → #B8351A.** The spec's red-orange (#D9421C) fails WCAG AA on cream (3.86:1, needs 4.5:1). Plan T10 step 5 explicitly required AA-clean before proceeding (D2 rationale: every editorial diagram is verified at runtime). Darkened to #B8351A (5.15:1, comfortable margin), preserving hue. Documented inline in theme.yaml and style.md. The risk row in the plan ("editorial palette pairs may flunk AA") predicted exactly this; mitigation row says "adjust hexes per AA before proceeding."

**Schema extensions.** The spec §5 editorial yaml uses keys not in T1's draft schema. Extended `themes/_schema.json` to accept: surface containerChrome/Color/Dasharray; accent[].token; categoryChip[].token + .textOn; typeBlock weight/size singular + transform enum; numeric letterSpacing; byRole shape="curved"; nodeChrome.computationBlock; chips enabled/cornerRadius/paddingX/paddingY. Top-level `additionalProperties: false` preserved (still rejects layout keys).

## Outcome
- 6 editorial tests pass: schema-validates, pinned-accents (with new hex), byRole-complete, AA-on-cream, atoms-exist, atoms-use-only-palette.
- 25/25 full suite; selftest green.
- 5 atom SVGs hand-authored; each parses + uses only editorial-palette colors.

## Notes
- All atom SVGs use Inter / ui-monospace stacks per theme.yaml. They render without external font dependency in any browser; rsvg / cairosvg fall back to system sans/mono.
- `letter-spacing="0.96"` in atoms = 12px × 0.08em per the eyebrow spec (CSS letter-spacing is absolute, not em).
