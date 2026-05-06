"""Tests for the editorial-v1 wrapper composition."""
import pathlib
import sys
import xml.etree.ElementTree as ET

HERE = pathlib.Path(__file__).parent
sys.path.insert(0, str(HERE.parent))
from wrapper.compose import compose_wrapper  # noqa: E402


STUB_SVG = (
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 400" '
    'width="800" height="400">'
    '<rect x="0" y="0" width="800" height="400" fill="#FFFFFF"/></svg>'
)
SAMPLE_TEXT = {
    "eyebrow": "EYEBROW",
    "headline": "Hi",
    "lede": "Short lede.",
    "figLabel": "FIG. 1 — STUB",
    "captions": [],
    "footer": "FOOT",
}


# ---------- T19a: skeleton ----------
def test_compose_returns_parseable_svg(theme_editorial):
    out = compose_wrapper(STUB_SVG, SAMPLE_TEXT, theme_editorial, "color", "playwright")
    ET.fromstring(out)  # raises if invalid


def test_compose_contains_all_zone_ids(theme_editorial):
    out = compose_wrapper(STUB_SVG, SAMPLE_TEXT, theme_editorial, "color", "playwright")
    for z in ("zone-eyebrow", "zone-headline", "zone-lede", "zone-fig-label",
              "zone-diagram", "zone-legend", "zone-footer"):
        assert f'id="{z}"' in out, f"missing {z}"


def test_diagram_embedded_with_translation(theme_editorial):
    out = compose_wrapper(STUB_SVG, SAMPLE_TEXT, theme_editorial, "color", "playwright")
    assert 'id="zone-diagram"' in out
    assert 'translate(' in out


def test_diagram_element_ids_preserved_in_zone_diagram(theme_editorial):
    diagram_with_id = (
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'
        '<rect id="my-node" x="0" y="0" width="40" height="40" fill="#FFFFFF"/></svg>'
    )
    out = compose_wrapper(diagram_with_id, SAMPLE_TEXT, theme_editorial, "color", "playwright")
    assert 'id="my-node"' in out
    pos_zone = out.index('id="zone-diagram"')
    pos_node = out.index('id="my-node"')
    assert pos_node > pos_zone


# ---------- T19b: text wrap ----------
def test_lede_wraps_via_heuristic_for_rsvg(theme_editorial):
    long_lede = " ".join(["word"] * 60)
    txt = {**SAMPLE_TEXT, "lede": long_lede}
    out = compose_wrapper(STUB_SVG, txt, theme_editorial, "color", "rsvg-convert")
    assert "<foreignObject" not in out
    assert out.count("<tspan") >= 3


def test_lede_uses_foreignobject_for_playwright_no_metrics(theme_editorial):
    long_lede = " ".join(["word"] * 60)
    txt = {**SAMPLE_TEXT, "lede": long_lede}
    out = compose_wrapper(STUB_SVG, txt, theme_editorial, "color", "playwright",
                          font_metrics_available=False)
    assert "<foreignObject" in out


def test_lede_uses_text_with_metrics_for_playwright(theme_editorial):
    long_lede = " ".join(["word"] * 60)
    txt = {**SAMPLE_TEXT, "lede": long_lede}
    out = compose_wrapper(STUB_SVG, txt, theme_editorial, "color", "playwright",
                          font_metrics_available=True)
    assert "<foreignObject" not in out
    assert out.count("<tspan") >= 3


def test_lede_bold_phrases_become_bold_tspans(theme_editorial):
    txt = {**SAMPLE_TEXT, "lede": "The **box** we compute on."}
    out = compose_wrapper(STUB_SVG, txt, theme_editorial, "color", "rsvg-convert")
    assert 'font-weight="600"' in out


def test_headline_wraps_to_max_two_lines(theme_editorial):
    txt = {**SAMPLE_TEXT, "headline": "A very long headline " * 8}
    out = compose_wrapper(STUB_SVG, txt, theme_editorial, "color", "rsvg-convert")
    head_start = out.index('id="zone-headline"')
    head_end = out.index("</g>", head_start)
    headline_block = out[head_start:head_end]
    # Each line emits a tspan with `dy=` — count line markers, not nested run tspans.
    line_markers = headline_block.count('dy=')
    assert line_markers <= 2
    # Ellipsis appears when truncation kicks in
    assert "…" in headline_block


# ---------- T19c: captions ----------
CAPS_3_COLOR = [
    {"title": "A", "body": "aa", "anchorColor": "#1E3A8A"},
    {"title": "B", "body": "bb", "anchorColor": "#B8351A"},
    {"title": "C", "body": "cc", "anchorColor": "#0F172A"},
]
CAPS_3_ORDINAL = [
    {"title": "A", "body": "aa", "anchorElementId": "e1"},
    {"title": "B", "body": "bb", "anchorElementId": "e2"},
    {"title": "C", "body": "cc", "anchorElementId": "e3"},
]


def test_color_mode_emits_left_rules_in_anchor_color(theme_editorial):
    # Diagram needs to actually contain the anchor colors so they're not remapped
    diagram = (
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 400" width="800" height="400">'
        '<rect x="0" y="0" width="100" height="100" fill="#1E3A8A"/>'
        '<rect x="100" y="0" width="100" height="100" fill="#B8351A"/>'
        '<rect x="200" y="0" width="100" height="100" fill="#0F172A"/></svg>'
    )
    txt = {**SAMPLE_TEXT, "captions": CAPS_3_COLOR}
    out = compose_wrapper(diagram, txt, theme_editorial, "color", "playwright")
    assert out.count('class="caption-rule"') == 3
    # All three anchor hexes appear in the captions section
    caps_start = out.index('id="zone-captions"')
    caps_block = out[caps_start:]
    for hx in ("#1E3A8A", "#B8351A", "#0F172A"):
        assert hx in caps_block


def test_ordinal_mode_emits_markers_in_both_zones(theme_editorial):
    diagram = (
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 400" width="800" height="400">'
        '<rect id="e1" x="10" y="10" width="40" height="20" fill="#FFFFFF"/>'
        '<rect id="e2" x="60" y="10" width="40" height="20" fill="#FFFFFF"/>'
        '<rect id="e3" x="110" y="10" width="40" height="20" fill="#FFFFFF"/></svg>'
    )
    txt = {**SAMPLE_TEXT, "captions": CAPS_3_ORDINAL}
    out = compose_wrapper(diagram, txt, theme_editorial, "ordinal", "playwright")
    # Each glyph appears at least twice (once in captions, once mirrored in zone-diagram)
    for glyph in ("●", "▲", "■"):
        assert out.count(glyph) >= 2, f"glyph {glyph} appeared {out.count(glyph)} times"


def test_caption_count_clamp_logged(theme_editorial):
    caps_too_many = [{"title": f"c{i}", "body": "x" * (10 + i)} for i in range(7)]
    txt = {**SAMPLE_TEXT, "captions": caps_too_many}
    out, info = compose_wrapper(STUB_SVG, txt, theme_editorial, "color", "playwright",
                                 return_info=True)
    assert info["captionCountClamp"]["from"] == 7
    assert info["captionCountClamp"]["to"] == 5


def test_caption_color_remap_when_color_absent_from_diagram(theme_editorial):
    # Diagram only has ink. Color anchor #FF00FF (magenta) → remap to ink.
    diagram = (
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 400" width="800" height="400">'
        '<rect x="0" y="0" width="100" height="100" fill="#0F172A"/>'
        '<rect x="100" y="0" width="100" height="100" fill="#0F172A"/>'
        '<rect x="200" y="0" width="100" height="100" fill="#0F172A"/></svg>'
    )
    bad_caps = [
        {"title": "A", "body": "aa", "anchorColor": "#FF00FF"},
        {"title": "B", "body": "bb", "anchorColor": "#0F172A"},
        {"title": "C", "body": "cc", "anchorColor": "#0F172A"},
    ]
    txt = {**SAMPLE_TEXT, "captions": bad_caps}
    out, info = compose_wrapper(diagram, txt, theme_editorial, "color", "playwright",
                                 return_info=True)
    assert any(r["from"] == "#FF00FF" for r in info["captionAnchorRemaps"])
