#!/usr/bin/env bash
# ============================================================================
# handshake-statusline-sensor.sh — Context telemetry sidecar.
#
# Reads Claude Code statusline JSON from stdin, extracts context_window
# telemetry, and writes it to .claude/handshake/context.json.
#
# This is the sensor. The monitor (handshake-context-monitor.sh) is the
# announcer. Keep them separate.
#
# Intended for use as a statusLine command in Claude Code settings:
#   "statusLine": {
#     "type": "command",
#     "command": "${CLAUDE_PLUGIN_ROOT}/scripts/handshake-statusline-sensor.sh",
#     "refreshInterval": 5
#   }
# ============================================================================

set -euo pipefail

input="$(cat)"

project_dir="$(echo "$input" | jq -r '.workspace.project_dir // .cwd // "."')"
state_dir="$project_dir/.claude/handshake"
mkdir -p "$state_dir"

tmp="$state_dir/context.json.tmp"
final="$state_dir/context.json"

echo "$input" | jq '{
  updated_at: (now | todateiso8601),
  session_id,
  transcript_path,
  cwd,
  context_window: {
    used_percentage: (.context_window.used_percentage // 0),
    remaining_percentage: (.context_window.remaining_percentage // 0),
    context_window_size: (.context_window.context_window_size // 0),
    total_input_tokens: (.context_window.total_input_tokens // 0),
    total_output_tokens: (.context_window.total_output_tokens // 0),
    current_usage: (.context_window.current_usage // {})
  }
}' > "$tmp"

mv "$tmp" "$final"

pct="$(echo "$input" | jq -r '.context_window.used_percentage // 0 | floor')"
echo "Handshake ${pct}%"
