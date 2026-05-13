"""stats.py — chi-square, two-proportion z-test, Holm-Bonferroni correction.

Dependencies: stdlib only.

Hand-rolled implementations of:
- `chi_square(observed)` — Pearson chi-square test of independence on a
  2-D contingency table. Returns chi2 statistic, df, and p-value (uses
  the regularized lower incomplete gamma via `math.lgamma` and a stable
  series expansion).
- `column_z_test(p1, n1, p2, n2)` — two-proportion z-test p-value.
- `holm_correct(p_values)` — Holm-Bonferroni step-down correction
  (Holm 1979). Returns adjusted p-values in the input order.
- `cross_tab(rows, row_col, segment_col)` — builds a 2-D table + runs
  chi-square on it.

CLI: python3 -m helpers.stats --selftest
"""
from __future__ import annotations
import sys
import math


# ---- chi-square ------------------------------------------------------

def _gammainc_regularized(a: float, x: float) -> float:
    """Regularized lower incomplete gamma P(a, x). Series expansion
    for x < a + 1, continued-fraction otherwise (Numerical Recipes)."""
    if x < 0 or a <= 0:
        return 0.0
    if x == 0:
        return 0.0
    if x < a + 1:
        # Series expansion.
        ap = a
        s = 1.0 / a
        term = s
        for _ in range(200):
            ap += 1
            term *= x / ap
            s += term
            if abs(term) < abs(s) * 1e-12:
                break
        return s * math.exp(-x + a * math.log(x) - math.lgamma(a))
    # Continued fraction (upper) then 1 - Q
    b = x + 1.0 - a
    c = 1.0 / 1e-300
    d = 1.0 / b
    h = d
    for i in range(1, 200):
        an = -i * (i - a)
        b += 2.0
        d = an * d + b
        if abs(d) < 1e-300:
            d = 1e-300
        c = b + an / c
        if abs(c) < 1e-300:
            c = 1e-300
        d = 1.0 / d
        h *= d * c
        if abs(d * c - 1.0) < 1e-12:
            break
    q = h * math.exp(-x + a * math.log(x) - math.lgamma(a))
    return 1.0 - q


def chi_square_pvalue(chi2: float, df: int) -> float:
    """p-value for chi-square test = 1 - P(df/2, chi2/2)."""
    if df < 1 or chi2 < 0:
        return 1.0
    return 1.0 - _gammainc_regularized(df / 2.0, chi2 / 2.0)


def chi_square(observed: list[list[int]]) -> dict:
    """Pearson chi-square test of independence on a 2-D contingency table.

    Returns {chi2, df, p, valid (bool)}. `valid` is False when any
    expected-cell count < 5 (the usual rule of thumb).
    """
    nrows = len(observed)
    if nrows == 0:
        return {"chi2": 0.0, "df": 0, "p": 1.0, "valid": False}
    ncols = len(observed[0])
    row_totals = [sum(r) for r in observed]
    col_totals = [sum(observed[i][j] for i in range(nrows)) for j in range(ncols)]
    n = sum(row_totals)
    if n == 0:
        return {"chi2": 0.0, "df": 0, "p": 1.0, "valid": False}
    chi2 = 0.0
    valid = True
    for i in range(nrows):
        for j in range(ncols):
            expected = row_totals[i] * col_totals[j] / n
            if expected < 5:
                valid = False
            if expected > 0:
                chi2 += (observed[i][j] - expected) ** 2 / expected
    df = (nrows - 1) * (ncols - 1)
    p = chi_square_pvalue(chi2, df)
    return {"chi2": round(chi2, 4), "df": df, "p": round(p, 6), "valid": valid}


# ---- two-proportion z-test -------------------------------------------

def _phi(x: float) -> float:
    """Standard normal CDF using erf."""
    return 0.5 * (1.0 + math.erf(x / math.sqrt(2.0)))


def column_z_test(c1: int, n1: int, c2: int, n2: int) -> dict:
    """Two-sample test of proportions. `c1`/`n1`, `c2`/`n2` are
    success-counts and trials. Two-sided p-value."""
    if n1 == 0 or n2 == 0:
        return {"z": 0.0, "p": 1.0}
    p1 = c1 / n1
    p2 = c2 / n2
    p_pool = (c1 + c2) / (n1 + n2)
    se = math.sqrt(p_pool * (1 - p_pool) * (1 / n1 + 1 / n2))
    if se == 0:
        return {"z": 0.0, "p": 1.0}
    z = (p1 - p2) / se
    p = 2 * (1 - _phi(abs(z)))
    return {"z": round(z, 4), "p": round(p, 6)}


# ---- Holm correction -------------------------------------------------

def holm_correct(p_values: list[float]) -> list[float]:
    """Holm-Bonferroni step-down correction.

    Input: a list of raw p-values (the family).
    Output: list of adjusted p-values in the same order as input.

    Algorithm (Holm 1979):
      1. Sort p-values ascending.
      2. For i in 0..m-1: adjusted[i] = max((m-i) * p_sorted[i],
         adjusted[i-1])   (monotone non-decreasing).
      3. Cap each at 1.0.
      4. Un-sort back to input order.
    """
    m = len(p_values)
    if m == 0:
        return []
    indexed = sorted(enumerate(p_values), key=lambda kv: kv[1])
    adjusted_sorted = [0.0] * m
    running_max = 0.0
    for rank, (_, p) in enumerate(indexed):
        adj = min((m - rank) * p, 1.0)
        running_max = max(running_max, adj)
        adjusted_sorted[rank] = running_max
    # Restore input order.
    out = [0.0] * m
    for rank, (orig_idx, _) in enumerate(indexed):
        out[orig_idx] = round(adjusted_sorted[rank], 6)
    return out


# ---- cross-tab -------------------------------------------------------

def cross_tab(rows, row_col, segment_col) -> dict:
    """Build a 2-D contingency table; run chi-square; return cells + base.

    Returns:
      {row_values, segment_values, cells: {<row_val>: {<seg_val>: count}},
       base_per_segment: {<seg_val>: n}, chi_square: {chi2, df, p, valid}}
    """
    row_vals_set: dict = {}
    seg_vals_set: dict = {}
    table: dict = {}
    for r in rows:
        rv = r.get(row_col)
        sv = r.get(segment_col)
        if rv in (None, "", "NA") or sv in (None, "", "NA"):
            continue
        rv = str(rv); sv = str(sv)
        row_vals_set.setdefault(rv, True)
        seg_vals_set.setdefault(sv, True)
        table.setdefault(rv, {}).setdefault(sv, 0)
        table[rv][sv] += 1
    row_values = list(row_vals_set)
    seg_values = list(seg_vals_set)
    cells = {rv: {sv: table.get(rv, {}).get(sv, 0) for sv in seg_values}
             for rv in row_values}
    base_per_segment = {sv: sum(cells[rv][sv] for rv in row_values) for sv in seg_values}
    observed = [[cells[rv][sv] for sv in seg_values] for rv in row_values]
    chi2 = chi_square(observed)
    return {"row_values": row_values, "segment_values": seg_values,
            "cells": cells, "base_per_segment": base_per_segment,
            "chi_square": chi2}


# ---- selftest --------------------------------------------------------

def _selftest() -> int:
    # Holm: known fixture (Holm 1979 / textbook).
    raw = [0.001, 0.008, 0.039, 0.041, 0.042]
    adj = holm_correct(raw)
    # Hand-computed adjusted: 0.005, 0.032, 0.117, 0.117, 0.117
    assert abs(adj[0] - 0.005) < 1e-3, adj
    assert abs(adj[1] - 0.032) < 1e-3, adj
    assert adj[2] == adj[3] == adj[4], adj
    # Holm preserves order: monotonic when re-sorted.
    sorted_adj = sorted(adj)
    for i in range(1, len(sorted_adj)):
        assert sorted_adj[i] >= sorted_adj[i - 1]
    # chi-square: 2x2 table known answer (Yates' uncorrected).
    obs = [[20, 30], [30, 20]]
    cs = chi_square(obs)
    assert cs["df"] == 1, cs
    assert 3.9 < cs["chi2"] < 4.1, cs   # ≈ 4.0
    assert cs["p"] < 0.05, cs
    # z-test: 50/100 vs 30/100 → significant
    zt = column_z_test(50, 100, 30, 100)
    assert zt["p"] < 0.01, zt
    # cross-tab integration
    rows = ([{"q": "A", "seg": "X"}] * 30 + [{"q": "A", "seg": "Y"}] * 10
            + [{"q": "B", "seg": "X"}] * 5 + [{"q": "B", "seg": "Y"}] * 25)
    ct = cross_tab(rows, "q", "seg")
    assert ct["cells"]["A"]["X"] == 30, ct
    assert ct["base_per_segment"]["X"] == 35, ct
    assert ct["chi_square"]["p"] < 0.001, ct
    print("stats: chi_square, column_z_test, holm_correct, cross_tab — all OK")
    return 0


if __name__ == "__main__":
    if "--selftest" in sys.argv:
        sys.exit(_selftest())
    print("usage: python3 -m helpers.stats --selftest")
    sys.exit(64)
