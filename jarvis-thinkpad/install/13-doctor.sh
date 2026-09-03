#!/usr/bin/env bash
# 13: the doctor. Real tests, not file checks: the models speak and hear, the servers
# answer, the agent boots as Flint and its hooks fire, the MCP servers connect. Writes
# ~/.flint-setup/report.md. Then one Timeshift snapshot of the working system.
. "$(dirname "$0")/lib.sh"
REPORT="$STATE_DIR/report.md"
BT="$AGENT_HOME/backtalk"

tts_test() {   # Kokoro says one line through the speakers; returns 0 if audio was produced
  ( cd "$BT" && timeout 300 .venv/bin/python - "$VOICE" "$YOUR_NAME" <<'PY'
import sys, wave, numpy as np, warnings; warnings.filterwarnings("ignore")
from kokoro import KPipeline
voice, name = sys.argv[1], sys.argv[2]
pipe = KPipeline(lang_code=voice[0] if voice[0] in "ab" else "a", repo_id="hexgrad/Kokoro-82M")
chunks = [np.asarray(audio, dtype=np.float32) for _, _, audio in pipe(f"All systems online, {name}. Your machine is ready.", voice=voice)]
pcm = (np.concatenate(chunks) * 32767).astype(np.int16)
with wave.open("/tmp/flint-tts.wav", "wb") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(24000); w.writeframes(pcm.tobytes())
assert len(pcm) > 24000, "less than a second of audio"
print("ok", len(pcm) / 24000, "s")
PY
  ) && { paplay /tmp/flint-tts.wav 2>/dev/null || aplay -q /tmp/flint-tts.wav 2>/dev/null || true; }
}
stt_test() {   # espeak-ng says a sentence into a file, faster-whisper must hear "hello"
  espeak-ng -w /tmp/flint-stt.wav -s 150 "hello flint, all systems online" 2>/dev/null || return 1
  ( cd "$BT" && timeout 300 .venv/bin/python - "$STT_MODEL" <<'PY'
import sys, warnings; warnings.filterwarnings("ignore")
from faster_whisper import WhisperModel
m = WhisperModel(sys.argv[1], device="cpu", compute_type="int8")
segs, _ = m.transcribe("/tmp/flint-stt.wav")
text = " ".join(s.text for s in segs).lower()
print(text)
assert "hello" in text or "flint" in text or "online" in text, text
PY
  )
}
face_test() {   # a throwaway face server on the real port, killed afterwards; skipped if the stack already runs
  if curl -fsS -m 2 -o /dev/null http://127.0.0.1:8790/state 2>/dev/null; then curl -fsS -m 5 http://127.0.0.1:8790/faces/core/ | grep -q "The Core"; return; fi
  ( cd "$AGENT_HOME/ai-visualizer" && exec python3 server.py --no-open --mock idle ) >/tmp/flint-face.log 2>&1 &
  local pid=$! r=1
  if wait_http http://127.0.0.1:8790/state 20 && curl -fsS -m 5 http://127.0.0.1:8790/faces/core/ | grep -q "The Core" && curl -fsS -m 5 http://127.0.0.1:8790/faces/command/team.json | grep -q departments; then r=0; fi
  kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true
  return $r
}
hands_test() {
  if curl -fsS -m 2 -o /dev/null http://127.0.0.1:8794/stage.html 2>/dev/null; then return 0; fi
  ( cd "$AGENT_HOME/barehands" && exec python3 server.py ) >/tmp/flint-hands.log 2>&1 &
  local pid=$! r=1
  wait_http http://127.0.0.1:8794/stage.html 20 && r=0
  kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true
  return $r
}
agent_test() {  # boots as the agent in its home; the hooks must record the turn (live.json's ts moves)
  local before after live="$AGENT_HOME/ai-visualizer/faces/command/live.json"
  before="$(json_get "$live" ts 2>/dev/null)"; before="${before:-0}"
  ( cd "$AGENT_HOME" && timeout 180 claude -p "Reply with exactly: FLINT ONLINE" --max-turns 1 --output-format text </dev/null 2>/dev/null | grep -q "ONLINE" ) || return 1
  after="$(json_get "$live" ts 2>/dev/null)"; after="${after:-0}"
  python3 -c "import sys; sys.exit(0 if float('${after:-0}' or 0) > float('${before:-0}' or 0) else 1)" || { warn "the agent answered but the hooks did not record the turn (live.json)"; return 1; }
}
mcp_test() {
  local out; out="$(cd "$AGENT_HOME" && timeout 120 claude mcp list </dev/null 2>/dev/null || true)"
  printf '%s' "$out" | grep -qi "playwright.*connected" || return 1
  if [ "$HOME_ASSISTANT" = 1 ]; then printf '%s' "$out" | grep -qi "home-assistant.*connected" || return 1; fi
}

run() {
  log "audio devices"
  arecord -l 2>/dev/null | grep -q '^card' && ok "capture: $(arecord -l | grep '^card' | head -1)" || warn "no ALSA capture device listed"
  pactl info >/dev/null 2>&1 && ok "default sink: $(pactl get-default-sink 2>/dev/null)  source: $(pactl get-default-source 2>/dev/null)" || warn "PulseAudio/PipeWire not reachable from this session"
  ls /dev/video* >/dev/null 2>&1 && ok "webcam: $(ls /dev/video* | head -1)" || warn "no webcam device (the hands need one)"
  log "the doctor runs the real tests now (a minute or two)"
}

check() {
  : > "$REPORT"; printf '# %s ThinkPad report, %s\n\n' "$AGENT_NAME" "$(date '+%Y-%m-%d %H:%M')" >> "$REPORT"
  # every real test keeps its output in logs/doctor-<name>.log, and a failure shows its last lines
  dlog() { printf '%s/doctor-%s.log' "$LOG_DIR" "$(printf '%s' "$1" | tr -c 'A-Za-z0-9' '-' | cut -c1-40)"; }
  tee_chk() { local w="$1"; shift; local l; l="$(dlog "$w")"; if "$@" >"$l" 2>&1; then chk "$w" true; printf -- '- ✓ %s\n' "$w" >> "$REPORT"; else chk "$w" false; tail -5 "$l" | sed 's/^/      /'; printf -- '- ✗ %s\n' "$w" >> "$REPORT"; fi; }
  tee_warn() { local w="$1"; shift; local l; l="$(dlog "$w")"; if "$@" >"$l" 2>&1; then chk "$w" true; printf -- '- ✓ %s\n' "$w" >> "$REPORT"; else chk_warn "$w" false; tail -3 "$l" | sed 's/^/      /'; printf -- '- ~ %s (optional)\n' "$w" >> "$REPORT"; fi; }
  tee_chk "X11 session (push-to-talk)" session_is_x11
  tee_chk "Claude Code logged in" bash -c 'claude auth status >/dev/null 2>&1 || timeout 90 claude -p "reply with exactly: ok" --max-turns 1 | grep -qi "^ok"'
  tee_chk "Kokoro speaks (you should have heard it)" tts_test
  tee_chk "faster-whisper hears" stt_test
  tee_chk "face server + The Core + roster" face_test
  tee_chk "hands server" hands_test
  tee_chk "the agent boots as $AGENT_NAME and the hooks record it" agent_test
  tee_warn "MCP servers connect (playwright$( [ "$HOME_ASSISTANT" = 1 ] && printf ', home-assistant'))" mcp_test
  [ "$HOME_ASSISTANT" = 1 ] && tee_chk "Home Assistant API with the token" bash -c ". '$HOME/.config/flint/ha.env'; curl -fsS -m 5 -H \"Authorization: Bearer \$HA_TOKEN\" http://127.0.0.1:8123/api/ | grep -q 'API running'"
  [ "$AGENT_TIMERS" = 1 ] && tee_chk "agent timers scheduled" bash -c "systemctl --user list-timers --all --no-legend 'flint-*' | grep -q flint-"
  [ "$VAULT_GIT" = 1 ] && tee_chk "vault backup timer" systemctl --user is-active flint-vault-backup.timer
  [ "$TAILSCALE" = 1 ] && tee_warn "Tailscale connected" tailscale status
  tee_chk "auto-login + Xorg configured" bash -c "sudo grep -Eq '^AutomaticLogin=$USER' /etc/gdm3/custom.conf && sudo grep -Eq '^WaylandEnable=false' /etc/gdm3/custom.conf"
  tee_chk "never-sleep config" test -f /etc/systemd/logind.conf.d/flint-server.conf
  tee_chk "sshd" systemctl is-active ssh
  [ "$UFW" = 1 ] && tee_chk "firewall" bash -c "sudo ufw status | grep -q 'Status: active'"
  printf '\nlogs: %s\nre-run any stage: setup.sh --only NN   the doctor alone: setup.sh --check\n' "$LOG_DIR" >> "$REPORT"
  say "report: $REPORT"
  checks_done
}
stage_main "$@"
