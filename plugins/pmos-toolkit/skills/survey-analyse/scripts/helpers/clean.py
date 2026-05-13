"""clean.py — pre-analysis data-quality detectors.

Dependencies: stdlib only.

Returns lists of row indices for each rule; the parent skill decides
whether to exclude (and records every rule + count in `cleaning.json`).
See `reference/data-quality-and-reporting.md` Part A for the dispositions.

Functions
---------
detect_straightliners(rows, matrix_cols) -> [row_indices]
detect_speeders(rows, duration_col, threshold_ratio=0.5) -> [row_indices]
detect_incompletes(rows, must_have_cols=None, min_completion_ratio=0.80) -> [row_indices]
detect_duplicates(rows, key_cols) -> [row_indices]
detect_failed_attention(rows, attention_checks) -> [row_indices]

CLI: python3 -m helpers.clean --selftest
"""
from __future__ import annotations
import statistics
import sys


def detect_straightliners(rows, matrix_cols: list[list[str]]) -> list[int]:
    """matrix_cols: list of column-groups (one group per matrix question).
    A respondent is flagged if any one group has zero variance AND has
    at least max(3, len(group)-1) non-null answers."""
    flagged = []
    for idx, r in enumerate(rows):
        for group in matrix_cols:
            vals = []
            for c in group:
                v = r.get(c)
                if v in (None, "", "NA"):
                    continue
                try:
                    vals.append(int(v))
                except (ValueError, TypeError):
                    continue
            if len(vals) >= max(3, len(group) - 1) and len(set(vals)) == 1:
                flagged.append(idx)
                break
    return flagged


def detect_speeders(rows, duration_col: str, threshold_ratio: float = 0.5) -> list[int]:
    """Threshold: completion time < threshold_ratio * median completion time.
    Computed AFTER all responses loaded (not on a running sample)."""
    durations: list[tuple[int, float]] = []
    for idx, r in enumerate(rows):
        v = r.get(duration_col)
        if v in (None, "", "NA"):
            continue
        try:
            d = float(v)
        except (ValueError, TypeError):
            continue
        durations.append((idx, d))
    if not durations:
        return []
    median = statistics.median(d for _, d in durations)
    cutoff = median * threshold_ratio
    return [idx for idx, d in durations if d < cutoff]


def detect_incompletes(rows, must_have_cols=None, min_completion_ratio: float = 0.80) -> list[int]:
    """A respondent is incomplete if:
       - any must_have_cols value is blank, OR
       - fewer than `min_completion_ratio` of the columns are non-blank."""
    if not rows:
        return []
    must_have_cols = list(must_have_cols or [])
    all_cols = list(rows[0].keys())
    flagged = []
    for idx, r in enumerate(rows):
        for c in must_have_cols:
            if r.get(c) in (None, "", "NA"):
                flagged.append(idx)
                break
        else:
            non_blank = sum(1 for c in all_cols if r.get(c) not in (None, "", "NA"))
            if non_blank / len(all_cols) < min_completion_ratio:
                flagged.append(idx)
    return flagged


def detect_duplicates(rows, key_cols: list[str]) -> list[int]:
    """First occurrence kept; subsequent rows with the same composite key flagged."""
    seen = {}
    flagged = []
    for idx, r in enumerate(rows):
        key = tuple(str(r.get(c, "")) for c in key_cols)
        if not any(key):
            continue
        if key in seen:
            flagged.append(idx)
        else:
            seen[key] = idx
    return flagged


def detect_failed_attention(rows, attention_checks: list[dict]) -> list[int]:
    """attention_checks: list of {col, expected}. Returns respondents who
    failed >= 2 checks (do not exclude on a single failure — false-positive
    risk per reference/data-quality-and-reporting.md §attention)."""
    flagged = []
    for idx, r in enumerate(rows):
        fails = 0
        for chk in attention_checks:
            actual = r.get(chk["col"])
            if actual is None or str(actual).strip().lower() != str(chk["expected"]).strip().lower():
                fails += 1
        if fails >= 2:
            flagged.append(idx)
    return flagged


def _selftest() -> int:
    # Straightlining
    rows = [
        {"m1": "4", "m2": "4", "m3": "5", "m4": "4"},
        {"m1": "3", "m2": "3", "m3": "3", "m4": "3"},
        {"m1": "5", "m2": "1", "m3": "3", "m4": "4"},
    ]
    sl = detect_straightliners(rows, [["m1", "m2", "m3", "m4"]])
    assert sl == [1], sl
    # Speeders
    rows = [{"d": "100"}, {"d": "50"}, {"d": "20"}, {"d": "120"}, {"d": "90"}]
    sp = detect_speeders(rows, "d", threshold_ratio=0.5)
    # median = 90, cutoff = 45 → only idx 2 (20) is below
    assert sp == [2], sp
    # Incompletes
    rows = [{"a": "1", "b": "2"}, {"a": "", "b": "2"}, {"a": "1", "b": ""}]
    ic = detect_incompletes(rows, must_have_cols=["a"], min_completion_ratio=0.5)
    assert ic == [1], ic
    # Duplicates
    rows = [{"e": "a@x"}, {"e": "b@x"}, {"e": "a@x"}]
    du = detect_duplicates(rows, ["e"])
    assert du == [2], du
    # Attention checks (need >= 2 fails)
    rows = [{"q1": "Strongly agree", "q2": "Strongly agree"},  # both pass
            {"q1": "Disagree", "q2": "Agree"},                  # both fail
            {"q1": "Strongly agree", "q2": "Disagree"}]         # one fails
    at = detect_failed_attention(rows, [
        {"col": "q1", "expected": "Strongly agree"},
        {"col": "q2", "expected": "Strongly agree"},
    ])
    assert at == [1], at
    print("clean.detect_*: OK")
    return 0


if __name__ == "__main__":
    if "--selftest" in sys.argv:
        sys.exit(_selftest())
    print("usage: python3 -m helpers.clean --selftest")
    sys.exit(64)
