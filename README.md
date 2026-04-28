# Handshake

Context-continuity plugin for Claude Code that prevents agent "memory loss" during compaction, `/clear`, or long-running sessions.

## What It Does

When enabled, Handshake automatically:

1. **Monitors** context pressure via `PreCompact` hook
2. **Checkpoints** structured workflow state to `.claude/handshake/checkpoint.json` before compaction or `/clear`
3. **Rehydrates** agent context after reset using the saved checkpoint
4. **Resumes safely** — automatically when safe, or asks when risks are present

## Installation

```bash
# Clone or copy the plugin to your plugins directory
cp -r handshake/ ~/.claude/plugins/

# Or load it directly
claude --plugin-dir /home/bamn/handshake
```

## Usage

### Enable/Disable

```
/handshake on     # Enable automatic context continuity
/handshake off    # Disable (normal Claude Code behavior)
/handshake status  # Show current state and last checkpoint
```

### What Gets Saved

Checkpoints include:
- Current objective and phase
- Files touched and active files
- Commands run and pending commands
- Decisions made and completed steps
- Unresolved TODOs and test status
- Risks, assumptions, and safety flags
- Next exact action to take

### Resume Behavior

**Auto-resume** (silent): When checkpoint is low-risk, repo unchanged, and next action is non-destructive.

**Ask-gated resume**: When risks are unresolved, next action could cause damage, repo state changed, or checkpoint is stale (>24h).

## State Files

All state is project-local by default:

- `.claude/handshake/config.json` — enabled/disabled state and thresholds
- `.claude/handshake/checkpoint.json` — machine-readable checkpoint (authority)
- `.claude/handshake/checkpoint.md` — human-readable summary

## Configuration

Edit `.claude/handshake/config.json` (created on first `/handshake on`):

```json
{
  "enabled": true,
  "warningThreshold": 90,
  "checkpointThreshold": 95,
  "autoResume": true,
  "stalenessHours": 24,
  "checkpointPath": ".claude/handshake/checkpoint.json",
  "markdownPath": ".claude/handshake/checkpoint.md"
}
```

## How It Works

### Hooks

| Hook | Purpose |
|------|---------|
| `PreCompact` | Instructs agent to save checkpoint before compaction |
| `SessionStart` | Checks for checkpoint and rehydrates if enabled |
| `UserPromptSubmit` | Detects `/clear` and saves checkpoint before clear executes |

### Skill

The `/handshake` skill handles:
- `on` — enables plugin, creates config, sets up state directory
- `off` — disables plugin (state preserved for later resume)
- `status` — shows enabled state, last checkpoint, resume mode

## Limitations

- `/clear` survival is best-effort — depends on `UserPromptSubmit` hook timing
- Context thresholds are configurable but monitoring depends on hook availability
- Checkpoint accuracy depends on agent's ability to summarize its own state

## License

MIT
