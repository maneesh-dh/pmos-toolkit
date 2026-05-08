# Deploy norms detection rubric

Used by `/complete-dev` Phase 5. Probe these signals in order, **collect ALL hits**, then emit a recommendation. Never silently pick.

## Signal catalog

### 1. CLAUDE.md / AGENTS.md explicit section

Look for an `## Deploy` or `## Release` heading with a command listed. Highest authority — the user has written it down.

```bash
grep -nE "^## (Deploy|Release|Shipping)" CLAUDE.md AGENTS.md 2>/dev/null
```

If found, read the section verbatim and treat the listed command as the recommended path.

### 2. package.json scripts

```bash
python3 -c "import json; d=json.load(open('package.json'))['scripts']; print({k:v for k,v in d.items() if k in ('deploy','release','publish','ship')})"
```

Common patterns:
- `"deploy": "vercel deploy --prod"` → Vercel
- `"deploy": "netlify deploy --prod"` → Netlify
- `"release": "semantic-release"` → semantic-release (often CI-driven)
- `"publish": "npm publish"` → npm registry

### 3. Makefile targets

```bash
grep -E "^(deploy|release|publish|ship):" Makefile 2>/dev/null
```

Treat as a deploy hint; show the target body in the prompt so the user knows what runs.

### 4. CI auto-deploy

Look for workflows that trigger on push to main:

```bash
grep -lE "on:\s*$|push:\s*$|branches:\s*\[?\s*main" .github/workflows/*.yml 2>/dev/null
```

For each match, parse the file enough to determine: does it deploy, or just test? Heuristic: filename contains `deploy` / `release` / `publish` / `ship`, or workflow steps invoke `vercel`, `netlify`, `gh release`, `npm publish`, etc.

If CI auto-deploys on push to main, the **recommendation should be to skip explicit local deploy** — pushing IS the deploy.

### 5. Plugin manifest (this repo's pattern)

For repos with `plugins/<name>/.claude-plugin/plugin.json` (the agent-skills convention), deploy = push to remotes. No separate command. The recommendation is: skip explicit deploy; Phase 15 push handles it.

### 6. pyproject.toml (PyPI publish via uv)

For Python packages distributed to PyPI, probe `pyproject.toml` at root and at the common nested `backend/` location:

```bash
for f in pyproject.toml backend/pyproject.toml; do
  [ -f "$f" ] || continue
  python3 -c "
import sys, tomllib
with open('$f', 'rb') as fh:
    d = tomllib.load(fh)
proj = d.get('project') or {}
if 'name' in proj:
    print('$f', proj.get('name'), proj.get('version', '<dynamic>'))
" 2>/dev/null
done
```

A signal counts only when the `[project]` table is present with a `name` key — bare tooling-only `pyproject.toml` files (e.g., a repo using it just for `[tool.ruff]`) are NOT a PyPI signal.

When the signal fires, the recommendation is `uv build && uv publish`. Show the package name and version (or `<dynamic>` placeholder) in the prompt so the user knows what they're shipping. Do NOT auto-run the publish command — gate it behind the user's selection of the "Build + publish to PyPI" option in the deploy menu.

If both root `./pyproject.toml` and `./backend/pyproject.toml` carry `[project]` metadata, list both and ask the user which to ship — never silently pick one.

## Recommendation logic

| Signals detected | Recommend |
|------------------|-----------|
| CI auto-deploy only | Skip explicit deploy (CI handles on push) |
| CI auto-deploy + local script | Skip local; trust CI (or warn if user disagrees) |
| CI auto-deploy + pyproject.toml | Skip local; trust CI (CI presumed to handle PyPI publish) |
| Local script only (npm/make) | Run local deploy |
| Plugin manifest only | Skip explicit deploy (push = deploy) |
| pyproject.toml only | Build + publish to PyPI via `uv publish` |
| pyproject.toml + plugin manifest | Multi-target: push (Phase 15) AND `uv publish` — ask user to confirm both |
| Multiple local scripts (deploy + release) | Ask user which |
| No signals detected | Skip explicit deploy; warn in summary |

The recommendation is a starting point — always present alternatives in the AskUserQuestion options.

## Anti-patterns

- Picking a deploy command without showing the user what it'll run.
- Inferring "no deploy needed" from absence of signals when the repo might have an external deploy mechanism (manual, CD pipeline outside the repo). Phase 5 should warn when no signals are detected.
- Running both a local script AND letting CI auto-deploy on the subsequent push. This is the double-deploy footgun.
