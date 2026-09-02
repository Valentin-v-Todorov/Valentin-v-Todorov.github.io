# The installer: one command, fifteen stages, a check after each

```bash
sudo apt-get install -y git
git clone -b claude/jarvis-thinkpad-setup-9a3aiv https://github.com/Valentin-v-Todorov/Valentin-v-Todorov.github.io.git ~/site
~/site/jarvis-thinkpad/setup.sh
```

That is the whole install on a fresh Ubuntu 24.04 Desktop. It asks for your
password once (sudo), opens a browser twice for logins only you can do (Claude
with your Max plan, GitHub), shows a Tailscale link once, reboots once and
continues by itself after the automatic login, then runs the doctor and starts
the stack. Budget about 1.5 to 2 hours, most of it downloads.

## How it works

`setup.sh` runs `install/NN-*.sh` in numeric order. Each stage is one bash
process that sources `install/lib.sh`, defines `run()` (idempotent: safe to
repeat) and `check()` (what must be true afterwards), and is called as
`bash NN.sh run` then `bash NN.sh check`. A stage is marked done in
`~/.flint-setup/done/` only when its checks pass; a failing check stops the run
with the reason and the log path. Re-running `setup.sh` continues where it
stopped. Your answers live in `~/.flint-setup/setup.env` (created from
`setup.env.example`; every value has a default from the decisions in the
README). Logs: `~/.flint-setup/logs/`. Report: `~/.flint-setup/report.md`.

| Stage | Does | Needs you |
| --- | --- | --- |
| 00 preflight | Ubuntu 24.04 check, internet, disk, power, sudo (one password; then a NOPASSWD rule if `SUDO_NOPASSWD=1`), git identity, timezone, hostname | the sudo password, once |
| 01 system-update | `apt full-upgrade`, autoremove, unattended security updates, Lenovo firmware via fwupd | no |
| 02 essentials | every apt package the stack needs (python 3.12, espeak-ng, PortAudio, ffmpeg, audio/video tools, bubblewrap+socat, xdotool and friends, ssh, ufw, tlp, timeshift, fonts) and `~/.local/bin` on PATH | no |
| 03 desktop | GDM auto-login on the Xorg session (push-to-talk needs X11), never sleep, no lock, dark theme, TLP battery thresholds 75–80 % | no |
| 04 remote-access | sshd, an ssh key, ufw (SSH, mDNS, 8123), Tailscale with `--ssh` | open the Tailscale link once (or put `TS_AUTHKEY` in setup.env) |
| 05 dev-tools | uv, Claude Code (native installer) + the bwrap AppArmor profile, Node 22, GitHub CLI, Docker, groups (input, dialout, video, kvm, docker) | no |
| 06 apps | Obsidian (.deb, not launched), Chrome, Claude Desktop (beta), VS Code (off by default) | no |
| 07 accounts | `claude auth login` with the subscription; `gh auth login` | the two browser logins (skip with `ACCOUNTS_LATER=1`) |
| 08 reboot | one reboot for groups, the Xorg session, firmware and kernel; an autostart entry reopens a terminal and continues | nothing: it continues by itself |
| 09 flint-wizard | Jared's `fullstack-agent` installer, headless (`claude -p` with every answer pre-supplied); then the configs pinned to the decisions, the vault registered in Obsidian, the speech models fetched | no (`WIZARD_MODE=interactive` if you want to watch) |
| 10 flint-wire | Desktop launchers, the Orbitals face as default + the roster + the live hooks, CLAUDE.md additions (team on screen, machine toolbox), Claude Code user settings (auto mode, deny list, vault access, sandbox), Playwright MCP, secrets loaded from `~/.config/flint/*.env`, hourly vault git commits, Remote Control in tmux, the stack at every login | no |
| 11 agent-team | `team.yaml` → subagent files and systemd user timers (morning brief, weekly finance, vault hygiene) | no |
| 12 home-assistant | Home Assistant Container (compose), onboarding over its REST API, long-lived token, the MCP Server integration, `.mcp.json` for the agent, port 8123 open on the LAN | no |
| 13 doctor | real tests: Kokoro speaks through the speakers, faster-whisper transcribes, face and hands servers answer, the agent boots as Flint and its hooks record the turn, MCP servers connect, HA API answers, timers, firewall; report; Timeshift snapshot | no |
| 14 finish | prints the map, starts the stack; Flint says hello | no |

## Commands

```bash
setup.sh              # continue / run everything not done yet
setup.sh --check      # the doctor: only checks, changes nothing
setup.sh --list       # stages and their state
setup.sh --only 12    # redo one stage (they are all idempotent)
setup.sh --from 09    # redo from a stage onward
setup.sh --reset      # forget progress (uninstalls nothing)
```

## What you can change before running

Edit `~/.flint-setup/setup.env` (or `install/setup.env.example` before the
first run). The important ones: `IDENTITY_DOOR` (B keeps Jared's personality
with the name Flint, C is the calmer one), `PTT_KEY`, `VOICE_PERMISSIONS`
(`ask` first; `bypassPermissions` when you trust him), `HOME_ASSISTANT`,
`SUDO_NOPASSWD`, `AUTOSTART_STACK`, `REMOTE_CONTROL`, `AGENT_TIMERS`, and the
five vault-interview answers (`YOUR_WORK`, `PROJECTS`, `KEY_PEOPLE`,
`PRIORITIES`, `RECURRING`) that become the agent's first profile of you.

## Secrets

Nothing secret is in this repo or in the vault. The install creates
`~/.config/flint/` (700) and writes `ha.env` (600) there with the Home Assistant
owner login and the long-lived token; every shell, launcher, timer and the voice
session load `~/.config/flint/*.env` into the environment, and configs reference
`${HA_TOKEN}` by name. An ElevenLabs key, if you ever want one, goes into
`~/.config/flint/elevenlabs.env` as `ELEVENLABS_API_KEY=...` the same way.
Claude Code's user settings deny the agent reading that folder.

## When something fails

The stage prints what failed and where its log is. Most failures are a download
that timed out: run `setup.sh` again. A stage that keeps failing: read
`~/.flint-setup/logs/NN-*.log`, fix the cause, `setup.sh --only NN`. The wizard
stage keeps its own transcript in `logs/wizard.log`; if it ends incomplete it
lists what is missing and, when a display exists, opens an interactive
`claude --continue` so you can finish it with the wizard by typing.
