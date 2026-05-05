#!/usr/bin/env python3
"""
handshake-monitor.py — Handshake compact-mode checkpoint daemon.

Maintains .claude/handshake/checkpoint.json by continuously distilling
transcript + git state into durable files. Sets resume gates. Emits only
meaningful state changes.

It does NOT inject context. That is the job of hooks (UserPromptSubmit).
"""

import json
import os
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(os.environ.get("CLAUDE_PROJECT_DIR", "."))
STATE_DIR = ROOT / ".claude" / "handshake"
CONFIG = STATE_DIR / "config.json"
RUNTIME = STATE_DIR / "runtime.json"
CHECKPOINT = STATE_DIR / "checkpoint.json"
CHECKPOINT_MD = STATE_DIR / "checkpoint.md"
EVENTS = STATE_DIR / "events.jsonl"
OFFSET = STATE_DIR / "monitor.offset"
HEARTBEAT = STATE_DIR / "heartbeat.json"
LOCK = STATE_DIR / "monitor.lock"

POLL_SECONDS = 2
MAX_CHECKPOINT_INTERVAL_SECONDS = 30


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def read_json(path: Path, default):
    try:
        return json.loads(path.read_text())
    except Exception:
        return default


def write_json_atomic(path: Path, data) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
    tmp.replace(path)


def append_event(event: dict) -> None:
    EVENTS.parent.mkdir(parents=True, exist_ok=True)
    with EVENTS.open("a") as f:
        f.write(json.dumps(event, sort_keys=True) + "\n")


def git(args):
    try:
        return subprocess.check_output(
            ["git", *args],
            cwd=str(ROOT),
            stderr=subprocess.DEVNULL,
            text=True,
        ).strip()
    except Exception:
        return ""


def git_state() -> dict:
    status = git(["status", "--short"])
    changed = []
    for line in status.splitlines():
        if not line.strip():
            continue
        changed.append(line[3:].strip())

    return {
        "branch": git(["branch", "--show-current"]),
        "head": git(["rev-parse", "--short", "HEAD"]),
        "upstream": git(["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"]),
        "dirty": bool(status),
        "status_short": status,
        "changed_files": changed,
        "status_hash": str(hash(status)),
    }


def read_new_transcript_lines(transcript_path: str, old_offset: int):
    path = Path(transcript_path)
    if not transcript_path or not path.exists():
        return old_offset, []

    with path.open("rb") as f:
        f.seek(old_offset)
        data = f.read()
        new_offset = f.tell()

    lines = []
    for raw in data.splitlines():
        try:
            lines.append(json.loads(raw.decode("utf-8")))
        except Exception:
            continue

    return new_offset, lines


def extract_activity(lines):
    activity = {
        "files_touched": [],
        "commands_run": [],
        "tests_run": [],
        "risks": [],
        "last_assistant_summary": None,
        "next_action_candidates": [],
    }

    RISK_TOKENS = ["risk", "danger", "destructive", "delete", "force push",
                   "rm -rf", "drop", "truncate", "irreversible"]

    for item in lines:
        text = json.dumps(item)

        if "Bash" in text or '"tool_name": "Bash"' in text:
            activity["commands_run"].append(text[:500])

        if any(t in text.lower() for t in ["npm test", "pytest", "vitest", "cargo test", "go test"]):
            activity["tests_run"].append(text[:500])

        if any(token in text for token in ["Edit", "Write", "MultiEdit"]):
            activity["files_touched"].append(text[:500])

        lowered = text.lower()
        if any(token in lowered for token in RISK_TOKENS):
            activity["risks"].append(text[:500])

        if "next action" in lowered or "next step" in lowered:
            activity["next_action_candidates"].append(text[:500])

    return activity


def choose_resume_mode(runtime, repo, activity):
    if not repo["branch"]:
        return "block", "not_a_git_repo"

    if activity["risks"]:
        return "ask", "risk_signals_detected"

    if repo["dirty"]:
        return "ask", "dirty_worktree"

    return "auto", "clean_checkpoint"


def build_checkpoint(runtime, previous, repo, activity):
    resume_mode, resume_reason = choose_resume_mode(runtime, repo, activity)

    old_workflow = previous.get("workflow", {})

    next_action = old_workflow.get("next_action")
    if not next_action:
        next_action = "Inspect checkpoint and determine the next safe action."

    if activity["next_action_candidates"]:
        next_action = "Review recent transcript next-action candidate and continue safely."

    return {
        "schema_version": 1,
        "created_at": previous.get("created_at") or now_iso(),
        "updated_at": now_iso(),
        "session": {
            "session_id": runtime.get("session_id"),
            "cwd": str(ROOT),
            "transcript_path": runtime.get("transcript_path"),
        },
        "repo": {
            "branch": repo["branch"],
            "head": repo["head"],
            "upstream": repo["upstream"],
            "dirty": repo["dirty"],
            "status_short": repo["status_short"],
            "changed_files": repo["changed_files"],
        },
        "workflow": {
            "objective": old_workflow.get("objective") or "Unknown objective. Recover from transcript/checkpoint.",
            "phase": old_workflow.get("phase") or "UNKNOWN",
            "current_task": old_workflow.get("current_task") or "Unknown current task.",
            "next_action": next_action,
            "completed_steps": old_workflow.get("completed_steps", []),
            "pending_steps": old_workflow.get("pending_steps", []),
            "decisions": old_workflow.get("decisions", []),
            "assumptions": old_workflow.get("assumptions", []),
        },
        "activity": {
            "files_touched": activity["files_touched"][-25:],
            "commands_run": activity["commands_run"][-25:],
            "tests_run": activity["tests_run"][-25:],
            "last_tool_use": None,
            "last_assistant_summary": activity["last_assistant_summary"],
        },
        "safety": {
            "risk_level": "medium" if resume_mode == "ask" else "low",
            "resume_mode": resume_mode,
            "resume_reason": resume_reason,
            "risks": activity["risks"][-25:],
            "blocked_actions": [],
            "requires_user_confirmation": resume_mode != "auto",
        },
    }


def write_checkpoint_md(checkpoint):
    changed = "\n".join(f"- `{f}`" for f in checkpoint["repo"]["changed_files"]) or "- None"
    md = f"""# Handshake Checkpoint

Updated: {checkpoint["updated_at"]}

## Objective

{checkpoint["workflow"]["objective"]}

## Phase

{checkpoint["workflow"]["phase"]}

## Current Task

{checkpoint["workflow"]["current_task"]}

## Next Action

{checkpoint["workflow"]["next_action"]}

## Repo

- Branch: `{checkpoint["repo"]["branch"]}`
- HEAD: `{checkpoint["repo"]["head"]}`
- Dirty: `{checkpoint["repo"]["dirty"]}`

## Changed Files

{changed}

## Resume

- Mode: `{checkpoint["safety"]["resume_mode"]}`
- Reason: `{checkpoint["safety"]["resume_reason"]}`
"""
    tmp = CHECKPOINT_MD.with_suffix(".md.tmp")
    tmp.write_text(md)
    tmp.replace(CHECKPOINT_MD)


def emit_once(runtime, key, line):
    emitted = runtime.setdefault("emitted", {})
    if emitted.get(key):
        return
    print(line, flush=True)
    emitted[key] = now_iso()


def acquire_lock():
    if LOCK.exists():
        try:
            pid = int(LOCK.read_text().strip())
            os.kill(pid, 0)
            return False  # already held by live process
        except (ProcessLookupError, ValueError, PermissionError, OSError):
            pass  # stale lock
    LOCK.write_text(str(os.getpid()))
    return True


def main():
    STATE_DIR.mkdir(parents=True, exist_ok=True)

    if not acquire_lock():
        return

    try:
        last_checkpoint_time = 0

        while True:
            config = read_json(CONFIG, {})
            runtime = read_json(RUNTIME, {})

            if not config.get("enabled", False):
                break

            if runtime.get("mode") != "compact":
                break

            transcript = str(runtime.get("transcript_path") or "")
            old_offset = int(read_json(OFFSET, {"offset": 0}).get("offset", 0))
            new_offset, lines = read_new_transcript_lines(transcript, old_offset)
            write_json_atomic(OFFSET, {"offset": new_offset, "updated_at": now_iso()})

            repo = git_state()
            activity = extract_activity(lines)
            previous = read_json(CHECKPOINT, {})

            important = bool(lines) or repo.get("status_hash") != runtime.get("last_git_status_hash")
            interval_due = time.time() - last_checkpoint_time > MAX_CHECKPOINT_INTERVAL_SECONDS

            if important or interval_due:
                checkpoint = build_checkpoint(runtime, previous, repo, activity)

                write_json_atomic(CHECKPOINT, checkpoint)
                write_checkpoint_md(checkpoint)

                runtime.update({
                    "monitor_pid": os.getpid(),
                    "last_checkpoint_at": checkpoint["updated_at"],
                    "checkpoint_fresh": True,
                    "last_git_head": repo["head"],
                    "last_git_status_hash": repo["status_hash"],
                    "risk_level": checkpoint["safety"]["risk_level"],
                })

                if checkpoint["safety"]["resume_mode"] != "auto":
                    runtime["needs_resume"] = True
                    runtime["resume_reason"] = checkpoint["safety"]["resume_reason"]
                    emit_once(
                        runtime,
                        f"risk:{checkpoint['safety']['resume_reason']}",
                        f"HANDSHAKE resume gated: reason={checkpoint['safety']['resume_reason']} checkpoint=.claude/handshake/checkpoint.json"
                    )

                write_json_atomic(RUNTIME, runtime)

                append_event({
                    "type": "checkpoint_written",
                    "at": now_iso(),
                    "resume_mode": checkpoint["safety"]["resume_mode"],
                    "resume_reason": checkpoint["safety"]["resume_reason"],
                    "head": repo["head"],
                    "dirty": repo["dirty"],
                })

                last_checkpoint_time = time.time()

            write_json_atomic(HEARTBEAT, {
                "at": now_iso(),
                "pid": os.getpid(),
                "mode": runtime.get("mode"),
                "checkpoint": str(CHECKPOINT),
            })

            time.sleep(POLL_SECONDS)

    finally:
        try:
            LOCK.unlink()
        except Exception:
            pass


if __name__ == "__main__":
    main()
