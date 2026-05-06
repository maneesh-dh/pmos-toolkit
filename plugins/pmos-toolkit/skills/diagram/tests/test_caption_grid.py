"""Caption auto-fit grid + clamp tests."""
import pathlib
import sys

import pytest

HERE = pathlib.Path(__file__).parent
sys.path.insert(0, str(HERE.parent))
from wrapper.caption_grid import caption_layout, clamp_captions  # noqa: E402


def test_three_captions_use_4_cols_each():
    r = caption_layout(3, total_width=1280, margin=64)
    assert r["cols_per_caption"] == 4
    assert r["gutter"] == 24
    assert len(r["columns"]) == 3
    assert r["columns"][0]["x"] == 64
    assert r["columns"][1]["x"] > r["columns"][0]["x"] + r["columns"][0]["width"]


def test_four_captions_use_3_cols_each():
    r = caption_layout(4, total_width=1280, margin=64)
    assert r["cols_per_caption"] == 3
    assert r["gutter"] == 24
    assert len(r["columns"]) == 4


def test_five_captions_use_2_cols_with_one_span():
    r = caption_layout(5, total_width=1280, margin=64)
    assert r["cols_per_caption"] == 2
    assert r["gutter"] == 16
    assert len(r["columns"]) == 5
    widths = [c["width"] for c in r["columns"]]
    # The middle column is wide (≈ 2 * narrow); integer-division slack lands here so
    # the rightmost edge lines up with margin-R exactly (no 1-2px gap).
    assert 2 * widths[0] <= widths[2] <= 2 * widths[0] + r["gutter"]


def test_five_captions_consume_full_usable_width():
    """Regression: the rightmost column must end at canvas-width - margin (no slack)."""
    r = caption_layout(5, total_width=1280, margin=64)
    last = r["columns"][-1]
    right_edge = last["x"] + last["width"]
    assert right_edge == 1280 - 64


def test_caption_layout_rejects_out_of_range():
    with pytest.raises(ValueError):
        caption_layout(2)
    with pytest.raises(ValueError):
        caption_layout(6)


def test_clamp_too_many_drops_weakest_by_body_length():
    caps = [
        {"title": "a", "body": "x" * 10},   # weakest by body length
        {"title": "b", "body": "x" * 100},
        {"title": "c", "body": "x" * 80},
        {"title": "d", "body": "x" * 60},
        {"title": "e", "body": "x" * 40},
        {"title": "f", "body": "x" * 20},   # 2nd-weakest
        {"title": "g", "body": "x" * 30},
    ]
    kept, info = clamp_captions(caps)
    assert len(kept) == 5
    assert info["from"] == 7 and info["to"] == 5
    titles = [c["title"] for c in kept]
    # Weakest two ('a' length=10, 'f' length=20) dropped
    assert "a" not in titles
    assert "f" not in titles
    # Original order preserved among kept
    assert titles == ["b", "c", "d", "e", "g"]


def test_clamp_too_few_returns_empty_with_info():
    caps = [{"title": "a", "body": "x"}, {"title": "b", "body": "y"}]
    kept, info = clamp_captions(caps)
    assert kept == []
    assert info["from"] == 2 and info["to"] == 0


def test_clamp_in_range_passes_through_with_empty_info():
    caps = [{"title": "a", "body": "aa"}, {"title": "b", "body": "bb"}, {"title": "c", "body": "cc"}]
    kept, info = clamp_captions(caps)
    assert kept == caps
    assert info == {}
