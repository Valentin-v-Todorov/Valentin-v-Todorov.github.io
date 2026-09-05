#!/usr/bin/env bash
# flint-health.sh [--brief]: the machine and the stack in one report, for the agent and for you.
#   flint-health.sh          markdown: machine, power, network, audio/video, services, stack, agent, updates, errors
#   flint-health.sh --brief  one line: "ok (...)" or "N issue(s): ..."
# Exit 0 always; the issues list is the verdict. No sudo, no network beyond one reachability probe.
set -uo pipefail
export PATH="$HOME/.local/bin:/usr/local/bin:/usr/sbin:/sbin:$PATH"
SETUP="$HOME/.flint-setup"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/flint"
ISSUES=(); issue() { ISSUES+=("$1"); }
has() { command -v "$1" >/dev/null 2>&1; }
val() { cat "$1" 2>/dev/null | head -1; }
cfg() { sed -n "s/^$1=\"\{0,1\}\([^\"#]*\)\"\{0,1\}.*$/\1/p" "$SETUP/setup.env" 2>/dev/null | head -1; }
BRIEF=0; [ "${1:-}" = "--brief" ] && BRIEF=1
out() { [ "$BRIEF" = 1 ] || printf '%s\n' "$*"; }

# ---- machine
load="$(cut -d' ' -f1-3 /proc/loadavg 2>/dev/null)"
cores="$(nproc 2>/dev/null || echo 1)"
temp=""
if has sensors; then temp="$(sensors 2>/dev/null | grep -m1 -E 'Package id 0|Tctl|Tdie|CPU' | grep -oE '\+[0-9.]+°C' | head -1)"; fi
if [ -z "$temp" ]; then t="$(cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -n | tail -1)"; [ -n "$t" ] && temp="+$((t / 1000))°C"; fi
tnum="${temp#+}"; tnum="${tnum%°C}"; tnum="${tnum%%.*}"
[ -n "$tnum" ] && [ "$tnum" -ge 90 ] 2>/dev/null && issue "CPU at ${temp} (hot)"
mem="$(free -h 2>/dev/null | awk '/^Mem:/{print $3" used of "$2}')"
memp="$(free 2>/dev/null | awk '/^Mem:/{printf "%d", $3*100/$2}')"
[ -n "$memp" ] && [ "$memp" -ge 92 ] && issue "memory ${memp}% used"
disk="$(df -h / 2>/dev/null | awk 'NR==2{print $3" used of "$2" ("$5")"}')"
diskp="$(df / 2>/dev/null | awk 'NR==2{print $5}' | tr -d %)"
[ -n "$diskp" ] && [ "$diskp" -ge 90 ] && issue "disk ${diskp}% full"
out "# $(hostname) health, $(date '+%Y-%m-%d %H:%M')"
out ""
out "## Machine"
out "- up $(uptime -p 2>/dev/null | sed 's/^up //'), load $load on $cores cores${temp:+, CPU $temp}"
out "- memory: $mem; disk /: $disk"
out "- kernel $(uname -r), $(sed -n 's/^PRETTY_NAME="\(.*\)"/\1/p' /etc/os-release 2>/dev/null)"

# ---- power
bat=""; for b in /sys/class/power_supply/BAT*; do [ -d "$b" ] || continue
  cap="$(val "$b/capacity")"; st="$(val "$b/status")"; bat="${cap}% ($st)"
  [ "$st" = "Discharging" ] && [ "${cap:-100}" -le 15 ] && issue "battery ${cap}% and discharging"
  thr="$(val "$b/charge_control_start_threshold")-$(val "$b/charge_control_end_threshold")"; [ "$thr" != "-" ] && bat="$bat, thresholds $thr"
done
ac="unknown"; for a in /sys/class/power_supply/AC* /sys/class/power_supply/ADP*; do [ -f "$a/online" ] && { [ "$(val "$a/online")" = 1 ] && ac="plugged in" || ac="on battery"; }; done
[ "$ac" = "on battery" ] && issue "running on battery"
out ""
out "## Power"
out "- ${bat:-no battery}; mains: $ac"
lid="$(grep -m1 -h '^HandleLidSwitch=' /etc/systemd/logind.conf.d/*.conf 2>/dev/null | tail -1)"
susp="$(systemctl is-enabled suspend.target 2>/dev/null)"
out "- sleep/lid policy: ${lid:-default (!)} ; suspend target: ${susp:-?}"

# ---- network
iface="$(ip -4 route get 1.1.1.1 2>/dev/null | grep -oP 'dev \K\S+' | head -1)"
ipa="$(ip -4 route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+' | head -1)"
inet="down"; curl -fsS -m 6 -o /dev/null https://api.github.com/ 2>/dev/null && inet="up"
[ "$inet" = up ] || issue "no internet"
ts=""; if has tailscale; then ts="$(tailscale ip -4 2>/dev/null | head -1)"; ts="${ts:+tailscale $ts}"; [ -n "$ts" ] || ts="tailscale: not connected"; fi
out ""
out "## Network"
out "- ${iface:-no route} ${ipa:+($ipa)}, internet $inet${ts:+; $ts}"
has ufw && out "- firewall: $(sudo -n ufw status 2>/dev/null | head -1 || echo 'ufw (needs sudo to read)')"

# ---- audio / video
sink="$(pactl get-default-sink 2>/dev/null)"; src="$(pactl get-default-source 2>/dev/null)"
nsrc="$(pactl list short sources 2>/dev/null | grep -vc monitor)"
vol="$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | grep -oE '[0-9]+%' | head -1)"
[ -n "$sink" ] || issue "no audio output (PipeWire not reachable)"
[ "${nsrc:-0}" -ge 1 ] || issue "no microphone"
cams="$(ls /dev/video* 2>/dev/null | tr '\n' ' ')"
out ""
out "## Audio and camera"
out "- output: ${sink:-none}${vol:+ at $vol}; input: ${src:-none} (${nsrc:-0} mic(s))"
out "- camera: ${cams:-none}"

# ---- services
svc() { systemctl is-active "$1" 2>/dev/null || echo inactive; }
usvc() { systemctl --user is-active "$1" 2>/dev/null || echo inactive; }
out ""
out "## Services"
out "- system: ssh $(svc ssh), tailscaled $(svc tailscaled), docker $(svc docker), tlp $(svc tlp)"
if [ -f "$HOME/homeassistant/compose.yaml" ] && has docker; then
  hst="$(docker ps --filter name=homeassistant --format '{{.Status}}' 2>/dev/null | head -1)"
  if [ -n "$hst" ]; then out "- home assistant: $hst"; else issue "Home Assistant container not running"; out "- home assistant: NOT RUNNING (docker compose -f ~/homeassistant/compose.yaml up -d)"; fi
fi
timers="$(systemctl --user list-timers --no-legend 'flint-*' 2>/dev/null | wc -l)"
out "- user: remote control $(usvc flint-rc.service), keeper $(usvc flint-keeper.timer), vault backup $(usvc flint-vault-backup.timer), $timers flint timers"
[ "$(cfg REMOTE_CONTROL)" = 0 ] || [ "$(usvc flint-rc.service)" = active ] || issue "remote control (flint-rc.service) not active"

# ---- the stack
voice=down; pgrep -f 'backtalk[.]main' >/dev/null 2>&1 && voice=up
face="$(curl -fsS -m 2 http://127.0.0.1:8790/state 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin).get("state","?"))' 2>/dev/null || echo down)"
hands=down; curl -fsS -m 2 -o /dev/null http://127.0.0.1:8794/stage.html 2>/dev/null && hands=up
music="$(flint-play status 2>/dev/null || true)"
offmark=""; [ -f "$SETUP/stack-off" ] && offmark=" (stopped on purpose)"
out ""
out "## The stack"
out "- voice line $voice$offmark, face $face, hands $hands"
out "- music: ${music:-nothing playing}"
if [ "$voice" = down ] && [ -z "$offmark" ] && [ "$(cfg AUTOSTART_STACK)" != 0 ] && pgrep -x gnome-shell -u "$(id -u)" >/dev/null 2>&1; then issue "voice line down (the keeper restarts it within 2 minutes)"; fi
[ -f "$STATE/keeper-gave-up" ] && issue "the keeper gave up restarting the stack (flint-stack start after fixing it)"
[ -f "$STATE/keeper.log" ] && out "- keeper: $(tail -1 "$STATE/keeper.log")"

# ---- the agent
out ""
out "## The agent"
out "- claude $(claude --version 2>/dev/null | head -1 || echo 'not on PATH'); login store: $( [ -f "$HOME/.claude/.credentials.json" ] && echo present || echo 'missing (claude auth login)')"
has claude || issue "claude not on PATH"
[ -f "$HOME/.claude/.credentials.json" ] || issue "Claude Code not logged in"
AH="$(cfg AGENT_HOME)"; AH="${AH:-$HOME/my-agent}"; AH="${AH/#\$HOME/$HOME}"
if [ -f "$AH/backtalk/backtalk.json" ]; then
  out "- voice config: $(python3 -c "
import json; d=json.load(open('$AH/backtalk/backtalk.json'))
print('mic', d.get('mic_mode','ptt'), '| key', d.get('ptt_key','home'), '| voice', d.get('voice','bm_lewis'), '| wake', ', '.join(d.get('wake_words') or [d.get('name','?')]), '| permissions', d.get('permission_mode','ask'))" 2>/dev/null)"
fi
vault="$(cfg VAULT_DIR)"; vault="${vault:-$HOME/Brain}"; vault="${vault/#\$HOME/$HOME}"
[ -d "$vault/.git" ] && out "- vault: $(git -C "$vault" log -1 --format='last commit %cr' 2>/dev/null), $(git -C "$vault" status --porcelain 2>/dev/null | wc -l) uncommitted change(s)"

# ---- updates and errors
upg="$(apt-get -s upgrade 2>/dev/null | grep -c '^Inst')"
out ""
out "## Updates and errors"
out "- apt: ${upg:-?} package(s) upgradable$( [ -f /var/run/reboot-required ] && printf '; REBOOT REQUIRED')"
[ -f /var/run/reboot-required ] && issue "reboot required (kernel or firmware)"
errs="$(journalctl -p 3 -b -q --no-pager 2>/dev/null | wc -l)"
out "- journal errors this boot: ${errs:-?}"
[ "${errs:-0}" -gt 0 ] && out "$(journalctl -p 3 -b -q --no-pager -n 3 -o cat 2>/dev/null | sed 's/^/  - /')"
if [ -f "$SETUP/report.md" ]; then
  fails="$(grep -c '✗' "$SETUP/report.md")"
  out "- last doctor: $(head -1 "$SETUP/report.md" | sed 's/^# //'), $fails failure(s)"
  [ "$fails" -gt 0 ] && issue "the last doctor report has $fails failure(s) (~/.flint-setup/report.md)"
fi

# ---- verdict
out ""
if [ "${#ISSUES[@]}" = 0 ]; then
  line="ok (voice $voice, face $face, ${bat:-no battery}, $ac, disk ${diskp:-?}%, internet $inet)"
  out "## Verdict"; out "- $line"; [ "$BRIEF" = 1 ] && echo "$line"
else
  line="${#ISSUES[@]} issue(s): $(printf '%s; ' "${ISSUES[@]}" | sed 's/; $//')"
  out "## Verdict"; for i in "${ISSUES[@]}"; do out "- $i"; done; [ "$BRIEF" = 1 ] && echo "$line"
fi
exit 0
