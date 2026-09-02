#!/usr/bin/env bash
# 14: done. Print the map of what exists, then start the stack so the first hello happens.
. "$(dirname "$0")/lib.sh"

run() {
  rm -f "$HOME/.config/autostart/flint-setup-continue.desktop"
  date -Is > "$STATE_DIR/DONE"
  log "$AGENT_NAME is installed"
  cat <<EOF
   Agent home      $AGENT_HOME            (cd there and run: claude      or the "Chat with $AGENT_NAME" launcher)
   Memory          $VAULT_DIR             (Obsidian opens straight into it)
   Voice           hold "$PTT_KEY", speak, release.  "go hands free" / "push to talk mode" switch the mic.
   Face            http://127.0.0.1:8790/faces/$FACE/   Z zooms into the team, Esc back, F fullscreen
   Hands           http://127.0.0.1:8794/stage.html   (Chrome, allow the camera)
   Start it        Desktop launcher "$AGENT_NAME full stack", or: $AGENT_HOME/bin/launch.sh all
   Stop it         Ctrl-C in its window
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
    log "starting the stack (the face opens, $AGENT_NAME says hello)"
    gnome-terminal --title="$AGENT_NAME" -- bash -lc "exec $AGENT_HOME/bin/launch.sh all" >/dev/null 2>&1 &
    sleep 3
  fi
}

check() {
  chk "setup marked done" test -f "$STATE_DIR/DONE"
  checks_done
}
stage_main "$@"
