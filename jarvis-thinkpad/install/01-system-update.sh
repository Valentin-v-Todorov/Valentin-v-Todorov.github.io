#!/usr/bin/env bash
# 01: a fresh Ubuntu is weeks behind. Update everything, firmware included, once.
. "$(dirname "$0")/lib.sh"

run() {
  log "apt: update, full-upgrade, clean"
  sudo apt-get update -qq
  sudo apt-get -y -qq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" full-upgrade
  sudo apt-get -y -qq autoremove --purge
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
      sudo fwupdmgr update -y --no-reboot-check >/dev/null 2>&1 && mark_reboot "firmware update staged" || warn "fwupd could not apply everything; run 'sudo fwupdmgr update' later"
    else ok "firmware current"; fi
  fi

  [ -f /var/run/reboot-required ] && mark_reboot "kernel or core library upgraded" || true
}

check() {
  chk "no packages left to upgrade" bash -c 'test "$(apt-get -s upgrade 2>/dev/null | grep -c "^Inst ")" = 0'
  chk "unattended-upgrades installed" pkg_installed unattended-upgrades
  checks_done
}
stage_main "$@"
