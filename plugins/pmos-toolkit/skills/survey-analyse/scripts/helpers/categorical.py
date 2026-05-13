"""categorical.py — single-select / nominal helpers.

Dependencies: stdlib only.

Functions
---------
freq_table(rows, col) -> {n, responses, percent, mode}
    Percentages are on the respondent base (non-null responses for `col`).

CLI
---
    python3 -m helpers.categorical --selftest
"""
from __future__ import annotations
import sys
from collections import Counter


def freq_table(rows: list[dict], col: str) -> dict:
    """Frequency table for a single-select column.

    Percentages are computed on the respondent base (non-null values for `col`).
    Returns Counter / dict in insertion order (stdlib `dict` is ordered).
    """
    vals = [r[col] for r in rows if r.get(col) not in (None, "", "NA")]
    n = len(vals)
    counts = Counter(vals)
    # Sorted by frequency descending, then value ascending for determinism.
    ordered = sorted(counts.items(), key=lambda kv: (-kv[1], str(kv[0])))
    responses = {k: v for k, v in ordered}
    percent = {k: round(100 * v / n, 1) if n else 0.0 for k, v in ordered}
    mode = ordered[0][0] if ordered else None
    return {"n": n, "responses": responses, "percent": percent, "mode": mode}


def _selftest() -> int:
    rows = [
        {"plan": "Free"}, {"plan": "Pro"}, {"plan": "Free"},
        {"plan": "Free"}, {"plan": "Team"}, {"plan": ""},
        {"plan": "Pro"}, {"plan": None}, {"plan": "Free"},
    ]
    out = freq_table(rows, "plan")
    # 4 Free + 2 Pro + 1 Team = 7 non-null responses; "" and None excluded.
    assert out["n"] == 7, f"expected n=7, got {out['n']}"
    assert out["responses"] == {"Free": 4, "Pro": 2, "Team": 1}, out["responses"]
    assert out["percent"]["Free"] == 57.1, out["percent"]
    assert out["mode"] == "Free", out["mode"]
    # Empty case
    assert freq_table([], "plan")["n"] == 0
    print("categorical.freq_table: OK")
    return 0


if __name__ == "__main__":
    if "--selftest" in sys.argv:
        sys.exit(_selftest())
    print("usage: python3 -m helpers.categorical --selftest")
    sys.exit(64)
