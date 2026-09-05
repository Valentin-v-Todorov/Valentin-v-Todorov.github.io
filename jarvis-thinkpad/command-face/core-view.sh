#!/usr/bin/env bash
# core-view.sh: the agent's own zoom control for the Core (and Command) face.
#   core-view.sh team            zoom into the team structure
#   core-view.sh team finance    zoom in and focus one department (its id from team.yaml)
#   core-view.sh voice           back to the voice sphere
# Writes faces/command/view.json; both faces poll it. Localhost only, nothing leaves the machine.
set -euo pipefail
HOME_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$HOME_DIR/ai-visualizer/faces/command/view.json"
VIEW="${1:-}"; FOCUS="${2:-}"
case "$VIEW" in team|voice) ;; *) echo "usage: core-view.sh team [department-id] | voice" >&2; exit 1 ;; esac
mkdir -p "$(dirname "$OUT")"
python3 - "$OUT" "$VIEW" "$FOCUS" <<'PY'
import json, sys, time, os, tempfile
out, view, focus = sys.argv[1:4]
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(out), prefix=".view-", suffix=".json")
with os.fdopen(fd, "w") as f:
    json.dump({"view": view, "focus": focus, "ts": time.time()}, f)
os.replace(tmp, out)
PY
echo "$VIEW${FOCUS:+ ($FOCUS)}"
