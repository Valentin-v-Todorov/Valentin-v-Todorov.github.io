#!/usr/bin/env bash
# 15: guard duty, backups, the offline brain. fail2ban and the LAN watch with alerts; restic backups nightly
# with a monthly restore test; Ollama with a small model so timers, lights and music keep working by voice
# when the internet or the Claude plan is out (the keeper switches over and back).
. "$(dirname "$0")/lib.sh"

run() {
  [ -f "$AGENT_HOME/CLAUDE.md" ] || die "no agent in $AGENT_HOME (stage 09 first)"
  mkdir -p "$HOME/.config/systemd/user" "$HOME/.local/bin"
  cp "$GUIDE_DIR"/bin/flint-* "$AGENT_HOME/bin/" && chmod +x "$AGENT_HOME"/bin/flint-*
  for t in "$GUIDE_DIR"/bin/flint-*; do ln -sfn "$AGENT_HOME/bin/$(basename "$t")" "$HOME/.local/bin/$(basename "$t")"; done

  if [ "$GUARD" = 1 ]; then
    log "guard duty: fail2ban on SSH, arp-scan for the LAN, a pass every two minutes"
    apt_install fail2ban arp-scan
    sudo tee /etc/fail2ban/jail.d/flint-sshd.conf >/dev/null <<'CONF'
[sshd]
enabled = true
backend = systemd
maxretry = 5
findtime = 10m
bantime = 1h
CONF
    sudo systemctl enable --now fail2ban >/dev/null 2>&1 && ok "fail2ban watching sshd (5 tries in 10 min = banned an hour)" || warn "fail2ban did not start"
    cat > "$HOME/.config/systemd/user/flint-guard.service" <<EOF
[Unit]
Description=$AGENT_NAME guard pass
[Service]
Type=oneshot
Environment=PATH=%h/.local/bin:/usr/local/bin:/usr/sbin:/sbin:/usr/bin:/bin
ExecStart=$AGENT_HOME/bin/flint-guard check
EOF
    cat > "$HOME/.config/systemd/user/flint-guard.timer" <<'EOF'
[Unit]
Description=Guard duty, every two minutes
[Timer]
OnStartupSec=2min
OnUnitActiveSec=2min
[Install]
WantedBy=timers.target
EOF
    systemctl --user daemon-reload 2>/dev/null; systemctl --user enable --now flint-guard.timer >/dev/null 2>&1 && ok "flint-guard.timer active" || warn "could not enable flint-guard.timer"
    "$AGENT_HOME/bin/flint-guard" check >/dev/null 2>&1 && ok "first pass done: $(python3 -c "import json; d=json.load(open('$HOME/.local/state/flint/lan-devices.json')); print(len([k for k in d if not k.startswith('_')]))" 2>/dev/null || echo 0) devices on the LAN learned (the first hour is learning, no alerts)"
  fi

  if [ "$BACKUP" = 1 ]; then
    log "backups: restic, encrypted, nightly at 02:30, a restore test on the first of the month"
    apt_install restic
    if [ ! -f "$HOME/.config/flint/backup.env" ] || ! grep -q '^BACKUP_REPO=' "$HOME/.config/flint/backup.env"; then
      "$AGENT_HOME/bin/flint-backup" setup "$BACKUP_REPO" </dev/null 2>&1 | tee "$LOG_DIR/backup-setup.log" | sed 's/^/   /'
      warn "the backup password is in ~/.config/flint/backup.env and in $LOG_DIR/backup-setup.log: copy it to your password manager now"
    else ok "repository already set up: $(grep '^BACKUP_REPO=' "$HOME/.config/flint/backup.env" | cut -d= -f2-)"; fi
    cat > "$HOME/.config/systemd/user/flint-backup.service" <<EOF
[Unit]
Description=$AGENT_NAME nightly backup
[Service]
Type=oneshot
Environment=PATH=%h/.local/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=$AGENT_HOME/bin/flint-backup run
EOF
    cat > "$HOME/.config/systemd/user/flint-backup.timer" <<'EOF'
[Unit]
Description=Backup, nightly
[Timer]
OnCalendar=*-*-* 02:30
Persistent=true
RandomizedDelaySec=10m
[Install]
WantedBy=timers.target
EOF
    cat > "$HOME/.config/systemd/user/flint-backup-check.service" <<EOF
[Unit]
Description=$AGENT_NAME backup restore test
[Service]
Type=oneshot
Environment=PATH=%h/.local/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=$AGENT_HOME/bin/flint-backup check
EOF
    cat > "$HOME/.config/systemd/user/flint-backup-check.timer" <<'EOF'
[Unit]
Description=Backup restore test, monthly
[Timer]
OnCalendar=*-*-01 04:00
Persistent=true
[Install]
WantedBy=timers.target
EOF
    systemctl --user daemon-reload 2>/dev/null; systemctl --user enable --now flint-backup.timer flint-backup-check.timer >/dev/null 2>&1 && ok "backup timers active" || warn "could not enable the backup timers"
    if [ ! -f "$STATE_DIR/.first-backup" ]; then
      log "the first backup (in the background if it takes longer than ten minutes)"
      if timeout 600 "$AGENT_HOME/bin/flint-backup" run >"$LOG_DIR/backup-first.log" 2>&1; then touch "$STATE_DIR/.first-backup"; ok "first backup done"
      else warn "still running or failed ($LOG_DIR/backup-first.log); the nightly timer finishes it"; fi
    fi
  fi

  if [ "$OFFLINE" = 1 ]; then
    log "the offline brain: Ollama + $OFFLINE_MODEL (a few gigabytes, once)"
    if ! has ollama; then curl -fsSL https://ollama.com/install.sh | sh >"$LOG_DIR/ollama-install.log" 2>&1 || warn "Ollama installer failed ($LOG_DIR/ollama-install.log)"; fi
    if has ollama; then
      sudo systemctl enable --now ollama >/dev/null 2>&1 || true
      wait_http http://127.0.0.1:11434/api/tags 60 && ok "ollama up" || warn "ollama not answering on 11434"
      if ! curl -fsS -m 5 http://127.0.0.1:11434/api/tags 2>/dev/null | grep -q "\"${OFFLINE_MODEL%%:*}"; then
        timeout 3600 ollama pull "$OFFLINE_MODEL" >"$LOG_DIR/ollama-pull.log" 2>&1 && ok "$OFFLINE_MODEL pulled" || warn "model pull failed or timed out ($LOG_DIR/ollama-pull.log); later: flint-offline pull"
      else ok "$OFFLINE_MODEL present"; fi
    fi
    cat > "$HOME/.config/systemd/user/flint-offline.service" <<EOF
[Unit]
Description=$AGENT_NAME offline voice loop (started by the keeper when the brain is unreachable)
[Service]
Environment=PATH=%h/.local/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=$AGENT_HOME/bin/flint-offline serve
Restart=on-failure
RestartSec=20
EOF
    systemctl --user daemon-reload 2>/dev/null || true
    ok "flint-offline.service written (the keeper starts it when the cloud is out, stops it when it is back)"
  fi

  append_once "$AGENT_HOME/CLAUDE.md" "## Guard, backups, offline" <<EOF
## Guard, backups, offline
- Guard: \`flint-guard status\` (SSH logins, fail2ban bans, new devices on the wifi, motion while away; the timer alerts
  by itself), \`flint-guard devices\`, \`flint-guard name <mac> "..."\` when $YOUR_NAME tells you what a device is.
- Backups: \`flint-backup status|snapshots\`; \`flint-backup restore <path>\` brings a file or folder back into ~/Restored.
  The nightly run and the monthly restore test report failures through flint-notify; mention them in the morning brief.
  Never print the backup password.
- Offline: when the cloud is out, the keeper runs \`flint-offline serve\` (a small local model) so timers, lights and music
  still work by voice; \`flint-offline status\` says whether it is ready. \`flint-ha on|off|set "<name>"\` controls Home Assistant
  from the shell, online or not.
EOF
  ok "CLAUDE.md: guard, backups, offline"
}

check() {
  [ "$GUARD" = 1 ] && chk "fail2ban active" systemctl is-active fail2ban
  [ "$GUARD" = 1 ] && chk "arp-scan installed" has arp-scan
  [ "$GUARD" = 1 ] && chk "guard timer active" systemctl --user is-active flint-guard.timer
  [ "$BACKUP" = 1 ] && chk "restic installed" has restic
  [ "$BACKUP" = 1 ] && chk "backup repository reachable" bash -c "'$AGENT_HOME/bin/flint-backup' status | grep -q 'last snapshot'"
  [ "$BACKUP" = 1 ] && chk "backup timers active" bash -c "systemctl --user is-active flint-backup.timer && systemctl --user is-active flint-backup-check.timer"
  [ "$BACKUP" = 1 ] && chk_warn "a snapshot exists" bash -c "'$AGENT_HOME/bin/flint-backup' snapshots | grep -qE '^[0-9a-f]{8} '"
  [ "$OFFLINE" = 1 ] && chk_warn "ollama up with $OFFLINE_MODEL" bash -c "'$AGENT_HOME/bin/flint-offline' status"
  [ "$OFFLINE" = 1 ] && chk "flint-offline.service written" test -f "$HOME/.config/systemd/user/flint-offline.service"
  chk "CLAUDE.md has the guard/backup/offline section" grep -q "flint-guard status" "$AGENT_HOME/CLAUDE.md"
  checks_done
}
stage_main "$@"
