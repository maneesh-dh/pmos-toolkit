"""nps.py — Net Promoter Score helpers.

Dependencies: stdlib only.

NPS = %Promoters (9-10) - %Detractors (0-6), reported as an **integer**
in [-100, +100]. **Never an average of the 0-10 scores.** See SKILL.md
Anti-Pattern #4.

CLI: python3 -m helpers.nps --selftest
"""
from __future__ import annotations
import sys


def nps(rows, col) -> dict:
    promoters = passives = detractors = 0
    valid = 0
    for r in rows:
        v = r.get(col)
        if v in (None, "", "NA"):
            continue
        try:
            iv = int(v)
        except (ValueError, TypeError):
            continue
        if iv < 0 or iv > 10:
            continue
        valid += 1
        if iv >= 9:
            promoters += 1
        elif iv >= 7:
            passives += 1
        else:
            detractors += 1
    if not valid:
        return {"n": 0, "promoter_percent": 0.0, "passive_percent": 0.0,
                "detractor_percent": 0.0, "nps_score": 0}
    pp = round(100 * promoters / valid, 1)
    pa = round(100 * passives / valid, 1)
    pd = round(100 * detractors / valid, 1)
    # NPS is an integer.
    score = int(round(pp - pd))
    return {"n": valid, "promoter_percent": pp, "passive_percent": pa,
            "detractor_percent": pd, "nps_score": score}


def _selftest() -> int:
    # 38.4% promoters, 42.3% passive, 19.2% detractor → NPS = 19 (integer).
    rows = (
        [{"r": 10}] * 100 + [{"r": 9}] * 88   # 188 promoters
        + [{"r": 8}] * 110 + [{"r": 7}] * 97   # 207 passives
        + [{"r": 6}] * 40 + [{"r": 5}] * 25 + [{"r": 0}] * 29   # 94 detractors
    )
    out = nps(rows, "r")
    assert out["n"] == 489, out
    assert out["nps_score"] == 19, out
    assert isinstance(out["nps_score"], int), "NPS must be int"
    # Bad inputs ignored
    bad = nps([{"r": "x"}, {"r": 11}, {"r": -1}, {"r": None}, {"r": "10"}], "r")
    assert bad["n"] == 1 and bad["nps_score"] == 100, bad
    print("nps.nps: OK")
    return 0


if __name__ == "__main__":
    if "--selftest" in sys.argv:
        sys.exit(_selftest())
    print("usage: python3 -m helpers.nps --selftest")
    sys.exit(64)
