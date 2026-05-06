"""Theme loader / palette-set / evaluate(theme=) contracts."""
import json
import pathlib
import sys

import pytest
import yaml
from jsonschema import ValidationError

HERE = pathlib.Path(__file__).parent
sys.path.insert(0, str(HERE))
import run  # noqa: E402


def test_load_theme_returns_palette_dict():
    theme = run.load_theme("technical")
    assert "#2563EB" in {a["hex"].upper() for a in theme["palette"]["accents"]}
    assert theme["palette"]["ink"].upper() == "#0F172A"


def test_load_unknown_theme_raises():
    with pytest.raises(FileNotFoundError):
        run.load_theme("nonexistent")


def test_load_theme_validates_against_schema(tmp_path, monkeypatch):
    """Inject a malformed theme into a tmp themes dir and assert validation raises."""
    bad_themes = tmp_path / "themes"
    (bad_themes / "broken").mkdir(parents=True)
    (bad_themes / "broken" / "theme.yaml").write_text(
        yaml.safe_dump({"name": "broken", "direction": "top-down"})
    )
    # Copy schema in so the loader finds it
    src_schema = pathlib.Path(run.SCHEMA_PATH).read_text()
    (bad_themes / "_schema.json").write_text(src_schema)

    monkeypatch.setattr(run, "THEMES_DIR", bad_themes)
    monkeypatch.setattr(run, "SCHEMA_PATH", bad_themes / "_schema.json")
    monkeypatch.setattr(run, "_THEME_CACHE", {})

    with pytest.raises(ValidationError):
        run.load_theme("broken")


def test_evaluate_with_explicit_theme_matches_default():
    svg = HERE / "golden" / "01-three-step-flow.svg"
    a = run.evaluate(svg)
    b = run.evaluate(svg, theme="technical")
    assert a["code_score"] == b["code_score"]
    assert a["hard_fails"] == b["hard_fails"]
    assert a["soft_metrics"] == b["soft_metrics"]


def test_build_palette_set_includes_all_token_layers():
    theme = run.load_theme("technical")
    pset = run.build_palette_set(theme)
    assert "#FFFFFF" in pset  # surface
    assert "#F4F5F7" in pset  # surfaceMuted (palette block)
    assert "#0F172A" in pset  # ink
    assert "#475569" in pset  # inkMuted
    assert "#2563EB" in pset  # accent
    assert "#B91C1C" in pset  # warn
