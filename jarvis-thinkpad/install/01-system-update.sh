#!/usr/bin/env bash
# 01: a fresh Ubuntu is weeks behind. Update everything, firmware included, once.
. "$(dirname "$0")/lib.sh"

run() {
  log "apt: update, full-upgrade, clean"
  aptget update -qq
  aptget -y -qq full-upgrade
  aptget -y -qq autoremove --purge
  touch "$STATE_DIR/.apt-updated"
  ok "packages current"

  log "security updates stay automatic"
  apt_install unattended-upgrades
  sudo tee /etc/apt/apt.conf.d/20auto-upgrades >/dev/null <<'CONF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
CONF
  ok "unattended-upgrades on (security pocket)"

  if [ "$FIRMWARE_UPDATE" = 1 ] && has fwupdmgr; then
    log "firmware (Lenovo LVFS via fwupd)"
    sudo fwupdmgr refresh --force >/dev/null 2>&1 || true
    # exit 2 means "nothing to do"; anything else is reported and not fatal
    if sudo fwupdmgr get-updates >/dev/null 2>&1; then
      say "updates available; applying (the machine may ask to reboot to flash)"
      sudo fwupdmgr update -y --no-reboot-check --no-unreported-check --no-metadata-check >"$LOG_DIR/fwupd.log" 2>&1 && mark_reboot "firmware update staged" || warn "fwupd could not apply everything ($LOG_DIR/fwupd.log); run 'sudo fwupdmgr update' later"
    else ok "firmware current"; fi
  fi

  [ -f /var/run/reboot-required ] && mark_reboot "kernel or core library upgraded" || true
}

check() {
  chk "the update ran" test -f "$STATE_DIR/.apt-updated"
  chk "unattended-upgrades installed and on" bash -c 'dpkg-query -W unattended-upgrades >/dev/null && grep -q "Unattended-Upgrade \"1\"" /etc/apt/apt.conf.d/20auto-upgrades'
  chk_warn "nothing new to upgrade right now" bash -c 'test "$(apt-get -s upgrade 2>/dev/null | grep -c "^Inst ")" = 0'
  checks_done
}
stage_main "$@"
