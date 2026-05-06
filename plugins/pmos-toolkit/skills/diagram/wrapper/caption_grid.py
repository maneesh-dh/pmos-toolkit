"""Caption auto-fit grid + clamp logic for the editorial-v1 infographic layout.

The 12-column grid maps caption count to columns:

    | n | cols-per-caption | inter-caption gutter |
    |---|------------------|----------------------|
    | 3 | 4 | 24 |
    | 4 | 3 | 24 |
    | 5 | 2 (one column spans 4) | 16 |

Clamp policy (spec D8): >5 drops weakest by body-length until 5; <3 returns
empty list (caller drops the caption block) so the wrapper rubric's
text-fit item never sees a half-populated row.
"""
from __future__ import annotations


GLYPHS_FOR_ORDINAL: list[str] = ["●", "▲", "■", "◆", "★"]


def caption_layout(n: int, total_width: int = 1280, margin: int = 64) -> dict:
    """Compute column geometry for `n` captions on a 12-col grid.

    Returns:
        {
          "cols_per_caption": int,
          "gutter": int,
          "columns": [{"x": int, "width": int}, ...]
        }
    """
    if n < 3 or n > 5:
        raise ValueError(f"caption_layout requires 3 <= n <= 5; got {n}")

    usable = total_width - 2 * margin

    if n == 3:
        cols_per = 4
        gutter = 24
        # 3 captions × 4 cols × col_w + 2 gutters of 24 = usable
        col_w = (usable - 2 * gutter) // 3
        widths = [col_w, col_w, col_w]
    elif n == 4:
        cols_per = 3
        gutter = 24
        # 4 captions × 3 cols × col_w + 3 gutters
        col_w = (usable - 3 * gutter) // 4
        widths = [col_w, col_w, col_w, col_w]
    else:  # n == 5
        cols_per = 2
        gutter = 16
        # 5 captions: 4 narrow (2-col) + 1 wide (4-col), 4 gutters of 16
        # Narrow_w * 4 + Wide_w + 4*16 = usable; Wide_w == 2*Narrow_w
        # So Narrow_w * 6 = usable - 64 ⇒ Narrow_w = (usable - 64) / 6
        narrow_w = (usable - 4 * gutter) // 6
        wide_w = narrow_w * 2
        widths = [narrow_w, narrow_w, wide_w, narrow_w, narrow_w]

    columns = []
    x = margin
    for w in widths:
        columns.append({"x": x, "width": w})
        x += w + gutter

    return {"cols_per_caption": cols_per, "gutter": gutter, "columns": columns}


def clamp_captions(captions: list[dict]) -> tuple[list[dict], dict]:
    """Apply caption count clamp policy.

    Returns (kept_captions, clamp_info).
    clamp_info shape: {"from": int, "to": int, "reason": str}
                      or {} when no clamping was needed.

    - >5: drop weakest by body length until 5 remain (deterministic — ties
      broken by original index).
    - <3: returns []; caller is expected to drop the caption block entirely.
    - 3, 4, 5: passthrough; clamp_info is {}.
    """
    n = len(captions)
    if 3 <= n <= 5:
        return list(captions), {}

    if n < 3:
        return [], {"from": n, "to": 0, "reason": "insufficient captions"}

    # n > 5: rank by body length descending; tie-break by original index ascending.
    ranked = sorted(
        enumerate(captions),
        key=lambda pair: (-len(pair[1].get("body") or ""), pair[0]),
    )
    kept_pairs = ranked[:5]
    # Restore original order to keep author's intent.
    kept_pairs.sort(key=lambda pair: pair[0])
    kept = [c for _, c in kept_pairs]
    return kept, {"from": n, "to": 5, "reason": "drop-weakest"}
