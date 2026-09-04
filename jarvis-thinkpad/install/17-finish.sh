#!/usr/bin/env bash
# 14: done. Print the map of what exists, then start the stack so the first hello happens.
. "$(dirname "$0")/lib.sh"

run() {
  rm -f "$HOME/.config/autostart/flint-setup-continue.desktop"
  if [ "$TIMESHIFT_SNAPSHOT" = 1 ] && has timeshift && [ ! -f "$STATE_DIR/.snapshot-done" ] && ! grep -q '✗' "$STATE_DIR/report.md" 2>/dev/null; then
    log "Timeshift snapshot of the working system (OS only, a few minutes)"
    local dev; dev="$(findmnt -no SOURCE / 2>/dev/null || true)"
    if timeout 1800 sudo timeshift --create --comments "flint installed" --tags D --snapshot-device "$dev" >"$LOG_DIR/timeshift.log" 2>&1; then touch "$STATE_DIR/.snapshot-done"; ok "snapshot taken (timeshift --list)"; else warn "snapshot skipped (see $LOG_DIR/timeshift.log); BTRFS/LVM layouts sometimes need the Timeshift GUI once"; fi
  fi
  [ "$REMOTE_CONTROL" = 1 ] && systemctl --user start flint-rc.service >/dev/null 2>&1 || true
  date -Is > "$STATE_DIR/DONE"
  log "$AGENT_NAME is installed"
  cat <<EOF
   Agent home      $AGENT_HOME            (cd there and run: claude      or the "Chat with $AGENT_NAME" launcher)
   Memory          $VAULT_DIR             (Obsidian opens straight into it)
   Voice           $( [ "$MIC_MODE" = open ] && printf 'say "%s, ..." and he answers; follow-ups within %ss need no name. Holding "%s" always works' "$AGENT_NAME" "$WAKE_WINDOW_S" "$PTT_KEY" || printf 'hold "%s", speak, release. "go hands free" switches to listening for his name' "$PTT_KEY")
   Music           "$AGENT_NAME, play Lose Yourself" / "play the album ..." / "stop the music"   (flint-play)
   His voice       flint-voice list | try af_heart | set af_heart   then: flint-stack restart
   Face            http://127.0.0.1:8790/faces/$FACE/   Z zooms into the team, Esc back, F fullscreen
   Hands           http://127.0.0.1:8794/stage.html   (Chrome, allow the camera)
   Start it        Desktop launcher "$AGENT_NAME full stack", or: flint-stack start   (it also starts at every login)
   Stop it         Ctrl-C in its window, "goodbye $AGENT_NAME", or: flint-stack stop  (then it stays stopped)
   Keeper          a dead stack is restarted within 2 minutes; log: ~/.local/state/flint/keeper.log
   Health          flint-health.sh (now) ; the nightly doctor at 03:30 repairs and writes "Doctor Log.md" in the vault
   Eyes and ears   "what's on my desk?" (camera), "read the screen" (OCR); the listener alerts on a doorbell, glass, a smoke alarm
   Presence        he greets you at the desk and pauses the music when you leave   (flint-presence enrol $YOUR_NAME if skipped)
   Timers          "$AGENT_NAME, timer ten minutes, the pasta"   flint-timer list
   Phone           Telegram: flint-telegram setup, then /start in the chat.   KDE Connect: flint-phone pair (accept on the phone)
   Mail, calendar  claude.ai > Settings > Connectors (Gmail, Google Calendar) ; local: flint-mail setup, flint-calendar setup
   Intercom        "$AGENT_NAME, tell the kitchen dinner is ready"   (flint-say --players lists the speakers)
   News, reading   "$AGENT_NAME, the news" ; drop a PDF or a link into $VAULT_DIR/Knowledge/Drop and he files a summary
   Guard, backups  flint-guard status ; flint-backup status  (THE BACKUP PASSWORD is in ~/.config/flint/backup.env: save it)
   Offline         when the cloud is out the keeper switches to the local model: timers, lights and music still work
   Phone           tmux attach -t flint  then press space for the QR (Remote Control)
   Team            $AGENT_HOME/team.yaml -> uv run bin/team-sync.py --agents ; timers: systemctl --user list-timers 'flint-*'
$( [ "$HOME_ASSISTANT" = 1 ] && printf '   Home Assistant  http://127.0.0.1:8123  login: see ~/.config/flint/ha.env ; expose entities to Assist so %s can control them\n' "$AGENT_NAME")
   Doctor          $GUIDE_DIR/setup.sh --check      report: $STATE_DIR/report.md
   Update          "Update $AGENT_NAME" launcher, or tell him "update everything and tell me what changed"

   Next, in a typed session in $AGENT_HOME, tell $AGENT_NAME:
     "read $GUIDE_DIR/04-full-power-agent.md, 05-home-automation.md and 07-agent-team.md, then finish what is
      not yet in the vault: your machine access note, remote access note, the team roster with my real departments."
EOF
  if [ "$AUTOSTART_STACK" = 1 ] && have_display; then
    if curl -fsS -m 2 -o /dev/null http://127.0.0.1:8790/state 2>/dev/null || pgrep -f 'backtalk[.]main' >/dev/null; then
      ok "the stack is already running (its own window)"
    else
      log "starting the stack (the face opens, $AGENT_NAME says hello)"
      gnome-terminal --title="$AGENT_NAME" -- bash -lc "$AGENT_HOME/bin/launch.sh all; echo; read -r -p 'stack stopped. press Enter to close.' _" >/dev/null 2>&1 &
      sleep 3
    fi
  fi
}

check() {
  chk "setup marked done" test -f "$STATE_DIR/DONE"
  [ "$AUTOSTART_STACK" = 1 ] && have_display && chk_warn "face server answering after the hello" wait_http http://127.0.0.1:8790/state 40
  checks_done
}
stage_main "$@"
