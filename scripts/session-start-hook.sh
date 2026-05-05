#!/bin/bash
# ============================================================================
# session-start-hook.sh — Opportunistic SessionStart hook (bonus path).
#
# Restores mode from config.json after /clear so mode persists across
# the total session. Enforces mutual exclusivity: compact XOR pass.
#
# This is a NON-authoritative resume path. The primary resume mechanism is
# UserPromptSubmit. SessionStart reinjection can silently discard
# additionalContext in some Claude Code versions, so this is best-effort only.
#
# If you need guaranteed resume, use /handshake resume instead.
# ============================================================================

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
HANDSHAKE_DIR="$PROJECT_DIR/.claude/handshake"
RUNTIME_FILE="$HANDSHAKE_DIR/runtime.json"
CONFIG_FILE="$HANDSHAKE_DIR/config.json"
CHECKPOINT_FILE="$HANDSHAKE_DIR/checkpoint.json"

# Check if enabled
if [ ! -f "$CONFIG_FILE" ]; then
    exit 0
fi

python3 << 'PYEOF'
import json, os, sys

project_dir = os.environ.get("CLAUDE_PROJECT_DIR", ".")
handshake_dir = os.path.join(project_dir, ".claude", "handshake")
runtime_file = os.path.join(handshake_dir, "runtime.json")
config_file = os.path.join(handshake_dir, "config.json")
checkpoint_file = os.path.join(handshake_dir, "checkpoint.json")

try:
    with open(config_file) as f:
        config = json.load(f)
except Exception:
    sys.exit(0)

if not config.get("enabled", False):
    sys.exit(0)

# Restore mode from config — mode persists across /clear
mode = config.get("mode", "")
if mode not in ("compact", "pass"):
    # Default: no mode active, don't inject anything
    sys.exit(0)

# Load or initialize runtime
try:
    with open(runtime_file) as f:
        runtime = json.load(f)
except Exception:
    runtime = {}

# Restore mode and ensure mutual exclusivity
# Only one mode can be active at a time
runtime["mode"] = mode
runtime["enabled"] = True

# Reset per-session transient fields
runtime["monitor_pid"] = None
runtime["needs_resume"] = True
runtime["resume_reason"] = runtime.get("resume_reason") or "post_clear"

# Write runtime
os.makedirs(os.path.dirname(runtime_file), exist_ok=True)
tmp = runtime_file + ".tmp"
with open(tmp, "w") as f:
    json.dump(runtime, f, indent=2, sort_keys=True)
os.replace(tmp, runtime_file)

# Check if checkpoint exists for resume
checkpoint = {}
if os.path.exists(checkpoint_file):
    try:
        with open(checkpoint_file) as f:
            checkpoint = json.load(f)
    except Exception:
        pass

if not checkpoint:
    sys.exit(0)

# Opportunistic resume notice — NOT authoritative.
# UserPromptSubmit is the real path.
print("")
print("--- Handshake SessionStart (opportunistic) ---")
print(f"Mode: {mode}")
print(f"Resume reason: {runtime.get('resume_reason', 'unknown')}")
print(f"Checkpoint: .claude/handshake/checkpoint.json")
print("For guaranteed resume, type any prompt or run /handshake resume.")
print("---")
print("")

PYEOF

exit 0
