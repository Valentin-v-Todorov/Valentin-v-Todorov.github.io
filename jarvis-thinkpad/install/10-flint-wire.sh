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
  "$GUIDE_DIR/make-launchers.sh" "$AGENT_HOME" "$AGENT_NAME" >/dev/null
  ok "launchers on the Desktop and in the app grid"

  log "the agent's own tools: flint-play (music), flint-voice (voices), flint-stack, flint-health.sh, flint-keeper.sh, flint-doctor.sh"
  mkdir -p "$AGENT_HOME/bin/voice-hook" "$HOME/.local/bin"
  cp "$GUIDE_DIR"/bin/flint-* "$AGENT_HOME/bin/" && chmod +x "$AGENT_HOME"/bin/flint-*
  cp "$GUIDE_DIR/voice/flint_voice.py" "$GUIDE_DIR/voice/install.sh" "$AGENT_HOME/bin/voice-hook/" && chmod +x "$AGENT_HOME/bin/voice-hook/install.sh"
  cat > "$AGENT_HOME/bin/flint-doctor.sh" <<EOF
#!/usr/bin/env bash
# flint-doctor.sh [--only NN | --from NN]: the installer's checks (setup.sh --check), silent, usable from
# inside the agent (a nested claude is allowed). With --only NN it redoes one stage: run and check.
exec env -u CLAUDECODE -u CLAUDE_CODE_ENTRYPOINT FLINT_QUIET=1 "$GUIDE_DIR/setup.sh" "\${1:---check}" "\${@:2}"
EOF
  chmod +x "$AGENT_HOME/bin/flint-doctor.sh"
  for t in flint-play flint-voice flint-stack flint-health.sh flint-doctor.sh; do ln -sfn "$AGENT_HOME/bin/$t" "$HOME/.local/bin/$t"; done
  ok "installed in $AGENT_HOME/bin and linked into ~/.local/bin"

  log "the wake phrase (\"$AGENT_NAME, ...\") and music ducking, hooked into backtalk's virtualenv"
  if "$AGENT_HOME/bin/voice-hook/install.sh" "$AGENT_HOME" >"$LOG_DIR/voice-hook.log" 2>&1; then ok "$(tail -1 "$LOG_DIR/voice-hook.log")"
  else warn "the voice hook could not be installed ($LOG_DIR/voice-hook.log); launch.sh retries at every start of the stack"; fi

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
  append_once "$AGENT_HOME/CLAUDE.md" "## Music, the screen, the browser, your voice, your health" <<EOF
## Music, the screen, the browser, your voice, your health
- Music, by its bare name: \`flint-play "eminem lose yourself"\` (the first YouTube match, audio only),
  \`flint-play --album "eminem the marshall mathers lp"\`, \`flint-play --queue "90s hip hop"\`,
  \`flint-play --local "beatles"\` (~/Music), a URL or a file; \`flint-play pause|resume|next|stop|volume 60|status\`.
  It prints the title: say it in one line. The music dips by itself while you speak.
- Showing things: \`xdg-open <url-or-file>\` puts it on the screen (Chrome, or the right app). The Playwright
  browser (MCP) is for doing things inside pages: searching, reading, logging in, clicking; it drives Google
  Chrome with its own profile, visibly, so $YOUR_NAME sees what you do. Find first (WebSearch or the browser),
  then open it on screen or play it. "Find me the album X by Y" means: find it, say what you found, offer to play it.
- Your voice: \`flint-voice list\`, \`flint-voice try af_heart\`, \`flint-voice set af_heart\`, \`flint-voice speed 1.15\`.
  A new voice takes effect after \`flint-stack restart\`; say so, then do it when asked.
- The stack: \`flint-stack status|restart|stop|start\`. A stopped stack stays stopped until started; the keeper
  timer restarts one that crashed within two minutes.
- Health: \`flint-health.sh\` (the machine and the stack, with a verdict) when asked how you or the machine are;
  \`flint-doctor.sh\` for the installer's full checks (minutes). Fix what they find: each piece's TROUBLESHOOTING.md,
  the logs in ~/.flint-setup/logs, \`flint-doctor.sh --only NN\` to redo one stage. The nightly doctor at 03:30
  does the same on its own and writes "Doctor Log.md" in the vault's ThinkPad folder.
- Listening: hands-free, you only hear utterances that start or end with your name, and follow-ups within
  thirty seconds of your reply. If $YOUR_NAME asks why you did not answer, that is why: say the name, or hold the key.
EOF
  ok "CLAUDE.md: team on screen, machine toolbox, music/screen/browser/voice/health"

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
for d in ["Bash(rm -rf /)", "Bash(rm -rf / *)", "Bash(rm -rf /*)", "Bash(rm -rf ~)", "Bash(rm -rf ~/)", "Bash(rm -rf /home)", "Bash(rm -rf /home/)",
          "Bash(rm -rf /home/*)", "Bash(sudo rm -rf /)", "Bash(sudo rm -rf /*)", "Bash(mkfs*)", "Bash(dd if=*)",
          "Bash(shutdown*)", "Bash(systemctl poweroff*)", "Bash(git push --force*)", "Read(~/.config/flint/**)", "Read(~/.ssh/id_*)"]:
    if d not in deny: deny.append(d)
add = perm.setdefault("additionalDirectories", [])
if vault not in add: add.append(vault)
sb = cfg.setdefault("sandbox", {}); sb.setdefault("enabled", True); sb.setdefault("autoAllowBashIfSandboxed", True)
# the machine toolbox needs the host: these run outside the sandbox (with the classifier watching in auto mode)
exc = sb.setdefault("excludedCommands", [])
home = os.path.expanduser(os.environ.get("AGENT_HOME", "~/my-agent"))
for c in ["sudo *", "docker *", "systemctl *", "loginctl *", "tailscale *", "gio *", "xdotool *", "wmctrl *", "playerctl *", "pactl *", "notify-send *", "gnome-screenshot *",
          # the screen, the speakers and the microphone are outside the sandbox (X11 and PipeWire sockets)
          "xdg-open *", "google-chrome *", "obsidian *", "mpv *", "yt-dlp *", "paplay *", "aplay *", "arecord *", "espeak-ng *",
          "flint-play *", "flint-voice *", "flint-stack *", "flint-health.sh *", "flint-doctor.sh *", "flint-keeper.sh *"] + \
         [f"{home}/bin/{t} *" for t in ("flint-play", "flint-voice", "flint-stack", "flint-health.sh", "flint-doctor.sh", "flint-keeper.sh", "core-view.sh", "board.sh")]:
    if c not in exc: exc.append(c)
# the agent's home is trusted, so a detached `claude remote-control` never waits on the trust dialog
try:
    cj = os.path.expanduser("~/.claude.json"); c = json.load(open(cj)) if os.path.exists(cj) else {}
    c.setdefault("projects", {}).setdefault(os.path.expanduser(os.environ.get("AGENT_HOME", "~/my-agent")), {})["hasTrustDialogAccepted"] = True
    t = cj + ".tmp"; json.dump(c, open(t, "w"), indent=2); os.replace(t, cj)
except Exception as e:
    print("   note: could not pre-trust the agent home in ~/.claude.json:", e)
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

  log "MCP: browser automation (Playwright driving Google Chrome, headed, with its own persistent profile)"
  local pw_profile="$HOME/.local/share/flint/chrome-profile"; mkdir -p "$pw_profile"
  if claude mcp get playwright 2>/dev/null | grep -q -- "--browser chrome"; then ok "playwright already drives Chrome (profile $pw_profile)"; else
    claude mcp remove playwright -s user >/dev/null 2>&1 || true
    if claude mcp add --scope user playwright -- npx -y @playwright/mcp@latest --browser chrome --user-data-dir "$pw_profile" >/dev/null 2>&1; then
      ok "playwright added: Chrome, headed (you see what the agent does), logins persist in $pw_profile"
    else warn "could not add the playwright MCP server; later: claude mcp add --scope user playwright -- npx -y @playwright/mcp@latest --browser chrome --user-data-dir $pw_profile"; fi
  fi

  log "secrets loaded for every shell and launcher"
  for rc in "$HOME/.bashrc" "$HOME/.profile"; do
    if ! grep -q 'jarvis-thinkpad: secrets' "$rc" 2>/dev/null; then
      cat >> "$rc" <<'EOF'

# jarvis-thinkpad: secrets (chmod 600 files) become environment variables, referenced by name
for f in "$HOME"/.config/flint/*.env; do [ -f "$f" ] && { set -a; . "$f"; set +a; }; done
EOF
    fi
  done
  ok "~/.bashrc and ~/.profile source ~/.config/flint/*.env"

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
    systemctl --user daemon-reload && systemctl --user enable --now flint-vault-backup.timer >/dev/null 2>&1 && ok "hourly vault commits (push to a private GitHub repo: ask $AGENT_NAME, section 7 of 04-full-power-agent.md)" || warn "could not enable the vault backup timer (systemctl --user); the check below will say so"
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
ExecStartPre=-/usr/bin/nm-online -q -t 120
ExecStart=/usr/bin/tmux new -d -s flint 'claude remote-control --name "$AGENT_NAME on ThinkPad" --permission-mode auto; sleep 30'
ExecStop=/usr/bin/tmux kill-session -t flint
Restart=always
RestartSec=30
[Install]
WantedBy=default.target
EOF
    systemctl --user daemon-reload && systemctl --user enable flint-rc.service >/dev/null 2>&1 && ok "flint-rc.service enabled (starts at login; scan the QR: tmux attach -t flint, then space)" || warn "could not enable flint-rc.service"
  fi
  sudo loginctl enable-linger "$USER" >/dev/null 2>&1 && ok "user services and timers run whether or not you are logged in" || warn "loginctl enable-linger failed (timers then run only while logged in; auto-login covers it)"

  if [ "$KEEPER" = 1 ]; then
    log "the keeper: a timer that restarts the stack when it dies (and leaves it alone when you stopped it)"
    mkdir -p "$HOME/.config/systemd/user"
    cat > "$HOME/.config/systemd/user/flint-keeper.service" <<EOF
[Unit]
Description=$AGENT_NAME keeper: restart the stack when it died
[Service]
Type=oneshot
Environment=PATH=%h/.local/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=$AGENT_HOME/bin/flint-keeper.sh
EOF
    cat > "$HOME/.config/systemd/user/flint-keeper.timer" <<'EOF'
[Unit]
Description=Keeper, every two minutes
[Timer]
OnStartupSec=90
OnUnitActiveSec=2min
AccuracySec=20s
[Install]
WantedBy=timers.target
EOF
    systemctl --user daemon-reload && systemctl --user enable --now flint-keeper.timer >/dev/null 2>&1 && ok "flint-keeper.timer active (log: ~/.local/state/flint/keeper.log)" || warn "could not enable flint-keeper.timer"
  fi

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
  chk_warn "playwright MCP drives Chrome" bash -c "claude mcp get playwright | grep -q -- '--browser chrome'"
  chk "flint-play, flint-voice, flint-stack, flint-health.sh, flint-doctor.sh on PATH" bash -c "for t in flint-play flint-voice flint-stack flint-health.sh flint-doctor.sh; do [ -x \"$HOME/.local/bin/\$t\" ] || exit 1; done"
  chk "wake-phrase hook in backtalk's virtualenv" "$AGENT_HOME/backtalk/.venv/bin/python" -c "import flint_voice, sys; sys.exit(0 if flint_voice.installed() else 1)"
  chk "CLAUDE.md has the music/screen/browser/voice/health section" grep -q "flint-play" "$AGENT_HOME/CLAUDE.md"
  [ "$KEEPER" = 1 ] && chk "keeper timer active" systemctl --user is-active flint-keeper.timer
  [ "$VAULT_GIT" = 1 ] && chk "vault backup timer active" systemctl --user is-active flint-vault-backup.timer
  [ "$REMOTE_CONTROL" = 1 ] && chk "flint-rc.service enabled" systemctl --user is-enabled flint-rc.service
  checks_done
}
stage_main "$@"
