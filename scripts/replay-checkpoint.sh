#!/bin/bash
# ============================================================================
# replay-checkpoint.sh — Restore an archived checkpoint for debugging
# ============================================================================
#
# DESCRIPTION
#   Copies an archived checkpoint back as the active checkpoint,
#   allowing SessionStart to reinject it on next session.
#
# USAGE
#   bash scripts/replay-checkpoint.sh <archive_file>
#   bash scripts/replay-checkpoint.sh .claude/handshake/archive/2026-04-28T1430Z-survival-hostile-audit.json
#
# ARGUMENTS
#   <archive_file>  Path to archived checkpoint JSON file
#
# EXIT CODES
#   0   Replay set successfully
#   1   Archive file not found or active checkpoint exists (user aborted)
#
# ============================================================================

set -e

ARCHIVE_FILE="$1"
HANDSHAKE_DIR=".claude/handshake"
POINTER="$HANDSHAKE_DIR/checkpoint.json"

if [ -z "$ARCHIVE_FILE" ]; then
    echo "ERROR: missing archive file argument"
    echo "Usage: bash replay-checkpoint.sh <archive_file>"
    exit 1
fi

if [ ! -f "$ARCHIVE_FILE" ]; then
    echo "ERROR: archive file not found: $ARCHIVE_FILE"
    exit 1
fi

# Safety check: warn if active checkpoint exists
if [ -f "$POINTER" ]; then
    echo "WARNING: active checkpoint already exists at $POINTER"
    echo "Overwrite? (y/N)"
    read -r answer
    if [ "$answer" != "y" ]; then
        echo "Aborted."
        exit 1
    fi
    # Backup existing
    cp "$POINTER" "$POINTER.backup.$(date +%s)" 2>/dev/null || true
fi

# Copy back as active checkpoint
mkdir -p "$HANDSHAKE_DIR"
cp "$ARCHIVE_FILE" "$POINTER"

echo "Replay set: $(basename "$ARCHIVE_FILE")"
echo "Restart Claude Code session to reinject this checkpoint."
echo ""
echo "NOTE: checkpoint.json is now a copy (not symlink) of the archive."
echo "To return to normal operation, run /handshake on or delete checkpoint.json."
