# The installer: one command, eighteen stages, a check after each

```bash
sudo apt-get install -y git
git clone -b claude/jarvis-thinkpad-setup-9a3aiv https://github.com/Valentin-v-Todorov/Valentin-v-Todorov.github.io.git ~/site
~/site/jarvis-thinkpad/setup.sh
```

That is the whole install on a fresh Ubuntu 24.04 Desktop. It asks for your
password once (sudo), opens a browser twice for logins only you can do (Claude
with your Max plan, GitHub), shows a Tailscale link once, reboots once and
continues by itself after the automatic login, asks you to look at the camera
once, then runs the doctor and starts the stack. Budget about 2 to 3 hours,
most of it downloads (the speech models, Chrome, Home Assistant, the offline
model).

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
| 02 essentials | every apt package the stack needs (python 3.12, espeak-ng, PortAudio, ffmpeg, audio/video tools, bubblewrap+socat, xdotool and friends, mpv for music, ssh, ufw, tlp, timeshift, fonts) and `~/.local/bin` on PATH | no |
| 03 desktop | GDM auto-login on the Xorg session (push-to-talk needs X11), never sleep, no lock, dark theme, TLP battery thresholds 75–80 % | no |
| 04 remote-access | sshd, an ssh key, ufw (SSH, mDNS, 8123), Tailscale with `--ssh` | open the Tailscale link once (or put `TS_AUTHKEY` in setup.env) |
| 05 dev-tools | uv, yt-dlp (music search, kept current by uv), Claude Code (native installer) + the bwrap AppArmor profile, Node 22, GitHub CLI, Docker, groups (input, dialout, video, kvm, docker) | no |
| 06 apps | Obsidian (.deb, not launched), Chrome, Claude Desktop (beta), VS Code (off by default) | no |
| 07 accounts | `claude auth login` with the subscription; `gh auth login` (token kept outside the locked keyring) | the two browser logins (postpone with `ACCOUNTS_LATER=1` in setup.env; `setup.sh --only 07` runs them regardless) |
| 08 reboot | one reboot for groups, the Xorg session, firmware and kernel; an autostart entry reopens a terminal and continues | nothing: it continues by itself |
| 09 flint-wizard | Jared's `fullstack-agent` installer, headless (`claude -p` with every answer pre-supplied); then the configs pinned to the decisions (mic always open, the wake words, the voice), the vault registered in Obsidian, the speech models fetched | no (`WIZARD_MODE=interactive` if you want to watch) |
| 10 flint-wire | Desktop launchers, Flint's tools (`flint-play`, `flint-voice`, `flint-stack`, `flint-health.sh`, `flint-doctor.sh`) on the PATH, the wake-phrase + ducking hook in backtalk's venv, the Orbitals face as default + the roster + the live hooks, CLAUDE.md additions (team on screen, machine toolbox, music/screen/browser/voice/health), Claude Code user settings (auto mode, deny list, vault access, sandbox with the machine tools excluded), Playwright MCP driving Chrome with its own profile, secrets loaded from `~/.config/flint/*.env`, hourly vault git commits, Remote Control in tmux, the keeper timer, the stack at every login | no |
| 11 agent-team | `team.yaml` → subagent files and systemd user timers (morning brief, weekly finance, vault hygiene) | no |
| 12 home-assistant | Home Assistant Container (compose), onboarding over its REST API, long-lived token, the MCP Server integration, `.mcp.json` for the agent, port 8123 open on the LAN | no |
| 13 senses | a second virtualenv (OpenCV, the YAMNet sound classifier, feeds, calendars, article extraction), the models, tesseract + pdftotext, the presence watcher (camera) and the listener (microphone) as user services, `flint-look`, `flint-say`, `flint-notify`, `flint-timer` | look at the camera for six seconds (or skip; `flint-presence enrol` later) |
| 14 connect | KDE Connect for the phone (+ the firewall ports), the Telegram bot service, the mail/calendar tools and the connector note, the intercom, the news sources note, the Knowledge/Drop folder + its timer, the DJ's taste note, the errands preferences note, CLAUDE.md, sandbox exclusions | no (later: `flint-telegram setup`, `flint-phone pair`, the connectors on claude.ai) |
| 15 guard-backup | fail2ban on SSH, arp-scan + the guard timer (learning for the first hour), restic + the backup repository (external disk if one is mounted, else a local folder) + nightly and monthly timers + the first backup, Ollama + the offline model + `flint-offline.service` | copy the backup password from `~/.config/flint/backup.env` to your password manager |
| 16 doctor | real tests: Kokoro speaks through the speakers, faster-whisper transcribes, the wake-phrase hook loads and passes its cases, the spoken-reply budget (ears + brain + mouth, in seconds), mpv plays a tone and yt-dlp finds a song, face and hands servers answer, the agent boots as Flint and its hooks record the turn, the health report, the keeper, MCP servers connect (Chrome-driving browser, HA), HA API answers, timers, firewall; report | no |
| 17 finish | Timeshift snapshot when the report is clean, Remote Control started, prints the map (how to talk, play music, change the voice, stop and start, the keeper, the nightly doctor), starts the stack; Flint says hello | no |

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
with the name Flint, C is the calmer one), `MIC_MODE` (`open`: always listening
for his name; `ptt`: key only) with `WAKE_WORDS` and `WAKE_WINDOW_S`, `PTT_KEY`,
`VOICE` and `VOICE_EFFORT` (`low` for the fastest spoken replies),
`VOICE_PERMISSIONS` (`ask` first; `bypassPermissions` when you trust him),
`HOME_ASSISTANT`, `SUDO_NOPASSWD`, `AUTOSTART_STACK`, `KEEPER`, `MUSIC`,
`REMOTE_CONTROL`, `AGENT_TIMERS`, the stage 13 to 15 toggles (`SENSES`, `PHONE`,
`TELEGRAM` + `TELEGRAM_BOT_TOKEN`, `GUARD`, `BACKUP` + `BACKUP_REPO`, `OFFLINE` +
`OFFLINE_MODEL`), and the five vault-interview answers (`YOUR_WORK`, `PROJECTS`,
`KEY_PEOPLE`, `PRIORITIES`, `RECURRING`) that become the agent's first profile of you.

## What he can do afterwards, and the tool behind each

Installed by stages 10 and 13 to 15 into `~/my-agent/bin` and the PATH;
`04-full-power-agent.md` section 5b has the table. In one breath: `flint-play`
(music from YouTube, an album, a queue, `~/Music`, a stream; likes, dislikes,
moods; the music dips while he talks), `flint-voice` (28 voices), `flint-stack`,
`flint-health.sh`, `flint-doctor.sh`, `flint-keeper.sh` (the watchdog; it also
switches to the offline brain when the cloud is out), the `flint_voice` hook
(the wake phrase and ducking), the Playwright server driving Chrome, the nightly
doctor; then the senses: `flint-look` (camera, screen, OCR), `flint-presence`
(your face: greetings, music paused when you leave), `flint-ears` (doorbell,
knock, glass, smoke alarm, siren, crying, dog), `flint-say` (here or on any
Home Assistant speaker), `flint-notify` (screen, Telegram, phone push, voice),
`flint-timer`; the connections: `flint-telegram` (the bot), `flint-phone` (KDE
Connect), `flint-mail`, `flint-calendar`, `flint-news`, `flint-ingest` (PDFs,
links, videos into the vault), `flint-ha` (Home Assistant from the shell); and
the ops: `flint-guard`, `flint-backup`, `flint-offline`.

## Secrets

Nothing secret is in this repo or in the vault. The install creates
`~/.config/flint/` (700) and writes `ha.env` (600) there with the Home Assistant
owner login and the long-lived token; every shell, launcher, timer and the voice
session load `~/.config/flint/*.env` into the environment, and configs reference
`${HA_TOKEN}` by name. An ElevenLabs key, if you ever want one, goes into
`~/.config/flint/elevenlabs.env` as `ELEVENLABS_API_KEY=...` the same way. The
same folder holds `telegram.env` (the bot token and your chat id), `mail.env`
(the IMAP app password and the private calendar links) and `backup.env` (the
restic repository and its password), each written by its tool's `setup` and
never read by the agent.
Claude Code's user settings deny the agent reading that folder. The GitHub
login is stored by `gh` in `~/.config/gh/hosts.yml` (mode 600) rather than in
the GNOME keyring, because the keyring stays locked after an automatic login
and would block every unattended vault push; Claude Code keeps its own login
in `~/.claude/` and is not affected.

## When something fails

The stage prints what failed and where its log is. Most failures are a download
that timed out: run `setup.sh` again. A stage that keeps failing: read
`~/.flint-setup/logs/NN-*.log`, fix the cause, `setup.sh --only NN`. The wizard
stage keeps its own transcript in `logs/wizard.log`; if it ends incomplete it
lists what is missing and, when a display exists, opens an interactive Claude
session that starts with the same answers and the list of what is missing, so
you can finish it with the wizard by typing.
