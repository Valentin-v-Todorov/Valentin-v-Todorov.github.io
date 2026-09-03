#!/usr/bin/env bash
# flint-keeper.sh: the watchdog. flint-keeper.timer runs it every 2 minutes (stage 10 installs both).
#   - the stack died (a crash, a kill, a login without its autostart) -> starts it again in its window
#   - you stopped it yourself (Ctrl-C, "goodbye", flint-stack stop)   -> leaves it alone (~/.flint-setup/stack-off)
#   - the voice is up but the face server stopped answering twice in a row -> restarts the stack
#   - three restarts within 30 minutes -> gives up, says so once (notify-send + log), until: flint-stack start
#   - once a week: uv tool upgrade yt-dlp (YouTube changes; an old yt-dlp stops finding music)
# Log: ~/.local/state/flint/keeper.log
set -uo pipefail
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
SETUP="$HOME/.flint-setup"; STATE="${XDG_STATE_HOME:-$HOME/.local/state}/flint"; mkdir -p "$STATE"
LOG="$STATE/keeper.log"; log() { printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$LOG"; }
cfg() { sed -n "s/^$1=\"\{0,1\}\([^\"#]*\)\"\{0,1\}.*$/\1/p" "$SETUP/setup.env" 2>/dev/null | head -1; }
AH="$(cfg AGENT_HOME)"; AH="${AH:-$HOME/my-agent}"; AH="${AH/#\$HOME/$HOME}"
STACK="$AH/bin/flint-stack"; [ -x "$STACK" ] || STACK="$(command -v flint-stack || true)"
[ -n "$STACK" ] || exit 0

# weekly maintenance, whatever the stack is doing
if command -v uv >/dev/null 2>&1 && [ -x "$HOME/.local/bin/yt-dlp" ]; then
  m="$STATE/ytdlp-upgraded"
  if [ ! -f "$m" ] || [ "$(( $(date +%s) - $(stat -c %Y "$m") ))" -gt 604800 ]; then
    if timeout 180 uv tool upgrade yt-dlp >/dev/null 2>&1; then log "yt-dlp upgraded to $(yt-dlp --version 2>/dev/null)"; else log "yt-dlp upgrade failed (offline?)"; fi
    touch "$m"
  fi
fi

[ "$(cfg AUTOSTART_STACK)" = 0 ] && exit 0
[ -f "$SETUP/stack-off" ] && exit 0
[ -f "$STATE/keeper-gave-up" ] && exit 0
pgrep -x gnome-shell -u "$(id -u)" >/dev/null 2>&1 || exit 0     # no desktop session: nothing to keep yet
voice_up() { pgrep -f 'backtalk[.]main' >/dev/null 2>&1; }
face_up() { curl -fsS -m 3 -o /dev/null http://127.0.0.1:8790/state 2>/dev/null; }

reason=""
if ! voice_up; then
  reason="voice line down"
elif ! face_up; then
  n=$(( $(cat "$STATE/face-down" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$STATE/face-down"
  [ "$n" -ge 2 ] && reason="face server not answering ($n checks in a row)"
else
  rm -f "$STATE/face-down"
fi
[ -n "$reason" ] || exit 0

# the restart budget: three in thirty minutes, then a human
now=$(date +%s); b="$STATE/keeper-restarts"
if [ -f "$b" ]; then awk -v t="$now" '$1 > t-1800' "$b" > "$b.tmp" && mv "$b.tmp" "$b"; fi
count=0; [ -f "$b" ] && count=$(wc -l < "$b" | tr -d ' ')
if [ "$count" -ge 3 ]; then
  touch "$STATE/keeper-gave-up"
  log "gave up: $reason after $count restarts in 30 min; fix it, then: flint-stack start"
  notify-send "Flint" "The stack keeps dying ($reason). I stopped restarting it; run flint-stack start once it is fixed." 2>/dev/null || true
  exit 0
fi
echo "$now" >> "$b"; rm -f "$STATE/face-down"
log "restarting: $reason"
if voice_up; then "$STACK" stop >/dev/null 2>&1; rm -f "$SETUP/stack-off"; fi
if "$STACK" start >>"$LOG" 2>&1; then log "restarted"; else log "restart failed (see above)"; fi
