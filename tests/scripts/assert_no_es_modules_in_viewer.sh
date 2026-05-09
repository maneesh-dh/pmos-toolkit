#!/usr/bin/env bash
# Wrapper assert: invokes plugins/pmos-toolkit/tools/lint-no-modules-in-viewer.sh.
# FR-05.1; spec §14.1.
set -e
TOOL=${TOOL:-plugins/pmos-toolkit/tools/lint-no-modules-in-viewer.sh}
bash "$TOOL" "$@"
