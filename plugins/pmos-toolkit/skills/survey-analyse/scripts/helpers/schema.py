"""schema.py — heuristic question-type inference.

Dependencies: stdlib only.

Inference is **proposal only** — the parent skill (Phase 2) ALWAYS surfaces
the result for user confirmation. Confidence is a hint; the user owns the
final schema.

Type tags emitted: single_select, multi_select, likert, nps, ranking,
numeric, open_text, unknown.

Functions
---------
infer(rows, header_order) -> {columns: {<col>: {type, confidence, ...meta}}}

CLI: python3 -m helpers.schema --selftest
"""
from __future__ import annotations
import re
import sys
from collections import Counter

_RECOMMEND_HINT = re.compile(r"\brecommend\b|\bnps\b|\bpromot", re.I)
_RANK_HINT = re.compile(r"\brank\b|\bin order\b|\bpriority\b", re.I)


def _try_int(v):
    try:
        return int(str(v).strip())
    except (ValueError, TypeError):
        return None


def _try_float(v):
    try:
        return float(str(v).strip())
    except (ValueError, TypeError):
        return None


def _col_values(rows, col):
    out = []
    for r in rows:
        v = r.get(col)
        if v in (None, "", "NA"):
            continue
        out.append(v)
    return out


def infer_column(rows, col) -> dict:
    """Returns {type, confidence, meta...}. Confidence in 0..1."""
    vals = _col_values(rows, col)
    if not vals:
        return {"type": "unknown", "confidence": 0.0, "reason": "no values"}
    n = len(vals)
    # NPS: integer 0..10 + "recommend" / "nps" in column header.
    int_vals = [_try_int(v) for v in vals]
    int_ok = [iv for iv in int_vals if iv is not None]
    int_share = len(int_ok) / n
    if int_share > 0.95 and all(0 <= iv <= 10 for iv in int_ok) and _RECOMMEND_HINT.search(col):
        return {"type": "nps", "confidence": 0.95, "reason": "0-10 + recommend-hint"}
    # Likert: integer 1..5 or 1..7 with low cardinality.
    if int_share > 0.95 and int_ok and max(int_ok) <= 7 and min(int_ok) >= 1:
        scale = max(int_ok)
        return {"type": "likert", "confidence": 0.80,
                "scale_size": scale if scale in (5, 7) else (5 if scale <= 5 else 7),
                "reason": f"integer 1..{scale}"}
    # Multi-select: presence of a delimiter in many cells.
    delim_count = sum(1 for v in vals if isinstance(v, str)
                      and any(d in v for d in ("|", ";")))
    if delim_count / n > 0.30:
        delim = "|" if sum(1 for v in vals if "|" in str(v)) >= sum(1 for v in vals if ";" in str(v)) else ";"
        return {"type": "multi_select", "confidence": 0.75,
                "delimiter": delim, "reason": "delimiter present in ≥30% of cells"}
    # Numeric: high float-parse share, not Likert-shaped.
    float_vals = [_try_float(v) for v in vals]
    float_ok = [fv for fv in float_vals if fv is not None]
    if len(float_ok) / n > 0.90:
        unique_count = len(set(float_ok))
        if unique_count > 10:
            return {"type": "numeric", "confidence": 0.85,
                    "reason": f">90% numeric, {unique_count} unique values"}
    # Categorical: low cardinality.
    counts = Counter(vals)
    if len(counts) <= max(8, n // 10):
        return {"type": "single_select", "confidence": 0.70,
                "reason": f"low cardinality ({len(counts)} unique)"}
    # Ranking: rank-hint in header + integer values.
    if _RANK_HINT.search(col) and int_share > 0.80:
        return {"type": "ranking", "confidence": 0.50,
                "reason": "rank-hint header + integer values (manual confirm)"}
    # Open text: long average length, high cardinality.
    if isinstance(vals[0], str):
        avg_len = sum(len(str(v)) for v in vals) / n
        if avg_len > 20 and len(counts) > n * 0.7:
            return {"type": "open_text", "confidence": 0.80,
                    "reason": f"avg cell length {avg_len:.0f}, high cardinality"}
    return {"type": "unknown", "confidence": 0.20,
            "reason": "no rule matched (manual classification needed)"}


def infer(rows, header_order) -> dict:
    return {"columns": {col: infer_column(rows, col) for col in header_order}}


def _selftest() -> int:
    # NPS
    rows = [{"How likely to recommend us?": str(i % 11)} for i in range(50)]
    out = infer(rows, ["How likely to recommend us?"])
    assert out["columns"]["How likely to recommend us?"]["type"] == "nps", out
    # Likert 1-5
    rows = [{"Satisfaction": str((i % 5) + 1)} for i in range(50)]
    out = infer(rows, ["Satisfaction"])
    assert out["columns"]["Satisfaction"]["type"] == "likert", out
    assert out["columns"]["Satisfaction"]["scale_size"] == 5, out
    # Multi-select
    rows = [{"Features": "Reports|Mobile"}, {"Features": "API"}, {"Features": "Reports"}] * 10
    out = infer(rows, ["Features"])
    assert out["columns"]["Features"]["type"] == "multi_select", out
    # Numeric
    rows = [{"Age": str(20 + i)} for i in range(50)]
    out = infer(rows, ["Age"])
    assert out["columns"]["Age"]["type"] == "numeric", out
    # Categorical
    rows = [{"Plan": "Free"}] * 20 + [{"Plan": "Pro"}] * 15 + [{"Plan": "Team"}] * 5
    out = infer(rows, ["Plan"])
    assert out["columns"]["Plan"]["type"] == "single_select", out
    # Open text
    rows = [{"Why?": f"This is a long open response number {i} explaining something detailed"}
            for i in range(20)]
    out = infer(rows, ["Why?"])
    assert out["columns"]["Why?"]["type"] == "open_text", out
    print("schema.infer: OK")
    return 0


if __name__ == "__main__":
    if "--selftest" in sys.argv:
        sys.exit(_selftest())
    print("usage: python3 -m helpers.schema --selftest")
    sys.exit(64)
