"""Caption-to-diagram anchor mode + ordinal-marker assignment.

When the diagram interior uses ≥ 3 distinct accent colors (excluding ink-muted
and surface tokens), captions can pair to elements visually via colored left
rules — `mode = "color"`. When the diagram is monochromatic or near-mono, that
visual cue collapses; we fall back to geometric markers — `mode = "ordinal"`.
"""
from __future__ import annotations

from .caption_grid import GLYPHS_FOR_ORDINAL


# Tokens that DO NOT count as a "distinct accent" for anchor-mode purposes.
# Surface tokens (cream, white, off-white) and ink-muted are structural, not
# semantic, so we exclude them when counting accents.
_NON_ACCENT_HEXES: set[str] = {
    "#475569",  # ink-muted (technical + editorial)
    "#FFFFFF",  # technical surface
    "#F4F5F7",  # technical surface-muted
    "#F4EFE6",  # editorial cream surface
    "#9CA3AF",  # editorial dashed-container chrome (gray)
}


def decide_anchor_mode(diagram_colors: set[str]) -> str:
    """Return "color" if ≥ 3 distinct semantic accents are present, else "ordinal".

    `diagram_colors` is a set of upper-cased hex strings (e.g. {"#1E3A8A", "#0F172A"}).
    """
    distinct = {c.upper() for c in diagram_colors} - {h.upper() for h in _NON_ACCENT_HEXES}
    return "color" if len(distinct) >= 3 else "ordinal"


def assign_markers(
    captions: list[dict],
    diagram_elements: list[dict],
) -> list[tuple[int, str, str | None]]:
    """Pair captions with ordinal markers (●▲■◆★) and the corresponding diagram element id.

    `diagram_elements` is provided in caption order — the caller is responsible for
    sorting/picking the elements. Returns a list of (caption_index, glyph, element_id).
    """
    out: list[tuple[int, str, str | None]] = []
    for i, caption in enumerate(captions):
        glyph = GLYPHS_FOR_ORDINAL[i] if i < len(GLYPHS_FOR_ORDINAL) else "•"
        if i < len(diagram_elements):
            eid = diagram_elements[i].get("id")
        else:
            eid = caption.get("anchorElementId")
        out.append((i, glyph, eid))
    return out
