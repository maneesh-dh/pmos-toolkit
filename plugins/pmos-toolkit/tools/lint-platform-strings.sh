#!/usr/bin/env bash
# lint-platform-strings.sh
#
# Verify _shared/platform-strings.md exposes all required platforms and
# all required keys per platform. Consumers (/plan v2 and others) read by
# H2 platform name, so each platform section must be present and contain
# the mandatory keys as bullet entries.
#
# Required platforms: claude-code, gemini, copilot, codex
# Required keys per platform: execute_invocation, skill_reference
#
# Exit codes:
#   0 — all platforms × keys present
#   1 — missing platform or key
#   2 — script invocation error

set -euo pipefail

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PLUGIN_ROOT="$( cd -- "${SCRIPT_DIR}/.." &> /dev/null && pwd )"
FILE="${PLUGIN_ROOT}/skills/_shared/platform-strings.md"

PLATFORMS=(claude-code gemini copilot codex)
REQUIRED_KEYS=(execute_invocation skill_reference)

if [[ ! -f "$FILE" ]]; then
    echo "FAIL: platform-strings.md not found at $FILE" >&2
    exit 1
fi

failures=0

for platform in "${PLATFORMS[@]}"; do
    if ! grep -q "^## ${platform}$" "$FILE"; then
        echo "DRIFT: missing platform section: ## ${platform}"
        failures=$((failures + 1))
        continue
    fi
    section=$(awk -v p="$platform" '
        $0 == "## " p { in_block = 1; next }
        /^## /        { in_block = 0 }
        in_block      { print }
    ' "$FILE")
    platform_ok=1
    for key in "${REQUIRED_KEYS[@]}"; do
        if ! echo "$section" | grep -q "^- \`${key}\`:"; then
            echo "DRIFT: ${platform} missing key: ${key}"
            platform_ok=0
            failures=$((failures + 1))
        fi
    done
    if [[ $platform_ok -eq 1 ]]; then
        echo "OK:    ${platform}"
    fi
done

if [[ $failures -gt 0 ]]; then
    echo
    echo "FAIL: ${failures} platform-strings drift(s)." >&2
    exit 1
fi

echo
echo "PASS: all ${#PLATFORMS[@]} platforms expose all ${#REQUIRED_KEYS[@]} required keys."
exit 0
