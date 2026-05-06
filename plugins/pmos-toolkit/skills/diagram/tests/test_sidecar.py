"""Sidecar v2 read/write helpers."""
import json
import pathlib
import sys
import tempfile

import pytest

HERE = pathlib.Path(__file__).parent
sys.path.insert(0, str(HERE))
import run  # noqa: E402


def _v2_payload(**overrides):
    base = {
        "schemaVersion": 2,
        "concept": "test",
        "theme": "technical",
        "mode": "diagram",
        "approach": "left-right",
        "alternativesConsidered": [],
        "canvas": {"aspect": "16:10", "width": 1280, "height": 800},
        "entities": [],
        "relationships": [],
        "positions": {},
        "colorAssignments": {},
        "evalSummary": {},
        "createdAt": "2026-05-06T00:00:00Z",
        "createdBy": "pmos-toolkit:diagram@v2",
    }
    base.update(overrides)
    return base


def test_v2_sidecar_round_trips():
    with tempfile.TemporaryDirectory() as d:
        p = pathlib.Path(d) / "x.diagram.json"
        run.write_sidecar(p, _v2_payload())
        loaded = run.read_sidecar(p)
        assert loaded is not None
        assert loaded["schemaVersion"] == 2
        assert loaded["theme"] == "technical"
        assert loaded["mode"] == "diagram"


def test_v1_sidecar_treated_as_absent():
    with tempfile.TemporaryDirectory() as d:
        p = pathlib.Path(d) / "x.diagram.json"
        p.write_text(json.dumps({"schemaVersion": 1, "concept": "old"}))
        assert run.read_sidecar(p) is None


def test_missing_sidecar_returns_none():
    with tempfile.TemporaryDirectory() as d:
        p = pathlib.Path(d) / "missing.diagram.json"
        assert run.read_sidecar(p) is None


def test_newer_sidecar_raises():
    with tempfile.TemporaryDirectory() as d:
        p = pathlib.Path(d) / "x.diagram.json"
        p.write_text(json.dumps({"schemaVersion": 99, "concept": "future"}))
        with pytest.raises(ValueError):
            run.read_sidecar(p)


def test_write_sidecar_stamps_version_when_missing():
    with tempfile.TemporaryDirectory() as d:
        p = pathlib.Path(d) / "x.diagram.json"
        payload = _v2_payload()
        del payload["schemaVersion"]
        run.write_sidecar(p, payload)
        loaded = run.read_sidecar(p)
        assert loaded["schemaVersion"] == 2


def test_v2_sidecar_relationships_carry_role():
    """Phase 2 forward-compat: write_sidecar passes relationships[].role through."""
    with tempfile.TemporaryDirectory() as d:
        p = pathlib.Path(d) / "x.diagram.json"
        payload = _v2_payload(relationships=[
            {"from": "a", "to": "b", "kind": "directed", "role": "feedback"},
            {"from": "b", "to": "c", "kind": "directed"},
        ])
        run.write_sidecar(p, payload)
        loaded = run.read_sidecar(p)
        assert loaded["relationships"][0]["role"] == "feedback"
        assert loaded["relationships"][1].get("role") is None
