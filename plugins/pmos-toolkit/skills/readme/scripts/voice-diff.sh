#!/usr/bin/env bash
# voice-diff.sh — compare two markdown files (pre/post /polish) and emit
# a single-line JSON object with sentence-length delta + Jaccard similarity
# of unique lowercase tokens.
#
# Usage:
#   voice-diff.sh <pre.md> <post.md>
#   voice-diff.sh --selftest
#
# Output (stdout, exit 0):
#   {"sentence_len_delta_pct": <num>, "jaccard_new_tokens": <num>}
#
# Errors (stderr, exit 64): missing arg or missing file.
#
# Bash 3.2-safe. Uses awk for tokenization + math. No associative arrays,
# no mapfile, no <<< for arrays.
#
# FR-V-1, FR-V-4 — /readme skill voice-preservation gate substrate.

set -u

# --- FR-V-4: /polish substrate graceful-detect -------------------------------
# We try to locate the /polish skill's voice substrate. We do not source it;
# this is purely a graceful-warn signal. The built-in tokenizer below is the
# canonical implementation either way.
_script_dir() {
  # Resolve script directory (Bash 3.2-safe; no readlink -f required).
  local src="$0"
  cd "$(dirname "$src")" 2>/dev/null && pwd
}

_polish_substrate_check() {
  # Walk up from the script dir to find a `plugins/pmos-toolkit/skills/polish`
  # neighbour, then look for any `voice*` artifact under it. Best-effort.
  local d
  d=$(_script_dir 2>/dev/null) || return 0
  # Walk up to 6 levels looking for plugins/pmos-toolkit/skills/polish
  local i=0
  while [ "$i" -lt 6 ] && [ -n "$d" ] && [ "$d" != "/" ]; do
    if [ -d "$d/plugins/pmos-toolkit/skills/polish" ]; then
      local hit
      hit=$(find "$d/plugins/pmos-toolkit/skills/polish/" -maxdepth 3 -name 'voice*' 2>/dev/null | head -1)
      if [ -n "$hit" ]; then
        return 0
      else
        echo "voice-diff: /polish substrate not found; using built-in tokenizer" >&2
        return 0
      fi
    fi
    d=$(dirname "$d")
    i=$((i + 1))
  done
  echo "voice-diff: /polish substrate not found; using built-in tokenizer" >&2
  return 0
}

# --- Core diff ---------------------------------------------------------------

_compute_diff() {
  # $1 = pre.md, $2 = post.md
  # Emits the JSON object on stdout.
  local pre="$1"
  local post="$2"

  awk -v pre="$pre" -v post="$post" '
    function strip_md(s) {
      # Strip fenced code blocks marker lines, headings, list bullets, link
      # syntax brackets, and inline code backticks. Keep prose tokens intact.
      gsub(/`/, " ", s)
      gsub(/\[/, " ", s); gsub(/\]/, " ", s)
      gsub(/\(/, " ", s); gsub(/\)/, " ", s)
      gsub(/[*_#>]/, " ", s)
      return s
    }
    function load_file(path,   line, buf, in_fence) {
      buf = ""
      in_fence = 0
      while ((getline line < path) > 0) {
        if (line ~ /^[[:space:]]*```/) { in_fence = 1 - in_fence; continue }
        if (in_fence) continue
        buf = buf " " line
      }
      close(path)
      return buf
    }
    function mean_sentence_len(text,   s, n, i, w, total, count, words) {
      text = strip_md(text)
      # Split on sentence terminators followed by whitespace or EOL.
      # Use gsub to insert a separator we can split on.
      gsub(/[.!?]+[[:space:]]+/, "\x01", text)
      gsub(/[.!?]+$/, "\x01", text)
      n = split(text, s, "\x01")
      count = 0; total = 0
      for (i = 1; i <= n; i++) {
        # Count words in this sentence
        words = 0
        # Trim
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", s[i])
        if (length(s[i]) == 0) continue
        w = split(s[i], dummy, /[[:space:]]+/)
        total += w
        count += 1
      }
      if (count == 0) return 0
      return total / count
    }
    function tokenize_into(text, set,   n, i, parts, t) {
      text = strip_md(text)
      # Lowercase
      text = tolower(text)
      # Replace non-alnum with space
      gsub(/[^a-z0-9]+/, " ", text)
      n = split(text, parts, /[[:space:]]+/)
      for (i = 1; i <= n; i++) {
        t = parts[i]
        if (length(t) > 0) set[t] = 1
      }
    }
    function jaccard(a, b,   k, inter, uni) {
      inter = 0; uni = 0
      for (k in a) { uni += 1; if (k in b) inter += 1 }
      for (k in b) { if (!(k in a)) uni += 1 }
      if (uni == 0) return 0
      return inter / uni
    }
    function round1(x) { return sprintf("%.1f", x + 0) + 0 }
    function round2(x) { return sprintf("%.2f", x + 0) + 0 }
    BEGIN {
      pre_text  = load_file(pre)
      post_text = load_file(post)
      m_pre  = mean_sentence_len(pre_text)
      m_post = mean_sentence_len(post_text)
      if (m_pre == 0) {
        delta = 0
      } else {
        delta = (m_post - m_pre) / m_pre * 100.0
      }
      delete a_set
      delete b_set
      tokenize_into(pre_text,  a_set)
      tokenize_into(post_text, b_set)
      j = jaccard(a_set, b_set)
      printf("{\"sentence_len_delta_pct\": %s, \"jaccard_new_tokens\": %s}\n", \
             sprintf("%.1f", delta), sprintf("%.2f", j))
    }
  '
}

# --- Selftest ----------------------------------------------------------------

_selftest() {
  local here
  here=$(_script_dir)
  local pre="$here/../tests/fixtures/voice/pre.md"
  local post="$here/../tests/fixtures/voice/post.md"
  if [ ! -f "$pre" ] || [ ! -f "$post" ]; then
    echo "selftest: FAIL (fixtures missing: pre=$pre post=$post)"
    exit 1
  fi
  local json
  json=$(_compute_diff "$pre" "$post") || {
    echo "selftest: FAIL (compute error)"
    exit 1
  }
  # Parse the two numbers out with awk.
  local delta jac
  delta=$(printf '%s\n' "$json" | awk -F'[:,}]' '{ gsub(/[[:space:]]/,"",$2); print $2 }')
  jac=$(printf '%s\n' "$json"   | awk -F'[:,}]' '{ gsub(/[[:space:]]/,"",$4); print $4 }')
  # Range checks via awk (handles floats portably).
  local ok
  ok=$(awk -v d="$delta" -v j="$jac" 'BEGIN{
    if (d == "" || j == "") { print "parse"; exit }
    if (d < -25 || d > 25)  { print "delta"; exit }
    if (j < 0.5)            { print "jaccard"; exit }
    print "ok"
  }')
  if [ "$ok" = "ok" ]; then
    echo "selftest: PASS"
    exit 0
  fi
  echo "selftest: FAIL (range:$ok delta=$delta jaccard=$jac json=$json)"
  exit 1
}

# --- Main --------------------------------------------------------------------

_polish_substrate_check

if [ "${1:-}" = "--selftest" ]; then
  _selftest
fi

if [ $# -lt 2 ]; then
  echo "voice-diff: usage: $0 <pre.md> <post.md>   (or --selftest)" >&2
  exit 64
fi

PRE="$1"
POST="$2"

if [ ! -f "$PRE" ]; then
  echo "voice-diff: file not found: $PRE" >&2
  exit 64
fi
if [ ! -f "$POST" ]; then
  echo "voice-diff: file not found: $POST" >&2
  exit 64
fi

_compute_diff "$PRE" "$POST"
exit 0
