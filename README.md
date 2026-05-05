# Handshake

Context-continuity plugin for Claude Code. Maintains durable checkpoints and resumes through the next prompt or explicit `/handshake resume`. Does **not** rely on SessionStart rehydration.

## What It Does

1. **Monitors** transcript + git state continuously via background Python daemon
2. **Checkpoints** structured workflow state to `.claude/handshake/checkpoint.json`
3. **Senses** context pressure via statusline sensor (real `used_percentage`, not transcript guessing)
4. **Warns** at 70/80/90/95% context bands via sparse monitor notifications
5. **Resumes** via `UserPromptSubmit` hook (primary) or `/handshake resume` (guaranteed fallback)

## Architecture

```
statusline sensor  →  context.json     (senses context_window.used_percentage)
context monitor    →  warnings         (emits at 70/80/90/95% threshold bands)
checkpointer       →  checkpoint.json  (distills transcript + git state)
PreCompact         →  gate setting     (validates freshness, sets needs_resume)
UserPromptSubmit   →  resume injection (PRIMARY — injects checkpoint as additionalContext)
SessionStart       →  opportunistic    (bonus path, non-authoritative)
SessionEnd         →  cleanup          (final checkpoint, lock release)
```

**Core principle:** Monitor maintains state. Hooks inject state. Commands expose state.

## Modes

Only one mode active at a time. Mode persists across `/clear`.

### `compact` — Continuous checkpointing + prompt-bound resume

```
/handshake compact
  → starts checkpointer monitor
  → starts context monitor
  → checkpoint refreshed continuously
  → UserPromptSubmit resumes when needs_resume=true
```

### `pass` — Intentional handoff packet

```
/handshake pass
  → writes handoff.json, handoff.md, resume-prompt.md
  → no monitor needed
  → no hidden auto-resume assumption
```

## Installation

```bash
# Load directly
claude --plugin-dir /home/bamn/handshake

# Or copy to plugins directory
cp -r handshake/ ~/.claude/plugins/
```

## Usage

```
/handshake           # Show status
/handshake on        # Enable
/handshake off       # Disable
/handshake compact   # Start compact mode
/handshake pass      # Create handoff packet
/handshake resume    # Explicitly print checkpoint summary (guaranteed fallback)
```

## State Files

```
.claude/handshake/
  config.json          # enabled, mode
  runtime.json         # control plane (needs_resume, emitted, etc.)
  checkpoint.json      # durable state packet (v1 schema)
  checkpoint.md        # human-readable checkpoint
  context.json         # context telemetry from statusline sensor
  events.jsonl         # event log
  monitor.lock         # monitor PID lock
  monitor.offset       # transcript read offset
  heartbeat.json       # monitor liveness
  handoff.json         # pass mode: handoff data
  handoff.md           # pass mode: human-readable handoff
  resume-prompt.md     # pass mode: resume instructions
```

## Configuration

Edit `.claude/handshake/config.json`:

```json
{
  "enabled": true,
  "mode": "compact",
  "stalenessHours": 24,
  "checkpointPath": ".claude/handshake/checkpoint.json",
  "markdownPath": ".claude/handshake/checkpoint.md"
}
```

### Statusline Sensor (optional but recommended)

To enable real context-pressure awareness, configure a statusLine in your Claude Code settings:

```json
{
  "statusLine": {
    "type": "command",
    "command": "${CLAUDE_PLUGIN_ROOT}/scripts/handshake-statusline-sensor.sh",
    "refreshInterval": 5
  }
}
```

Requires `jq`. This writes `.claude/handshake/context.json` with `context_window.used_percentage` from Claude Code's status line data. The context monitor polls this file and emits threshold warnings.

## Context Pressure Bands

| Threshold | Band       | Behavior |
|-----------|------------|----------|
| 70%       | advisory   | Keep checkpoint warm |
| 80%       | warning    | Refresh checkpoint before major edits |
| 90%       | danger     | Checkpoint required before continuing |
| 95%       | critical   | Set needs_resume=true, avoid new write-heavy work |

## Resume Modes

The checkpointer computes a `resume_mode` in `checkpoint.json`:

| Mode | Behavior |
|------|----------|
| `auto` | Safe to proceed with read-only or test-only actions |
| `ask` | Ask before writing |
| `block` | Stop and ask before any action |

Resume is gated by: dirty worktree, risk signals, stale checkpoint, branch changes.

## Scripts

| Script | Role |
|--------|------|
| `scripts/handshake-monitor.py` | Checkpoint daemon (Python) |
| `scripts/handshake-statusline-sensor.sh` | Context telemetry sidecar |
| `scripts/handshake-context-monitor.sh` | Context pressure threshold broadcaster |
| `scripts/userprompt-resume.sh` | UserPromptSubmit hook — primary resume injection |
| `scripts/precompact-check.sh` | PreCompact hook — emergency freshness validation |
| `scripts/session-start-hook.sh` | SessionStart hook — opportunistic mode restore |
| `scripts/sessionend-finalize.sh` | SessionEnd hook — cleanup |

## What NOT to Rely On

- **SessionStart rehydration** — can silently discard `additionalContext`. Use `UserPromptSubmit` (primary) or `/handshake resume` (guaranteed).
- **Auto-resume for writes** — the checkpointer is conservative. Anything that modifies files will be `ask`-gated if the repo is dirty.
- **Transcript-length context estimation** — use the statusline sensor for real percentages.

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

## License

MIT
