#!/usr/bin/env bash
# 00: preflight. Is this the right machine, is it online, do we have sudo, what are the answers.
. "$(dirname "$0")/lib.sh"

run() {
  log "who and where"
  say "user: $USER   home: $HOME   guide: $GUIDE_DIR"
  say "answers: $ENV_FILE  (agent $AGENT_NAME for $YOUR_NAME, home $AGENT_HOME, vault $VAULT_DIR)"
  . /etc/os-release
  if [ "${ID:-}" != ubuntu ] || [ "${VERSION_ID:-}" != 24.04 ]; then
    warn "this is ${PRETTY_NAME:-unknown}; the guide was written and verified for Ubuntu 24.04 LTS. Continuing, but 24.04 is the supported path."
  else ok "$PRETTY_NAME"; fi
  [ "$(dpkg --print-architecture)" = amd64 ] || warn "architecture $(dpkg --print-architecture): Chrome and Claude Desktop have no build; the rest works"

  log "internet"
  curl -fsS -m 10 -o /dev/null https://api.github.com/ || die "no internet (https://api.github.com unreachable). Connect Wi-Fi and re-run."
  ok "online"

  log "disk, memory, power"
  local free_gb; free_gb="$(df -BG --output=avail "$HOME" | tail -1 | tr -dc '0-9')"
  [ "$free_gb" -ge 15 ] || die "only ${free_gb} GB free in $HOME; the stack needs about 15 GB (models, Docker, Chrome)."
  ok "${free_gb} GB free"
  local mem_gb; mem_gb="$(awk '/MemTotal/ {printf "%d", $2/1024/1024}' /proc/meminfo)"
  [ "$mem_gb" -ge 15 ] && ok "${mem_gb} GB RAM" || warn "${mem_gb} GB RAM: works, 16 GB is comfortable"
  if ls /sys/class/power_supply/ 2>/dev/null | grep -q '^AC\|^ADP\|^ACAD'; then
    local online; online="$(cat /sys/class/power_supply/A*/online 2>/dev/null | head -1 || echo 1)"
    [ "$online" = 1 ] && ok "on mains power" || warn "on battery: plug the charger in, this takes a while"
  fi

  log "sudo"
  sudo -v || die "sudo is needed (your login password)."
  if [ "$SUDO_NOPASSWD" = 1 ]; then
    local f="/etc/sudoers.d/90-flint-$USER"
    if ! sudo test -f "$f"; then
      printf '%s ALL=(ALL) NOPASSWD:ALL\n' "$USER" > /tmp/flint-sudoers
      sudo visudo -cf /tmp/flint-sudoers >/dev/null && sudo install -m 440 /tmp/flint-sudoers "$f"
      rm -f /tmp/flint-sudoers
      ok "passwordless sudo for $USER ($f). Remove it any time: sudo rm $f"
    else ok "passwordless sudo already set"; fi
  fi

  log "identity, time, name"
  if [ -n "$GIT_NAME" ] && [ "$(git config --global user.name || true)" != "$GIT_NAME" ]; then git config --global user.name "$GIT_NAME"; fi
  if [ -n "$GIT_EMAIL" ] && [ "$(git config --global user.email || true)" != "$GIT_EMAIL" ]; then git config --global user.email "$GIT_EMAIL"; fi
  git config --global init.defaultBranch main
  [ -n "$(git config --global user.email || true)" ] || warn "GIT_EMAIL is empty in setup.env: git will nag about identity; set it when you can"
  if [ -n "$TIMEZONE" ] && [ "$(timedatectl show -p Timezone --value)" != "$TIMEZONE" ]; then sudo timedatectl set-timezone "$TIMEZONE"; fi
  ok "timezone $(timedatectl show -p Timezone --value)"
  sudo timedatectl set-ntp true || true
  if [ -n "$HOSTNAME_WANTED" ] && [ "$(hostnamectl --static)" != "$HOSTNAME_WANTED" ]; then
    sudo hostnamectl set-hostname "$HOSTNAME_WANTED"
    grep -q "$HOSTNAME_WANTED" /etc/hosts || echo "127.0.1.1 $HOSTNAME_WANTED" | sudo tee -a /etc/hosts >/dev/null
  fi
  ok "hostname $(hostnamectl --static)"
  mkdir -p "$HOME/.config/flint" && chmod 700 "$HOME/.config/flint"
}

check() {
  chk "internet" curl -fsS -m 10 -o /dev/null https://api.github.com/
  chk "sudo works without a prompt" sudo -n true
  chk "git identity set" test -n "$(git config --global user.name || true)"
  chk "secrets folder ~/.config/flint (700)" test "$(stat -c %a "$HOME/.config/flint")" = 700
  checks_done
}
stage_main "$@"
