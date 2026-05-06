# Render SVG → PNG

The vision-reviewer subagent (Phase 5) needs a PNG of the SVG. The skill detects an available renderer in Phase 0 and refuses to run if none is found.

PNG path: `~/.pmos/diagram-cache/<slug>-<sha1-of-svg-bytes>.png`. Cache persists across runs (same content → reuse). Cleared explicitly via `/diagram --clear-cache`.

## Detection (Phase 0 hard gate)

Run these checks in order; first hit wins:

```bash
# 1. Playwright MCP — check if mcp__plugin_playwright_playwright__browser_navigate is available in the current session.
#    The skill cannot detect this from bash; it must check its own tool list at runtime.
#    If invoked from Claude Code with playwright plugin: available.

# 2. rsvg-convert
command -v rsvg-convert >/dev/null 2>&1

# 3. cairosvg
python3 -c "import cairosvg" 2>/dev/null
```

If all three fail → exit with the install hint:

```
/diagram requires an SVG renderer for vision review. Install one of:
  • Playwright MCP (preferred):  add the playwright plugin to your Claude Code session
  • rsvg-convert (macOS):        brew install librsvg
  • rsvg-convert (Linux):        apt-get install librsvg2-bin    # or your distro's equivalent
  • cairosvg (any platform):     pip install cairosvg
```

## Invocation by renderer

### 1. Playwright MCP (preferred)

```
1. Compute absolute path to the SVG.
2. Call mcp__plugin_playwright_playwright__browser_navigate
     url: "file:///Users/.../diagrams/<slug>.svg"
3. Call mcp__plugin_playwright_playwright__browser_resize
     width: 1280, height: <canvas height>
4. Call mcp__plugin_playwright_playwright__browser_take_screenshot
     fullPage: true, filename: "<cache-path>"
```

### 2. rsvg-convert

```bash
mkdir -p ~/.pmos/diagram-cache
rsvg-convert -w 1280 "<svg-path>" -o "<cache-path>"
```

`-w 1280` matches the canonical canvas width. Height auto-scales preserving aspect ratio.

### 3. cairosvg

```bash
mkdir -p ~/.pmos/diagram-cache
python3 -m cairosvg "<svg-path>" -o "<cache-path>" --output-width 1280
```

## Cache key derivation

```python
import hashlib, pathlib, re

def cache_path(svg_path, slug):
    body = pathlib.Path(svg_path).read_bytes()
    digest = hashlib.sha1(body).hexdigest()[:12]
    cache_dir = pathlib.Path.home() / ".pmos" / "diagram-cache"
    cache_dir.mkdir(parents=True, exist_ok=True)
    return cache_dir / f"{slug}-{digest}.png"
```

If the cache file already exists, skip rendering.

## `--clear-cache` behavior

Wipe `~/.pmos/diagram-cache/` (only — never any other directory). Exit 0 with a count of files removed.
