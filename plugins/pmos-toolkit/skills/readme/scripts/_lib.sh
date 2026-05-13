#!/usr/bin/env bash
# _lib.sh — shared helpers for /readme bundled scripts. Bash ≥ 4 required.
readme::log() { printf '[/readme] %s\n' "$*" >&2; }
readme::die() { readme::log "ERROR: $*"; exit 2; }
