#!/usr/bin/env bash
# 13: the doctor. Real tests, not file checks: the models speak and hear, the servers
# answer, the agent boots as Flint and its hooks fire, the MCP servers connect. Writes
# ~/.flint-setup/report.md. Then one Timeshift snapshot of the working system.
. "$(dirname "$0")/lib.sh"
REPORT="$STATE_DIR/report.md"
BT="$AGENT_HOME/backtalk"

tts_test() {   # Kokoro says one line through the speakers; returns 0 if audio was produced (FLINT_QUIET=1: no playback)
  ( cd "$BT" && timeout 300 .venv/bin/python - "$VOICE" "$YOUR_NAME" "$STATE_DIR/.lat-tts" <<'PY'
import sys, time, wave, numpy as np, warnings; warnings.filterwarnings("ignore")
from kokoro import KPipeline
voice, name = sys.argv[1], sys.argv[2]
pipe = KPipeline(lang_code=voice[0] if voice[0] in "ab" else "a", repo_id="hexgrad/Kokoro-82M")
t0 = time.monotonic()
chunks = [np.asarray(audio, dtype=np.float32) for _, _, audio in pipe(f"All systems online, {name}. Your machine is ready.", voice=voice)]
synth = time.monotonic() - t0
pcm = (np.concatenate(chunks) * 32767).astype(np.int16)
with wave.open("/tmp/flint-tts.wav", "wb") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(24000); w.writeframes(pcm.tobytes())
assert len(pcm) > 24000, "less than a second of audio"
open(sys.argv[3], "w").write(f"{synth:.2f}")
print(f"ok {len(pcm) / 24000:.1f}s of audio, synthesised in {synth:.2f}s (model warm)")
PY
  ) && { [ "${FLINT_QUIET:-0}" = 1 ] || paplay /tmp/flint-tts.wav 2>/dev/null || aplay -q /tmp/flint-tts.wav 2>/dev/null || true; }
}
stt_test() {   # espeak-ng says a sentence into a file, faster-whisper must hear "hello"
  espeak-ng -w /tmp/flint-stt.wav -s 150 "hello flint, all systems online" 2>/dev/null || return 1
  ( cd "$BT" && timeout 300 .venv/bin/python - "$STT_MODEL" "$STATE_DIR/.lat-stt" <<'PY'
import sys, time, warnings; warnings.filterwarnings("ignore")
from faster_whisper import WhisperModel
m = WhisperModel(sys.argv[1], device="cpu", compute_type="int8")
list(m.transcribe("/tmp/flint-stt.wav")[0])          # warm-up: the live voice line keeps the model warm too
t0 = time.monotonic()
segs, _ = m.transcribe("/tmp/flint-stt.wav")
text = " ".join(s.text for s in segs).lower()
took = time.monotonic() - t0
open(sys.argv[2], "w").write(f"{took:.2f}")
print(f"{text!r} in {took:.2f}s (model warm)")
assert "hello" in text or "flint" in text or "online" in text, text
PY
  )
}
wake_test() {   # the hook loads inside backtalk's virtualenv and its matcher cases pass
  ( cd "$BT" && .venv/bin/python -m flint_voice --selftest -q )
}
latency_test() {  # the spoken-reply budget: ears + brain + mouth, from the numbers the tests above left behind
  local t0 t1 brain ears mouth total
  t0="$(date +%s.%N)"
  ( cd "$AGENT_HOME" && timeout 120 claude -p "Reply with exactly: ready" --max-turns 1 --output-format text </dev/null >/dev/null 2>&1 ) || return 1
  t1="$(date +%s.%N)"
  ears="$(cat "$STATE_DIR/.lat-stt" 2>/dev/null || echo 0)"; mouth="$(cat "$STATE_DIR/.lat-tts" 2>/dev/null || echo 0)"
  brain="$(python3 -c "print(round($t1 - $t0, 1))")"
  total="$(python3 -c "print(round($ears + $brain + $mouth, 1))")"
  printf 'ears %ss + brain %ss + mouth %ss = about %ss to the first spoken word (the brain figure includes starting a fresh claude process, which the live voice line does not pay; expect it faster)\n' "$ears" "$brain" "$mouth" "$total" | tee "$STATE_DIR/.lat-total"
  python3 -c "import sys; sys.exit(0 if $total <= 3.0 else 1)"
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
  tee_chk "Claude Code logged in" bash -c "claude auth status >/dev/null 2>&1 || (cd '$STATE_DIR' && timeout 90 claude -p 'reply with exactly: ok' --max-turns 1 --output-format text </dev/null | grep -qi ok)"
  tee_chk "Kokoro speaks (you should have heard it)" tts_test
  tee_chk "faster-whisper hears" stt_test
  tee_chk "face server + The Core + roster" face_test
  tee_chk "hands server" hands_test
  tee_chk "the agent boots as $AGENT_NAME and the hooks record it" agent_test
  tee_chk "wake phrase: the hook loads in backtalk and its cases pass" wake_test
  tee_warn "spoken reply budget under 3 s (ears + brain + mouth)" latency_test
  [ -f "$STATE_DIR/.lat-total" ] && printf -- '- reply budget: %s\n' "$(cat "$STATE_DIR/.lat-total")" >> "$REPORT"
  [ "$MUSIC" = 1 ] && tee_chk "music: mpv plays a tone, yt-dlp present" flint-play --selftest
  [ "$MUSIC" = 1 ] && tee_warn "music: a YouTube search answers" bash -c "timeout 90 yt-dlp --simulate --print title 'ytsearch1:eminem lose yourself' | grep -q ."
  tee_chk "flint-health.sh reports" bash -c "flint-health.sh --brief | grep -q ."
  tee_chk "flint-stack answers" bash -c "flint-stack status >/dev/null 2>&1; [ \$? -le 1 ]"
  [ "$KEEPER" = 1 ] && tee_chk "keeper timer" systemctl --user is-active flint-keeper.timer
  if [ "$SENSES" = 1 ]; then
    tee_chk "eyes: a webcam frame (flint-look desk)" bash -c "ls /dev/video* >/dev/null 2>&1 && f=\$(flint-look desk) && [ -s \"\$f\" ]"
    tee_chk "ears: the sound classifier hears silence as Silence" bash -c "python3 -c \"import wave; w=wave.open('/tmp/flint-silence.wav','wb'); w.setnchannels(1); w.setsampwidth(2); w.setframerate(16000); w.writeframes(bytes(32000)); w.close()\" && flint-ears test /tmp/flint-silence.wav | grep -qi silence"
    tee_chk "OCR reads text (flint-look text)" bash -c "python3 -c \"import cv2,numpy as np; img=np.full((120,600,3),255,np.uint8); cv2.putText(img,'FLINT ONLINE',(20,80),cv2.FONT_HERSHEY_SIMPLEX,2,(0,0,0),4); cv2.imwrite('/tmp/flint-ocr.png',img)\" 2>/dev/null || '$AGENT_HOME/senses/.venv/bin/python' -c \"import cv2,numpy as np; img=np.full((120,600,3),255,np.uint8); cv2.putText(img,'FLINT ONLINE',(20,80),cv2.FONT_HERSHEY_SIMPLEX,2,(0,0,0),4); cv2.imwrite('/tmp/flint-ocr.png',img)\"; flint-look text /tmp/flint-ocr.png | grep -qi 'flint'"
    tee_chk "voice anywhere: flint-say writes audio" bash -c "f=\$(flint-say --file /tmp/flint-say.wav 'Doctor test.') && [ -s /tmp/flint-say.wav ]"
    tee_chk "timers: flint-timer schedules and cancels" bash -c "out=\$(flint-timer 45m 'doctor test') && id=\$(echo \"\$out\" | grep -oE 'timer [0-9]+' | awk '{print \$2}') && flint-timer cancel \"\$id\" | grep -q cancelled"
    ls /dev/video* >/dev/null 2>&1 && tee_warn "presence: your face enrolled and the watcher running" bash -c "test -f '$HOME/.local/share/flint/faces/$YOUR_NAME.npy' && systemctl --user is-active flint-presence.service"
    tee_warn "listener service running" systemctl --user is-active flint-ears.service
  fi
  [ "$TELEGRAM" = 1 ] && tee_warn "Telegram bot reachable (token + /start)" flint-telegram status
  [ "$PHONE" = 1 ] && tee_warn "a phone paired over KDE Connect" bash -c "kdeconnect-cli -a --id-only 2>/dev/null | grep -q ."
  tee_warn "calendars or the Calendar connector" bash -c "flint-calendar today >/dev/null 2>&1 || claude mcp list 2>/dev/null | grep -qi 'calendar.*connected'"
  tee_warn "mail (flint-mail) or the Gmail connector" bash -c "[ -f '$HOME/.config/flint/mail.env' ] && grep -q MAIL_USER '$HOME/.config/flint/mail.env' || claude mcp list 2>/dev/null | grep -qi 'gmail.*connected'"
  [ "$HOME_ASSISTANT" = 1 ] && tee_warn "intercom: a Home Assistant media player to speak on" bash -c "flint-say --players | grep -q media_player"
  tee_warn "news feeds reachable (flint-news)" bash -c "timeout 120 flint-news --sources | grep -q http && timeout 120 flint-news | grep -q ."
  tee_chk "knowledge drop folder timer" systemctl --user is-active flint-ingest.timer
  [ "$GUARD" = 1 ] && tee_chk "guard: fail2ban up and a guard pass works" bash -c "systemctl is-active fail2ban && flint-guard check && flint-guard status | grep -q passes"
  [ "$BACKUP" = 1 ] && tee_chk "backup repository answers" bash -c "flint-backup status | grep -q 'last snapshot'"
  [ "$BACKUP" = 1 ] && tee_warn "a backup snapshot exists" bash -c "flint-backup snapshots | grep -qE '^[0-9a-f]{8} '"
  [ "$OFFLINE" = 1 ] && tee_warn "offline brain: ollama answers with the model" bash -c "flint-offline status && timeout 120 flint-offline ask 'what time is it' | grep -q say"
  tee_warn "browser: Playwright MCP drives Chrome with its own profile" bash -c "claude mcp get playwright | grep -q -- '--browser chrome'"
  tee_warn "MCP servers connect (playwright$( [ "$HOME_ASSISTANT" = 1 ] && printf ', home-assistant'))" mcp_test
  [ "$HOME_ASSISTANT" = 1 ] && tee_chk "Home Assistant API with the token" bash -c ". '$HOME/.config/flint/ha.env'; curl -fsS -m 5 -H \"Authorization: Bearer \$HA_TOKEN\" http://127.0.0.1:8123/api/ | grep -q 'API running'"
  [ "$AGENT_TIMERS" = 1 ] && tee_chk "agent timers scheduled" bash -c "ls '$HOME'/.config/systemd/user/flint-*.timer.made-by-team-timers >/dev/null 2>&1 && for m in '$HOME'/.config/systemd/user/flint-*.timer.made-by-team-timers; do systemctl --user is-active \"\$(basename \"\${m%.made-by-team-timers}\")\" >/dev/null || exit 1; done"
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
