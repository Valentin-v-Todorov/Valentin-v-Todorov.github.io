#!/usr/bin/env bash
# install.sh: put the Command face into the running Jarvis stack. Idempotent.
#   ./install.sh                # agent home ~/my-agent
#   ./install.sh ~/my-agent     # explicit
# Does: copies the face into ai-visualizer/faces/command, the two helper scripts into
# ~/my-agent/bin, seeds ~/my-agent/team.yaml from the example if missing, generates
# team.json, wires the live hooks into ~/my-agent/.claude/settings.json (merged, never
# replaced), and makes "command" the default face in ai-visualizer.json (backup kept).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
HOME_DIR="${1:-$HOME/my-agent}"
VIS="$HOME_DIR/ai-visualizer"
export PATH="$HOME/.local/bin:$PATH"
[ -f "$HOME_DIR/CLAUDE.md" ] || { echo "no CLAUDE.md in $HOME_DIR: install Jarvis first (02-jarvis-install.md)" >&2; exit 1; }
[ -f "$VIS/server.py" ] || { echo "no ai-visualizer in $HOME_DIR: install the face piece first" >&2; exit 1; }

echo "== face"
mkdir -p "$VIS/faces/command"
cp "$HERE/face/index.html" "$HERE/face/face.json" "$VIS/faces/command/"
echo "   $VIS/faces/command/ (untracked by ai-visualizer's git, so update.sh leaves it alone)"

echo "== helpers"
mkdir -p "$HOME_DIR/bin"
cp "$HERE/team-sync.py" "$HERE/team-live.py" "$HOME_DIR/bin/"
chmod +x "$HOME_DIR/bin/team-sync.py" "$HOME_DIR/bin/team-live.py"

echo "== roster"
if [ ! -f "$HOME_DIR/team.yaml" ] && [ ! -f "$HOME_DIR/team.json" ]; then
  cp "$HERE/team.example.yaml" "$HOME_DIR/team.yaml"
  echo "   seeded $HOME_DIR/team.yaml from the example; edit it (or let Jarvis interview you) and re-run team-sync"
fi
if command -v uv >/dev/null 2>&1; then
  uv run --quiet "$HOME_DIR/bin/team-sync.py" --home "$HOME_DIR"
else
  python3 "$HOME_DIR/bin/team-sync.py" --home "$HOME_DIR"
fi

echo "== hooks (live activity on the graph)"
python3 - "$HOME_DIR" <<'PY'
import json, os, sys
home = sys.argv[1]
p = os.path.join(home, ".claude", "settings.json")
os.makedirs(os.path.dirname(p), exist_ok=True)
try:
    cfg = json.load(open(p))
except FileNotFoundError:
    cfg = {}
except ValueError as e:
    sys.exit(f"{p} is not valid JSON ({e}); fix it and re-run")
hooks = cfg.setdefault("hooks", {})
cmd = f"python3 {home}/bin/team-live.py"
added = []
for ev in ("SubagentStart", "SubagentStop", "UserPromptSubmit", "Stop"):
    entries = hooks.setdefault(ev, [])
    present = any("team-live.py" in str(h.get("command", "")) for e in entries for h in e.get("hooks", []))
    if not present:
        entries.append({"hooks": [{"type": "command", "command": cmd}]})
        added.append(ev)
if added:
    tmp = p + ".tmp"
    json.dump(cfg, open(tmp, "w"), indent=2)
    os.replace(tmp, p)
print("   hooks added:", ", ".join(added) if added else "none (already wired)")
PY

echo "== default face"
python3 - "$VIS" <<'PY'
import json, os, shutil, sys
vis = sys.argv[1]
p = os.path.join(vis, "ai-visualizer.json")
if not os.path.exists(p):
    shutil.copy(os.path.join(vis, "ai-visualizer.json.example"), p)
cfg = json.load(open(p))
if cfg.get("face") != "command":
    if not os.path.exists(p + ".bak"):
        shutil.copy(p, p + ".bak")
    cfg["face"] = "command"
    json.dump(cfg, open(p, "w"), indent=2)
    print("   ai-visualizer.json: face = command (previous copy in ai-visualizer.json.bak)")
else:
    print("   ai-visualizer.json already opens the command face")
PY

cat <<'NEXT'

done. Restart the stack (Ctrl-C, then ./fullstack-agent/start.sh) and the browser opens
http://127.0.0.1:8790/faces/command/  ->  the board full screen, the team on the right.
  T  focus team / voice     G  team full screen     Esc  back     H  hide the team pane
  R  reload the roster      wheel zoom, drag pan, click a lead to zoom into its department
Try it with no voice line:  cd ~/my-agent/ai-visualizer && ./run.sh --mock speaking
Create the agent files from the roster:  uv run ~/my-agent/bin/team-sync.py --agents
NEXT
