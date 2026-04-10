---
name: macos-battery-drain-diagnostics
description: Use when a Mac seems hot, slow, battery-hungry, memory-pressured, or full of leftover background work, especially to identify orphaned processes, browser extension leaks, long-lived local dev services, and safe cleanup opportunities before proposing fixes.
---

# MacOS Battery Drain Diagnostics

## Overview

Diagnose first, kill later. Start with current CPU, memory, battery, and parent-child process evidence. Separate active work from detached leftovers before recommending cleanup.

## When to Use

- Mac battery is draining unusually fast
- Fans, heat, or sluggishness suggest background load
- Memory pressure, compression, or swap seem high
- The user suspects orphaned local agents, browser helpers, or stale dev services
- Browser profiles or managed extensions may be leaking helpers

Do not kill Docker, browsers, VPN/security agents, or app processes the user still needs without explicit confirmation.

## Workflow

### 1. Capture a baseline

Preferred:

```bash
bash /Users/maneeshdhabria/.codex-work/skills/macos-battery-drain-diagnostics/scripts/baseline_snapshot.sh
```

Manual equivalent:

Run:

```bash
ps -Ao pid,ppid,%cpu,%mem,rss,vsz,state,etime,command | sort -k3 -nr | head -n 25
ps -Ao pid,ppid,%mem,%cpu,rss,vsz,state,etime,command | sort -k3 -nr | head -n 25
top -l 1 -o cpu -n 20 | sed -n '1,80p'
pmset -g batt
pmset -g assertions
vm_stat
```

Look for:

- `ppid 1` on long-running high-CPU app/tool processes
- high compressor or heavy swap activity
- large browser/editor/Docker footprints
- sleep blockers in `pmset -g assertions`

The bundled script prints a timestamped snapshot with the same sections in one pass.

### 2. Count likely offenders

Use targeted counts before cleanup:

```bash
ps -Ao command= | awk '
/JumpCloudGo-Chrome/ {jc++}
/Google Chrome Helper \(Renderer\)/ {gcr++}
/Google Chrome.app\/Contents\/MacOS\/Google Chrome$/ {gc++}
/Cursor Helper \(Renderer\)/ {cr++}
/Cursor Helper \(Plugin\)/ {cp++}
/^codex / {cx++}
END {printf("jumpcloud=%d\nchrome_renderers=%d\nchrome_main=%d\ncursor_renderers=%d\ncursor_plugins=%d\ncodex=%d\n", jc,gcr,gc,cr,cp,cx)}'
```

For specific suspect trees:

```bash
ps -eo ppid=,pid=,command= | awk '$1==1 && /codex|claude/ {print}' | sort -k2n
ps -Ao pid,ppid,state,etime,command | awk '/JumpCloudGo-Chrome/ && $2==1 {print}'
```

### 3. Handle browser-extension leaks carefully

If Chrome helpers are excessive, determine whether this is a tab problem, extension problem, or managed work-profile problem.

Inspect open tabs:

```bash
osascript <<'APPLESCRIPT'
tell application "Google Chrome"
  set out to {}
  repeat with w in windows
    repeat with t in tabs of w
      set end of out to (title of t) & tab & (URL of t)
    end repeat
  end repeat
  return out
end tell
APPLESCRIPT
```

Check managed-profile extension ownership:

```bash
rg -l 'jdoahkhfkeipblhbhppmcbdgapeoaopa' "$HOME/Library/Application Support/Google/Chrome"/*/Preferences "$HOME/Library/Application Support/Google/Chrome"/*/'Secure Preferences' 2>/dev/null
python3 - <<'PY'
import json, os
path=os.path.expanduser('~/Library/Application Support/Google/Chrome/Local State')
with open(path) as f:
    data=json.load(f)
for profile, info in data.get('profile', {}).get('info_cache', {}).items():
    if profile == 'Profile 8':
        for k in ['name','user_name','hosted_domain','is_managed']:
            print(f'{k}={info.get(k)}')
PY
```

If an extension is "Installed by administrator", do not suggest disabling it locally.

### 4. Safe cleanup rules

Only kill detached or explicitly-approved processes.

Typical safe cleanup examples:

```bash
kill -TERM <pid> ...
pkill -TERM -f '/opt/jc_user_ro/JumpCloudGo-Chrome'
```

After any kill, re-check whether:

- the target is gone
- the PID was reused
- helpers immediately respawn
- respawned helpers are attached to a live parent or orphaned again

Never use destructive system-wide cleanup commands. Never restart Docker unless the user asked.

### 5. Verify impact

Always measure after cleanup:

```bash
top -l 1 -o cpu -n 20 | sed -n '1,25p'
pmset -g batt
ps -Ao command= | awk '/JumpCloudGo-Chrome/ {jc++} /Google Chrome Helper \(Renderer\)/ {gcr++} END {printf("jumpcloud=%d\nchrome_renderers=%d\n", jc,gcr)}'
```

Summarize before vs after:

- process counts
- approximate memory recovered
- CPU idle improvement
- battery estimate change
- what still remains active

## Common Findings

- `ppid 1` plus long runtime plus high CPU usually means a detached leftover process
- thousands of browser helper processes are usually an extension/profile issue, not "too many tabs"
- managed Chrome profiles can force-install problematic extensions the user cannot disable
- after orphan cleanup, the remaining drain is often active Chrome renderers or long-lived local dev stacks
