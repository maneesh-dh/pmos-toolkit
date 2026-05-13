"""multi_select.py — multiple-response ("select all that apply") helpers.

Dependencies: stdlib only.

Percentages are **% of respondents** (count of selectors / n_respondents).
They will sum to >100% by design — this is correct, not a bug.

Functions
---------
multi_select_table(rows, col, delimiter="|")
    -> {n_respondents, option_counts, option_percent_of_respondents,
        mean_selected_per_respondent}

CLI: python3 -m helpers.multi_select --selftest
"""
from __future__ import annotations
import sys
from collections import Counter


def multi_select_table(rows: list[dict], col: str, delimiter: str = "|") -> dict:
    n_respondents = 0
    counts: Counter = Counter()
    selected_per_resp: list[int] = []
    for r in rows:
        raw = r.get(col)
        if raw in (None, ""):
            continue
        n_respondents += 1
        opts = [o.strip() for o in str(raw).split(delimiter) if o.strip()]
        # Deduplicate within a respondent (some platforms repeat the option).
        opts = list(dict.fromkeys(opts))
        selected_per_resp.append(len(opts))
        for o in opts:
            counts[o] += 1
    ordered = sorted(counts.items(), key=lambda kv: (-kv[1], kv[0]))
    option_counts = {k: v for k, v in ordered}
    option_percent = {
        k: round(100 * v / n_respondents, 1) if n_respondents else 0.0
        for k, v in ordered
    }
    mean_sel = (
        round(sum(selected_per_resp) / len(selected_per_resp), 2)
        if selected_per_resp else 0.0
    )
    return {
        "n_respondents": n_respondents,
        "option_counts": option_counts,
        "option_percent_of_respondents": option_percent,
        "mean_selected_per_respondent": mean_sel,
    }


def _selftest() -> int:
    rows = [
        {"features": "Reports|Integrations"},
        {"features": "Reports"},
        {"features": "Reports|Mobile|API"},
        {"features": ""},
        {"features": "Mobile|Reports"},
    ]
    out = multi_select_table(rows, "features")
    assert out["n_respondents"] == 4, out
    assert out["option_counts"]["Reports"] == 4, out
    assert out["option_percent_of_respondents"]["Reports"] == 100.0, out
    assert out["option_percent_of_respondents"]["Mobile"] == 50.0, out
    assert out["mean_selected_per_respondent"] == 2.0, out
    # Percentages SHOULD sum to > 100%
    total = sum(out["option_percent_of_respondents"].values())
    assert total > 100, f"expected sum>100, got {total}"
    print("multi_select.multi_select_table: OK")
    return 0


if __name__ == "__main__":
    if "--selftest" in sys.argv:
        sys.exit(_selftest())
    print("usage: python3 -m helpers.multi_select --selftest")
    sys.exit(64)
