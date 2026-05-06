"""check_caption_colors_in_diagram() tests."""
import pathlib
import sys

HERE = pathlib.Path(__file__).parent
sys.path.insert(0, str(HERE))
import run  # noqa: E402


def test_caption_color_not_in_diagram_flagged():
    composite = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1280 1600">
      <g id="zone-diagram"><rect x="0" y="0" width="100" height="100" fill="#1E3A8A"/></g>
      <g id="zone-legend"></g>
      <g id="zone-captions">
        <line class="caption-rule" x1="64" y1="100" x2="64" y2="200" stroke="#1E3A8A"/>
        <line class="caption-rule" x1="200" y1="100" x2="200" y2="200" stroke="#FF00FF"/>
      </g>
      <g id="zone-footer"></g>
    </svg>"""
    ok, reason = run.check_caption_colors_in_diagram(composite)
    assert ok is False
    assert "#FF00FF" in reason or "caption-color-not-in-diagram" in reason


def test_caption_colors_all_present_passes():
    composite = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1280 1600">
      <g id="zone-diagram">
        <rect x="0" y="0" width="100" height="100" fill="#1E3A8A"/>
        <rect x="100" y="0" width="100" height="100" fill="#B8351A"/>
      </g>
      <g id="zone-legend"></g>
      <g id="zone-captions">
        <line class="caption-rule" x1="64" y1="100" x2="64" y2="200" stroke="#1E3A8A"/>
        <line class="caption-rule" x1="200" y1="100" x2="200" y2="200" stroke="#B8351A"/>
      </g>
      <g id="zone-footer"></g>
    </svg>"""
    ok, _ = run.check_caption_colors_in_diagram(composite)
    assert ok is True


def test_ink_muted_caption_rule_excluded():
    """Ordinal mode uses ink-muted as caption-rule color even when absent from diagram."""
    composite = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1280 1600">
      <g id="zone-diagram"><rect fill="#1E3A8A" width="100" height="100"/></g>
      <g id="zone-legend"></g>
      <g id="zone-captions">
        <line class="caption-rule" stroke="#475569" x1="0" y1="0" x2="0" y2="100"/>
      </g>
      <g id="zone-footer"></g>
    </svg>"""
    ok, _ = run.check_caption_colors_in_diagram(composite)
    assert ok is True


def test_no_captions_passes():
    composite = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
      <g id="zone-diagram"><rect fill="#1E3A8A" width="50" height="50"/></g>
    </svg>"""
    ok, _ = run.check_caption_colors_in_diagram(composite)
    assert ok is True
