#!/bin/bash
# post-tool-hook.sh — Context Transport Middleware (Handshake)
# Optional 95% auto-checkpoint (gated by config.json checkpointThreshold)

PLUGIN_ROOT="$HOME/.claude/plugins/marketplaces/local/plugins/handshake"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
CONFIG_FILE="$PROJECT_DIR/.claude/handshake/config.json"

# Check if 95% auto-checkpoint is enabled
if [ ! -f "$CONFIG_FILE" ]; then
    exit 0
fi

# Read checkpointThreshold - if 0 or missing, feature is disabled
THRESHOLD=$(python3 -c "import sys, json; d=json.load(open('$CONFIG_FILE')); print(d.get('checkpointThreshold', 0))" 2>/dev/null || echo 0)
if [ "$THRESHOLD" -eq 0 ]; then
    exit 0  # Feature disabled
fi

# Feature enabled - proceed with 95% detection
SESSION_DIR="$HOME/.claude/projects/$(echo "$PROJECT_DIR" | sed 's/[^a-zA-Z0-9]/-/g')"

# Find latest session file
LATEST_JSONL=$(ls -t "$SESSION_DIR"/*.jsonl 2>/dev/null | head -1)
[ -z "$LATEST_JSONL" ] && exit 0

CURRENT_LINES=$(wc -l < "$LATEST_JSONL" | tr -d ' ')
SESSION_ID=$(basename "$LATEST_JSONL" .jsonl)

# Get last saved position
LAST_SAVE_FILE="$PROJECT_DIR/.claude/handshake/tmp/last-save.json"
LAST_LINE=0 SAVED_SESSION=""
if [ -f "$LAST_SAVE_FILE" ]; then
    SAVED_SESSION=$(python3 -c "import sys,json; d=json.load(open(sys.argv[1])); print(d.get('session',''))" "$LAST_SAVE_FILE" 2>/dev/null)
    [ "$SAVED_SESSION" = "$SESSION_ID" ] && LAST_LINE=$(python3 -c "import sys,json; d=json.load(open(sys.argv[1])); print(d.get('line',0))" "$LAST_SAVE_FILE" 2>/dev/null)
fi

DELTA=$((CURRENT_LINES - LAST_LINE))

# 5000 lines = 100% context
THRESHOLD_LINES=$((THRESHOLD * 5000 / 100))

if [ "$DELTA" -ge "$THRESHOLD_LINES" ]; then
    FLAG="$PROJECT_DIR/.claude/handshake/tmp/checkpoint-saved.flag"
    [ -f "$FLAG" ] && exit 0
    
    mkdir -p "$PROJECT_DIR/.claude/handshake/tmp"
    mkdir -p "$PROJECT_DIR/.claude/handshake/logs/autonomous"
    # Save context transport payload in background
    nohup python3 "$PLUGIN_ROOT/scripts/save-checkpoint.py" "$SESSION_ID" "$SESSION_DIR" "$PROJECT_DIR" > "$PROJECT_DIR/.claude/handshake/logs/autonomous/save-$(date +%s).log" 2>&1 &
    echo "$CURRENT_LINES" > "$FLAG"
    python3 -c "import json; json.dump({'line':$CURRENT_LINES,'session':'$SESSION_ID'},open('$LAST_SAVE_FILE','w'))" 2>/dev/null
fi

exit 0
