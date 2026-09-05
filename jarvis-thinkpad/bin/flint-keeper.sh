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

# --- the cloud: no internet, or the brain refusing (plan out of usage) -> the offline loop instead of restart loops
if [ "$(cfg OFFLINE)" != 0 ] && [ -f "$HOME/.config/systemd/user/flint-offline.service" ]; then
  cloud=0; [ -n "$(curl -sS -m 6 -o /dev/null -w '%{http_code}' https://api.anthropic.com/ 2>/dev/null)" ] && cloud=1
  brain_down=0; bl="$AH/backtalk/logs/backtalk.log"
  if [ -f "$bl" ] && [ "$(( $(date +%s) - $(stat -c %Y "$bl") ))" -lt 600 ] && tail -40 "$bl" | grep -q "BRAIN CONNECT"; then brain_down=1; fi
  offline_active=0; [ "$(systemctl --user is-active flint-offline.service 2>/dev/null)" = active ] && offline_active=1
  if [ "$cloud" = 0 ] || { [ "$brain_down" = 1 ] && ! voice_up; }; then
    if [ "$offline_active" = 0 ] && ! voice_up; then
      systemctl --user start flint-offline.service 2>/dev/null && log "cloud unreachable (internet $cloud, brain down $brain_down): offline mode started"
    fi
    exit 0                                         # do not burn the restart budget while the cloud is out
  elif [ "$offline_active" = 1 ]; then
    systemctl --user stop flint-offline.service 2>/dev/null; rm -f "$STATE/keeper-restarts"; log "cloud back: offline mode stopped"
  fi
fi

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
