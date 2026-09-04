#!/usr/bin/env bash
# lib.sh: shared helpers for the staged installer. Every stage sources this file.
# Stages define run() and check(); stage_main dispatches "run" | "check" | both.
set -euo pipefail

: "${USER:=$(id -un)}"; export USER            # not set in every context (autostart, systemd)
: "${HOME:=$(getent passwd "$USER" | cut -d: -f6)}"; export HOME
INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GUIDE_DIR="$(cd "$INSTALL_DIR/.." && pwd)"
STATE_DIR="$HOME/.flint-setup"
ENV_FILE="$STATE_DIR/setup.env"
LOG_DIR="$STATE_DIR/logs"
DONE_DIR="$STATE_DIR/done"
mkdir -p "$STATE_DIR" "$LOG_DIR" "$DONE_DIR"
export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a           # never pop the "which services to restart" dialog

# ------------------------------------------------------------------ config
# sourced, not exported: an optional key in setup.env (TS_AUTHKEY) must not reach every
# child process; the values the stages' children need are exported by name below
if [ -f "$ENV_FILE" ]; then . "$ENV_FILE"; fi
: "${YOUR_NAME:=Valentin}"
: "${AGENT_NAME:=Flint}"
: "${AGENT_HOME:=$HOME/my-agent}"
: "${VAULT_DIR:=$HOME/Brain}"
: "${IDENTITY_DOOR:=B}"
: "${PTT_KEY:=home}"
: "${MIC_MODE:=open}"                    # open = always listening, but only for its name (the wake phrase); the key still works
: "${WAKE_WORDS:=}"                      # empty = the agent's name and "hey <name>" (the transcriber's near-misses match too)
: "${WAKE_WINDOW_S:=30}"
: "${VOICE_EFFORT:=}"                    # "" = the model's default; "low" is the fastest spoken reply
: "${VOICE:=bm_lewis}"
: "${STT_MODEL:=small.en}"
: "${VOICE_PERMISSIONS:=ask}"
: "${FACE:=core}"
: "${TIMEZONE:=}"
: "${HOSTNAME_WANTED=thinkpad}"          # empty in setup.env = keep the hostname the installer chose
: "${GIT_NAME:=$YOUR_NAME}"
: "${GIT_EMAIL:=}"
: "${SUDO_NOPASSWD:=1}"
: "${TAILSCALE:=1}"
: "${TS_AUTHKEY:=}"
: "${DOCKER:=1}"
: "${HOME_ASSISTANT:=1}"
: "${HA_USER:=}"
: "${CLAUDE_DESKTOP:=1}"
: "${GITHUB_CLI:=1}"
: "${VSCODE:=0}"
: "${AUTOSTART_STACK:=1}"
: "${REMOTE_CONTROL:=1}"
: "${AGENT_TIMERS:=1}"
: "${VAULT_GIT:=1}"
: "${TIMESHIFT_SNAPSHOT:=1}"
: "${FIRMWARE_UPDATE:=1}"
: "${UFW:=1}"
: "${ACCOUNTS_LATER:=0}"
: "${WIZARD_MODE:=headless}"
: "${MUSIC:=1}"                          # mpv + yt-dlp + flint-play (music by request, YouTube or local files)
: "${KEEPER:=1}"                         # the watchdog timer that restarts a dead stack
: "${SENSES:=1}"                         # the camera watcher (your face), the listener (sounds), OCR, timers, the intercom
: "${PHONE:=1}"                          # KDE Connect: the phone's SMS, notifications, battery, ring, share
: "${TELEGRAM:=1}"                       # the Telegram bot (token from @BotFather: setup.env or flint-telegram setup)
: "${TELEGRAM_BOT_TOKEN:=}"
: "${GUARD:=1}"                          # fail2ban, LAN watch, motion while away
: "${BACKUP:=1}"                         # restic nightly + monthly restore test
: "${BACKUP_REPO:=}"                     # empty = the first external disk under /media, else ~/Backups/restic
: "${OFFLINE:=1}"                        # Ollama + a small model for when the cloud is out
: "${OFFLINE_MODEL:=qwen2.5:3b}"
: "${YOUR_WORK:=I run a personal business and I am building an AI operating partner on this ThinkPad.}"
: "${PROJECTS:=Personal Business; Home Automation; ThinkPad (this machine, the server the agent runs on)}"
: "${KEY_PEOPLE:=}"
: "${PRIORITIES:=Get the agent, the team and the home automation working end to end}"
: "${RECURRING:=Morning brief; Inbox triage; Weekly finance review; Vault backup}"
export YOUR_NAME AGENT_NAME AGENT_HOME VAULT_DIR PTT_KEY MIC_MODE VOICE STT_MODEL VOICE_PERMISSIONS FACE WAKE_WORDS WAKE_WINDOW_S VOICE_EFFORT MUSIC KEEPER
export SENSES PHONE TELEGRAM GUARD BACKUP OFFLINE OFFLINE_MODEL
# the machine's secrets (chmod 600 files written by the stages) as environment, by name
for _f in "$HOME"/.config/flint/*.env; do [ -f "$_f" ] && { set -a; . "$_f"; set +a; }; done; unset _f

# ------------------------------------------------------------------ output
if [ -t 1 ]; then C_H=$'\033[1;36m'; C_OK=$'\033[1;32m'; C_W=$'\033[1;33m'; C_E=$'\033[1;31m'; C_0=$'\033[0m'; else C_H=""; C_OK=""; C_W=""; C_E=""; C_0=""; fi
log()  { printf '\n%s== %s%s\n' "$C_H" "$*" "$C_0"; }
ok()   { printf '   %s%s%s\n' "$C_OK" "$*" "$C_0"; }
warn() { printf '   %s%s%s\n' "$C_W" "$*" "$C_0"; }
err()  { printf '   %s%s%s\n' "$C_E" "$*" "$C_0" >&2; }
die()  { err "$*"; exit 1; }
say()  { printf '   %s\n' "$*"; }

# ------------------------------------------------------------------ helpers
has() { command -v "$1" >/dev/null 2>&1; }
in_group() { id -nG "$USER" | tr ' ' '\n' | grep -qx "$1"; }
pkg_installed() { dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"; }
# sudo resets the environment, so the non-interactive flags must ride on the command itself;
# apt-get does not wait for the dpkg lock by default (the first minutes after a fresh login
# are exactly when apt-daily and unattended-upgrades hold it), so it waits up to 10 minutes
aptget() { sudo env DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a apt-get -o DPkg::Lock::Timeout=600 -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold "$@"; }
apt_update_once() { if [ ! -f "$STATE_DIR/.apt-updated" ] || [ "$(( $(date +%s) - $(stat -c %Y "$STATE_DIR/.apt-updated") ))" -gt 3600 ]; then aptget update -qq; touch "$STATE_DIR/.apt-updated"; fi; }
apt_install() {           # apt_install pkg...   (retries once; skips what is present)
  local want=() p
  for p in "$@"; do pkg_installed "$p" || want+=("$p"); done
  [ "${#want[@]}" = 0 ] && return 0
  apt_update_once
  aptget install -y -qq --no-install-recommends "${want[@]}" || { sleep 5; aptget install -y -qq --no-install-recommends "${want[@]}"; }
}
apt_install_full() {      # with recommends (desktop apps want them)
  local want=() p
  for p in "$@"; do pkg_installed "$p" || want+=("$p"); done
  [ "${#want[@]}" = 0 ] && return 0
  apt_update_once
  aptget install -y -qq "${want[@]}" || { sleep 5; aptget install -y -qq "${want[@]}"; }
}
mark_reboot() { echo "$1" >> "$STATE_DIR/reboot-needed"; warn "reboot needed later: $1"; }
reboot_needed() { [ -s "$STATE_DIR/reboot-needed" ]; }
json_get() {              # json_get file key   (top-level key; prints "" if absent)
  python3 - "$1" "$2" <<'PY'
import json, sys
try:
    v = json.load(open(sys.argv[1])).get(sys.argv[2], "")
    print(v if isinstance(v, str) else json.dumps(v))
except Exception:
    print("")
PY
}
json_set() {              # json_set file key value-as-json   (creates the file; keeps other keys)
  python3 - "$1" "$2" "$3" <<'PY'
import json, os, sys
p, k, v = sys.argv[1:4]
try:
    d = json.load(open(p))
except Exception:
    d = {}
d[k] = json.loads(v)
os.makedirs(os.path.dirname(p) or ".", exist_ok=True)
tmp = p + ".tmp"
json.dump(d, open(tmp, "w"), indent=2); os.replace(tmp, p)
PY
}
session_is_x11() { [ "${XDG_SESSION_TYPE:-}" = "x11" ]; }
net_ok() {                # is https://api.github.com reachable, with whatever tool this machine has
  if has curl; then curl -fsS -m 10 -o /dev/null https://api.github.com/ 2>/dev/null && return 0; fi
  if has wget; then wget -q --spider --timeout=10 https://api.github.com/ 2>/dev/null && return 0; fi
  python3 -c 'import urllib.request; urllib.request.urlopen("https://api.github.com/", timeout=10)' 2>/dev/null
}
export -f has in_group pkg_installed json_get json_set session_is_x11 aptget net_ok      # usable inside `bash -c` checks too
have_display() { [ -n "${DISPLAY:-}" ] && [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]; }
wait_http() {             # wait_http url seconds
  local i=0; while [ $i -lt "$2" ]; do curl -fsS -m 3 -o /dev/null "$1" 2>/dev/null && return 0; sleep 2; i=$((i+2)); done; return 1
}
term_run() {              # open a visible terminal window that runs a command (falls back to plain run)
  if have_display && has gnome-terminal; then gnome-terminal --wait -- bash -lc "$1"; else bash -lc "$1"; fi
}
append_once() {           # append_once file marker-heading <<content   (adds the block unless the marker is already there)
  local f="$1" marker="$2" body; body="$(cat)"
  grep -qF "$marker" "$f" 2>/dev/null || printf '\n%s\n' "$body" >> "$f"
}

# ------------------------------------------------------------------ checks
CHECK_FAILS=0; CHECK_TOTAL=0
chk() {                   # chk "what" cmd args...   -> prints a tick or a cross, counts failures
  local what="$1"; shift
  CHECK_TOTAL=$((CHECK_TOTAL+1))
  if "$@" >/dev/null 2>&1; then printf '   %s✓%s %s\n' "$C_OK" "$C_0" "$what"; return 0
  else printf '   %s✗%s %s\n' "$C_E" "$C_0" "$what"; CHECK_FAILS=$((CHECK_FAILS+1)); return 1; fi
}
chk_warn() {              # like chk, but a failure is only a warning (optional feature)
  local what="$1"; shift
  if "$@" >/dev/null 2>&1; then printf '   %s✓%s %s\n' "$C_OK" "$C_0" "$what"; else printf '   %s~%s %s (optional)\n' "$C_W" "$C_0" "$what"; fi
  return 0
}
checks_done() { if [ "$CHECK_FAILS" = 0 ]; then ok "all $CHECK_TOTAL checks passed"; return 0; else err "$CHECK_FAILS of $CHECK_TOTAL checks failed"; return 1; fi; }

# run() stops at the first real failure (errexit). check() must run every check and
# report all of them, so errexit is off while it runs; checks_done decides the verdict.
stage_main() {
  local __stage_rc=0                    # a name no stage's own variables can shadow (bash scoping is dynamic)
  case "${1:-both}" in
    run)   run ;;
    check) set +e; check; __stage_rc=$?; set -e ;;
    both)  run; set +e; check; __stage_rc=$?; set -e ;;
    *) die "usage: $0 run|check" ;;
  esac
  return "$__stage_rc"
}
