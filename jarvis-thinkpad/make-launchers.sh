#!/usr/bin/env bash
# make-launchers.sh: Linux desktop launchers for the Flint stack.
# The fullstack-agent wizard only knows macOS .command and Windows .bat files;
# this writes .desktop entries that open a visible terminal, with the PATH the
# launchers need (claude and uv live in ~/.local/bin, which a bare desktop
# session does not have).
#
#   ./make-launchers.sh                 # agent home ~/my-agent, name read from backtalk.json
#   ./make-launchers.sh ~/my-agent Flint
set -euo pipefail
HOME_DIR="${1:-$HOME/my-agent}"
HOME_DIR="$(cd "$HOME_DIR" 2>/dev/null && pwd)" || { echo "no such folder: ${1:-}" >&2; exit 1; }
NAME="${2:-}"
DESKTOP="$(xdg-user-dir DESKTOP 2>/dev/null || true)"; DESKTOP="${DESKTOP:-$HOME/Desktop}"
if [ ! -f "$HOME_DIR/CLAUDE.md" ]; then echo "no CLAUDE.md in $HOME_DIR; is Flint installed?" >&2; exit 1; fi
if [ -z "$NAME" ] && [ -f "$HOME_DIR/backtalk/backtalk.json" ]; then
  NAME="$(python3 -c "import json;print(json.load(open('$HOME_DIR/backtalk/backtalk.json')).get('name','Flint'))")"
fi
NAME="${NAME:-Flint}"
SLUG="$(printf '%s' "$NAME" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//; s/-*$//')"

mkdir -p "$HOME_DIR/bin" "$HOME/.local/share/applications" "$DESKTOP"

# One wrapper does the work; the .desktop files just pick a mode.
cat > "$HOME_DIR/bin/launch.sh" <<'WRAP'
#!/usr/bin/env bash
# launch.sh <chat|talk|hands|all|update>
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
for f in "$HOME"/.config/flint/*.env; do [ -f "$f" ] && { set -a; . "$f"; set +a; }; done   # secrets by name (chmod 600 files)
HERE="$(cd "$(dirname "$0")/.." && pwd)"
cd "$HERE"
OFF="$HOME/.flint-setup/stack-off"     # "stopped on purpose": the keeper leaves the stack down while this exists
stack() {                              # the wake-phrase hook must be in backtalk's venv before every start
  [ -x "$HERE/bin/voice-hook/install.sh" ] && "$HERE/bin/voice-hook/install.sh" "$HERE" -q || true
  rm -f "$OFF"
  ./fullstack-agent/start.sh "$@"; local rc=$?
  # a hang-up ("goodbye"), Ctrl-C or a clean exit was you; anything else is a crash the keeper may retry
  case "$rc" in 0|130) mkdir -p "$(dirname "$OFF")"; touch "$OFF" ;; esac
  return $rc
}
case "${1:-chat}" in
  chat)    exec claude ;;
  talk)    stack voice ;;
  hands)   stack hands ;;
  all)     stack ;;
  stop)    exec "$HERE/bin/flint-stack" stop ;;
  restart) exec "$HERE/bin/flint-stack" restart ;;
  update)  ./fullstack-agent/update.sh; echo; read -r -p "done. press Enter to close." _ ;;
  *) echo "usage: launch.sh chat|talk|hands|all|stop|restart|update" >&2; exit 1 ;;
esac
WRAP
chmod +x "$HOME_DIR/bin/launch.sh"

mk() { # mk <mode> <title> <comment> <icon>
  local f="$HOME/.local/share/applications/$SLUG-$1.desktop"
  cat > "$f" <<DESK
[Desktop Entry]
Type=Application
Name=$2
Comment=$3
Exec=$HOME_DIR/bin/launch.sh $1
Path=$HOME_DIR
Icon=$4
Terminal=true
Categories=Utility;
DESK
  cp "$f" "$DESKTOP/"
  chmod +x "$DESKTOP/$(basename "$f")"
  # GNOME marks desktop files untrusted until this metadata is set
  gio set "$DESKTOP/$(basename "$f")" metadata::trusted true 2>/dev/null || true
  echo "  $2  ->  $f"
}

echo "launchers for $NAME in $HOME_DIR:"
mk chat   "Chat with $NAME"   "Typed Claude Code session in the agent's home" utilities-terminal
mk talk   "Talk to $NAME"     "Voice + face (Ctrl-C in the window stops it)"  audio-input-microphone
mk all    "$NAME full stack"  "Voice + face + hands server"                     video-display
[ -d "$HOME_DIR/barehands" ] && mk hands "$NAME barehands" "Voice + hands board (open http://127.0.0.1:8794/stage.html in Chrome)" camera-web
mk update "Update $NAME"      "Pull the newest version of every piece"          system-software-update
mk stop   "Stop $NAME"        "Hang up the voice, close the face and hands; stays stopped until started again" process-stop
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
echo "done. Double-click one on the Desktop to test it (GNOME may ask once to trust it)."
