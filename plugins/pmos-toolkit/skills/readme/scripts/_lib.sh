#!/usr/bin/env bash
# _lib.sh — shared helpers for /readme bundled scripts. Bash ≥ 4 required.
readme::log() { printf '[/readme] %s\n' "$*" >&2; }
readme::die() { readme::log "ERROR: $*"; exit 2; }

readme::yaml_get() {
  # Usage: readme::yaml_get <dot.path> <yaml-file>
  # Emits the value at <dot.path>. For lists/maps, emits JSON; for scalars, the value as a string.
  # Empty string + return 1 if path not found OR python3/PyYAML missing.
  command -v python3 >/dev/null || { readme::log "warn: python3 absent; yaml_get returns nothing"; return 1; }
  python3 - "$1" "$2" <<'PY'
import sys, json
try:
    import yaml
except ImportError:
    sys.exit(1)
path, file = sys.argv[1], sys.argv[2]
try:
    data = yaml.safe_load(open(file))
except Exception as e:
    sys.stderr.write(f"[/readme] yaml_get parse error in {file}: {e}\n")
    sys.exit(1)
v = data
for key in path.split("."):
    if isinstance(v, dict) and key in v:
        v = v[key]
    else:
        sys.exit(1)
if isinstance(v, (dict, list)):
    print(json.dumps(v))
elif v is None:
    print("")
else:
    print(v)
PY
}
