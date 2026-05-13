"""ranking.py — ranking-question helpers.

Dependencies: stdlib only.

Returns BOTH conventions (average rank — lower = more preferred; weighted
points — higher = more preferred) plus a `convention` field stating which
is being recommended for the report (avg_rank by default). Unranked items
are excluded from a respondent's contribution; the count of partial
rankings is reported.

CLI: python3 -m helpers.ranking --selftest
"""
from __future__ import annotations
import sys


def ranking_stats(rows, items_cols: dict) -> dict:
    """`items_cols` maps display item-name -> the rank-column for that item.

    Each cell holds the rank that respondent assigned to the item (1..k).
    Missing / non-integer cells are excluded for that respondent.
    """
    k = len(items_cols)
    items_data = {item: {"ranks": [], "weighted_pts": 0.0} for item in items_cols}
    partial_rankers = 0
    n_respondents = 0
    for r in rows:
        ranks_this_resp = {}
        for item, col in items_cols.items():
            v = r.get(col)
            if v in (None, "", "NA"):
                continue
            try:
                iv = int(v)
            except (ValueError, TypeError):
                continue
            if iv < 1 or iv > k:
                continue
            ranks_this_resp[item] = iv
        if not ranks_this_resp:
            continue
        n_respondents += 1
        if len(ranks_this_resp) < k:
            partial_rankers += 1
        for item, rank in ranks_this_resp.items():
            items_data[item]["ranks"].append(rank)
            items_data[item]["weighted_pts"] += (k - rank + 1)
    out = {"n_respondents": n_respondents, "k_items": k,
           "partial_rankers": partial_rankers, "items": {}}
    for item, data in items_data.items():
        n = len(data["ranks"])
        avg_rank = round(sum(data["ranks"]) / n, 2) if n else None
        wpts = round(data["weighted_pts"] / n_respondents, 2) if n_respondents else 0.0
        pct_top = round(100 * sum(1 for r in data["ranks"] if r == 1) / n_respondents, 1) if n_respondents else 0.0
        out["items"][item] = {"n_ranked": n, "avg_rank": avg_rank,
                              "weighted_points": wpts, "pct_top1": pct_top}
    out["convention"] = "avg_rank (lower = more preferred)"
    return out


def _selftest() -> int:
    rows = [
        {"a": 1, "b": 2, "c": 3},
        {"a": 2, "b": 1, "c": 3},
        {"a": 1, "b": 3, "c": 2},
        {"a": 1, "b": 2, "c": 3},
    ]
    out = ranking_stats(rows, {"A": "a", "B": "b", "C": "c"})
    assert out["n_respondents"] == 4, out
    assert out["k_items"] == 3, out
    assert out["items"]["A"]["avg_rank"] == 1.25, out["items"]["A"]
    assert out["items"]["A"]["pct_top1"] == 75.0, out["items"]["A"]
    assert out["items"]["A"]["weighted_points"] > out["items"]["B"]["weighted_points"], out
    # Partial-ranking fixture
    out2 = ranking_stats([{"a": 1, "b": 2}], {"A": "a", "B": "b", "C": "c"})
    assert out2["partial_rankers"] == 1, out2
    print("ranking.ranking_stats: OK")
    return 0


if __name__ == "__main__":
    if "--selftest" in sys.argv:
        sys.exit(_selftest())
    print("usage: python3 -m helpers.ranking --selftest")
    sys.exit(64)
