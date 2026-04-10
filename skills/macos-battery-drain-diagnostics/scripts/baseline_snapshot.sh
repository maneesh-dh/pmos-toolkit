#!/usr/bin/env bash
set -euo pipefail

echo "=== timestamp ==="
date
echo

echo "=== battery ==="
pmset -g batt || true
echo

echo "=== assertions ==="
pmset -g assertions || true
echo

echo "=== top cpu snapshot ==="
top -l 1 -o cpu -n 20 | sed -n '1,80p' || true
echo

echo "=== top cpu processes ==="
ps -Ao pid,ppid,%cpu,%mem,rss,vsz,state,etime,command | sort -k3 -nr | head -n 25 || true
echo

echo "=== top memory processes ==="
ps -Ao pid,ppid,%mem,%cpu,rss,vsz,state,etime,command | sort -k3 -nr | head -n 25 || true
echo

echo "=== virtual memory ==="
vm_stat || true
echo

echo "=== common process counts ==="
ps -Ao command= | awk '
/JumpCloudGo-Chrome/ {jc++}
/Google Chrome Helper \(Renderer\)/ {gcr++}
/Google Chrome.app\/Contents\/MacOS\/Google Chrome$/ {gc++}
/Cursor Helper \(Renderer\)/ {cr++}
/Cursor Helper \(Plugin\)/ {cp++}
/^codex / {cx++}
/^claude / {cl++}
END {
  printf("jumpcloud=%d\nchrome_renderers=%d\nchrome_main=%d\ncursor_renderers=%d\ncursor_plugins=%d\ncodex=%d\nclaude=%d\n",
    jc,gcr,gc,cr,cp,cx,cl)
}' || true
echo

echo "=== orphaned agent candidates ==="
ps -eo ppid=,pid=,command= | awk '$1==1 && /codex|claude/ {print}' | sort -k2n || true
echo

echo "=== orphaned jumpcloud helpers ==="
ps -Ao pid,ppid,state,etime,command | awk '/JumpCloudGo-Chrome/ && $2==1 {print}' || true
