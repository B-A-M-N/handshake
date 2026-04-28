---
name: handshake
description: "Context transport middleware for Claude Code. Captures agent state before /clear or compaction, transports structured checkpoints, rehydrates context on session start. Optional 95% auto-checkpoint."
---

# Handshake — Context Transport Middleware

## Overview

Handshake is a **context transport layer** for Claude Code. It captures agent state, stores structured checkpoints, and rehydrates context across session boundaries (/clear, compaction).

**Core transport flow:**
1. **Capture** — PreCompact hook or manual `/handshake on` + `/clear`
2. **Transport** — Store structured JSON payload to `.claude/handshake/checkpoint.json`
3. **Inject** — SessionStart hook rehydrates agent context from transported payload
4. **Cleanup** — Temp files auto-delete after successful handoff

## Commands

| Command | Action |
|---------|--------|
| `/handshake on` | Enable transport layer (creates config + state dirs) |
| `/handshake off` | Disable transport (preserves existing state) |
| `/handshake status` | Show enabled/disabled state + transport info |

## Transport Payload (v2.0)

The checkpoint.json is a **transport container** with these fields:

```json
{
  "version": "2.0",
  "timestamp": "ISO8601",
  "source": "handshake_transport",
  "transportedAt": "ISO8601",
  "sessionId": "session-uuid",
  "projectDir": "/path/to/project",
  "objective": "what the user asked",
  "phase": "current phase",
  "currentPlan": "approach being followed",
  "filesTouched": ["list"],
  "activeFiles": ["list"],
  "commandsRun": ["list"],
  "pendingCommands": ["list"],
  "decisionsMade": [{"decision": "...", "reason": "..."}],
  "completedSteps": ["list"],
  "unresolvedTodos": ["list"],
  "testStatus": "none|passing|failing|unknown",
  "verificationRequired": ["list"],
  "risks": ["list"],
  "failedAttempts": [{"attempt": "...", "reason": "..."}],
  "assumptions": ["list"],
  "nextAction": "exact next step",
  "handoffMode": "auto|ask",
  "resumeSafety": {
    "repoChanged": false,
    "stale": false,
    "unresolvedRisks": false,
    "destructiveNextAction": false,
    "ambiguousTask": false,
    "reasons": []
  },
  "repoState": {
    "branch": "main",
    "commit": "abc123",
    "dirty": true
  }
}
```

## Optional: 95% Auto-Checkpoint

Enable automatic checkpoint at 95% context (uses PostToolUse hook):

```json
// .claude/handshake/config.json
{
  "enabled": true,
  "checkpointThreshold": 95  // Set to 0 to disable
}
```

When enabled, the PostToolUse hook monitors context usage and triggers transport automatically at the threshold.

## File Locations

| File | Purpose |
|------|---------|
| `.claude/handshake/config.json` | Transport layer config |
| `.claude/handshake/checkpoint.json` | Machine-readable transport payload |
| `.claude/handshake/checkpoint.md` | Human-readable summary |
| `.claude/handshake/tmp/` | Temp files (auto-cleaned) |

## Notes

- Transport works across **both** `/clear` and compaction
- 95% auto-checkpoint is **optional** (set `checkpointThreshold: 0` to disable)
- Temp files auto-delete after successful rehydration
- The PreCompact hook fires **before** compaction — relies on agent cooperation
