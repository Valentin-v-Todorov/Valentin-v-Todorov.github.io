#!/usr/bin/env bash
# 04: reach the ThinkPad from anywhere. SSH on the LAN now, Tailscale from everywhere,
# a firewall that allows only what the guide opens.
. "$(dirname "$0")/lib.sh"

run() {
  log "SSH server"
  sudo systemctl enable --now ssh >/dev/null 2>&1 || sudo systemctl enable --now sshd
  sudo tee /etc/ssh/sshd_config.d/10-flint.conf >/dev/null <<'CONF'
# keys and Tailscale SSH are the way in; password logins stay on until a key is installed
PermitRootLogin no
X11Forwarding no
ClientAliveInterval 60
CONF
  sudo systemctl reload ssh 2>/dev/null || sudo systemctl reload sshd 2>/dev/null || true
  mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
  [ -f "$HOME/.ssh/id_ed25519" ] || ssh-keygen -q -t ed25519 -N "" -C "$USER@$(hostname)" -f "$HOME/.ssh/id_ed25519"
  ok "sshd on; your key: $HOME/.ssh/id_ed25519.pub (add it to GitHub if you want git over ssh)"

  if [ "$UFW" = 1 ]; then
    log "firewall"
    sudo ufw default deny incoming >/dev/null
    sudo ufw default allow outgoing >/dev/null
    sudo ufw allow OpenSSH >/dev/null
    sudo ufw allow 5353/udp >/dev/null            # mDNS (thinkpad.local)
    [ "$HOME_ASSISTANT" = 1 ] && sudo ufw allow 8123/tcp >/dev/null
    sudo ufw --force enable >/dev/null
    ok "ufw on: SSH$( [ "$HOME_ASSISTANT" = 1 ] && printf ', 8123' ) allowed; the agent's servers bind to localhost"
  fi

  if [ "$TAILSCALE" = 1 ]; then
    log "Tailscale"
    if ! has tailscale; then curl -fsSL https://tailscale.com/install.sh | sh >/dev/null 2>&1; fi
    sudo systemctl enable --now tailscaled >/dev/null 2>&1 || true
    if tailscale status >/dev/null 2>&1; then
      ok "already connected: $(tailscale ip -4 2>/dev/null | head -1)"
    elif [ -n "$TS_AUTHKEY" ]; then
      sudo tailscale up --ssh --auth-key="$TS_AUTHKEY" --hostname="$HOSTNAME_WANTED" && ok "connected with the auth key"
    else
      warn "One-time login: a link (and a QR code) follows. Open it on any device where you are logged into Tailscale."
      warn "This waits up to 5 minutes; if you skip it, run later:  sudo tailscale up --ssh"
      timeout 300 sudo tailscale up --ssh --qr --hostname="$HOSTNAME_WANTED" 2>&1 | tee "$LOG_DIR/tailscale-login.txt" || \
      timeout 300 sudo tailscale up --ssh --hostname="$HOSTNAME_WANTED" 2>&1 | tee -a "$LOG_DIR/tailscale-login.txt" || \
      warn "not connected yet (run: sudo tailscale up --ssh)"
    fi
    tailscale status >/dev/null 2>&1 && ok "Tailscale: $(tailscale ip -4 2>/dev/null | head -1)  ssh $USER@$(hostname) works from any of your devices"
  fi
}

check() {
  chk "sshd active" systemctl is-active ssh
  chk "ssh key exists" test -f "$HOME/.ssh/id_ed25519.pub"
  [ "$UFW" = 1 ] && chk "ufw active" bash -c "sudo ufw status | grep -q 'Status: active'"
  [ "$TAILSCALE" = 1 ] && chk_warn "Tailscale connected (finish with: sudo tailscale up --ssh)" tailscale status
  checks_done
}
stage_main "$@"
