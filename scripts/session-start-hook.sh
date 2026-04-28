#!/bin/bash
# session-start-hook.sh — Context Transport Layer for Handshake
# Injects transported context from checkpoint.json back into agent's working memory.

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
CHECKPOINT_FILE="$PROJECT_DIR/.claude/handshake/checkpoint.json"
CONFIG_FILE="$PROJECT_DIR/.claude/handshake/config.json"

# Check if enabled
if [ ! -f "$CONFIG_FILE" ]; then
    exit 0
fi

ENABLED=$(python3 -c "import sys,json; d=json.load(open('$CONFIG_FILE')); print('true' if d.get('enabled',False) else 'false')" 2>/dev/null)

if [ "$ENABLED" != "true" ]; then
    exit 0
fi

# Check if transport payload exists
if [ ! -f "$CHECKPOINT_FILE" ]; then
    exit 0
fi

# Output transport payload for agent rehydration
echo "=== HANDSHAKE CONTEXT TRANSPORT (v2.0) ==="
echo "Transport payload loaded from: $CHECKPOINT_FILE"
echo ""

python3 <<'PYEOF'
import json, sys, os
try:
    checkpoint = json.load(open(sys.argv[1]))
    
    print("## Transport Metadata")
    print(f"Version: {checkpoint.get('version', 'N/A')}")
    print(f"Transported At: {checkpoint.get('transportedAt', 'N/A')}")
    print(f"Session ID: {checkpoint.get('sessionId', 'N/A')}")
    print(f"Source: {checkpoint.get('source', 'unknown')}")
    print("")
    
    print("## Core Context")
    print(f"Objective: {checkpoint.get('objective', 'N/A')}")
    print(f"Phase: {checkpoint.get('phase', 'N/A')}")
    print(f"Next Action: {checkpoint.get('nextAction', 'N/A')}")
    print(f"Current Plan: {checkpoint.get('currentPlan', 'N/A')}")
    print("")
    
    print("## Work State")
    print(f"Files Touched: {checkpoint.get('filesTouched', [])}")
    print(f"Active Files: {checkpoint.get('activeFiles', [])}")
    print(f"Commands Run: {checkpoint.get('commandsRun', [])}")
    print(f"Pending Commands: {checkpoint.get('pendingCommands', [])}")
    print("")
    
    print("## Progress")
    print(f"Decisions Made: {checkpoint.get('decisionsMade', [])}")
    print(f"Completed Steps: {checkpoint.get('completedSteps', [])}")
    print(f"Unresolved TODOs: {checkpoint.get('unresolvedTodos', [])}")
    print("")
    
    print("## Quality & Safety")
    print(f"Test Status: {checkpoint.get('testStatus', 'unknown')}")
    print(f"Verification Required: {checkpoint.get('verificationRequired', [])}")
    print(f"Risks: {checkpoint.get('risks', [])}")
    print(f"Failed Attempts: {checkpoint.get('failedAttempts', [])}")
    print(f"Assumptions: {checkpoint.get('assumptions', [])}")
    print("")
    
    # Resume safety
    safety = checkpoint.get('resumeSafety', {})
    if safety:
        print("## Resume Safety")
        print(f"Repo Changed: {safety.get('repoChanged', False)}")
        print(f"Stale: {safety.get('stale', False)}")
        print(f"Unresolved Risks: {safety.get('unresolvedRisks', False)}")
        print(f"Destructive Next Action: {safety.get('destructiveNextAction', False)}")
        print(f"Ambiguous Task: {safety.get('ambiguousTask', False)}")
        print(f"Reasons: {safety.get('reasons', [])}")
        print("")
    
    # Repo state
    repo = checkpoint.get('repoState', {})
    if repo:
        print("## Repo State")
        print(f"Branch: {repo.get('branch', 'unknown')}")
        print(f"Commit: {repo.get('commit', 'unknown')}")
        print(f"Dirty: {repo.get('dirty', True)}")
        print("")
    
    print("== End Transport Payload ==")
    
except Exception as e:
    print(f"Error loading transport payload: {e}")
    sys.exit(1)
PYEOF
"$CHECKPOINT_FILE"

echo ""
echo "Transport complete. Evaluate resume safety and continue with next action."
exit 0
