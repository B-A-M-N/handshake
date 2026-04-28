#!/usr/bin/env python3
"""save-checkpoint.py — Context Transport Layer for Handshake
Saves a complete agent state snapshot for transport across session boundaries.
"""
import json, sys, os, datetime, re
from typing import Any, Dict, List, Optional

def extract_context_from_session(session_path: str) -> Dict[str, Any]:
    """Extract agent context from session JSONL file."""
    lines = []
    try:
        with open(session_path, 'r') as f:
            for line in f:
                lines.append(line)
                if len(lines) > 500:  # Keep last 500 lines
                    lines.pop(0)
    except Exception:
        return {}
    
    context = {
        "objective": "",
        "phase": "unknown",
        "currentPlan": "",
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
        "repoState": {},
        "messages": []
    }
    
    # Parse session messages
    user_messages = []
    assistant_messages = []
    
    for line in lines:
        try:
            obj = json.loads(line)
            msg_type = obj.get('type', '')
            if msg_type == 'user':
                user_messages.append(obj)
            elif msg_type == 'assistant':
                assistant_messages.append(obj)
        except:
            continue
    
    # Extract objective from first substantive user message
    for msg in user_messages:
        content = msg.get('message', {}).get('content', '')
        if isinstance(content, str) and len(content.strip()) > 20:
            context['objective'] = content.strip()[:500]
            break
        elif isinstance(content, list):
            for item in content:
                if isinstance(item, dict) and item.get('type') == 'text':
                    text = item.get('text', '')
                    if len(text.strip()) > 20:
                        context['objective'] = text.strip()[:500]
                        break
            if context['objective']:
                break
    
    # Extract phase from recent messages
    for msg in reversed(assistant_messages):
        content = str(msg.get('message', {}).get('content', ''))
        phase_match = re.search(r'(?:phase|step)\s*:?\s*([^\n.]{3,50})', content, re.IGNORECASE)
        if phase_match:
            context['phase'] = phase_match.group(1).strip()
            break
    
    # Extract git state
    try:
        import subprocess
        result = subprocess.run(['git', 'branch', '--show-current'], 
                            capture_output=True, text=True, timeout=5)
        if result.returncode == 0:
            context['repoState']['branch'] = result.stdout.strip()
        
        result = subprocess.run(['git', 'rev-parse', 'HEAD'],
                            capture_output=True, text=True, timeout=5)
        if result.returncode == 0:
            context['repoState']['commit'] = result.stdout.strip()[:10]
            
        result = subprocess.run(['git', 'status', '--porcelain'],
                            capture_output=True, text=True, timeout=5)
        context['repoState']['dirty'] = len(result.stdout.strip()) > 0
    except:
        pass
    
    return context

def save_checkpoint(session_id: str, session_dir: str, project_dir: str) -> bool:
    """Save checkpoint as context transport payload."""
    checkpoint_file = os.path.join(project_dir, '.claude/handshake/checkpoint.json')
    checkpoint_md = os.path.join(project_dir, '.claude/handshake/checkpoint.md')
    jsonl_path = os.path.join(session_dir, f'{session_id}.jsonl')
    
    os.makedirs(os.path.dirname(checkpoint_file), exist_ok=True)
    
    if not os.path.exists(jsonl_path):
        print(f'Session file not found: {jsonl_path}')
        return False
    
    # Extract context from session
    context = extract_context_from_session(jsonl_path)
    
    # Build transport payload
    checkpoint = {
        "version": "2.0",
        "timestamp": datetime.datetime.now().isoformat(),
        "source": "handshake_transport",
        "transportedAt": datetime.datetime.now().isoformat(),
        "sessionId": session_id,
        "projectDir": project_dir,
        **context
    }
    
    # Write machine-readable checkpoint
    with open(checkpoint_file, 'w') as f:
        json.dump(checkpoint, f, indent=2)
    
    # Write human-readable summary
    with open(checkpoint_md, 'w') as f:
        f.write(f'# Context Transport (Handshake v2.0)\n\n')
        f.write(f'**Transported At**: {checkpoint["transportedAt"]}\n')
        f.write(f'**Session**: {session_id}\n')
        f.write(f'**Objective**: {checkpoint.get("objective", "N/A")}\n')
        f.write(f'**Phase**: {checkpoint.get("phase", "N/A")}\n')
        f.write(f'**Next Action**: {checkpoint.get("nextAction", "N/A")}\n')
        f.write(f'\n## Repo State\n')
        f.write(f'- Branch: {checkpoint.get("repoState", {}).get("branch", "unknown")}\n')
        f.write(f'- Commit: {checkpoint.get("repoState", {}).get("commit", "unknown")}\n')
        f.write(f'- Dirty: {checkpoint.get("repoState", {}).get("dirty", True)}\n')
    
    print(f'Context transport saved to {checkpoint_file}')
    return True

if __name__ == '__main__':
    if len(sys.argv) < 4:
        print('Usage: save-checkpoint.py <session_id> <session_dir> <project_dir>')
        sys.exit(1)
    success = save_checkpoint(sys.argv[1], sys.argv[2], sys.argv[3])
    sys.exit(0 if success else 1)
