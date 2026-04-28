#!/bin/bash
# ===========================================================================
# save-checkpoint.sh — Saves checkpoint JSON for Handshake
# ===========================================================================
# 
# DESCRIPTION
#   Generates a checkpoint JSON file at .claude/handshake/checkpoint.json
#   by parsing the current session JSONL. Called automatically when
#   context hits 95% threshold.
#
# USAGE
#   save-checkpoint.sh <session_id> <session_dir> <project_dir>
#
# ARGUMENTS
#   session_id     Session ID (JSONL filename without extension)
#   session_dir    Session directory
#   project_dir    Project root directory
#
# ===========================================================================

SESSION_ID="$1"
SESSION_DIR="$2"
PROJECT_DIR="$3"
CHECKPOINT_FILE="$PROJECT_DIR/.claude/handshake/checkpoint.json"
CHECKPOINT_MD="$PROJECT_DIR/.claude/handshake/checkpoint.md"
TMP_DIR="$PROJECT_DIR/.claude/handshake/tmp"

mkdir -p "$(dirname "$CHECKPOINT_FILE")"
mkdir -p "$TMP_DIR"

JSONL_PATH="$SESSION_DIR/${SESSION_ID}.jsonl"

[ -f "$JSONL_PATH" ] || exit 0

# --- Extract session data with Python ---
python3 <<'PYEOF'
import json, sys, os, datetime, re

session_id = sys.argv[1]
jsonl_path = sys.argv[2]
checkpoint_file = sys.argv[3]
checkpoint_md = sys.argv[4]
project_dir = sys.argv[5]

# Read last N lines to extract context
lines = []
with open(jsonl_path, 'r') as f:
    for line in f:
        lines.append(line)
        if len(lines) > 200:  # Keep last 200 lines
            lines.pop(0)

# Parse messages to extract context
messages = []
for line in lines:
    try:
        obj = json.loads(line)
        if obj.get('type') == 'user' or obj.get('type') == 'assistant':
            messages.append(obj)
    except:
        pass

# Extract info from messages
objective = ""
phase = "checkpoint"
files_touched = []
commands_run = []
decisions_made = []
completed_steps = []
unresolved_todos = []

# Simple extraction logic
for msg in messages:
    content = msg.get('message', {}).get('content', '')
    if isinstance(content, list):
        for item in content:
            if isinstance(item, dict) and item.get('type') == 'text':
                text = item.get('text', '')
                # Extract objective from first user message
                if not objective and msg.get('type') == 'user' and len(text) > 10:
                    objective = text[:200]  # First 200 chars
                # Look for phase indicators
                if 'phase' in text.lower() or 'step' in text.lower():
                    phase_match = re.search(r'(phase|step)\s*:?\s*([^\n.]+)', text, re.IGNORECASE)
                    if phase_match:
                        phase = phase_match.group(2)[:50]
    elif isinstance(content, str):
        if not objective and msg.get('type') == 'user' and len(content) > 10:
            objective = content[:200]

# Generate checkpoint
checkpoint = {
    "version": "1.0",
    "timestamp": datetime.datetime.now().isoformat(),
    "source": "auto_95pct",
    "objective": objective or "auto-saved at 95% context",
    "phase": phase,
    "currentPlan": "context saved, ready for /clear or compaction",
    "filesTouched": files_touched,
    "activeFiles": [],
    "commandsRun": commands_run,
    "pendingCommands": [],
    "decisionsMade": [{"decision": d, "reason": ""} for d in decisions_made],
    "completedSteps": completed_steps,
    "unresolvedTodos": unresolved_todos,
    "testStatus": "unknown",
    "verificationRequired": [],
    "risks": [],
    "failedAttempts": [],
    "assumptions": [],
    "nextAction": "continue work after /clear or compaction",
    "handoffMode": "auto",
    "resumeSafety": {
        "repoChanged": False,
        "stale": False,
        "unresolvedRisks": False,
        "destructiveNextAction": False,
        "ambiguousTask": False,
        "reasons": []
    },
    "repoState": {
        "branch": "",
        "commit": "",
        "dirty": True
    }
}

with open(checkpoint_file, 'w') as f:
    json.dump(checkpoint, f, indent=2)

# Write markdown summary
with open(checkpoint_md, 'w') as f:
    f.write(f"# Checkpoint (Auto-saved at 95%)\n\n")
    f.write(f"**Time**: {checkpoint['timestamp']}\n")
    f.write(f"**Objective**: {checkpoint['objective']}\n")
    f.write(f"**Phase**: {checkpoint['phase']}\n")
    f.write(f"**Next Action**: {checkpoint['nextAction']}\n")

print(f"Checkpoint saved to {checkpoint_file}")
PYEOF
"$SESSION_ID" "$SESSION_DIR" "$CHECKPOINT_FILE" "$CHECKPOINT_MD" "$PROJECT_DIR"

# Write flag for PreCompact hook
echo "checkpoint_saved_at_95pct" > "$TMP_DIR/checkpoint-saved.flag"

exit 0
