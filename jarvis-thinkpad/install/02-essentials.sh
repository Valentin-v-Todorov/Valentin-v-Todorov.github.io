#!/usr/bin/env bash
# 02: every system package the stack needs, in one apt call. Nothing from the Jared repos yet.
. "$(dirname "$0")/lib.sh"

PKGS=(
  # build and scripting basics
  build-essential git curl wget ca-certificates gnupg jq unzip zip tmux htop tree ripgrep fd-find net-tools dnsutils
  python3 python3-venv python3-dev python3-pip pipx
  # the voice: Kokoro phonemizes through espeak-ng, sounddevice needs PortAudio, ElevenLabs needs ffmpeg
  espeak-ng libespeak-ng1 libportaudio2 portaudio19-dev ffmpeg libsndfile1
  # audio and camera tooling for tests and for the agent
  alsa-utils pulseaudio-utils pipewire-audio v4l-utils
  # secrets and the Claude Code sandbox
  libsecret-tools gnome-keyring bubblewrap socat
  # the agent's hands on the desktop (X11 session)
  xdotool wmctrl playerctl libnotify-bin xclip x11-utils x11-xserver-utils gnome-screenshot dconf-cli dbus-x11
  # server things
  openssh-server ufw tlp avahi-daemon libnss-mdns qrencode lm-sensors usbutils pciutils
  # apps and their helpers
  libfuse2t64 timeshift gnome-tweaks xdg-utils fonts-inter
  # music by request (flint-play): mpv plays, mpv-mpris lets playerctl see it; yt-dlp comes from uv in stage 05
  mpv mpv-mpris
)

run() {
  log "apt packages"
  apt_install_full "${PKGS[@]}" || { warn "one package name failed; installing one by one"; for p in "${PKGS[@]}"; do apt_install_full "$p" || warn "not available: $p"; done; }
  ok "system packages present"
  has fdfind && [ ! -e "$HOME/.local/bin/fd" ] && { mkdir -p "$HOME/.local/bin"; ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"; }
  local pyv; pyv="$(python3 -c 'import sys;print(f"{sys.version_info[0]}.{sys.version_info[1]}")')"
  case "$pyv" in 3.11|3.12) ok "python $pyv (backtalk wants 3.11 or 3.12)" ;; *) warn "python $pyv: backtalk needs <3.13; stage 05 pins a managed 3.12 with uv" ;; esac
  if ! grep -q 'jarvis-thinkpad: PATH' "$HOME/.bashrc" 2>/dev/null; then
    printf '\n# jarvis-thinkpad: PATH for uv, claude and the agent tools\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$HOME/.bashrc"
  fi
  if ! grep -q 'jarvis-thinkpad: PATH' "$HOME/.profile" 2>/dev/null; then
    printf '\n# jarvis-thinkpad: PATH for uv, claude and the agent tools\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$HOME/.profile"
  fi
  ok "~/.local/bin on PATH for shells and the desktop session"
}

check() {
  for c in git curl python3 espeak-ng ffmpeg arecord pactl secret-tool bwrap socat xdotool wmctrl notify-send tmux jq rg ufw qrencode mpv playerctl; do
    chk "$c" has "$c"
  done
  for p in tlp openssh-server timeshift libfuse2t64 avahi-daemon libnss-mdns fd-find pipx alsa-utils v4l-utils; do chk "package $p" pkg_installed "$p"; done
  chk "python 3.11 or 3.12 (or uv-managed 3.12 later)" python3 -c 'import sys; assert sys.version_info[:2] in ((3,11),(3,12))'
  chk "libespeak-ng.so.1 installed" bash -c 'ldconfig -p | grep -q libespeak-ng.so.1'
  chk "portaudio library" bash -c 'ldconfig -p | grep -q portaudio'
  checks_done
}
stage_main "$@"
