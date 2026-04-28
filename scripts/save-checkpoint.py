#!/usr/bin/env python3
"""save-checkpoint.py — Save checkpoint JSON for Handshake"""
import json, sys, os, datetime

def save_checkpoint(session_id, session_dir, project_dir):
    checkpoint_file = os.path.join(project_dir, '.claude/handshake/checkpoint.json')
    checkpoint_md = os.path.join(project_dir, '.claude/handshake/checkpoint.md')
    jsonl_path = os.path.join(session_dir, f'{session_id}.jsonl')
    
    os.makedirs(os.path.dirname(checkpoint_file), exist_ok=True)
    
    if not os.path.exists(jsonl_path):
        print(f'Session file not found: {jsonl_path}')
        return False
    
    # Read last 200 lines to extract context
    lines = []
    with open(jsonl_path, 'r') as f:
        for line in f:
            lines.append(line)
            if len(lines) > 200:
                lines.pop(0)
    
    # Extract objective from first user message
    objective = ""
    phase = "checkpoint"
    
    for line in lines:
        try:
            obj = json.loads(line)
            if obj.get('type') == 'user':
                content = obj.get('message', {}).get('content', '')
                if isinstance(content, list):
                    for item in content:
                        if isinstance(item, dict) and item.get('type') == 'text':
                            text = item.get('text', '')
                            if text and not objective:
                                objective = text[:200]
                                break
                elif isinstance(content, str) and not objective:
                    objective = content[:200]
                break
        except:
            pass
    
    checkpoint = {
        "version": "1.0",
        "timestamp": datetime.datetime.now().isoformat(),
        "source": "auto_95pct",
        "objective": objective or "auto-saved at 95% context",
        "phase": phase,
        "currentPlan": "context saved, ready for /clear or compaction",
        "filesTouched": [],
        "activeFiles": [],
        "commandsRun": [],
        "pendingCommands": [],
        "decisionsMade": [],
        "completedSteps": [],
        "unresolvedTodos": [],
        "testStatus": "unknown",
        "verificationRequired": [],
        "risks": [],
        "failedAttempts": [],
        "assumptions": [],
        "nextAction": "continue work after /clear or compaction",
        "handoffMode": "auto",
        "resumeSafety": {
            "repoChanged": False,
            "stale": False,
            "unresolvedRisks": False,
            "destructiveNextAction": False,
            "ambiguousTask": False,
            "reasons": []
        },
        "repoState": {
            "branch": "",
            "commit": "",
            "dirty": True
        }
    }
    
    with open(checkpoint_file, 'w') as f:
        json.dump(checkpoint, f, indent=2)
    
    with open(checkpoint_md, 'w') as f:
        f.write(f'# Checkpoint (Auto-saved at 95%)\n\n')
        f.write(f'**Time**: {checkpoint["timestamp"]}\n')
        f.write(f'**Objective**: {checkpoint["objective"]}\n')
        f.write(f'**Phase**: {checkpoint["phase"]}\n')
        f.write(f'**Next Action**: {checkpoint["nextAction"]}\n')
    
    print(f'Checkpoint saved to {checkpoint_file}')
    return True

if __name__ == '__main__':
    if len(sys.argv) < 4:
        print('Usage: save-checkpoint.py <session_id> <session_dir> <project_dir>')
        sys.exit(1)
    success = save_checkpoint(sys.argv[1], sys.argv[2], sys.argv[3])
    sys.exit(0 if success else 1)
