#!/bin/bash
# ============================================================================
# userprompt-resume.sh — Primary resume injection via UserPromptSubmit hook.
#
# Reads runtime.json. When needs_resume=true, injects checkpoint context
# as additionalContext alongside the user's submitted prompt.
#
# This is the reliable injection point. UserPromptSubmit explicitly supports
# additionalContext, unlike SessionStart which can silently discard it.
# ============================================================================

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
HANDSHAKE_DIR="$PROJECT_DIR/.claude/handshake"
RUNTIME_FILE="$HANDSHAKE_DIR/runtime.json"
CONFIG_FILE="$HANDSHAKE_DIR/config.json"

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

# Check runtime state
python3 << 'PYEOF'
import json, os, sys

project_dir = os.environ.get("CLAUDE_PROJECT_DIR", ".")
handshake_dir = os.path.join(project_dir, ".claude", "handshake")
runtime_file = os.path.join(handshake_dir, "runtime.json")
checkpoint_json = os.path.join(handshake_dir, "checkpoint.json")
checkpoint_md = os.path.join(handshake_dir, "checkpoint.md")

try:
    with open(runtime_file) as f:
        runtime = json.load(f)
except Exception:
    sys.exit(0)

if not runtime.get("needs_resume", False):
    sys.exit(0)

checkpoint = {}
if os.path.exists(checkpoint_json):
    try:
        with open(checkpoint_json) as f:
            checkpoint = json.load(f)
    except Exception:
        pass

# Build resume context
lines = []
lines.append("HANDSHAKE RESUME CONTEXT")
lines.append("")
lines.append("A checkpoint exists and should be treated as the durable continuation state.")
lines.append("")
lines.append("Read:")
lines.append("- .claude/handshake/checkpoint.json")
lines.append("- .claude/handshake/checkpoint.md")
lines.append("")
lines.append("Before making edits:")
lines.append("1. Acknowledge the checkpoint.")
lines.append("2. Verify cwd, branch, git HEAD, and changed files.")
lines.append("3. Resume from workflow.next_action.")

safety = checkpoint.get("safety", {})
resume_mode = safety.get("resume_mode", "ask")
resume_reason = safety.get("resume_reason", "unknown")

lines.append(f"4. safety.resume_mode is '{resume_mode}' — ", end="")
if resume_mode == "block":
    lines[-1] += "STOP and ask before any action."
elif resume_mode == "ask":
    lines[-1] += "ask before writing."
else:
    lines[-1] += "safe to proceed with read-only or test-only actions."

workflow = checkpoint.get("workflow", {})
objective = workflow.get("objective", "Unknown")
phase = workflow.get("phase", "UNKNOWN")
next_action = workflow.get("next_action", "Determine next safe action.")

lines.append("")
lines.append(f"Objective: {objective}")
lines.append(f"Phase: {phase}")
lines.append(f"Next action: {next_action}")

repo = checkpoint.get("repo", {})
if repo.get("changed_files"):
    lines.append("")
    lines.append("Changed files:")
    for f in repo["changed_files"][:20]:
        lines.append(f"  - {f}")

if safety.get("risks"):
    lines.append("")
    lines.append("Risks:")
    for r in safety["risks"][:10]:
        lines.append(f"  - {r[:200]}")

resume_context = "\n".join(lines)

# Output as JSON for Claude Code hooks API
output = {
    "resume_context": resume_context,
    "checkpoint_path": ".claude/handshake/checkpoint.json",
    "resume_mode": resume_mode,
    "resume_reason": resume_reason
}
print(json.dumps(output))
PYEOF

exit 0
