#!/usr/bin/env bash
# 08: the one reboot. New groups, the Xorg session, a staged firmware update and a new
# kernel all want it. setup.sh continues by itself after the auto-login.
. "$(dirname "$0")/lib.sh"

run() {
  local need=0
  reboot_needed && need=1
  session_is_x11 || need=1
  [ "$DOCKER" = 1 ] && ! id -nG | tr ' ' '\n' | grep -qx docker && need=1
  if [ "$need" = 0 ]; then ok "no reboot needed (already X11, groups active)"; return 0; fi

  log "reboot needed for: $(tr '\n' ',' < "$STATE_DIR/reboot-needed" 2>/dev/null | sed 's/,$//')$(session_is_x11 || printf ' Xorg session')"
  mkdir -p "$HOME/.config/autostart"
  cat > "$HOME/.config/autostart/flint-setup-continue.desktop" <<DESK
[Desktop Entry]
Type=Application
Name=Flint setup (continues after reboot)
Exec=gnome-terminal --title="Flint setup" -- bash -lc "sleep 8; '$GUIDE_DIR/setup.sh' --continue; echo; read -r -p 'setup finished. press Enter to close.' _"
X-GNOME-Autostart-enabled=true
NoDisplay=false
DESK
  rm -f "$STATE_DIR/reboot-needed"
  touch "$DONE_DIR/$(basename "$0")"
  touch "$STATE_DIR/stop"
  warn "Rebooting in 20 seconds. After the automatic login a terminal opens and the setup continues on its own."
  warn "Ctrl-C now to reboot later by hand (then just log in; the setup continues by itself)."
  sleep 20
  sudo systemctl reboot
}

check() {
  chk_warn "X11 session" session_is_x11
  return 0
}
stage_main "$@"
