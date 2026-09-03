#!/usr/bin/env bash
# 09: Jared's installer builds the agent (memory vault, voice, face, hands) with every
# answer pre-supplied, headless. Then this stage checks each result and fixes the configs
# deterministically, so what the wizard improvised cannot drift from the decisions.
. "$(dirname "$0")/lib.sh"
FSA="$AGENT_HOME/fullstack-agent"
PROMPT="$STATE_DIR/wizard-prompt.txt"
WLOG="$LOG_DIR/wizard.log"

identity_text() {
  if [ "$IDENTITY_DOOR" = C ]; then
    printf 'door C: build my own. Name "%s". Role: chief of staff and operating partner. Tone: direct, dry British butler wit, no profanity, pushes back hard when my ideas do not add up. Welcome line: "All systems online, sir. What are we working on today?"' "$AGENT_NAME"
  else
    printf 'door B: keep the shipped Jarvis personality exactly as it is and rename it to "%s"' "$AGENT_NAME"
  fi
}

write_prompt() {
  local perm; perm="$([ "$VOICE_PERMISSIONS" = bypassPermissions ] && echo "auto-approve (run without asking)" || echo "ask (spoken permission checks)")"
  cat > "$PROMPT" <<EOF
set me up. Run all six phases of fullstack-agent.md WITHOUT asking me anything: every answer you need is below. This is an unattended install on a fresh Ubuntu 24.04 ThinkPad; nobody is watching the terminal. Where a component wizard would ask something not answered here, take the documented default and keep going. Never stop to confirm. When everything is installed and wired, print exactly: FLINT SETUP COMPLETE

ANSWERS
- Home folder: $AGENT_HOME (fresh install: no existing CLAUDE.md, no old Claude Code memory to migrate, no existing vaults, no hand-built pieces anywhere).
- Pieces: all four (ai-memory-vault, backtalk, ai-visualizer, barehands). A webcam exists.
- My name: $YOUR_NAME
- Identity: $(identity_text)
- Vault: NEW at $VAULT_DIR (in my home folder, never inside the agent's home).
- Vault interview (ai-memory-vault Phase 3), my answers: who I am: $YOUR_NAME. What I do: $YOUR_WORK. Projects (each gets its numbered folder): $PROJECTS. Key people: ${KEY_PEOPLE:-none to record yet}. Current priorities: $PRIORITIES. Recurring tasks (each becomes a Job note): $RECURRING. Optional sections: skip them all; I will fill them in with the agent later.
- Microphone: push to talk, key "$PTT_KEY"$( [ "$MIC_MODE" = open ] && printf ' (but set mic_mode to "open", hands-free)' ).
- Voice engine: built-in Kokoro, voice $VOICE. No ElevenLabs.
- Face: board (a custom face is installed afterwards by another script; leave "face" as board).
- Permissions for the voice: $perm.
- Marketing skill in Phase 6: yes, install it.
- Launchers in Phase 6: skip; Linux .desktop launchers are made by another script afterwards.

HARD RULES FOR THIS RUN
- Phase 5 (the first hello): do NOT run start.sh, run.sh or any server, and do not open a browser. I test the stack separately. Do the file checks, skip the live run, and say so.
- Everything system-level is already installed (Obsidian from the official .deb, uv, python 3.12, espeak-ng, PortAudio, ffmpeg, Chrome, Node, Docker). Do not run apt, do not ask for sudo. backtalk's install.sh may run as is; it will find everything present.
- Obsidian on this machine: the .deb. Its registry file is ~/.config/obsidian/obsidian.json (back it up first if it exists, then register the vault). Launch it only after registering, with: setsid obsidian >/dev/null 2>&1 & ; do not wait for it and do not close it.
- Write backtalk.json, ai-visualizer.json and barehands.json exactly as fullstack-agent.md Phase 4 says, then read each back.
- Do not skip the Obsidian, vault, CLAUDE.md, backtalk, ai-visualizer or barehands steps for any reason. If a download fails, retry it up to three times before moving on, and list anything that still failed at the end under the heading "NOT DONE:".
- ai-memory-vault: no Obsidian Sync (the vault is backed up with git by another script); Obsidian is installed already, do not reinstall it. Preview-and-confirm steps are confirmed in advance: build.
- backtalk: do not run any live microphone or speaker test, do not record or play audio, do not start run.sh; the doctor tests the voice afterwards. Leave mic_device unset.
- barehands and ai-visualizer: do not open a browser; the camera permission happens on the first real open.
- No old Claude Code memory exists on this machine: skip every migration offer.
EOF
}

wizard_ok() {   # the artefacts a finished wizard leaves behind
  [ -f "$AGENT_HOME/CLAUDE.md" ] && [ -d "$AGENT_HOME/ai-memory-vault" ] && [ -d "$AGENT_HOME/backtalk" ] && [ -d "$AGENT_HOME/ai-visualizer" ] && [ -d "$AGENT_HOME/barehands" ] \
  && [ -f "$AGENT_HOME/backtalk/backtalk.json" ] && [ -f "$AGENT_HOME/ai-visualizer/ai-visualizer.json" ] && [ -f "$AGENT_HOME/barehands/barehands.json" ] \
  && [ -f "$VAULT_DIR/VAULT-INDEX.md" ] && [ -x "$AGENT_HOME/backtalk/.venv/bin/python" ]
}
missing_list() {
  local m=""
  [ -f "$AGENT_HOME/CLAUDE.md" ] || m="$m $AGENT_HOME/CLAUDE.md;"
  for d in ai-memory-vault backtalk ai-visualizer barehands; do [ -d "$AGENT_HOME/$d" ] || m="$m clone of $d;"; done
  [ -f "$AGENT_HOME/backtalk/backtalk.json" ] || m="$m backtalk/backtalk.json;"
  [ -f "$AGENT_HOME/ai-visualizer/ai-visualizer.json" ] || m="$m ai-visualizer/ai-visualizer.json;"
  [ -f "$AGENT_HOME/barehands/barehands.json" ] || m="$m barehands/barehands.json;"
  [ -f "$VAULT_DIR/VAULT-INDEX.md" ] || m="$m the vault at $VAULT_DIR (VAULT-INDEX.md);"
  [ -x "$AGENT_HOME/backtalk/.venv/bin/python" ] || m="$m backtalk/.venv (run backtalk/install.sh);"
  printf '%s' "$m"
}

run_wizard() {  # run_wizard "<prompt text>"
  ( cd "$FSA" && timeout 5400 claude -p "$1" --dangerously-skip-permissions --max-turns 500 --output-format text </dev/null 2>&1 | tee -a "$WLOG" ) || true
}

fix_configs() {
  log "pinning the configs to the decisions"
  local bt="$AGENT_HOME/backtalk/backtalk.json"
  json_set "$bt" agent_dir "\"$AGENT_HOME\""
  json_set "$bt" name "\"$AGENT_NAME\""
  json_set "$bt" ptt_key "\"$PTT_KEY\""
  json_set "$bt" mic_mode "\"$MIC_MODE\""
  json_set "$bt" voice "\"$VOICE\""
  json_set "$bt" stt_model "\"$STT_MODEL\""
  json_set "$bt" permission_mode "\"$VOICE_PERMISSIONS\""
  json_set "$bt" extra_dirs "[\"$VAULT_DIR\"]"
  json_set "$bt" barehands_state_dir "\"$AGENT_HOME/barehands/state\""
  json_set "$bt" greeting "\"Hello $YOUR_NAME, what are we working on today?\""
  json_set "$bt" show_usage "true"
  # the wake phrase (read by the flint_voice hook stage 10 installs; inert for a plain backtalk)
  json_set "$bt" wake_words "$(python3 -c 'import json,sys; ws=[w.strip().lower() for w in sys.argv[1].split(",") if w.strip()]; n=sys.argv[2].strip().lower(); print(json.dumps(ws or [n, "hey " + n]))' "$WAKE_WORDS" "$AGENT_NAME")"
  json_set "$bt" wake_window_s "$WAKE_WINDOW_S"
  json_set "$bt" wake_required "true"
  json_set "$bt" greeting_open_mic "\"Hello $YOUR_NAME. I'm listening. Say my name when you want me.\""
  [ -n "$VOICE_EFFORT" ] && json_set "$bt" effort "\"$VOICE_EFFORT\""
  local vz="$AGENT_HOME/ai-visualizer/ai-visualizer.json"
  [ -f "$vz" ] || cp "$AGENT_HOME/ai-visualizer/ai-visualizer.json.example" "$vz" 2>/dev/null || echo '{}' > "$vz"
  json_set "$vz" name "\"$(printf '%s' "$AGENT_NAME" | tr '[:lower:]' '[:upper:]')\""
  json_set "$vz" bus_dir "\"$AGENT_HOME/backtalk\""
  json_set "$vz" port "8790"
  local bh="$AGENT_HOME/barehands/barehands.json"
  [ -f "$bh" ] || cp "$AGENT_HOME/barehands/barehands.json.example" "$bh" 2>/dev/null || echo '{}' > "$bh"
  json_set "$bh" name "\"$AGENT_NAME\""
  json_set "$bh" port "8794"
  mkdir -p "$AGENT_HOME/barehands/state" "$AGENT_HOME/logs"
  ok "backtalk.json, ai-visualizer.json, barehands.json pinned"

  # the Obsidian registry must list the vault, or the first launch is a welcome screen;
  # Obsidian rewrites that file while it runs, so it is closed first, only if a write is needed
  if ! python3 -c "import json,os,sys;v=os.path.abspath(os.path.expanduser('$VAULT_DIR'));d=json.load(open(os.path.expanduser('~/.config/obsidian/obsidian.json')));sys.exit(0 if any(os.path.abspath(x.get('path',''))==v for x in d.get('vaults',{}).values()) else 1)" 2>/dev/null; then
    pgrep -x obsidian >/dev/null && { pkill -x obsidian || true; sleep 2; }
  fi
  python3 - "$VAULT_DIR" <<'PY'
import json, os, shutil, time, secrets
vault = os.path.abspath(os.path.expanduser(__import__("sys").argv[1]))
p = os.path.expanduser("~/.config/obsidian/obsidian.json")
os.makedirs(os.path.dirname(p), exist_ok=True)
d = {}
if os.path.exists(p):
    shutil.copy(p, p + ".bak")
    try: d = json.load(open(p))
    except Exception: d = {}
vaults = d.setdefault("vaults", {})
if not any(os.path.abspath(v.get("path", "")) == vault for v in vaults.values()):
    vaults[secrets.token_hex(8)] = {"path": vault, "ts": int(time.time() * 1000), "open": True}
    json.dump(d, open(p, "w"))
    print("   registered", vault, "in", p)
else:
    print("   vault already registered")
PY
  os_app="$VAULT_DIR/.obsidian/app.json"; mkdir -p "$VAULT_DIR/.obsidian"
  [ -f "$os_app" ] || echo '{"alwaysUpdateLinks": true}' > "$os_app"
}

run() {
  log "before the wizard"
  claude auth status >/dev/null 2>&1 || (cd "$STATE_DIR" && timeout 90 claude -p "reply with exactly: ok" --max-turns 1 --output-format text </dev/null 2>/dev/null | grep -qi 'ok') || die "Claude Code is not logged in (stage 07)."
  wizard_ok || { pgrep -x obsidian >/dev/null && { warn "closing Obsidian so the wizard can register the vault"; pkill -x obsidian || true; sleep 2; }; }
  session_is_x11 || warn "not an X11 session (push-to-talk needs one after the reboot); the wizard does not care"
  mkdir -p "$AGENT_HOME"
  if [ ! -d "$FSA/.git" ]; then git clone -q https://github.com/jaredrhod/fullstack-agent "$FSA"; ok "fullstack-agent cloned"; else ok "fullstack-agent present"; fi

  if wizard_ok; then ok "the agent is already installed; skipping the wizard"; else
    write_prompt
    if [ "$WIZARD_MODE" = interactive ]; then
      log "Jared's installer, interactive (answer with the sheet in 02-jarvis-install.md; it closes when done)"
      term_run "cd '$FSA' && claude \"\$(cat '$PROMPT')\""
    else
      log "Jared's installer, headless (30-60 minutes: it clones four repos, builds the vault, downloads ~1 GB of speech models)"
      say "live log: tail -f $WLOG"
      run_wizard "$(cat "$PROMPT")"
      if ! wizard_ok; then
        warn "first pass left things missing:$(missing_list)"
        log "second pass"
        run_wizard "Continue the setup from fullstack-agent.md with the same answers as before (they are in $PROMPT; read it). These are still missing and must be completed now:$(missing_list). Do not ask anything, do not start servers. Print FLINT SETUP COMPLETE when done."
      fi
    fi
  fi

  if ! wizard_ok; then
    warn "still missing:$(missing_list)"
    if [ -d "$AGENT_HOME/backtalk" ] && [ ! -x "$AGENT_HOME/backtalk/.venv/bin/python" ]; then
      log "running backtalk's installer directly"; ( cd "$AGENT_HOME/backtalk" && ./install.sh ) 2>&1 | tail -5 || true
    fi
  fi
  if ! wizard_ok; then
    if have_display; then
      warn "opening an interactive session so you can finish it with the wizard (the headless run cannot be resumed; this one starts with its context)"
      term_run "cd '$FSA' && claude \"We got cut off during setup. Continue from fullstack-agent.md with the answers in $PROMPT (read it first). Still missing:$(missing_list). Ask me only what you truly cannot decide.\""
    fi
    wizard_ok || die "the agent is not fully installed:$(missing_list). Run again: setup.sh --only 09  (log: $WLOG)"
  fi
  fix_configs
  # speech models: backtalk's installer prefetches them; make sure (idempotent, skips when present)
  log "speech models"
  ( cd "$AGENT_HOME/backtalk" && ./install.sh ) >"$LOG_DIR/backtalk-install.log" 2>&1 && ok "backtalk environment and models ready" || warn "backtalk install.sh reported a problem (log: $LOG_DIR/backtalk-install.log)"
}

check() {
  chk "agent home $AGENT_HOME/CLAUDE.md" test -f "$AGENT_HOME/CLAUDE.md"
  for d in ai-memory-vault backtalk ai-visualizer barehands; do chk "$d cloned" test -d "$AGENT_HOME/$d"; done
  chk "backtalk .venv" test -x "$AGENT_HOME/backtalk/.venv/bin/python"
  chk "backtalk imports (faster_whisper, kokoro, sounddevice)" "$AGENT_HOME/backtalk/.venv/bin/python" -c "import faster_whisper, kokoro, sounddevice, soundfile"
  chk "backtalk.json name=$AGENT_NAME ptt=$PTT_KEY" bash -c "[ \"\$(json_get '$AGENT_HOME/backtalk/backtalk.json' name)\" = '$AGENT_NAME' ] && [ \"\$(json_get '$AGENT_HOME/backtalk/backtalk.json' ptt_key)\" = '$PTT_KEY' ]"
  chk "ai-visualizer.json bus_dir" bash -c "[ \"\$(json_get '$AGENT_HOME/ai-visualizer/ai-visualizer.json' bus_dir)\" = '$AGENT_HOME/backtalk' ]"
  chk "barehands.json" test -f "$AGENT_HOME/barehands/barehands.json"
  chk "vault $VAULT_DIR/VAULT-INDEX.md" test -f "$VAULT_DIR/VAULT-INDEX.md"
  chk "vault registered in Obsidian" python3 -c "import json,os;v=os.path.abspath(os.path.expanduser('$VAULT_DIR'));d=json.load(open(os.path.expanduser('~/.config/obsidian/obsidian.json')));assert any(os.path.abspath(x.get('path',''))==v for x in d.get('vaults',{}).values())"
  chk "CLAUDE.md names the vault" grep -q "$(basename "$VAULT_DIR")" "$AGENT_HOME/CLAUDE.md"
  checks_done
}
stage_main "$@"
