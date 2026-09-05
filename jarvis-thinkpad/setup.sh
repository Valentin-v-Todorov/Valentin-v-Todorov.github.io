#!/usr/bin/env bash
# setup.sh: the whole Flint ThinkPad in one command, on a fresh Ubuntu 24.04 Desktop.
#
#   ~/site/jarvis-thinkpad/setup.sh            run every stage that is not done yet, in order
#   setup.sh --check                           only run the checks (the doctor), change nothing
#   setup.sh --list                            show the stages and which are done
#   setup.sh --from 05                         re-run from a stage onward
#   setup.sh --only 12                         re-run one stage
#   setup.sh --reset                           forget progress (does not uninstall anything)
#   setup.sh --continue                        what the post-reboot autostart runs; same as no flag
#
# Every stage is idempotent and ends with its own checks; a failed check stops the run
# with the reason. Fix it (or just re-run: most failures are network hiccups) and run
# setup.sh again; it continues where it stopped. Progress: ~/.flint-setup/done/, logs in
# ~/.flint-setup/logs/, your answers in ~/.flint-setup/setup.env (edit before the run to
# change any default; the defaults are the decisions in README.md).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL="$HERE/install"
STATE="$HOME/.flint-setup"; DONE="$STATE/done"; LOGS="$STATE/logs"; ENVF="$STATE/setup.env"
mkdir -p "$DONE" "$LOGS"

if [ "$(id -u)" = 0 ]; then echo "Run this as your normal user (it uses sudo where needed), not as root." >&2; exit 1; fi
if [ ! -f "$ENVF" ]; then
  cp "$INSTALL/setup.env.example" "$ENVF"; chmod 600 "$ENVF"
  echo "Created $ENVF from the example (defaults = the decisions in README.md). Edit it any time before a stage runs."
fi
chmod +x "$INSTALL"/*.sh "$INSTALL"/*.py 2>/dev/null || true

MODE=run; FROM=""; ONLY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --check) MODE=check ;;
    --list) MODE=list ;;
    --from) FROM="${2:?--from needs a stage number}"; shift ;;
    --only) ONLY="${2:?--only needs a stage number}"; shift ;;
    --reset) rm -rf "$DONE" "$STATE/reboot-needed" "$STATE/.apt-updated" "$STATE/stop"; mkdir -p "$DONE"; echo "progress forgotten"; exit 0 ;;
    --continue) : ;;
    -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac; shift
done

# stage numbers as typed by a human ("5") or as listed ("05")
[ -n "$FROM" ] && FROM="$(printf '%02d' "$((10#$FROM))")"
[ -n "$ONLY" ] && ONLY="$(printf '%02d' "$((10#$ONLY))")"
export FLINT_ONLY="$ONLY"            # a stage asked for by name runs even if setup.env says "later"
# a stop marker left by the reboot stage belongs to the run that rebooted, not to this one;
# the post-reboot autostart entry is consumed only by a run that actually continues
rm -f "$STATE/stop"
[ "$MODE" = run ] && rm -f "$HOME/.config/autostart/flint-setup-continue.desktop"

mapfile -t STAGES < <(ls "$INSTALL" | grep -E '^[0-9]{2}-.*\.sh$' | sort)
stage_num() { printf '%s' "$1" | cut -c1-2; }

if [ "$MODE" = list ]; then
  for s in "${STAGES[@]}"; do
    if [ -f "$DONE/$s" ]; then printf '  \033[1;32mdone\033[0m  %s\n' "$s"; else printf '  \033[1;33mtodo\033[0m  %s\n' "$s"; fi
  done; exit 0
fi

# keep sudo alive for the whole run (one password at the start; none at all once
# stage 00 has written the NOPASSWD rule, if you left that default on)
sudo -v
( while true; do sudo -n true 2>/dev/null || true; sleep 50; done ) &
KEEPALIVE=$!
trap 'kill $KEEPALIVE 2>/dev/null || true' EXIT

# every stage keeps the real terminal (the two browser logins and the Tailscale prompt need
# a TTY) while everything is still written to its log; without a TTY, plain tee
run_stage() {  # run_stage <stage file> <run|check> <log>
  if [ -t 1 ] && command -v script >/dev/null 2>&1; then script -q -e -f -a -c "bash '$INSTALL/$1' $2" "$3"
  else bash "$INSTALL/$1" "$2" 2>&1 | tee -a "$3"; fi
}

printf '\n\033[1;36mFlint ThinkPad setup\033[0m  %s  (%s)\n' "$(date '+%Y-%m-%d %H:%M')" "$HERE"
FAILED=0; MATCHED=0
for s in "${STAGES[@]}"; do
  n="$(stage_num "$s")"
  if [ -n "$ONLY" ] && [ "$n" != "$ONLY" ]; then continue; fi
  if [ -n "$FROM" ] && [ "$n" -lt "$FROM" ]; then continue; fi
  MATCHED=$((MATCHED+1))
  if [ "$MODE" = run ] && [ -z "$ONLY" ] && [ -z "$FROM" ] && [ -f "$DONE/$s" ]; then continue; fi
  printf '\n\033[1;35m######## %s\033[0m\n' "$s"
  logf="$LOGS/${s%.sh}.log"
  if [ "$MODE" = check ]; then
    run_stage "$s" check "$logf" || FAILED=$((FAILED+1))
    continue
  fi
  if run_stage "$s" run "$logf" && run_stage "$s" check "$logf"; then
    touch "$DONE/$s"
  else
    [ -f "$STATE/interrupted" ] && { rm -f "$STATE/interrupted"; exit 0; }
    printf '\n\033[1;31mstage %s did not pass its checks.\033[0m  Log: %s\n' "$s" "$logf"
    printf 'Fix what it printed (or just run setup.sh again: many failures are a download that timed out).\n'
    exit 1
  fi
  # a stage may have rebooted the machine (08); if it asked us to stop, stop
  [ -f "$STATE/stop" ] && { rm -f "$STATE/stop"; exit 0; }
done

[ "$MATCHED" = 0 ] && { echo "no such stage: ${ONLY:-$FROM} (see setup.sh --list)" >&2; exit 1; }
if [ "$MODE" = check ]; then
  [ "$FAILED" = 0 ] && printf '\n\033[1;32mdoctor: everything passes.\033[0m\n' || printf '\n\033[1;31mdoctor: %s stage(s) have failing checks.\033[0m\n' "$FAILED"
  exit "$FAILED"
fi
