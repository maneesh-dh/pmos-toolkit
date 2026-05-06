"""Editorial theme — schema validation + AA contrast + atoms."""
import pathlib
import sys

HERE = pathlib.Path(__file__).parent
sys.path.insert(0, str(HERE))
import run  # noqa: E402


def test_editorial_theme_validates():
    theme = run.load_theme("editorial")
    assert theme["name"] == "editorial"
    assert theme["surface"]["background"].upper() == "#F4EFE6"
    assert theme["connectors"]["mixingPermitted"] is True
    assert theme["infographic"]["supported"] is True
    assert theme["infographic"]["layout"] == "editorial-v1"


def test_editorial_pinned_accents():
    theme = run.load_theme("editorial")
    roles = {a["pinnedRole"]: a["hex"].upper() for a in theme["palette"]["accents"] if "pinnedRole" in a}
    assert roles["feedback"] == "#1E3A8A"
    # Spec used #D9421C; we darkened to #B8351A to pass WCAG AA on cream.
    assert roles["emphasis"] == "#B8351A"


def test_editorial_byrole_dispatch_complete():
    theme = run.load_theme("editorial")
    by_role = theme["connectors"]["byRole"]
    for r in ["contribution", "emphasis", "feedback", "default"]:
        assert r in by_role, f"missing role: {r}"


def test_editorial_palette_passes_aa_on_cream():
    theme = run.load_theme("editorial")
    cream = theme["surface"]["background"]
    for a in theme["palette"]["accents"]:
        ratio = run.contrast_ratio(a["hex"], cream)
        assert ratio >= 4.5, f"{a['hex']} on {cream} is {ratio:.2f}:1, fails AA"


def test_editorial_atoms_exist():
    atoms = pathlib.Path(__file__).parents[1] / "themes" / "editorial" / "atoms"
    for name in [
        "eyebrow-mono",
        "dashed-container",
        "pastel-chip-stack",
        "computation-block",
        "return-loop-arrow",
    ]:
        path = atoms / f"{name}.svg"
        assert path.exists(), f"Missing atom: {name}.svg"
        # Atoms must be parseable XML and use only theme-token colors
        import xml.etree.ElementTree as ET
        ET.parse(path)  # raises if malformed


def test_editorial_atoms_use_only_theme_palette():
    """Each atom's fill/stroke values must be in the editorial palette set
    (or recognized non-color keywords like 'none', 'context-stroke')."""
    import re
    theme = run.load_theme("editorial")
    palette = run.build_palette_set(theme)
    # Editorial-specific extras: chip-warm/cool hexes, dashed container stroke, ink chip
    for chip in theme["palette"].get("categoryChips", []):
        palette.add(chip["hex"].upper())
    palette.add(theme["surface"]["containerStrokeColor"].upper())

    atoms = pathlib.Path(__file__).parents[1] / "themes" / "editorial" / "atoms"
    hex_pat = re.compile(r"#[0-9A-Fa-f]{6}")
    for atom in atoms.glob("*.svg"):
        text = atom.read_text()
        for m in hex_pat.findall(text):
            assert m.upper() in palette, f"{atom.name}: color {m} not in editorial palette"
