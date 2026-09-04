#!/usr/bin/env bash
# 13: the senses. A second virtualenv with OpenCV (face detection and recognition), the YAMNet sound
# classifier, article extraction, calendars and feeds; the models; OCR and PDF text; the presence watcher
# (camera) and the listener (microphone) as user services; your face enrolled. All local.
. "$(dirname "$0")/lib.sh"
SENSES_DIR="$AGENT_HOME/senses"; VENV="$SENSES_DIR/.venv"; MODELS="$HOME/.local/share/flint/models"
PIP_PKGS="numpy opencv-python-headless ai-edge-litert sounddevice trafilatura icalendar recurring-ical-events feedparser"

install_tools() {
  mkdir -p "$AGENT_HOME/bin" "$HOME/.local/bin"
  cp "$GUIDE_DIR"/bin/flint-* "$AGENT_HOME/bin/" && chmod +x "$AGENT_HOME"/bin/flint-*
  for t in "$GUIDE_DIR"/bin/flint-*; do ln -sfn "$AGENT_HOME/bin/$(basename "$t")" "$HOME/.local/bin/$(basename "$t")"; done
}

run() {
  [ "$SENSES" = 1 ] || { say "SENSES=0 in setup.env: skipped"; return 0; }
  [ -f "$AGENT_HOME/CLAUDE.md" ] || die "no agent in $AGENT_HOME (stage 09 first)"

  log "packages: OCR, PDF text, a text browser"
  apt_install tesseract-ocr tesseract-ocr-eng poppler-utils lynx
  ok "tesseract, pdftotext, lynx"

  log "the senses virtualenv (opencv, the sound classifier, feeds, calendars, article extraction)"
  mkdir -p "$SENSES_DIR"
  [ -x "$VENV/bin/python" ] || uv venv "$VENV" --python 3.12 -q >"$LOG_DIR/senses-venv.log" 2>&1 || die "uv venv failed: $LOG_DIR/senses-venv.log"
  # shellcheck disable=SC2086
  uv pip install --python "$VENV/bin/python" -q $PIP_PKGS >"$LOG_DIR/senses-pip.log" 2>&1 || die "pip into $VENV failed: $LOG_DIR/senses-pip.log"
  ok "$("$VENV/bin/python" -c 'import cv2, numpy; print("opencv", cv2.__version__, "numpy", numpy.__version__)')"

  log "models: face detection and recognition (OpenCV zoo), YAMNet sounds (MediaPipe), the class list"
  mkdir -p "$MODELS"
  fetch() { [ -s "$MODELS/$1" ] && return 0; curl -fsSL --retry 3 -m 600 -o "$MODELS/$1.part" "$2" && mv "$MODELS/$1.part" "$MODELS/$1"; }
  fetch face_detection_yunet_2023mar.onnx https://media.githubusercontent.com/media/opencv/opencv_zoo/main/models/face_detection_yunet/face_detection_yunet_2023mar.onnx || warn "YuNet download failed (flint-presence downloads it on first use)"
  fetch face_recognition_sface_2021dec.onnx https://media.githubusercontent.com/media/opencv/opencv_zoo/main/models/face_recognition_sface/face_recognition_sface_2021dec.onnx || warn "SFace download failed"
  fetch yamnet.tflite https://storage.googleapis.com/mediapipe-models/audio_classifier/yamnet/float32/latest/yamnet.tflite || warn "YAMNet download failed"
  fetch yamnet_class_map.csv https://raw.githubusercontent.com/tensorflow/models/master/research/audioset/yamnet/yamnet_class_map.csv || warn "class map download failed"
  ok "$(ls "$MODELS" 2>/dev/null | wc -l) model files in $MODELS"

  log "the tools (every bin/flint-*), linked into ~/.local/bin"
  install_tools; ok "installed"

  log "services: the presence watcher (camera) and the listener (microphone)"
  mkdir -p "$HOME/.config/systemd/user"
  for svc in presence ears; do
    cat > "$HOME/.config/systemd/user/flint-$svc.service" <<EOF
[Unit]
Description=$AGENT_NAME $svc
After=graphical-session.target
[Service]
Environment=PATH=%h/.local/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=$AGENT_HOME/bin/flint-$svc watch
Restart=on-failure
RestartSec=30
[Install]
WantedBy=default.target
EOF
  done
  systemctl --user daemon-reload 2>/dev/null || true
  if ls /dev/video* >/dev/null 2>&1; then systemctl --user enable flint-presence.service >/dev/null 2>&1 && ok "flint-presence.service enabled (starts at login)" || warn "could not enable flint-presence.service"
  else warn "no camera found: flint-presence.service written but not enabled (systemctl --user enable --now flint-presence when one exists)"; fi
  if arecord -l 2>/dev/null | grep -q '^card'; then systemctl --user enable flint-ears.service >/dev/null 2>&1 && ok "flint-ears.service enabled" || warn "could not enable flint-ears.service"
  else warn "no microphone found: flint-ears.service not enabled"; fi

  if ls /dev/video* >/dev/null 2>&1 && [ ! -f "$HOME/.local/share/flint/faces/$YOUR_NAME.npy" ]; then
    log "your face (so he greets you by name and knows when the desk is empty)"
    if [ -t 0 ]; then
      say "look at the camera for six seconds and turn your head a little. Enrol now? [Y/n] (Y in 20 s; later: flint-presence enrol $YOUR_NAME)"
      read -r -t 20 ans || ans=y
      if [ "${ans:-y}" != n ] && [ "${ans:-y}" != N ]; then
        "$AGENT_HOME/bin/flint-presence" enrol "$YOUR_NAME" 2>&1 | tail -2 || warn "enrolment failed; later: flint-presence enrol $YOUR_NAME"
      fi
    else warn "no terminal to enrol from; later: flint-presence enrol $YOUR_NAME"; fi
  fi
  if have_display; then systemctl --user start flint-presence.service flint-ears.service >/dev/null 2>&1 || true; fi

  append_once "$AGENT_HOME/CLAUDE.md" "## Your senses" <<EOF
## Your senses
- Eyes: \`flint-look desk\` (a webcam frame; then read the image), \`flint-look screen\`, \`flint-look window "title"\`,
  \`flint-look text\` (what the screen says, by OCR), \`flint-look phone\` (the phone's camera). "What is on my desk?" means
  flint-look desk and read it back in one or two sentences.
- Presence: \`flint-presence status\` says whether $YOUR_NAME is at the desk (the watcher greets on arrival, pauses the
  music when the desk empties, flags an unknown face). Enrol someone new: \`flint-presence enrol "<name>"\` (they must
  agree, and look at the camera for six seconds).
- Ears: the listener (\`flint-ears\`) hears a doorbell, a knock, glass, a smoke alarm, a siren, crying, a dog, and alerts by
  itself through \`flint-notify\`. \`flint-notify --log\` shows what happened; answer "what happened while I was out" from it.
- Voice anywhere: \`flint-say "text"\` speaks here; \`flint-say --to media_player.kitchen "text"\` speaks on a Home
  Assistant speaker; \`flint-say --to all\` everywhere; \`flint-say --players\` lists them.
- Timers: \`flint-timer 10m "the pasta"\`, \`flint-timer at 07:30 "wake up"\`, \`flint-timer list\`, \`flint-timer cancel <id>\`.
  They outlive you: the machine speaks and notifies when they fire.
EOF
  ok "CLAUDE.md: your senses"
}

check() {
  [ "$SENSES" = 1 ] || { ok "senses off"; return 0; }
  chk "senses virtualenv imports" "$VENV/bin/python" -c "import cv2, numpy, ai_edge_litert, trafilatura, icalendar, recurring_ical_events, feedparser, sounddevice"
  chk "models present" bash -c "for f in face_detection_yunet_2023mar.onnx face_recognition_sface_2021dec.onnx yamnet.tflite yamnet_class_map.csv; do [ -s '$MODELS'/\$f ] || exit 1; done"
  chk "face detector and recogniser load" "$VENV/bin/python" -c "import cv2; cv2.FaceDetectorYN.create('$MODELS/face_detection_yunet_2023mar.onnx','',(320,240)); cv2.FaceRecognizerSF.create('$MODELS/face_recognition_sface_2021dec.onnx','')"
  chk "the listener classifies (a second of silence -> Silence)" bash -c "python3 -c \"import wave; w=wave.open('/tmp/flint-silence.wav','wb'); w.setnchannels(1); w.setsampwidth(2); w.setframerate(16000); w.writeframes(bytes(32000)); w.close()\" && '$AGENT_HOME/bin/flint-ears' test /tmp/flint-silence.wav | grep -qi silence"
  chk "tesseract + pdftotext" bash -c "has tesseract && has pdftotext"
  chk "tools on PATH (flint-look, flint-say, flint-notify, flint-timer)" bash -c "for t in flint-look flint-say flint-notify flint-timer flint-presence flint-ears; do [ -x '$HOME/.local/bin/'\$t ] || exit 1; done"
  chk "CLAUDE.md has the senses section" grep -q "flint-look desk" "$AGENT_HOME/CLAUDE.md"
  chk_warn "your face enrolled" test -f "$HOME/.local/share/flint/faces/$YOUR_NAME.npy"
  ls /dev/video* >/dev/null 2>&1 && chk_warn "presence watcher running" systemctl --user is-active flint-presence.service
  arecord -l 2>/dev/null | grep -q '^card' && chk_warn "listener running" systemctl --user is-active flint-ears.service
  checks_done
}
stage_main "$@"
