"""Anchor mode + ordinal marker assignment tests."""
import pathlib
import sys

HERE = pathlib.Path(__file__).parent
sys.path.insert(0, str(HERE.parent))
from wrapper.anchors import decide_anchor_mode, assign_markers  # noqa: E402


def test_color_mode_when_3_or_more_accents():
    assert decide_anchor_mode({"#1E3A8A", "#D9421C", "#0F172A"}) == "color"


def test_ordinal_mode_when_fewer():
    assert decide_anchor_mode({"#0F172A"}) == "ordinal"
    assert decide_anchor_mode({"#0F172A", "#2563EB"}) == "ordinal"


def test_ordinal_mode_excludes_ink_muted_and_surface():
    # Only ink (#0F172A) counts as an accent — others are surface/ink-muted.
    colors = {"#475569", "#FFFFFF", "#F4F5F7", "#F4EFE6", "#0F172A"}
    assert decide_anchor_mode(colors) == "ordinal"


def test_assign_markers_returns_5_glyphs():
    caps = [{"title": f"c{i}"} for i in range(5)]
    elements = [{"id": f"e{i}", "bbox": (0, i * 20, 100, 20)} for i in range(5)]
    out = assign_markers(caps, elements)
    glyphs = [m for _, m, _ in out]
    assert glyphs == ["●", "▲", "■", "◆", "★"]
    assert all(eid is not None for _, _, eid in out)


def test_assign_markers_falls_back_to_caption_anchorElementId():
    caps = [{"title": "x", "anchorElementId": "fallback-id"}]
    out = assign_markers(caps, [])
    assert out[0][2] == "fallback-id"
