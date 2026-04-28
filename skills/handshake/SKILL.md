---
name: handshake
description: This skill should be used when the user types "/handshake on", "/handshake off", or "/handshake status". Provides toggle control for the Handshake context-continuity plugin, managing automatic checkpoint save before compaction/clear and resume after context reset.
---

# Handshake — Context Continuity Control

## Overview

Handshake is a context-continuity plugin that checkpoints agent state before compaction or `/clear`, then rehydrates after context reset. This skill provides the user-facing toggle: `/handshake on|off|status`.

## Command Interface

| Command | Action |
|---------|--------|
| `/handshake on` | Enable automatic continuity (creates config and state dirs) |
| `/handshake off` | Disable automatic continuity (preserves existing state) |
| `/handshake status` | Show current enabled/disabled state and checkpoint info |

## Implementation

### `/handshake on`

To enable Handshake:

1. Create the config directory if it does not exist:
   ```bash
   mkdir -p .claude/handshake
   ```

2. Read or create the config file at `.claude/handshake/config.json`:
   ```json
   {
     "enabled": true,
     "warningThreshold": 90,
     "checkpointThreshold": 95,
     "autoResume": true,
     "stalenessHours": 24,
     "checkpointPath": ".claude/handshake/checkpoint.json",
     "markdownPath": ".claude/handshake/checkpoint.md",
     "lastCheckpoint": null
   }
   ```
   If the file already exists, update only the `enabled` field to `true`.

3. Confirm to the user: "Handshake enabled. Context continuity is now active."

### `/handshake off`

To disable Handshake:

1. Read the config file at `.claude/handshake/config.json`.
2. Update only the `enabled` field to `false` (preserve all other fields).
3. Confirm to the user: "Handshake disabled. Context continuity is off. State files preserved."

### `/handshake status`

To show status:

1. Read the config file at `.claude/handshake/config.json`. If the file does not exist, report "Handshake not configured. Use `/handshake on` to enable."

2. Display:
   - **Enabled**: [true/false from config]
   - **Auto-resume**: [autoResume value]
   - **Thresholds**: warning [warningThreshold]%, checkpoint [checkpointThreshold]%
   - **Staleness**: [stalenessHours] hours

3. If `lastCheckpoint` is set, read the checkpoint file at `checkpointPath` and display:
   - **Last checkpoint**: [timestamp, relative time]
   - **Source**: [source field from checkpoint]
   - **Objective**: [objective field]
   - **Phase**: [phase field]
   - **Next action**: [nextAction field]
   - **Stale?**: Yes if older than stalenessHours, else No

4. Determine resume mode:
   - If `resumeSafety` flags are present and indicate risk → "Ask-gated"
   - Otherwise → "Automatic"

5. Show summary to user in a clean format.

## Allowed Tools

Use these tools only:
- `Read` — read config and checkpoint files
- `Write` — create or update config file (use Edit if file exists)
- `Edit` — update specific fields in existing config
- `Bash` — limited to safe repo inspection:
  - `git status`
  - `git rev-parse --git-dir`
  - `git branch --show-current`
  - `git diff --stat`

## Notes

- The checkpoint save/resume behavior is hook-driven (PreCompact, SessionStart, UserPromptSubmit). This skill only controls the enabled/disabled toggle and shows state.
- Config is project-local at `.claude/handshake/config.json`.
- Checkpoint files: `checkpoint.json` (machine-readable authority) and `checkpoint.md` (human-readable summary).
- Do not create checkpoint files from this skill — checkpoint creation is automatic via hooks.

## Additional Resources

### Reference Files

For detailed checkpoint format and field descriptions:
- **`references/checkpoint-format.md`** — Complete JSON structure, field descriptions, resume safety flags, and markdown summary format

### Example Files

Working examples in `examples/`:
- **`checkpoint.json`** — Complete example of a machine-readable checkpoint
- **`checkpoint.md`** — Corresponding human-readable summary
