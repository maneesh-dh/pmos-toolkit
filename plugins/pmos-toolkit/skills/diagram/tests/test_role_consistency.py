"""role-style-consistency check — uses sidecar role tags + SVG element ids."""
import json
import pathlib
import sys
import tempfile

HERE = pathlib.Path(__file__).parent
sys.path.insert(0, str(HERE))
import run  # noqa: E402


SVG_CONSISTENT = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 100">
  <line id="e1" x1="0" y1="0" x2="100" y2="0" stroke="#1E3A8A" stroke-dasharray="4 4"/>
  <line id="e2" x1="0" y1="20" x2="100" y2="20" stroke="#1E3A8A" stroke-dasharray="4 4"/>
</svg>"""

SVG_MIXED = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 100">
  <line id="e1" x1="0" y1="0" x2="100" y2="0" stroke="#1E3A8A" stroke-dasharray="4 4"/>
  <line id="e2" x1="0" y1="20" x2="100" y2="20" stroke="#1E3A8A"/>
</svg>"""

SIDECAR_BOTH_FEEDBACK = {
    "schemaVersion": 2,
    "relationships": [
        {"from": "a", "to": "b", "kind": "directed", "role": "feedback", "_svgId": "e1"},
        {"from": "c", "to": "d", "kind": "directed", "role": "feedback", "_svgId": "e2"},
    ],
}


def _setup(svg_text, sidecar_obj):
    d = tempfile.mkdtemp()
    svg = pathlib.Path(d) / "x.svg"
    sidecar = pathlib.Path(d) / "x.diagram.json"
    svg.write_text(svg_text)
    sidecar.write_text(json.dumps(sidecar_obj))
    return svg, sidecar


def test_role_consistency_passes_when_same_role_same_style():
    svg, sidecar = _setup(SVG_CONSISTENT, SIDECAR_BOTH_FEEDBACK)
    ok, reason = run.check_role_style_consistency(svg, sidecar)
    assert ok, reason


def test_role_consistency_fails_when_same_role_different_style():
    svg, sidecar = _setup(SVG_MIXED, SIDECAR_BOTH_FEEDBACK)
    ok, reason = run.check_role_style_consistency(svg, sidecar)
    assert not ok
    assert "role-style-consistency" in reason
    assert "feedback" in reason


def test_role_consistency_passes_when_no_role_tagged():
    svg, sidecar = _setup(SVG_CONSISTENT, {"schemaVersion": 2, "relationships": []})
    ok, _ = run.check_role_style_consistency(svg, sidecar)
    assert ok


def test_role_consistency_passes_when_sidecar_missing():
    d = tempfile.mkdtemp()
    svg = pathlib.Path(d) / "x.svg"
    svg.write_text(SVG_CONSISTENT)
    ok, _ = run.check_role_style_consistency(svg, pathlib.Path(d) / "missing.json")
    assert ok


def test_role_consistency_fails_when_svgid_missing():
    svg, sidecar = _setup(
        SVG_CONSISTENT,
        {
            "schemaVersion": 2,
            "relationships": [
                {"from": "a", "to": "b", "kind": "directed", "role": "feedback", "_svgId": "e1"},
                {"from": "c", "to": "d", "kind": "directed", "role": "feedback", "_svgId": "missing"},
            ],
        },
    )
    ok, reason = run.check_role_style_consistency(svg, sidecar)
    assert not ok
    assert "missing" in reason
