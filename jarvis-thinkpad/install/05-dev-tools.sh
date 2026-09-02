#!/usr/bin/env bash
# 05: the tools the agent runs on: uv, Claude Code (+ sandbox), Node, Docker, GitHub CLI, groups.
. "$(dirname "$0")/lib.sh"

run() {
  log "uv (Python manager backtalk uses)"
  if ! has uv; then curl -LsSf https://astral.sh/uv/install.sh | sh >/dev/null 2>&1; fi
  ok "uv $(uv --version 2>/dev/null | awk '{print $2}')"
  local pyv; pyv="$(python3 -c 'import sys;print(f"{sys.version_info[0]}.{sys.version_info[1]}")')"
  case "$pyv" in 3.11|3.12) ;; *) uv python install 3.12 >/dev/null 2>&1 && ok "uv-managed python 3.12 for backtalk" || warn "uv could not fetch python 3.12; backtalk's install will try again" ;; esac

  log "Claude Code (native installer, auto-updates)"
  if ! has claude; then curl -fsSL https://claude.ai/install.sh | bash >/dev/null 2>&1; fi
  has claude || die "claude did not install; check $LOG_DIR and re-run"
  ok "claude $(claude --version 2>/dev/null | head -1)"

  log "Claude Code sandbox on Ubuntu 24.04 (bubblewrap + AppArmor profile)"
  if [ "$(sysctl -n kernel.apparmor_restrict_unprivileged_userns 2>/dev/null || echo 0)" = 1 ] && ! sudo test -f /etc/apparmor.d/bwrap; then
    sudo tee /etc/apparmor.d/bwrap >/dev/null <<'PROFILE'
abi <abi/4.0>,
include <tunables/global>

profile bwrap /usr/bin/bwrap flags=(unconfined) {
  userns,
  include if exists <local/bwrap>
}
PROFILE
    sudo systemctl reload apparmor >/dev/null 2>&1 || sudo apparmor_parser -r /etc/apparmor.d/bwrap || true
  fi
  ok "bwrap profile in place"

  log "Node.js 22 (Playwright MCP, npm-based MCP servers, the FounderOS demo)"
  if ! has node || [ "$(node -p 'process.versions.node.split(".")[0]')" -lt 20 ]; then
    curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - >/dev/null 2>&1
    apt_install nodejs
  fi
  ok "node $(node --version)"

  if [ "$GITHUB_CLI" = 1 ]; then
    log "GitHub CLI"
    if ! has gh; then
      sudo install -dm 755 /etc/apt/keyrings
      curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
      sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
      sudo apt-get update -qq && apt_install gh
    fi
    ok "gh $(gh --version | head -1 | awk '{print $3}')"
  fi

  if [ "$DOCKER" = 1 ]; then
    log "Docker Engine"
    if ! has docker; then curl -fsSL https://get.docker.com | sh >/dev/null 2>&1; fi
    sudo systemctl enable --now docker >/dev/null 2>&1
    if ! in_group docker; then sudo usermod -aG docker "$USER"; mark_reboot "docker group membership"; fi
    ok "docker $(docker --version | awk '{print $3}' | tr -d ,)"
  fi

  log "groups: input (PTT fallback), dialout (Zigbee/Z-Wave sticks), video (webcam), kvm (Claude Desktop Cowork)"
  for g in input dialout video kvm; do
    if getent group "$g" >/dev/null && ! in_group "$g"; then sudo usermod -aG "$g" "$USER"; mark_reboot "group $g"; fi
  done
  ok "group memberships set"

  log "tmux config (Remote Control lives in tmux)"
  [ -f "$HOME/.tmux.conf" ] || printf 'set -g mouse on\nset -g history-limit 50000\n' > "$HOME/.tmux.conf"
}

check() {
  chk "uv" has uv
  chk "claude" has claude
  chk "claude --version" claude --version
  chk "bwrap AppArmor profile (or not needed)" bash -c '[ "$(sysctl -n kernel.apparmor_restrict_unprivileged_userns 2>/dev/null || echo 0)" != 1 ] || sudo test -f /etc/apparmor.d/bwrap'
  chk "node >= 20" bash -c 'test "$(node -p "process.versions.node.split(\".\")[0]")" -ge 20'
  [ "$GITHUB_CLI" = 1 ] && chk "gh" has gh
  [ "$DOCKER" = 1 ] && chk "docker daemon active" systemctl is-active docker
  [ "$DOCKER" = 1 ] && chk_warn "docker group active in this shell (after re-login)" bash -c 'id -nG | tr " " "\n" | grep -qx docker'
  checks_done
}
stage_main "$@"
