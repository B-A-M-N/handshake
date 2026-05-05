#!/bin/bash
# ============================================================================
# precompact-check.sh — PreCompact lifecycle hook.
#
# Verifies checkpoint freshness before compaction and sets needs_resume=true.
# Does NOT inject context — that is UserPromptSubmit's job.
# ============================================================================

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
HANDSHAKE_DIR="$PROJECT_DIR/.claude/handshake"
CONFIG_FILE="$HANDSHAKE_DIR/config.json"
RUNTIME_FILE="$HANDSHAKE_DIR/runtime.json"
CHECKPOINT_FILE="$HANDSHAKE_DIR/checkpoint.json"

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

python3 << 'PYEOF'
import json, os, sys
from datetime import datetime, timezone

project_dir = os.environ.get("CLAUDE_PROJECT_DIR", ".")
handshake_dir = os.path.join(project_dir, ".claude", "handshake")
runtime_file = os.path.join(handshake_dir, "runtime.json")
checkpoint_file = os.path.join(handshake_dir, "checkpoint.json")
config_file = os.path.join(handshake_dir, "config.json")

try:
    with open(config_file) as f:
        config = json.load(f)
    with open(runtime_file) as f:
        runtime = json.load(f)
except Exception:
    sys.exit(0)

# Verify checkpoint exists and is fresh
checkpoint = {}
if os.path.exists(checkpoint_file):
    try:
        with open(checkpoint_file) as f:
            checkpoint = json.load(f)
    except Exception:
        pass

now = datetime.now(timezone.utc).isoformat()
needs_resume = True
reason = "precompact"

if checkpoint:
    updated = checkpoint.get("updated_at")
    if updated:
        try:
            updated_dt = datetime.fromisoformat(updated.replace("Z", "+00:00"))
            age_seconds = (datetime.now(timezone.utc) - updated_dt).total_seconds()
            # If checkpoint is older than 5 minutes, warn
            if age_seconds > 300:
                print(f"HANDSHAKE precompact: checkpoint is stale ({int(age_seconds)}s old). Run /handshake compact to refresh.", flush=True)
                reason = "precompact_stale"
        except Exception:
            pass
    resume_mode = "ask"
    safety = checkpoint.get("safety", {})
    if safety.get("resume_mode") == "auto":
        resume_mode = "auto"
else:
    resume_mode = "ask"
    reason = "precompact_no_checkpoint"
    print("HANDSHAKE precompact: no checkpoint found. Consider running /handshake compact first.", flush=True)

# Preserve mode from config — do not lose it during compaction
config_mode = config.get("mode", runtime.get("mode", ""))
runtime["mode"] = config_mode
runtime["needs_resume"] = needs_resume
runtime["resume_reason"] = reason
runtime["resume_mode"] = resume_mode
runtime["last_precompact_at"] = now

os.makedirs(os.path.dirname(runtime_file), exist_ok=True)
tmp = runtime_file + ".tmp"
with open(tmp, "w") as f:
    json.dump(runtime, f, indent=2)
os.replace(tmp, runtime_file)

print(f"HANDSHAKE precompact: needs_resume=true reason={reason} mode={resume_mode}", flush=True)
PYEOF

exit 0
