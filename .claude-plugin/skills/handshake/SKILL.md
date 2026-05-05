---
name: handshake
description: "Context-continuity plugin. Maintains durable checkpoints and resumes through the next prompt or explicit /handshake resume. Does not rely on SessionStart rehydration."
---

# Handshake — Context Continuity Plugin

## What Handshake Does

Handshake maintains durable workflow checkpoints that survive `/clear` and compaction.

**Core principle:** The monitor maintains state. Hooks inject state. Commands expose state.

**Do NOT rely on SessionStart rehydration.** It is opportunistic at best.

## Context Awareness: Two-Process Loop

Context pressure is handled by a **statusline sensor + monitor** pair:

```
Claude Code statusLine JSON (has context_window.used_percentage)
        ↓
handshake-statusline-sensor.sh  →  .claude/handshake/context.json
        ↓
handshake-context-monitor.sh    →  emits threshold warnings
        ↓
HANDSHAKE context advisory/warning/danger/critical
        ↓
Claude sees notification → checkpoints / avoids write-heavy work
```

Do NOT estimate context from transcript length. Use the official
`context_window.used_percentage` field from status line data.

### Sensor: `handshake-statusline-sensor.sh`

Reads statusline JSON from stdin, writes `context.json`. Configure as:

```json
{
  "statusLine": {
    "type": "command",
    "command": "${CLAUDE_PLUGIN_ROOT}/scripts/handshake-statusline-sensor.sh",
    "refreshInterval": 5
  }
}
```

Requires `jq`.

### Monitor: `handshake-context-monitor.sh`

Polls `context.json`, emits only on threshold crossings:

| Threshold | Band       | Action |
|-----------|------------|--------|
| 70%       | advisory   | Keep checkpoint warm |
| 80%       | warning    | Refresh checkpoint before major edits |
| 90%       | danger     | Checkpoint required before continuing |
| 95%       | critical   | Set needs_resume=true, avoid new write-heavy work |

Every monitor stdout line interrupts the session, so the monitor is sparse — it only emits when the band changes.

## Modes

**Only one mode can be active at a time.** compact XOR pass.

**Mode persists across `/clear`.** The active mode is stored in `config.json` and
restored by the SessionStart hook. Toggling to a different mode replaces the
previous one. Exiting Claude Code does not persist mode — it must be set again
each session (or left in config.json deliberately).

### `/handshake compact` — Continuous checkpointing + prompt-bound resume

```
monitor keeps checkpoint.json fresh
compaction or /clear happens
PreCompact sets needs_resume=true
next UserPromptSubmit injects checkpoint
if that fails, user runs /handshake resume
```

Starts the checkpointer monitor and context monitor. Mode is written to
`config.json` so it survives `/clear`.

### `/handshake pass` — Intentional handoff packet

```
writes handoff.json, handoff.md, resume-prompt.md
no monitor needed
no hidden auto-resume assumption
```

Does not start any monitor. Creates a one-time handoff packet. Mode is
written to `config.json` so it persists, but no background processes run.

## File Layout

```
.claude/handshake/
  config.json          # Plugin configuration (enabled, mode)
  runtime.json         # Control plane (mode, needs_resume, emitted, etc.)
  checkpoint.json      # Durable state packet (v1 schema)
  checkpoint.md        # Human-readable checkpoint
  context.json         # Context telemetry from statusline sensor
  events.jsonl         # Event log
  monitor.lock         # Monitor PID lock
  monitor.offset       # Transcript read offset
  heartbeat.json       # Monitor liveness
  handoff.json         # Pass mode: handoff data
  handoff.md           # Pass mode: human-readable handoff
  resume-prompt.md     # Pass mode: resume instructions
```

## Hook Architecture

```
statusline sensor    → handshake-statusline-sensor.sh  (writes context.json)
context monitor      → handshake-context-monitor.sh    (emits threshold warnings)
PreCompact           → precompact-check.sh    (emergency freshness validation, sets needs_resume)
UserPromptSubmit     → userprompt-resume.sh   (PRIMARY resume injection)
SessionStart         → session-start-hook.sh  (OPPORTUNISTIC bonus only)
SessionEnd           → sessionend-finalize.sh (final checkpoint, cleanup)
```

**PreCompact is NOT early warning.** It fires when compaction is already imminent.
Early warning comes from the statusline sensor + context monitor.

**No PostToolUse hook.** The checkpointer monitor handles continuous checkpointing.

## Checkpoint Schema (v1)

```json
{
  "schema_version": 1,
  "created_at": "ISO-8601",
  "updated_at": "ISO-8601",
  "session": { "session_id": "...", "cwd": "...", "transcript_path": "..." },
  "repo": { "branch": "...", "head": "...", "dirty": true, "changed_files": [] },
  "workflow": { "objective": "...", "phase": "...", "next_action": "..." },
  "activity": { "files_touched": [], "commands_run": [], "tests_run": [] },
  "safety": { "risk_level": "low|medium|high", "resume_mode": "auto|ask|block" }
}
```

## Resume Modes

| Mode | Behavior |
|------|----------|
| `auto` | Safe to proceed with read-only or test-only actions |
| `ask` | Ask before writing |
| `block` | Stop and ask before any action |

## Commands

- `/handshake` or `/handshake status` — Show current state
- `/handshake on` — Enable Handshake
- `/handshake off` — Disable Handshake
- `/handshake compact` — Start compact mode (monitor + prompt-bound resume)
- `/handshake pass` — Create handoff packet
- `/handshake resume` — Explicitly print/inject checkpoint summary

## What to Tell Users

```
Maintains durable checkpoints and resumes through the next prompt
or explicit /handshake resume.
```

Do NOT advertise "Rehydrates automatically after reset." That is too strong.
