#!/usr/bin/env bash
# 10: wire the agent into the machine: launchers, the Orbitals face, the hooks, the
# permission profile, the sandbox, MCP servers, the vault's git safety net, Remote Control,
# and the stack starting at login.
. "$(dirname "$0")/lib.sh"

append_once() {  # append_once file marker-heading <<content on stdin
  local f="$1" marker="$2" body; body="$(cat)"
  grep -qF "$marker" "$f" 2>/dev/null || printf '\n%s\n' "$body" >> "$f"
}

run() {
  [ -f "$AGENT_HOME/CLAUDE.md" ] || die "no agent in $AGENT_HOME (stage 09 first)"

  log "launchers (.desktop) and bin/launch.sh"
  "$GUIDE_DIR/make-launchers.sh" "$AGENT_HOME" "$AGENT_NAME" >/dev/null && ok "launchers on the Desktop and in the app grid"

  log "the Orbitals face, the roster, the live hooks"
  "$GUIDE_DIR/command-face/install.sh" "$AGENT_HOME" "--default=$FACE" >"$LOG_DIR/command-face-install.log" 2>&1 && ok "faces core + command installed; default $FACE; hooks wired" || { cat "$LOG_DIR/command-face-install.log"; die "command-face/install.sh failed"; }

  log "what the agent knows about this machine (CLAUDE.md additions)"
  append_once "$AGENT_HOME/CLAUDE.md" "## Showing the team on screen" <<EOF
## Showing the team on screen
The face on the visualizer can zoom into the agent team. When $YOUR_NAME asks to see the
team, the structure, who is working, or one department, run
\`$AGENT_HOME/bin/core-view.sh team [department-id]\` (ids from team.yaml: comms, finance,
content, knowledge, automations) and then answer. When the conversation moves on, run
\`$AGENT_HOME/bin/core-view.sh voice\`. Say what you put on screen in one short sentence.
EOF
  append_once "$AGENT_HOME/CLAUDE.md" "## Machine control toolbox" <<'EOF'
## Machine control toolbox (Ubuntu, X11 session)
- Launch apps: `gio launch /usr/share/applications/<app>.desktop`, `xdg-open <file-or-url>`, `google-chrome <url>`.
- Windows: `wmctrl -l` lists, `wmctrl -a "<title>"` focuses, `xdotool search --name "<title>" windowactivate`.
- Keystrokes and clicks: `xdotool key ctrl+s`, `xdotool type "text"`, `xdotool mousemove X Y click 1`.
- Media: `playerctl play-pause|next|previous`, `playerctl -l` lists players; `pactl set-sink-volume @DEFAULT_SINK@ 50%`.
- Screen: `gnome-screenshot -f /tmp/shot.png` then read the image to see the screen.
- Notifications: `notify-send "Flint" "message"`.
- Clipboard: `xclip -selection clipboard` (read with `-o`).
- Power: `systemctl suspend` is blocked by the no-sleep config on purpose; reboot only when asked.
- Services: `systemctl --user status`, `systemctl status <unit>`, `docker ps`. sudo works without a password on this box; use it for apt, systemctl and docker only.
- Secrets live in ~/.config/flint/*.env (chmod 600) and are loaded into the environment; refer to them by variable name, never print or copy them into notes.
- The barehands board (`bin/board.sh`) is for showing things; xdotool is for doing things.
EOF
  ok "CLAUDE.md: team on screen, machine toolbox"

  log "Claude Code permission profile (user settings: auto mode, deny list, vault access, sandbox)"
  python3 - "$HOME/.claude/settings.json" "$VAULT_DIR" <<'PY'
import json, os, sys
p, vault = sys.argv[1], sys.argv[2]
os.makedirs(os.path.dirname(p), exist_ok=True)
try: cfg = json.load(open(p))
except Exception: cfg = {}
perm = cfg.setdefault("permissions", {})
perm.setdefault("defaultMode", "auto")
deny = perm.setdefault("deny", [])
for d in ["Bash(rm -rf /*)", "Bash(rm -rf ~*)", "Bash(rm -rf /home/*)", "Bash(sudo rm *)", "Bash(mkfs*)", "Bash(dd if=*)",
          "Bash(shutdown*)", "Bash(systemctl poweroff*)", "Bash(git push --force*)", "Read(~/.config/flint/**)", "Read(~/.ssh/id_*)"]:
    if d not in deny: deny.append(d)
add = perm.setdefault("additionalDirectories", [])
if vault not in add: add.append(vault)
cfg.setdefault("sandbox", {"enabled": True, "autoAllowBashIfSandboxed": True})
tmp = p + ".tmp"; json.dump(cfg, open(tmp, "w"), indent=2); os.replace(tmp, p)
print("   ~/.claude/settings.json: defaultMode auto, deny list, vault in additionalDirectories, sandbox on")
PY
  python3 - "$AGENT_HOME/.claude/settings.json" "$VAULT_DIR" <<'PY'
import json, os, sys
p, vault = sys.argv[1], sys.argv[2]
os.makedirs(os.path.dirname(p), exist_ok=True)
try: cfg = json.load(open(p))
except Exception: cfg = {}
add = cfg.setdefault("permissions", {}).setdefault("additionalDirectories", [])
if vault not in add: add.append(vault)
tmp = p + ".tmp"; json.dump(cfg, open(tmp, "w"), indent=2); os.replace(tmp, p)
PY

  log "MCP: browser automation (Playwright)"
  if claude mcp get playwright >/dev/null 2>&1; then ok "playwright already added"; else
    claude mcp add --scope user playwright -- npx -y @playwright/mcp@latest >/dev/null 2>&1 && ok "playwright added (user scope)" || warn "could not add the playwright MCP server; later: claude mcp add --scope user playwright -- npx -y @playwright/mcp@latest"
  fi

  log "secrets loaded for every shell and launcher"
  if ! grep -q 'jarvis-thinkpad: secrets' "$HOME/.bashrc" 2>/dev/null; then
    cat >> "$HOME/.bashrc" <<'EOF'

# jarvis-thinkpad: secrets (chmod 600 files) become environment variables, referenced by name
for f in "$HOME"/.config/flint/*.env; do [ -f "$f" ] && { set -a; . "$f"; set +a; }; done
EOF
  fi
  ok "~/.bashrc sources ~/.config/flint/*.env"

  if [ "$VAULT_GIT" = 1 ]; then
    log "vault safety net: git, hourly commits"
    if [ ! -d "$VAULT_DIR/.git" ]; then
      ( cd "$VAULT_DIR" && git init -q -b main && printf '.obsidian/workspace*.json\n.obsidian/cache\n.trash/\n' > .gitignore && git add -A && git -c user.name="$GIT_NAME" -c user.email="${GIT_EMAIL:-$USER@$(hostname)}" commit -qm "vault: initial" )
      ok "git initialised in $VAULT_DIR"
    else ok "vault already a git repo"; fi
    mkdir -p "$HOME/.config/systemd/user"
    cat > "$HOME/.config/systemd/user/flint-vault-backup.service" <<EOF
[Unit]
Description=Commit the vault (and push if a remote exists)
[Service]
Type=oneshot
WorkingDirectory=$VAULT_DIR
ExecStart=/bin/bash -lc 'git add -A && (git diff --cached --quiet || git -c user.name="$GIT_NAME" -c user.email="${GIT_EMAIL:-$USER@$(hostname)}" commit -qm "auto \$(date -Is)") && (git remote get-url origin >/dev/null 2>&1 && git push -q || true)'
EOF
    cat > "$HOME/.config/systemd/user/flint-vault-backup.timer" <<'EOF'
[Unit]
Description=Vault backup, hourly
[Timer]
OnCalendar=hourly
Persistent=true
RandomizedDelaySec=5m
[Install]
WantedBy=timers.target
EOF
    systemctl --user daemon-reload && systemctl --user enable --now flint-vault-backup.timer >/dev/null 2>&1 && ok "hourly vault commits (push to a private GitHub repo: ask $AGENT_NAME, section 7 of 04-full-power-agent.md)"
  fi

  if [ "$REMOTE_CONTROL" = 1 ]; then
    log "Remote Control (drive $AGENT_NAME from the phone), kept alive in tmux"
    mkdir -p "$HOME/.config/systemd/user"
    cat > "$HOME/.config/systemd/user/flint-rc.service" <<EOF
[Unit]
Description=$AGENT_NAME Remote Control (tmux)
After=graphical-session.target network-online.target
[Service]
Type=forking
Environment=PATH=%h/.local/bin:/usr/local/bin:/usr/bin:/bin
EnvironmentFile=-%h/.config/flint/ha.env
EnvironmentFile=-%h/.config/flint/elevenlabs.env
WorkingDirectory=$AGENT_HOME
ExecStart=/usr/bin/tmux new -d -s flint 'claude remote-control --name "$AGENT_NAME on ThinkPad" --permission-mode auto'
ExecStop=/usr/bin/tmux kill-session -t flint
Restart=on-failure
RestartSec=30
[Install]
WantedBy=default.target
EOF
    systemctl --user daemon-reload && systemctl --user enable flint-rc.service >/dev/null 2>&1 && ok "flint-rc.service enabled (starts at login; scan the QR: tmux attach -t flint, then space)"
  fi
  sudo loginctl enable-linger "$USER" >/dev/null 2>&1 && ok "user services and timers run whether or not you are logged in"

  if [ "$AUTOSTART_STACK" = 1 ]; then
    log "the stack at every login (voice + face + hands in a terminal window)"
    mkdir -p "$HOME/.config/autostart"
    cat > "$HOME/.config/autostart/flint-stack.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$AGENT_NAME
Comment=Voice, face and hands. Ctrl-C in the window stops it; the launcher on the Desktop starts it again.
Exec=gnome-terminal --title="$AGENT_NAME" -- bash -lc "sleep 6; exec $AGENT_HOME/bin/launch.sh all"
X-GNOME-Autostart-enabled=true
EOF
    ok "autostart entry written"
  fi
}

check() {
  chk "launch.sh" test -x "$AGENT_HOME/bin/launch.sh"
  chk "desktop launchers" bash -c "ls $HOME/.local/share/applications/*-chat.desktop >/dev/null"
  chk "face core installed" test -f "$AGENT_HOME/ai-visualizer/faces/core/index.html"
  chk "face command installed" test -f "$AGENT_HOME/ai-visualizer/faces/command/index.html"
  chk "default face = $FACE" bash -c "[ \"\$(json_get '$AGENT_HOME/ai-visualizer/ai-visualizer.json' face)\" = '$FACE' ]"
  chk "team.json generated" test -f "$AGENT_HOME/ai-visualizer/faces/command/team.json"
  chk "hooks wired (team-live)" grep -q team-live.py "$AGENT_HOME/.claude/settings.json"
  chk "user settings valid JSON with deny list" python3 -c "import json,os;d=json.load(open(os.path.expanduser('~/.claude/settings.json')));assert d['permissions']['deny']"
  chk "CLAUDE.md has the team-on-screen section" grep -q "Showing the team on screen" "$AGENT_HOME/CLAUDE.md"
  chk_warn "playwright MCP registered" claude mcp get playwright
  [ "$VAULT_GIT" = 1 ] && chk "vault backup timer active" systemctl --user is-active flint-vault-backup.timer
  [ "$REMOTE_CONTROL" = 1 ] && chk "flint-rc.service enabled" systemctl --user is-enabled flint-rc.service
  checks_done
}
stage_main "$@"
