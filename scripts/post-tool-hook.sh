#!/bin/bash
# post-tool-hook.sh — PostToolUse hook for Handshake
# Fires after every tool call. At 95% context, saves checkpoint.

PLUGIN_ROOT="$HOME/.claude/plugins/marketplaces/local/plugins/handshake"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
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

# Get threshold (default 95%)
THRESHOLD_PCT=95
[ -f "$PROJECT_DIR/.claude/handshake/config.json" ] && THRESHOLD_PCT=$(python3 -c "import sys,json; print(json.load(open(sys.argv[1])).get('checkpointThreshold',95))" "$PROJECT_DIR/.claude/handshake/config.json" 2>/dev/null || echo 95)

# 5000 lines = 100% context
THRESHOLD_LINES=$((THRESHOLD_PCT * 5000 / 100))

if [ "$DELTA" -ge "$THRESHOLD_LINES" ]; then
    FLAG="$PROJECT_DIR/.claude/handshake/tmp/checkpoint-saved.flag"
    [ -f "$FLAG" ] && exit 0
    
    mkdir -p "$PROJECT_DIR/.claude/handshake/tmp"
    mkdir -p "$PROJECT_DIR/.claude/handshake/logs/autonomous"
    # Save checkpoint in background
    nohup python3 "$PLUGIN_ROOT/scripts/save-checkpoint.py" "$SESSION_ID" "$SESSION_DIR" "$PROJECT_DIR" > "$PROJECT_DIR/.claude/handshake/logs/autonomous/save-$(date +%s).log" 2>&1 &
    echo "$CURRENT_LINES" > "$FLAG"
    python3 -c "import json; json.dump({'line':$CURRENT_LINES,'session':'$SESSION_ID'},open('$LAST_SAVE_FILE','w'))" 2>/dev/null
fi

exit 0
