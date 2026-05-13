"""numeric.py — numeric / open-numeric helpers.

Dependencies: stdlib only.

Returns n, mean, median, SD, min, max, percentiles, a binned histogram,
and 1.5xIQR outliers (indices into the row list). Median leads — many
real-world numeric distributions (income, counts, durations) are skewed.

CLI: python3 -m helpers.numeric --selftest
"""
from __future__ import annotations
import sys
import math
import statistics


def _percentile(sorted_vals: list[float], p: float) -> float:
    """Linear-interpolation percentile (NIST / Excel-compatible)."""
    if not sorted_vals:
        return 0.0
    if len(sorted_vals) == 1:
        return float(sorted_vals[0])
    k = (len(sorted_vals) - 1) * (p / 100)
    f = math.floor(k)
    c = math.ceil(k)
    if f == c:
        return float(sorted_vals[int(k)])
    return sorted_vals[f] * (c - k) + sorted_vals[c] * (k - f)


def numeric_stats(rows, col) -> dict:
    vals_indexed = []
    for i, r in enumerate(rows):
        v = r.get(col)
        if v in (None, "", "NA"):
            continue
        try:
            fv = float(v)
        except (ValueError, TypeError):
            continue
        if math.isnan(fv) or math.isinf(fv):
            continue
        vals_indexed.append((i, fv))
    if not vals_indexed:
        return {"n": 0}
    vals = [v for _, v in vals_indexed]
    sv = sorted(vals)
    n = len(vals)
    mean = round(sum(vals) / n, 4)
    median = _percentile(sv, 50)
    sd = round(statistics.pstdev(vals), 4) if n > 1 else 0.0
    p25 = _percentile(sv, 25)
    p75 = _percentile(sv, 75)
    iqr = p75 - p25
    lo = p25 - 1.5 * iqr
    hi = p75 + 1.5 * iqr
    outliers = [i for (i, v) in vals_indexed if v < lo or v > hi]
    # Histogram: 10 equal-width bins.
    lo_v, hi_v = sv[0], sv[-1]
    if hi_v > lo_v:
        bins = 10
        step = (hi_v - lo_v) / bins
        edges = [lo_v + i * step for i in range(bins + 1)]
        hist = [0] * bins
        for v in vals:
            idx = min(int((v - lo_v) / step), bins - 1)
            hist[idx] += 1
        histogram = [{"bin": f"{edges[i]:.2f}–{edges[i+1]:.2f}", "count": hist[i]}
                     for i in range(bins)]
    else:
        histogram = [{"bin": f"{lo_v}", "count": n}]
    return {
        "n": n, "mean": mean, "median": round(median, 4), "sd": sd,
        "min": sv[0], "max": sv[-1],
        "p25": round(p25, 4), "p50": round(median, 4), "p75": round(p75, 4),
        "outliers_iqr": outliers, "histogram": histogram,
    }


def _selftest() -> int:
    rows = [{"x": v} for v in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 100]]
    out = numeric_stats(rows, "x")
    assert out["n"] == 11, out
    assert out["median"] == 6, out
    assert 100 in [rows[i]["x"] for i in out["outliers_iqr"]], out
    # Empty case
    assert numeric_stats([], "x") == {"n": 0}
    print("numeric.numeric_stats: OK")
    return 0


if __name__ == "__main__":
    if "--selftest" in sys.argv:
        sys.exit(_selftest())
    print("usage: python3 -m helpers.numeric --selftest")
    sys.exit(64)
