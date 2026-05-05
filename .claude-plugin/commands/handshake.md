---
description: "Toggle Handshake context-continuity plugin on/off, check status, or manage modes."
---

# /handshake

Manage the Handshake context-continuity plugin.

## Usage

```
/handshake           # Show status
/handshake status    # Show status
/handshake on        # Enable Handshake
/handshake off       # Disable Handshake
/handshake compact   # Start compact mode (monitor + prompt-bound resume)
/handshake pass      # Create handoff packet
/handshake resume    # Explicitly print checkpoint summary
```

## Actions

### Status

Read and display `.claude/handshake/config.json`, `runtime.json`, `checkpoint.json`, and `heartbeat.json`.

### On/Off

Toggle `enabled` in `config.json`.

### Compact Mode

Set `mode=compact` in both `config.json` and `runtime.json`. The monitor will start automatically via plugin monitor declaration.

### Pass Mode

Set `mode=pass`. Create `handoff.json`, `handoff.md`, and `resume-prompt.md` from the current checkpoint.

### Resume

Read `checkpoint.json` and `checkpoint.md` and print a formatted summary. This is the guaranteed fallback when automatic resume does not fire.
