#!/usr/bin/env python3
"""team-live.py: Claude Code hook helper that tells the Command face who is working.

Wire it (install.sh does) into ~/my-agent/.claude/settings.json for the events
SubagentStart, SubagentStop, UserPromptSubmit and Stop. Claude Code pipes the hook
event as JSON on stdin; this writes faces/command/live.json:

  {"active": {"comms-inbox-triage": 1725000000.0, ...}, "command": "thinking"|"idle", "ts": ...}

Prints nothing (a UserPromptSubmit hook's stdout would become context), never fails
the hook (always exits 0). Override the output path with COMMAND_FACE_LIVE.
"""
import json, os, sys, time, tempfile

HOME_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIVE = os.environ.get("COMMAND_FACE_LIVE") or os.path.join(HOME_DIR, "ai-visualizer", "faces", "command", "live.json")
STALE_S = 3600


def main():
    try:
        ev = json.loads(sys.stdin.read() or "{}")
    except Exception:
        ev = {}
    name = ev.get("hook_event_name", "")
    agent = ev.get("agent_type") or ""
    in_subagent = bool(ev.get("agent_id"))
    now = time.time()
    try:
        with open(LIVE, encoding="utf-8") as f:
            live = json.load(f)
    except Exception:
        live = {}
    active = live.get("active") if isinstance(live.get("active"), dict) else {}
    command = live.get("command", "idle")

    if name == "SubagentStart" and agent:
        active[agent] = now
    elif name == "SubagentStop" and agent:
        active.pop(agent, None)
    elif name == "UserPromptSubmit" and not in_subagent:
        command = "thinking"
    elif name in ("Stop", "SessionEnd") and not in_subagent:
        command = "idle"
    for k in [k for k, ts in active.items() if now - float(ts) > STALE_S]:
        active.pop(k, None)

    try:
        os.makedirs(os.path.dirname(LIVE), exist_ok=True)
        fd, tmp = tempfile.mkstemp(dir=os.path.dirname(LIVE), prefix=".live-", suffix=".json")
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump({"active": active, "command": command, "ts": now}, f)
        os.replace(tmp, LIVE)
    except Exception:
        pass


if __name__ == "__main__":
    main()
    sys.exit(0)
