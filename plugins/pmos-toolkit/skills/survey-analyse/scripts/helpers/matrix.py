"""matrix.py — matrix / grid question helpers.

Dependencies: stdlib only.

Treats each matrix row as its own Likert question (delegates to likert.py)
and adds a per-respondent straightlining flag (zero variance across the
row columns for that respondent).

CLI: python3 -m helpers.matrix --selftest
"""
from __future__ import annotations
import sys
from . import likert


def matrix_stats(rows, row_cols: dict, scale_size: int = 5) -> dict:
    """`row_cols` maps row-label -> the column for that row.

    Returns per-row Likert stats + a list of respondent indices flagged as
    straightlining the whole matrix.
    """
    out_rows = {}
    for label, col in row_cols.items():
        out_rows[label] = likert.likert_stats(rows, col, scale_size=scale_size)
    straightliners = []
    for idx, r in enumerate(rows):
        vals = []
        for col in row_cols.values():
            v = r.get(col)
            if v in (None, "", "NA"):
                continue
            try:
                vals.append(int(v))
            except (ValueError, TypeError):
                continue
        if len(vals) >= max(3, len(row_cols) - 1) and len(set(vals)) == 1:
            straightliners.append(idx)
    return {"rows": out_rows, "straightliner_indices": straightliners,
            "straightliner_count": len(straightliners)}


def _selftest() -> int:
    rows = [
        {"a": 4, "b": 4, "c": 5, "d": 4},  # mixed
        {"a": 3, "b": 3, "c": 3, "d": 3},  # straightliner
        {"a": 5, "b": 1, "c": 3, "d": 4},  # mixed
        {"a": 2, "b": 2, "c": 2, "d": 2},  # straightliner
    ]
    out = matrix_stats(rows, {"Row A": "a", "Row B": "b", "Row C": "c", "Row D": "d"})
    assert "Row A" in out["rows"], out
    assert out["rows"]["Row A"]["n"] == 4, out["rows"]["Row A"]
    assert out["straightliner_count"] == 2, out
    assert 1 in out["straightliner_indices"] and 3 in out["straightliner_indices"], out
    print("matrix.matrix_stats: OK")
    return 0


if __name__ == "__main__":
    if "--selftest" in sys.argv:
        sys.exit(_selftest())
    print("usage: python3 -m helpers.matrix --selftest")
    sys.exit(64)
