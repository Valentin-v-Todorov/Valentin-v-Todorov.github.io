#!/usr/bin/env python3
"""team-live.py: Claude Code hook helper that tells the faces what is going on.

Wire it (install.sh does) into ~/my-agent/.claude/settings.json for the events
SubagentStart, SubagentStop, UserPromptSubmit and Stop. Claude Code pipes the hook
event as JSON on stdin; this keeps faces/command/live.json current:

  {"active":  {"comms-inbox-triage": 1725000000.0, ...},   who is working right now
   "command": "thinking" | "idle",                         the main session
   "you":     {"text": "...", "ts": ...},                  the last thing you said (typed or spoken)
   "said":    {"text": "...", "ts": ...},                  the last thing the agent answered
   "feed":    [{"ts": ..., "who": "...", "what": "..."}],  the last 20 events, newest first
   "turns":   42, "day": "2026-09-02",                     answers today
   "ts": ...}

The voice session is a Claude Agent SDK session in ~/my-agent, so these hooks fire
for it too: the conversation panel shows what you said and what Flint answered.
Everything stays on this machine (the visualizer serves 127.0.0.1 only). Set
COMMAND_FACE_WORDS=0 in the hook's environment to keep the words out of the file
and record only who is working. Override the path with COMMAND_FACE_LIVE.

Prints nothing (a UserPromptSubmit hook's stdout would become context), never fails
the hook (always exits 0).
"""
import json, os, sys, time, tempfile, datetime

HOME_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIVE = os.environ.get("COMMAND_FACE_LIVE") or os.path.join(HOME_DIR, "ai-visualizer", "faces", "command", "live.json")
WORDS = os.environ.get("COMMAND_FACE_WORDS", "1") != "0"
STALE_S = 3600
FEED_N = 20
TEXT_N = 600


def squash(s, n=TEXT_N):
    s = " ".join(str(s or "").split())
    return s if len(s) <= n else s[: n - 1] + "…"


def agent_name():
    """The agent's name as the roster spells it ("command" in team.json), else Flint."""
    try:
        with open(os.path.join(os.path.dirname(LIVE), "team.json"), encoding="utf-8") as f:
            n = str(json.load(f).get("command") or "").strip()
        return n[:1].upper() + n[1:] if n else "Flint"
    except Exception:
        return "Flint"


def last_assistant_text(path):
    """The final text the assistant wrote in a Claude Code transcript (JSONL).
    Reads only the tail of the file; a transcript can be many megabytes."""
    try:
        size = os.path.getsize(path)
        with open(path, "rb") as f:
            f.seek(max(0, size - 400_000))
            tail = f.read().decode("utf-8", "replace")
    except OSError:
        return ""
    best = ""
    for line in tail.splitlines():
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            ev = json.loads(line)
        except ValueError:
            continue
        if ev.get("type") != "assistant":
            continue
        msg = ev.get("message") if isinstance(ev.get("message"), dict) else ev
        content = msg.get("content")
        if isinstance(content, str):
            texts = [content]
        elif isinstance(content, list):
            texts = [b.get("text", "") for b in content if isinstance(b, dict) and b.get("type") == "text"]
        else:
            texts = []
        text = "\n".join(t for t in texts if t).strip()
        if text:
            best = text
    return best


def main():
    try:
        ev = json.loads(sys.stdin.read() or "{}")
    except Exception:
        ev = {}
    name = ev.get("hook_event_name", "")
    agent = ev.get("agent_type") or ""
    in_subagent = bool(ev.get("agent_id"))
    now = time.time()
    today = datetime.date.today().isoformat()
    try:
        with open(LIVE, encoding="utf-8") as f:
            live = json.load(f)
    except Exception:
        live = {}
    active = live.get("active") if isinstance(live.get("active"), dict) else {}
    feed = live.get("feed") if isinstance(live.get("feed"), list) else []
    command = live.get("command", "idle")
    you, said = live.get("you"), live.get("said")
    turns = int(live.get("turns") or 0) if live.get("day") == today else 0

    def note(who, what):
        feed.insert(0, {"ts": now, "who": who, "what": squash(what, 160)})

    if name == "SubagentStart" and agent:
        active[agent] = now
        note(agent, "started")
    elif name == "SubagentStop" and agent:
        active.pop(agent, None)
        what = last_assistant_text(ev.get("agent_transcript_path") or "") if WORDS else ""
        note(agent, what or "finished")
    elif name == "UserPromptSubmit" and not in_subagent:
        command = "thinking"
        if WORDS and ev.get("prompt"):
            you = {"text": squash(ev["prompt"]), "ts": now}
            note("You", "“" + squash(ev["prompt"], 140) + "”")
    elif name in ("Stop", "SessionEnd") and not in_subagent:
        command = "idle"
        if name == "Stop":
            turns += 1
            if WORDS:
                text = last_assistant_text(ev.get("transcript_path") or "")
                if text:
                    said = {"text": squash(text), "ts": now}
                    note(agent_name(), squash(text, 140))
    for k in [k for k, ts in active.items() if now - float(ts) > STALE_S]:
        active.pop(k, None)
    del feed[FEED_N:]

    out = {"active": active, "command": command, "you": you, "said": said, "feed": feed,
           "turns": turns, "day": today, "ts": now}
    try:
        os.makedirs(os.path.dirname(LIVE), exist_ok=True)
        fd, tmp = tempfile.mkstemp(dir=os.path.dirname(LIVE), prefix=".live-", suffix=".json")
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(out, f)
        os.replace(tmp, LIVE)
    except Exception:
        pass


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass
    sys.exit(0)
