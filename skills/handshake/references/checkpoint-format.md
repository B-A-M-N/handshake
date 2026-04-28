# Checkpoint Format Reference

## Overview

Handshake checkpoints are saved as two files:
- `checkpoint.json` — machine-readable authority (JSON)
- `checkpoint.md` — human-readable summary (Markdown)

## JSON Structure (checkpoint.json)

```json
{
  "version": "1.0",
  "timestamp": "2026-04-27T10:30:00Z",
  "source": "precompact | clear | session",
  "objective": "What the agent is trying to accomplish",
  "phase": "discovery | planning | implementation | testing | review | done",
  "currentPlan": "The plan or approach being followed",
  "filesTouched": ["src/auth/login.js", "tests/auth.test.js"],
  "activeFiles": ["src/auth/login.js"],
  "commandsRun": ["npm test", "git status"],
  "pendingCommands": ["npm run build"],
  "decisionsMade": [
    {
      "decision": "Use JWT for tokens",
      "reason": "Stateless auth needed"
    }
  ],
  "completedSteps": ["Created login endpoint", "Added JWT middleware"],
  "unresolvedTodos": ["Add refresh token logic", "Write integration tests"],
  "testStatus": "none | passing | failing | unknown",
  "verificationRequired": ["Run full test suite", "Manual login flow test"],
  "risks": ["Breaking change to token format"],
  "failedAttempts": [
    {
      "attempt": "Used session tokens",
      "reason": "Doesn't scale to multiple servers"
    }
  ],
  "assumptions": ["User is using Node.js 18+"],
  "nextAction": "Run npm test to verify changes",
  "handoffMode": "auto | ask",
  "resumeSafety": {
    "repoChanged": false,
    "stale": false,
    "unresolvedRisks": false,
    "destructiveNextAction": false,
    "ambiguousTask": false,
    "reasons": ["list of safety flags that triggered ask-mode"]
  },
  "repoState": {
    "branch": "fix-auth",
    "commit": "abc1234",
    "dirty": true
  }
}
```

## Field Descriptions

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `version` | string | yes | Checkpoint format version |
| `timestamp` | string | yes | ISO8601 timestamp of checkpoint creation |
| `source` | string | yes | What triggered the checkpoint: `precompact`, `clear`, or `session` |
| `objective` | string | yes | Current high-level objective |
| `phase` | string | yes | Current workflow phase |
| `currentPlan` | string | no | Active plan or approach |
| `filesTouched` | array | no | All files modified during this task |
| `activeFiles` | array | no | Files currently being worked on |
| `commandsRun` | array | no | Commands executed so far |
| `pendingCommands` | array | no | Commands planned but not yet run |
| `decisionsMade` | array | no | Key decisions with reasons |
| `completedSteps` | array | no | Steps already finished |
| `unresolvedTodos` | array | no | Items remaining to be done |
| `testStatus` | string | no | Current test suite status |
| `verificationRequired` | array | no | What needs verifying before task completion |
| `risks` | array | no | Potential risks of continuing |
| `failedAttempts` | array | no | Previous failed approaches with reasons |
| `assumptions` | array | no | Current assumptions about the task/environment |
| `nextAction` | string | yes | Exact next step the agent should take |
| `handoffMode` | string | yes | `auto` (resume silently) or `ask` (confirm first) |
| `resumeSafety` | object | yes | Safety flags determining resume behavior |
| `repoState` | object | yes | Git repository state at checkpoint time |

## Resume Safety Flags

The `resumeSafety` object determines whether to auto-resume or ask for confirmation:

| Flag | Type | Description |
|------|------|-------------|
| `repoChanged` | boolean | True if git branch, commit, or dirty state changed since checkpoint |
| `stale` | boolean | True if checkpoint is older than `stalenessHours` (default 24h) |
| `unresolvedRisks` | boolean | True if `risks` array has items that haven't been addressed |
| `destructiveNextAction` | boolean | True if next action could cause data loss or damage |
| `ambiguousTask` | boolean | True if it's unclear what task to resume |
| `reasons` | array | List of human-readable reasons why ask-mode was triggered |

## Handoff Mode Logic

```
IF handoffMode == "ask" OR resumeSafety has any true flags:
  → Ask user for confirmation before resuming
ELSE:
  → Auto-resume silently
```

## Markdown Summary (checkpoint.md)

The Markdown file is for human inspection. It should contain:

```markdown
# Handshake Checkpoint

**Created:** 2026-04-27 10:30:00 UTC
**Source:** precompact
**Stale:** No (2 hours old)

## Objective
Fix authentication bug in login flow

## Phase
implementation

## Next Action
Run npm test to verify changes

## Resume Mode
Auto (safe to resume)

## Files Touched
- src/auth/login.js
- tests/auth.test.js

## Commands Run
- npm test
- git status

## Decisions Made
- **Use JWT for tokens** — Stateless auth needed

## Unresolved TODOs
- Add refresh token logic
- Write integration tests

## Risks
- Breaking change to token format

## Repo State
- Branch: fix-auth
- Commit: abc1234
- Dirty: true
```

## Example Checkpoint Files

See `examples/checkpoint.json` and `examples/checkpoint.md` for complete working examples.
