#!/bin/bash
# ============================================================================
# sessionend-finalize.sh — SessionEnd lifecycle hook.
#
# Writes a final checkpoint at session end. Cleans up monitor lock.
# ============================================================================

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
HANDSHAKE_DIR="$PROJECT_DIR/.claude/handshake"
CONFIG_FILE="$HANDSHAKE_DIR/config.json"
RUNTIME_FILE="$HANDSHAKE_DIR/runtime.json"
LOCK_FILE="$HANDSHAKE_DIR/monitor.lock"

# Check if enabled
if [ ! -f "$CONFIG_FILE" ]; then
    exit 0
fi

ENABLED=$(python3 -c "
import json, sys
try:
    d = json.load(open('$CONFIG_FILE'))
    print('true' if d.get('enabled', False) else 'false')
except:
    print('false')
" 2>/dev/null)

if [ "$ENABLED" != "true" ]; then
    exit 0
fi

# Clean up stale monitor lock
if [ -f "$LOCK_FILE" ]; then
    PID=$(cat "$LOCK_FILE" 2>/dev/null)
    if [ -n "$PID" ]; then
        if ! kill -0 "$PID" 2>/dev/null; then
            rm -f "$LOCK_FILE"
        fi
    fi
fi

python3 << 'PYEOF'
import json, os, sys
from datetime import datetime, timezone

project_dir = os.environ.get("CLAUDE_PROJECT_DIR", ".")
handshake_dir = os.path.join(project_dir, ".claude", "handshake")
runtime_file = os.path.join(handshake_dir, "runtime.json")

try:
    with open(runtime_file) as f:
        runtime = json.load(f)
except Exception:
    runtime = {}

runtime["monitor_pid"] = None
runtime["session_ended_at"] = datetime.now(timezone.utc).isoformat()

os.makedirs(os.path.dirname(runtime_file), exist_ok=True)
tmp = runtime_file + ".tmp"
with open(tmp, "w") as f:
    json.dump(runtime, f, indent=2)
os.replace(tmp, runtime_file)
PYEOF

exit 0
