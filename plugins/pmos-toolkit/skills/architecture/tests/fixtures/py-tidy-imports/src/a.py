# Purpose: T10 fixture — TID252 relative-import + B006 mutable default; ruff must flag.
from .b import value


def f(items=[]):  # B006: mutable default arg
    return items + [value]
