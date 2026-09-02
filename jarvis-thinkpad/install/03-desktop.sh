#!/usr/bin/env bash
# 03: the desktop as a server. Xorg session (push-to-talk needs it), auto-login, never sleep,
# no screen lock, battery thresholds, dark theme for the face.
. "$(dirname "$0")/lib.sh"

run() {
  log "GDM: Ubuntu on Xorg, auto-login for $USER"
  local gdm=/etc/gdm3/custom.conf
  sudo mkdir -p /etc/gdm3
  sudo test -f "$gdm" || printf '[daemon]\n' | sudo tee "$gdm" >/dev/null
  sudo python3 - "$gdm" "$USER" <<'PY'
import re, sys
p, user = sys.argv[1], sys.argv[2]
s = open(p).read()
want = {"WaylandEnable": "false", "AutomaticLoginEnable": "true", "AutomaticLogin": user}
if "[daemon]" not in s:
    s = "[daemon]\n" + s
head, _, rest = s.partition("[daemon]")
# the daemon section runs until the next [section]
m = re.search(r"\n\[", rest)
daemon, tail = (rest[:m.start()], rest[m.start():]) if m else (rest, "")
lines = [l for l in daemon.split("\n") if not re.match(r"\s*#?\s*(WaylandEnable|AutomaticLoginEnable|AutomaticLogin)\s*=", l)]
body = "\n".join(lines).rstrip("\n")
body += "\n" + "\n".join(f"{k}={v}" for k, v in want.items()) + "\n"
open(p, "w").write(head + "[daemon]" + body + tail)
PY
  # the per-user session GDM remembers; both spellings, old and new AccountsService
  sudo mkdir -p /var/lib/AccountsService/users
  sudo python3 - "/var/lib/AccountsService/users/$USER" <<'PY'
import configparser, sys, os
p = sys.argv[1]
c = configparser.ConfigParser(); c.optionxform = str
if os.path.exists(p): c.read(p)
if "User" not in c: c["User"] = {}
c["User"]["Session"] = "ubuntu-xorg"
c["User"]["XSession"] = "ubuntu-xorg"
c["User"]["SystemAccount"] = "false"
with open(p, "w") as f: c.write(f, space_around_delimiters=False)
PY
  ok "custom.conf: WaylandEnable=false, AutomaticLogin=$USER; session ubuntu-xorg"
  session_is_x11 || mark_reboot "switch to the Xorg session"

  log "never sleep (lid, idle, power button)"
  sudo mkdir -p /etc/systemd/logind.conf.d
  sudo tee /etc/systemd/logind.conf.d/flint-server.conf >/dev/null <<'CONF'
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
HandlePowerKey=ignore
IdleAction=ignore
CONF
  sudo mkdir -p /etc/systemd/sleep.conf.d
  sudo tee /etc/systemd/sleep.conf.d/flint-server.conf >/dev/null <<'CONF'
[Sleep]
AllowSuspend=no
AllowHibernation=no
AllowHybridSleep=no
AllowSuspendThenHibernate=no
CONF
  sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target >/dev/null 2>&1 || true
  # logind picks the drop-in up on its next start; restarting it now can end this session
  ok "logind: lid and idle ignored; suspend masked (applies fully after the reboot)"

  log "GNOME: no idle sleep, no screen lock, no blanking, dark, for every login"
  sudo mkdir -p /etc/dconf/profile /etc/dconf/db/local.d
  printf 'user-db:user\nsystem-db:local\n' | sudo tee /etc/dconf/profile/user >/dev/null
  sudo tee /etc/dconf/db/local.d/00-flint-server >/dev/null <<'CONF'
[org/gnome/settings-daemon/plugins/power]
sleep-inactive-ac-type='nothing'
sleep-inactive-battery-type='nothing'
idle-dim=false
power-button-action='nothing'

[org/gnome/desktop/session]
idle-delay=uint32 0

[org/gnome/desktop/screensaver]
lock-enabled=false
idle-activation-enabled=false

[org/gnome/desktop/lockdown]
disable-lock-screen=true

[org/gnome/desktop/interface]
color-scheme='prefer-dark'

[org/gnome/desktop/notifications]
show-in-lock-screen=false
CONF
  sudo dconf update
  if have_display; then
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing' || true
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing' || true
    gsettings set org.gnome.desktop.session idle-delay 0 || true
    gsettings set org.gnome.desktop.screensaver lock-enabled false || true
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' || true
    xset s off -dpms 2>/dev/null || true
  fi
  ok "dconf system defaults written (and applied to this session)"

  log "battery: charge thresholds 75-80 %, TLP"
  sudo mkdir -p /etc/tlp.d
  sudo tee /etc/tlp.d/01-flint-server.conf >/dev/null <<'CONF'
START_CHARGE_THRESH_BAT0=75
STOP_CHARGE_THRESH_BAT0=80
CPU_ENERGY_PERF_POLICY_ON_AC=balance_performance
CPU_ENERGY_PERF_POLICY_ON_BAT=balance_power
USB_AUTOSUSPEND=0
CONF
  sudo systemctl enable --now tlp >/dev/null 2>&1 || true
  sudo tlp start >/dev/null 2>&1 || true
  ok "TLP on (thresholds apply on ThinkPads with the thinkpad_acpi driver)"

  log "sound: no login/logout jingles, a sane default volume"
  if have_display; then
    pactl set-sink-volume @DEFAULT_SINK@ 70% 2>/dev/null || true
    pactl set-sink-mute @DEFAULT_SINK@ 0 2>/dev/null || true
    pactl set-source-mute @DEFAULT_SOURCE@ 0 2>/dev/null || true
  fi
  ok "speaker 70 %, mic unmuted"
}

check() {
  chk "GDM WaylandEnable=false" bash -c "sudo grep -Eq '^WaylandEnable=false' /etc/gdm3/custom.conf"
  chk "GDM auto-login for $USER" bash -c "sudo grep -Eq '^AutomaticLogin=$USER' /etc/gdm3/custom.conf && sudo grep -Eq '^AutomaticLoginEnable=true' /etc/gdm3/custom.conf"
  chk "logind lid/idle drop-in" test -f /etc/systemd/logind.conf.d/flint-server.conf
  chk "dconf defaults compiled" test -f /etc/dconf/db/local
  chk "TLP threshold config" test -f /etc/tlp.d/01-flint-server.conf
  chk_warn "this session is X11 (after the reboot it will be)" session_is_x11
  checks_done
}
stage_main "$@"
