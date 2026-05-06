"""Strict positive-list schema validation for theme.yaml files."""
import json
import pathlib
import pytest
from jsonschema import validate, ValidationError

SCHEMA_PATH = pathlib.Path(__file__).parents[1] / "themes" / "_schema.json"


def load_schema():
    return json.loads(SCHEMA_PATH.read_text())


MINIMAL = {
    "name": "x",
    "displayName": "X",
    "surface": {"background": "#FFFFFF"},
    "palette": {"ink": "#000000", "inkMuted": "#444444", "accents": []},
    "typography": {"body": {"stack": "sans-serif", "weights": [400], "sizes": [12]}},
    "connectors": {"mixingPermitted": False},
    "arrowheads": {"style": "filled-triangle", "sizes": {"default": "8x6"}},
    "rubricOverrides": {"waive": [], "add": []},
    "infographic": {"supported": False},
}


def test_minimal_theme_validates():
    validate(MINIMAL, load_schema())


def test_unknown_top_level_key_rejected():
    bad = {**MINIMAL, "direction": "top-down"}
    with pytest.raises(ValidationError):
        validate(bad, load_schema())


def test_layout_keys_explicitly_rejected():
    for key in ("direction", "canvas", "nodePositions", "readingOrder", "placement", "layout"):
        with pytest.raises(ValidationError):
            validate({**MINIMAL, key: "anything"}, load_schema())


def test_extends_rejected_in_v1():
    with pytest.raises(ValidationError):
        validate({**MINIMAL, "extends": "technical"}, load_schema())
