#!/usr/bin/env bash
# ============================================================================
# handshake-context-monitor.sh — Context pressure threshold broadcaster.
#
# Polls .claude/handshake/context.json (written by the statusline sensor)
# and emits warnings only when context usage crosses threshold bands.
#
# Bands:
#   70%  advisory  — keep checkpoint warm
#   80%  warning   — refresh checkpoint before major edits
#   90%  danger    — checkpoint required before continuing
#   95%  critical  — set needs_resume=true, avoid new write-heavy work
#
# Emits sparse, structured lines. Every stdout line interrupts the session.
# ============================================================================

set -euo pipefail

STATE_DIR="${CLAUDE_PROJECT_DIR:-.}/.claude/handshake"
CONTEXT="$STATE_DIR/context.json"
RUNTIME="$STATE_DIR/runtime.json"

last_band=""

while true; do
  if [[ ! -f "$CONTEXT" ]]; then
    sleep 2
    continue
  fi

  pct="$(jq -r '.context_window.used_percentage // 0 | floor' "$CONTEXT" 2>/dev/null || echo 0)"

  band="normal"
  if (( pct >= 95 )); then
    band="critical"
  elif (( pct >= 90 )); then
    band="danger"
  elif (( pct >= 80 )); then
    band="warning"
  elif (( pct >= 70 )); then
    band="advisory"
  fi

  if [[ "$band" != "$last_band" ]]; then
    case "$band" in
      advisory)
        echo "HANDSHAKE context advisory: ${pct}% used. Keep checkpoint warm."
        ;;
      warning)
        echo "HANDSHAKE context warning: ${pct}% used. Refresh checkpoint before major edits."
        ;;
      danger)
        echo "HANDSHAKE context danger: ${pct}% used. Checkpoint is required before continuing."
        ;;
      critical)
        if [[ -f "$RUNTIME" ]]; then
          jq '.needs_resume = true | .resume_reason = "context_critical"' "$RUNTIME" > "$RUNTIME.tmp" 2>/dev/null || true
          [[ -f "$RUNTIME.tmp" ]] && mv "$RUNTIME.tmp" "$RUNTIME"
        fi
        echo "HANDSHAKE context critical: ${pct}% used. Set needs_resume=true; avoid new write-heavy work."
        ;;
    esac

    last_band="$band"
  fi

  sleep 3
done
