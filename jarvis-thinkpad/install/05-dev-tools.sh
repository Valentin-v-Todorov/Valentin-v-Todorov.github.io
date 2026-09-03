#!/usr/bin/env bash
# 05: the tools the agent runs on: uv, Claude Code (+ sandbox), Node, Docker, GitHub CLI, groups.
. "$(dirname "$0")/lib.sh"

run() {
  log "uv (Python manager backtalk uses)"
  if ! has uv; then curl -LsSf https://astral.sh/uv/install.sh | sh >"$LOG_DIR/uv-install.log" 2>&1 || die "uv installer failed: $LOG_DIR/uv-install.log"; fi
  ok "uv $(uv --version 2>/dev/null | awk '{print $2}')"
  local pyv; pyv="$(python3 -c 'import sys;print(f"{sys.version_info[0]}.{sys.version_info[1]}")')"
  case "$pyv" in 3.11|3.12) ;; *) uv python install 3.12 >/dev/null 2>&1 && ok "uv-managed python 3.12 for backtalk" || warn "uv could not fetch python 3.12; backtalk's install will try again" ;; esac

  if [ "$MUSIC" = 1 ]; then
    log "yt-dlp (music search for flint-play; the apt version is too old for YouTube, uv keeps this one current)"
    if [ -x "$HOME/.local/bin/yt-dlp" ]; then uv tool upgrade yt-dlp >/dev/null 2>&1 || true; else uv tool install yt-dlp >"$LOG_DIR/yt-dlp-install.log" 2>&1 || warn "uv tool install yt-dlp failed ($LOG_DIR/yt-dlp-install.log); the keeper retries weekly"; fi
    has yt-dlp && ok "yt-dlp $(yt-dlp --version 2>/dev/null)"
  fi

  log "Claude Code (native installer, auto-updates)"
  if ! has claude; then curl -fsSL https://claude.ai/install.sh | bash >"$LOG_DIR/claude-install.log" 2>&1 || die "Claude Code installer failed: $LOG_DIR/claude-install.log"; fi
  has claude || die "claude did not install; see $LOG_DIR/claude-install.log and re-run"
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
    sudo systemctl reload apparmor >/dev/null 2>&1 || sudo apparmor_parser -r /etc/apparmor.d/bwrap || warn "could not load the bwrap profile; the check below tells"
  fi
  ok "bwrap profile in place"

  log "Node.js 22 (Playwright MCP, npm-based MCP servers, the FounderOS demo)"
  if ! has node || [ "$(node -p 'process.versions.node.split(".")[0]')" -lt 20 ]; then
    curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - >"$LOG_DIR/nodesource.log" 2>&1 || die "NodeSource setup failed: $LOG_DIR/nodesource.log"
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
      aptget update -qq && apt_install gh
    fi
    ok "gh $(gh --version | head -1 | awk '{print $3}')"
  fi

  if [ "$DOCKER" = 1 ]; then
    log "Docker Engine"
    if ! has docker; then curl -fsSL https://get.docker.com | sh >"$LOG_DIR/docker-install.log" 2>&1 || die "Docker installer failed: $LOG_DIR/docker-install.log"; fi
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
  [ "$MUSIC" = 1 ] && chk "yt-dlp (music search)" has yt-dlp
  chk "claude" has claude
  chk "claude --version" claude --version
  chk "bwrap can sandbox (Claude Code sandbox works)" bwrap --ro-bind / / --unshare-user --unshare-pid true
  chk "node >= 20" bash -c 'test "$(node -p "process.versions.node.split(\".\")[0]")" -ge 20'
  [ "$GITHUB_CLI" = 1 ] && chk "gh" has gh
  [ "$DOCKER" = 1 ] && chk "docker daemon active" systemctl is-active docker
  [ "$DOCKER" = 1 ] && chk_warn "docker group active in this shell (after re-login)" bash -c 'id -nG | tr " " "\n" | grep -qx docker'
  checks_done
}
stage_main "$@"
