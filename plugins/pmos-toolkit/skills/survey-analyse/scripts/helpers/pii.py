"""pii.py — PII regex detectors for verbatim quotes.

Dependencies: stdlib only.

**Detect-and-warn only.** The parent skill (Phase 5) uses these matches
to surface a chat-side count BEFORE the report renders, but the verbatim
text is emitted unchanged into the report. See SKILL.md Anti-Pattern #7.

Functions
---------
detect_pii(text) -> {email_matches, phone_matches, name_matches}

CLI: python3 -m helpers.pii --selftest
"""
from __future__ import annotations
import re
import sys


EMAIL_RE = re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}")
# Permissive phone regex — international + US; requires ≥7 digits to limit FPs.
PHONE_RE = re.compile(
    r"(?:\+?\d{1,3}[-.\s]?)?\(?\d{2,4}\)?[-.\s]?\d{3,4}[-.\s]?\d{3,4}"
)
NAME_RE = re.compile(r"\b(Mr|Mrs|Ms|Dr|Prof)\.?\s+[A-Z][a-z]+(?:\s+[A-Z][a-z]+)?\b")


def detect_pii(text: str) -> dict:
    if not isinstance(text, str):
        return {"email_matches": [], "phone_matches": [], "name_matches": []}
    emails = EMAIL_RE.findall(text)
    # Filter phone matches: require >= 7 digits total to drop noisy false-positives.
    phones: list[str] = []
    for m in PHONE_RE.finditer(text):
        digits = re.sub(r"\D", "", m.group(0))
        if len(digits) >= 7:
            phones.append(m.group(0))
    # NAME_RE.findall returns the honorific capture group only; use finditer
    # to keep the full matched span (honorific + name).
    name_full = [m.group(0) for m in NAME_RE.finditer(text)]
    return {
        "email_matches": emails,
        "phone_matches": phones,
        "name_matches": name_full,
    }


def _selftest() -> int:
    q = "I'm Sarah Connor; reach me at sarah.connor@cyberdyne.com or +1 (415) 555-1234."
    out = detect_pii(q)
    assert "sarah.connor@cyberdyne.com" in out["email_matches"], out
    assert any("415" in p for p in out["phone_matches"]), out
    # Honorific-name pattern
    q2 = "Dr. Alice Smith said this was great."
    out2 = detect_pii(q2)
    assert any("Alice Smith" in n for n in out2["name_matches"]), out2
    # Clean text — no false positives
    clean = "I love the integrations and would recommend to anyone."
    out3 = detect_pii(clean)
    assert out3["email_matches"] == [] and out3["phone_matches"] == [] and out3["name_matches"] == [], out3
    # Brand name without honorific should NOT match
    q4 = "Apple integration is the best."
    out4 = detect_pii(q4)
    assert out4["name_matches"] == [], out4
    print("pii.detect_pii: OK")
    return 0


if __name__ == "__main__":
    if "--selftest" in sys.argv:
        sys.exit(_selftest())
    print("usage: python3 -m helpers.pii --selftest")
    sys.exit(64)
