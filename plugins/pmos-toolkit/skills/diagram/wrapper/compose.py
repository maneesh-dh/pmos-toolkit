"""Editorial-v1 infographic wrapper composition.

Wraps a Phase-6 diagram SVG with the editorial-v1 layout: eyebrow / headline /
lede / fig label / embedded diagram / legend / captions / footer.

Public entrypoint:
    compose_wrapper(diagram_svg, wrapped_text, theme, anchor_mode, renderer,
                    font_metrics_available=False, return_info=False)
"""
from __future__ import annotations

import re
import xml.etree.ElementTree as ET

from .anchors import assign_markers
from .caption_grid import GLYPHS_FOR_ORDINAL, caption_layout, clamp_captions

# --------------------------------------------------------------------------
# Layout constants (editorial-v1 spec §2)
# --------------------------------------------------------------------------
CANVAS_WIDTH = 1280
MARGIN_L = 64
MARGIN_R = 64
MARGIN_T = 56
MARGIN_B = 48

ZONE_EYEBROW_H = 24
ZONE_HEADLINE_LINE_H = 52  # display 36–44 leading
ZONE_HEADLINE_MAX_LINES = 2
ZONE_LEDE_LINE_H = 22  # body 16, leading ~22
ZONE_LEDE_MAX_LINES = 5
ZONE_FIG_LABEL_H = 16
ZONE_LEGEND_H = 32
ZONE_FOOTER_H = 16

# Zone gap (vertical breathing room between zones)
ZONE_GAP = 24

# Heuristic wrap factor: width ≈ font_size_px * 0.55 per char (with 5% slack).
HEURISTIC_WIDTH_PER_CHAR = 0.55
HEURISTIC_SLACK = 1.05

SVG_NS = "http://www.w3.org/2000/svg"
ET.register_namespace("", SVG_NS)


# --------------------------------------------------------------------------
# Markdown-bold parser (only **...** is supported in v1)
# --------------------------------------------------------------------------
_BOLD_RE = re.compile(r"\*\*([^*]+)\*\*")


def parse_bold_runs(text: str) -> list[dict]:
    """Tokenize `text` into a list of {text, bold} runs."""
    runs: list[dict] = []
    pos = 0
    for m in _BOLD_RE.finditer(text):
        if m.start() > pos:
            runs.append({"text": text[pos:m.start()], "bold": False})
        runs.append({"text": m.group(1), "bold": True})
        pos = m.end()
    if pos < len(text):
        runs.append({"text": text[pos:], "bold": False})
    return runs or [{"text": text, "bold": False}]


# --------------------------------------------------------------------------
# Text wrapping
# --------------------------------------------------------------------------
def _runs_to_words(runs: list[dict]) -> list[dict]:
    """Convert run list to per-word records with bold flag preserved."""
    out: list[dict] = []
    for run in runs:
        for word in run["text"].split():
            out.append({"text": word, "bold": run["bold"]})
    return out


def heuristic_wrap_words(words: list[dict], width_px: int, font_size_px: int) -> list[list[dict]]:
    """Greedy fill — returns list of lines, each a list of word-dicts."""
    if not words:
        return [[]]
    char_w = font_size_px * HEURISTIC_WIDTH_PER_CHAR * HEURISTIC_SLACK
    max_chars_per_line = max(1, int(width_px / char_w))
    lines: list[list[dict]] = []
    current: list[dict] = []
    current_len = 0
    for word in words:
        wlen = len(word["text"])
        # +1 for the space we'll insert before this word
        proposed = current_len + (1 if current else 0) + wlen
        if proposed > max_chars_per_line and current:
            lines.append(current)
            current = [word]
            current_len = wlen
        else:
            current.append(word)
            current_len = proposed
    if current:
        lines.append(current)
    return lines


def wrap_lede(text: str, width_px: int, font_size_px: int, mode: str) -> dict:
    """Wrap `text` (markdown-bold permitted) for the given renderer/metrics mode.

    Returns:
        {"strategy": "foreignobject" | "tspan", "lines": [[run, ...], ...], "html": "..."}
    """
    runs = parse_bold_runs(text)
    if mode == "foreignobject":
        # Build HTML <p> with <strong> spans
        html_parts: list[str] = []
        for run in runs:
            esc = _xml_escape(run["text"])
            if run["bold"]:
                html_parts.append(f"<strong>{esc}</strong>")
            else:
                html_parts.append(esc)
        return {"strategy": "foreignobject", "lines": [], "html": "".join(html_parts)}

    # heuristic + metrics both produce tspan lines (metrics uses same heuristic in v1; spec §13)
    words = _runs_to_words(runs)
    lines = heuristic_wrap_words(words, width_px, font_size_px)
    return {"strategy": "tspan", "lines": lines, "html": ""}


def wrap_with_truncate(text: str, width_px: int, font_size_px: int, max_lines: int) -> list[list[dict]]:
    """Heuristic wrap for headline-style text with hard cap; truncates with '…'."""
    words = _runs_to_words(parse_bold_runs(text))
    lines = heuristic_wrap_words(words, width_px, font_size_px)
    if len(lines) <= max_lines:
        return lines
    # Truncate to max_lines, ellipsizing the last allowed line.
    kept = lines[: max_lines]
    last = kept[-1]
    if last:
        last[-1] = {"text": last[-1]["text"].rstrip(",.;:") + "…", "bold": last[-1]["bold"]}
    return kept


# --------------------------------------------------------------------------
# SVG generation helpers
# --------------------------------------------------------------------------
def _xml_escape(s: str) -> str:
    return (s.replace("&", "&amp;")
             .replace("<", "&lt;")
             .replace(">", "&gt;")
             .replace('"', "&quot;"))


def _emit_tspan_lines(lines: list[list[dict]], font_size: int, line_h: int, base_x: int) -> str:
    """Emit <tspan> rows for greedily-wrapped word lines."""
    parts: list[str] = []
    for i, line in enumerate(lines):
        dy = "0" if i == 0 else str(line_h)
        # Concatenate words within a line, splitting on bold boundary if needed.
        # For simplicity: one tspan per word when bold differs, else single concatenated tspan.
        line_xml: list[str] = []
        cur_bold: bool | None = None
        cur_buf: list[str] = []
        for word in line:
            if cur_bold is None or word["bold"] == cur_bold:
                cur_buf.append(word["text"])
                cur_bold = word["bold"]
            else:
                weight = "600" if cur_bold else "400"
                line_xml.append(f'<tspan font-weight="{weight}">{_xml_escape(" ".join(cur_buf))}</tspan>')
                cur_buf = [word["text"]]
                cur_bold = word["bold"]
        if cur_buf:
            weight = "600" if cur_bold else "400"
            line_xml.append(f'<tspan font-weight="{weight}">{_xml_escape(" ".join(cur_buf))}</tspan>')
        parts.append(f'<tspan x="{base_x}" dy="{dy}">{"".join(line_xml)}</tspan>')
    return "".join(parts)


def _resolve_color_token(value: str, theme: dict) -> str:
    """Resolve a token name (e.g. 'ink', 'accent-primary') OR pass through a hex."""
    if value.startswith("#"):
        return value
    pal = theme.get("palette", {})
    surf = theme.get("surface", {})
    aliases = {
        "ink": pal.get("ink"),
        "ink-muted": pal.get("inkMuted"),
        "inkMuted": pal.get("inkMuted"),
        "warn": pal.get("warn"),
        "surface": pal.get("surface") or surf.get("background"),
    }
    if value in aliases and aliases[value]:
        return aliases[value]
    for accent in pal.get("accents", []):
        if accent.get("token") == value or accent.get("name") == value:
            return accent["hex"]
        if accent.get("pinnedRole") == value:
            return accent["hex"]
    for chip in pal.get("categoryChips", []):
        if chip.get("token") == value or chip.get("name") == value:
            return chip["hex"]
    return value  # let caller see the unknown token; caller may reject it


# --------------------------------------------------------------------------
# Diagram embedding
# --------------------------------------------------------------------------
def _parse_diagram(diagram_svg: str) -> tuple[str, tuple[float, float, float, float]]:
    """Return (inner_xml, (vbX, vbY, vbW, vbH)) for the diagram SVG."""
    if diagram_svg.lstrip().startswith("<svg"):
        text = diagram_svg
    else:
        # treat as path
        from pathlib import Path
        text = Path(diagram_svg).read_text()

    # Strip the outer <svg ...> ... </svg> while preserving inner XML verbatim.
    open_match = re.search(r"<svg\b[^>]*>", text)
    close_idx = text.rfind("</svg>")
    if not open_match or close_idx == -1:
        raise ValueError("compose_wrapper: source diagram is not a parseable SVG")
    inner = text[open_match.end():close_idx]

    # Parse just the open tag for viewBox.
    open_tag = open_match.group(0)
    vb_match = re.search(r'viewBox="([^"]+)"', open_tag)
    if vb_match:
        nums = [float(n) for n in vb_match.group(1).split()]
        vbX, vbY, vbW, vbH = nums
    else:
        # Fall back to width/height
        wm = re.search(r'\bwidth="(\d+(?:\.\d+)?)"', open_tag)
        hm = re.search(r'\bheight="(\d+(?:\.\d+)?)"', open_tag)
        vbX, vbY = 0.0, 0.0
        vbW = float(wm.group(1)) if wm else 800.0
        vbH = float(hm.group(1)) if hm else 400.0
    return inner, (vbX, vbY, vbW, vbH)


# --------------------------------------------------------------------------
# Public entrypoint
# --------------------------------------------------------------------------
def _wrap_mode_for(renderer: str, font_metrics_available: bool) -> str:
    if renderer in ("rsvg-convert", "cairosvg", "rsvg"):
        return "heuristic"
    # Playwright (or unknown): with metrics → tspan path; without → foreignobject
    if font_metrics_available:
        return "metrics"  # emits tspans (metrics-aware in a future revision)
    return "foreignobject"


def compose_wrapper(
    diagram_svg: str,
    wrapped_text: dict,
    theme: dict,
    anchor_mode: str,
    renderer: str,
    font_metrics_available: bool = False,
    return_info: bool = False,
):
    """Compose the editorial-v1 infographic wrapper.

    `diagram_svg` may be the SVG text or a filesystem path.
    `wrapped_text` is the {eyebrow, headline, lede, figLabel, captions[], footer} dict.
    `anchor_mode` is "color" or "ordinal".
    `renderer` is one of "playwright", "rsvg-convert", "cairosvg".
    `font_metrics_available` only matters for the playwright path.

    Returns the composite SVG text, or (svg, info) when return_info=True.
    """
    # --- Diagram parse ---------------------------------------------------
    inner_diagram, (vbX, vbY, vbW, vbH) = _parse_diagram(diagram_svg)

    # --- Extract diagram element ids (id="...") for ordinal mirroring ----
    id_pattern = re.compile(r'\bid="([^"]+)"')
    diagram_ids = id_pattern.findall(inner_diagram)
    # Crude bbox lookup from rect/circle attributes
    bbox_by_id: dict[str, tuple[float, float, float, float]] = {}
    for el_match in re.finditer(r'<(rect|circle|ellipse|line|path)\b[^>]*\bid="([^"]+)"[^>]*>', inner_diagram):
        tag = el_match.group(1)
        eid = el_match.group(2)
        attrs = el_match.group(0)
        def num(name: str, default: float = 0.0) -> float:
            m = re.search(rf'\b{name}="(-?\d+(?:\.\d+)?)"', attrs)
            return float(m.group(1)) if m else default
        if tag == "rect":
            x = num("x"); y = num("y"); w = num("width"); h = num("height")
            bbox_by_id[eid] = (x + w / 2, y + h / 2, w, h)
        elif tag in ("circle", "ellipse"):
            cx = num("cx"); cy = num("cy")
            bbox_by_id[eid] = (cx, cy, 0.0, 0.0)
        elif tag == "line":
            x1 = num("x1"); y1 = num("y1"); x2 = num("x2"); y2 = num("y2")
            bbox_by_id[eid] = ((x1 + x2) / 2, (y1 + y2) / 2, 0.0, 0.0)
        elif tag == "path":
            # take the M command's first coords if present
            d_m = re.search(r'\bd="([^"]+)"', attrs)
            if d_m:
                first_xy = re.search(r"M\s*(-?\d+(?:\.\d+)?)\s*[, ]\s*(-?\d+(?:\.\d+)?)", d_m.group(1))
                if first_xy:
                    bbox_by_id[eid] = (float(first_xy.group(1)), float(first_xy.group(2)), 0.0, 0.0)

    # --- Caption clamp ---------------------------------------------------
    captions_in = list(wrapped_text.get("captions") or [])
    captions, clamp_info = clamp_captions(captions_in)
    n_caps = len(captions)

    # --- Caption layout --------------------------------------------------
    cap_layout = caption_layout(n_caps) if 3 <= n_caps <= 5 else None

    # --- Caption-color remaps (color mode only) --------------------------
    diagram_colors_upper = {h.upper() for h in re.findall(r"#[0-9A-Fa-f]{6}", inner_diagram)}
    remaps: list[dict] = []
    if anchor_mode == "color":
        for cap in captions:
            anchor = cap.get("anchorColor")
            if not anchor:
                continue
            resolved = _resolve_color_token(anchor, theme).upper()
            if resolved not in diagram_colors_upper:
                ink_hex = theme["palette"]["ink"]
                remaps.append({"from": anchor, "to": "ink", "reason": "color absent from diagram"})
                cap["_resolvedAnchor"] = ink_hex
            else:
                cap["_resolvedAnchor"] = resolved
    else:
        # ordinal mode: each caption gets a glyph + diagram element id pairing
        marker_pairs = assign_markers(
            captions,
            [{"id": cap.get("anchorElementId")} for cap in captions if cap.get("anchorElementId")],
        )
        for i, glyph, eid in marker_pairs:
            captions[i]["_glyph"] = glyph
            captions[i]["_anchorElementId"] = eid

    # --- Wrap zones text -------------------------------------------------
    text_width = CANVAS_WIDTH - MARGIN_L - MARGIN_R
    wrap_mode = _wrap_mode_for(renderer, font_metrics_available)
    headline_text = wrapped_text.get("headline") or ""
    headline_lines = wrap_with_truncate(headline_text, text_width, 36, ZONE_HEADLINE_MAX_LINES)
    headline_h = max(ZONE_HEADLINE_LINE_H, ZONE_HEADLINE_LINE_H * len(headline_lines))

    lede_text = wrapped_text.get("lede") or ""
    lede = wrap_lede(lede_text, text_width, 16, wrap_mode)
    if lede["strategy"] == "tspan":
        lede_lines = lede["lines"][: ZONE_LEDE_MAX_LINES]
        lede_h = max(ZONE_LEDE_LINE_H, ZONE_LEDE_LINE_H * len(lede_lines))
    else:  # foreignobject
        # Estimate height from char-count fallback
        approx_lines = max(1, min(ZONE_LEDE_MAX_LINES, len(lede_text) // 80 + 1))
        lede_h = ZONE_LEDE_LINE_H * approx_lines
        lede_lines = []

    # Diagram zone height: scale-to-fit width, compute scaled diagram height
    diagram_inset = 16
    diagram_scaled_w = text_width
    scale = (text_width - 2 * diagram_inset) / vbW if vbW else 1.0
    diagram_scaled_h = vbH * scale
    diagram_zone_h = int(diagram_scaled_h) + 2 * diagram_inset

    # Caption zone height: per-column tallest body; estimate by line count
    cap_zone_h = 0
    if cap_layout:
        for i, cap in enumerate(captions):
            col = cap_layout["columns"][i]
            body_text = cap.get("body") or ""
            body_lines = heuristic_wrap_words(_runs_to_words(parse_bold_runs(body_text)),
                                              col["width"], 13)
            est = 28 + 18 * max(1, len(body_lines))  # title + body lines
            cap_zone_h = max(cap_zone_h, est)
        if anchor_mode == "ordinal":
            cap_zone_h += 24  # leading glyph row

    # --- Compute zone Y offsets ------------------------------------------
    y = MARGIN_T
    y_eyebrow = y;       y += ZONE_EYEBROW_H + ZONE_GAP
    y_headline = y;      y += headline_h + ZONE_GAP
    y_lede = y;          y += lede_h + ZONE_GAP
    y_fig = y;           y += ZONE_FIG_LABEL_H + ZONE_GAP
    y_diagram = y;       y += diagram_zone_h + ZONE_GAP
    y_legend = y;        y += ZONE_LEGEND_H + ZONE_GAP
    y_caps = y;          y += cap_zone_h + ZONE_GAP if cap_zone_h else 0
    y_footer = y;        y += ZONE_FOOTER_H

    total_h = y + MARGIN_B
    surface = theme["surface"]["background"]
    ink = theme["palette"]["ink"]
    ink_muted = theme["palette"]["inkMuted"]

    # --- Emit composite SVG ----------------------------------------------
    parts: list[str] = []
    parts.append(f'<?xml version="1.0" encoding="UTF-8"?>')
    parts.append(f'<svg xmlns="http://www.w3.org/2000/svg" width="{CANVAS_WIDTH}" '
                 f'height="{int(total_h)}" viewBox="0 0 {CANVAS_WIDTH} {int(total_h)}" '
                 f'font-family="Inter, ui-sans-serif, system-ui, sans-serif">')
    parts.append(f'<title>{_xml_escape(headline_text)}</title>')
    parts.append(f'<rect class="bg" x="0" y="0" width="{CANVAS_WIDTH}" height="{int(total_h)}" fill="{surface}"/>')

    # Eyebrow
    parts.append(f'<g id="zone-eyebrow" transform="translate(0,{int(y_eyebrow)})">')
    parts.append(
        f'<text x="{MARGIN_L}" y="14" '
        f'font-family="ui-monospace, SFMono-Regular, Menlo, Consolas, monospace" '
        f'font-size="12" font-weight="400" fill="{ink_muted}" letter-spacing="0.96">'
        f'{_xml_escape((wrapped_text.get("eyebrow") or "").upper())}</text>'
    )
    parts.append('</g>')

    # Headline
    parts.append(f'<g id="zone-headline" transform="translate(0,{int(y_headline)})">')
    parts.append(
        f'<text x="{MARGIN_L}" y="44" font-size="36" font-weight="700" fill="{ink}">'
        f'{_emit_tspan_lines(headline_lines, 36, ZONE_HEADLINE_LINE_H, MARGIN_L)}</text>'
    )
    parts.append('</g>')

    # Lede
    parts.append(f'<g id="zone-lede" transform="translate(0,{int(y_lede)})">')
    if lede["strategy"] == "tspan":
        parts.append(
            f'<text x="{MARGIN_L}" y="18" font-size="16" font-weight="400" fill="{ink}">'
            f'{_emit_tspan_lines(lede_lines, 16, ZONE_LEDE_LINE_H, MARGIN_L)}</text>'
        )
    else:
        parts.append(
            f'<foreignObject x="{MARGIN_L}" y="0" width="{text_width}" height="{int(lede_h)}">'
            f'<body xmlns="http://www.w3.org/1999/xhtml" '
            f'style="margin:0;font:400 16px Inter,sans-serif;color:{ink};">'
            f'<p style="margin:0">{lede["html"]}</p></body></foreignObject>'
        )
    parts.append('</g>')

    # Fig label
    parts.append(f'<g id="zone-fig-label" transform="translate(0,{int(y_fig)})">')
    parts.append(
        f'<text x="{MARGIN_L}" y="12" '
        f'font-family="ui-monospace, SFMono-Regular, Menlo, Consolas, monospace" '
        f'font-size="12" font-weight="400" fill="{ink_muted}" letter-spacing="0.96">'
        f'{_xml_escape((wrapped_text.get("figLabel") or "").upper())}</text>'
    )
    parts.append('</g>')

    # Diagram (preserve element ids verbatim — via inner string copy)
    parts.append(f'<g id="zone-diagram" transform="translate(0,{int(y_diagram)})">')
    diagram_x = MARGIN_L + diagram_inset
    parts.append(
        f'<g transform="translate({diagram_x},{diagram_inset}) '
        f'scale({scale:.6f}) translate({-vbX},{-vbY})">'
    )
    parts.append(inner_diagram)
    parts.append('</g>')

    # Ordinal markers in diagram zone
    if anchor_mode == "ordinal":
        for cap in captions:
            eid = cap.get("_anchorElementId")
            glyph = cap.get("_glyph")
            if not eid or not glyph or eid not in bbox_by_id:
                continue
            cx, cy, _, _ = bbox_by_id[eid]
            # Translate diagram coords through the same transform as the embedded diagram
            x_in_canvas = diagram_x + (cx - vbX) * scale
            y_in_canvas = diagram_inset + (cy - vbY) * scale
            parts.append(
                f'<text x="{x_in_canvas:.1f}" y="{y_in_canvas:.1f}" '
                f'font-size="12" fill="{ink}" text-anchor="middle">{glyph}</text>'
            )
    parts.append('</g>')

    # Legend
    parts.append(f'<g id="zone-legend" transform="translate(0,{int(y_legend)})">')
    sw_x = MARGIN_L
    for accent in theme["palette"].get("accents", []):
        parts.append(
            f'<rect x="{sw_x}" y="6" width="16" height="16" rx="2" fill="{accent["hex"]}"/>'
        )
        label = accent.get("token") or accent.get("name") or accent["hex"]
        parts.append(
            f'<text x="{sw_x + 24}" y="20" font-size="12" fill="{ink}">{_xml_escape(label)}</text>'
        )
        sw_x += 16 + 8 + 12 * len(label) + 24
    parts.append('</g>')

    # Captions
    if cap_layout:
        parts.append(f'<g id="zone-captions" transform="translate(0,{int(y_caps)})">')
        for i, cap in enumerate(captions):
            col = cap_layout["columns"][i]
            x = col["x"]; cw = col["width"]
            rule_color = cap.get("_resolvedAnchor") or ink_muted
            # Left rule
            parts.append(
                f'<line class="caption-rule" x1="{x}" y1="0" x2="{x}" y2="{cap_zone_h}" '
                f'stroke="{rule_color}" stroke-width="2"/>'
            )
            content_x = x + 12
            content_w = cw - 12
            yy = 16
            if anchor_mode == "ordinal":
                glyph = cap.get("_glyph", "")
                parts.append(
                    f'<text x="{content_x}" y="{yy}" font-size="16" font-weight="700" fill="{ink}">'
                    f'{glyph}</text>'
                )
                yy += 22
            title = cap.get("title") or ""
            parts.append(
                f'<text x="{content_x}" y="{yy}" font-size="14" font-weight="600" fill="{ink}">'
                f'{_xml_escape(title)}</text>'
            )
            yy += 22
            body_lines = heuristic_wrap_words(
                _runs_to_words(parse_bold_runs(cap.get("body") or "")),
                content_w, 13,
            )
            for line in body_lines:
                parts.append(
                    f'<text x="{content_x}" y="{yy}" font-size="13" font-weight="400" fill="{ink}">'
                    f'{_emit_tspan_lines([line], 13, 18, content_x)}</text>'
                )
                yy += 18
        parts.append('</g>')

    # Footer
    parts.append(f'<g id="zone-footer" transform="translate(0,{int(y_footer)})">')
    parts.append(
        f'<text x="{MARGIN_L}" y="12" '
        f'font-family="ui-monospace, SFMono-Regular, Menlo, Consolas, monospace" '
        f'font-size="12" font-weight="400" fill="{ink_muted}" letter-spacing="0.96">'
        f'{_xml_escape((wrapped_text.get("footer") or "").upper())}</text>'
    )
    parts.append('</g>')

    parts.append('</svg>')
    svg_text = "\n".join(parts)

    info = {
        "captionAnchorMode": anchor_mode,
        "captionAnchorRemaps": remaps,
        "captionCountClamp": clamp_info,
    }
    if return_info:
        return svg_text, info
    return svg_text
