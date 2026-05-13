"""likert.py — Likert / rating-scale (ordinal) helpers.

Dependencies: stdlib only.

The returned dict carries the full distribution, median, mode, T2B%, B2B%,
net (T2B - B2B), and a `mean_with_ordinal_caveat` — surfaced as a convenience
summary, NOT as an interval-scale mean. The accompanying SKILL.md
Anti-Pattern #2 forbids reporting a Likert mean without also showing the
distribution and T2B.

CLI: python3 -m helpers.likert --selftest
"""
from __future__ import annotations
import sys


def likert_stats(rows, col, scale_size: int = 5, reverse_scored: bool = False) -> dict:
    vals = []
    for r in rows:
        v = r.get(col)
        if v in (None, "", "NA"):
            continue
        try:
            iv = int(v)
        except (ValueError, TypeError):
            continue
        if iv < 1 or iv > scale_size:
            continue
        if reverse_scored:
            iv = scale_size + 1 - iv
        vals.append(iv)
    n = len(vals)
    distribution = {i: 0 for i in range(1, scale_size + 1)}
    for v in vals:
        distribution[v] += 1
    distribution_pct = {i: round(100 * c / n, 1) if n else 0.0
                        for i, c in distribution.items()}
    if not n:
        return {
            "n": 0, "distribution": distribution, "distribution_pct": distribution_pct,
            "median": None, "mode": None, "t2b_percent": 0.0, "b2b_percent": 0.0,
            "net_score": 0.0, "mean_with_ordinal_caveat": None,
        }
    sorted_vals = sorted(vals)
    mid = n // 2
    median = sorted_vals[mid] if n % 2 == 1 else (sorted_vals[mid - 1] + sorted_vals[mid]) / 2
    mode = max(distribution.items(), key=lambda kv: kv[1])[0]
    t2b = sum(distribution[i] for i in (scale_size, scale_size - 1))
    b2b = sum(distribution[i] for i in (1, 2))
    t2b_pct = round(100 * t2b / n, 1)
    b2b_pct = round(100 * b2b / n, 1)
    mean = round(sum(vals) / n, 2)
    return {
        "n": n,
        "distribution": distribution,
        "distribution_pct": distribution_pct,
        "median": median,
        "mode": mode,
        "t2b_percent": t2b_pct,
        "b2b_percent": b2b_pct,
        "net_score": round(t2b_pct - b2b_pct, 1),
        "mean_with_ordinal_caveat": mean,
    }


def _selftest() -> int:
    # Known-answer fixture: 5-pt Likert with handcrafted distribution.
    rows = (
        [{"q": 1}] * 12 + [{"q": 2}] * 28 + [{"q": 3}] * 84
        + [{"q": 4}] * 198 + [{"q": 5}] * 167
    )
    out = likert_stats(rows, "q", scale_size=5)
    assert out["n"] == 489, out
    assert out["distribution"][4] == 198, out
    assert out["median"] == 4, out
    assert out["mode"] == 4, out
    assert out["t2b_percent"] == 74.6 or out["t2b_percent"] == 74.7, out
    assert out["b2b_percent"] == 8.2, out
    assert 66.4 <= out["net_score"] <= 66.5, out
    assert 3.97 <= out["mean_with_ordinal_caveat"] <= 3.99, out
    # Reverse-scored
    rev = likert_stats([{"q": 5}, {"q": 1}], "q", scale_size=5, reverse_scored=True)
    assert rev["distribution"][1] == 1 and rev["distribution"][5] == 1, rev
    print("likert.likert_stats: OK")
    return 0


if __name__ == "__main__":
    if "--selftest" in sys.argv:
        sys.exit(_selftest())
    print("usage: python3 -m helpers.likert --selftest")
    sys.exit(64)
