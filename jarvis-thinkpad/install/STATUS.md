# Where the installer stands (2026-09-03)

Read this first when picking the work back up. `install/README.md` explains how
the installer works; this file says what has been verified and what has not.

## Verified

- **Syntax**: every script passes `bash -n`; the Python helpers compile.
- **In a real Ubuntu 24.04 container, as a normal user through `setup.sh` with a
  pseudo-terminal**: stages 00, 01, 02, 03, 05, 06 run and pass their checks
  (every apt package name is valid on noble; uv, Claude Code, Node 22, GitHub
  CLI, Obsidian .deb, Chrome and Claude Desktop install through their real
  installers; the GDM, AccountsService, logind, dconf and TLP files come out
  right). Stage 04 (sshd, ufw, Tailscale) and 08 (reboot) need systemd and a
  real machine.
- **Stages 10 and 11 against a fake agent home** (the real ai-visualizer and
  barehands clones, a CLAUDE.md, configs, a vault): launchers, both faces, the
  roster, the hooks, Claude Code settings, the Playwright MCP server, the
  subagent files, all pass.
- **Stage 09's config pinning and vault registration**: run twice, idempotent.
- **ha-setup.py against a fake Home Assistant** that implements the onboarding
  views, `/auth/token`, the login flow, the websocket long-lived-token command
  (client frames must be masked) and the mcp_server config flow: fresh
  onboarding, idempotent re-run, and recovery from a lost token all pass.
- **team-timers.py** with a stub systemctl: units and job files come out right,
  renamed schedules are pruned.
- **Two independent review panels** read the files against the tools' docs and
  the Jared repos. All confirmed and most raised findings are applied (piped
  stdout breaking the browser logins, sudo dropping the apt flags, no apt lock
  timeout, curl missing on a fresh Desktop, the Tailscale key leaking into the
  wizard's environment, gh tokens in a locked keyring, a null `client_icon`
  rejected by Home Assistant, the doctor's server PIDs, the day-reset false
  negative, the sandbox blocking sudo/docker, and more).

## Not yet verified on real hardware

Nothing has run on the actual ThinkPad yet. The things only a real run can
prove, in the order they will happen:

1. **Stage 04**: `tailscale up --ssh --qr` shows the QR; ufw does not lock out SSH.
2. **Stage 07**: `claude auth login` under `script` (pseudo-terminal) opens the
   browser and returns; `gh auth login --web --insecure-storage`.
3. **Stage 08**: the reboot, then the GNOME autostart entry opening a terminal
   after the automatic login on the Xorg session and continuing by itself.
4. **Stage 09**: Jared's wizard headless (`claude -p` with the answer sheet in
   `~/.flint-setup/wizard-prompt.txt`) completing all six phases without a human,
   including the vault interview and the 1 GB model download; `wizard_ok()`
   naming exactly the files it leaves behind. The fallback opens an interactive
   session with the same context.
5. **Stage 12**: Home Assistant Container's first start time; `${HA_TOKEN}`
   expansion in `.mcp.json` when `claude mcp list` runs.
6. **Stage 16**: Kokoro through the speakers (KPipeline API), faster-whisper
   hearing the espeak-ng sample, `claude -p` booting as Flint with the hooks
   recording the turn, `claude mcp list` reporting playwright and home-assistant
   connected.
7. **Stage 17**: the stack starting in its terminal, the greeting.

## The two critic passes, done by hand (the panel's ran out of usage)

- **Post-reboot continuation**: the autostart entry opens gnome-terminal (a real
  TTY, so `script` and the logins work), waits for the network (`nm-online`),
  and runs `setup.sh --continue` in a login shell: `~/.profile` gives it
  `~/.local/bin`, lib.sh loads `~/.config/flint/*.env`, sudo is passwordless,
  the docker group is active, DISPLAY and DBus exist for gsettings, gnome-terminal
  and the audio tests. The stack's own autostart entry is only written in stage
  10, after that login, so it cannot collide with the continuation; stage 17
  starts the stack only if nothing answers on 8790; the doctor uses the face
  port only while the stack is not running.
- **Headless wizard prompt against fullstack-agent.md and the four component
  wizards**: every Phase 2 answer is supplied; the prompt forbids the things the
  wizards would otherwise try unattended (start.sh, live mic and speaker tests,
  opening a browser, apt, Obsidian Sync, memory migration) and pre-confirms the
  memory wizard's preview step. What remains unprovable without a run: whether
  `claude -p` with `--max-turns 500` completes the ~1 GB model download and the
  vault build inside the 90-minute timeout on the ThinkPad's connection. If not,
  the stage's second pass and then the interactive rescue window take over.

## The capability pass (2026-09-03): wake phrase, music, voices, keeper, health

Added after the question list ("can he hear me without a key, play music,
change voice, come back after a power cut, repair and diagnose himself, drive
Chrome, show me things"). What exists now, and how far each is proven:

- **`voice/flint_voice.py`** (wake phrase + Linux ducking, loaded into
  backtalk's venv by a `.pth`): its matcher passes 15 built-in cases
  (`python -m flint_voice --selftest`); the import hook was exercised
  end-to-end against a stub backtalk (filtering, the summons acknowledgement,
  the follow-up window after an address and after a reply, the ducker swap)
  and the installer against a real virtualenv (idempotent, `.pth` loads).
  Not yet proven: the real backtalk on the ThinkPad, i.e. that
  `Ears.listen_once` and `Mouth.__init__` still have the signatures the hook
  wraps (they match the clone at commit 84b3a6c) and how often the
  transcriber writes "Flint" as something the loose match misses. The doctor
  runs the self-test inside the real venv (stage 16).
- **`bin/flint-play`**: tested here with the real mpv over its IPC socket
  (local files, status, pause, volume, next, seek, restart while playing,
  stop, the ducker dipping it from 40 to 25 and back). YouTube search is not
  provable from this container (Google's bot check on datacenter IPs and a
  yt-dlp too old on apt, which is why stage 05 installs it with uv and the
  keeper refreshes it weekly). On the ThinkPad the doctor's optional check
  "a YouTube search answers" is the proof; if YouTube ever demands a login,
  `--cookies-from-browser chrome` is the yt-dlp answer.
- **`bin/flint-stack`, `bin/flint-keeper.sh`, `launch.sh`**: tested with a
  fake voice process and a fake desktop session: start (headless path),
  status, stop with the marker, the keeper honouring the marker, restarting
  after a crash, doing nothing while healthy, giving up after three restarts
  in thirty minutes and clearing that on `flint-stack start`, and `launch.sh`
  marking a clean exit but not a crash. Not yet proven: `gnome-terminal` from
  a user timer (DISPLAY/XAUTHORITY fallback in `flint-stack`), `ss -ltnp`
  finding the face and hands servers to close.
- **`bin/flint-health.sh`**: runs here (a container without audio, battery
  or systemd) and produces the report and the verdict; the ThinkPad-specific
  rows (battery, TLP thresholds, sensors, Tailscale, HA) are unverified.
- **`bin/flint-voice`**: `list`, `set` validation and the config write are
  tested; `try`/`audition` need Kokoro (stage 16's TTS test uses the same call).
- **Stage 10** was dry-run against the fake agent home with stubbed
  `claude`/`sudo`: the tools, the symlinks, the `flint-doctor.sh` wrapper,
  the hook, the Playwright re-registration with `--browser chrome
  --user-data-dir`, the sandbox exclusions, the CLAUDE.md section and all
  checks pass; only the systemd units could not be enabled here.
- **Docs**: README 4b answers the question list; `04` 5b has the tool table;
  `01` C has the BIOS setting for coming back after a power cut.

## The second capability pass (2026-09-04): senses, connections, guard, backups, offline

Fourteen features from the "20 cool things" list, as tools in `bin/`, three new
stages (13 senses, 14 connect, 15 guard-backup; the doctor and finish moved to
16 and 17) and the doctor's new tests. What is proven here and what is not:

- **Proven in this container**: every script passes `bash -n` / `py_compile`
  and the Python bodies parse; the YAMNet classifier runs through
  `flint-ears test` with the real model (a second of silence scores 0.80
  "Silence", a pulsed 3 kHz tone scores "Beep" then "Smoke detector"); the
  YuNet and SFace models download and load in a virtualenv built with the same
  packages; `flint-play like/dislike/taste/--for` write the vault note and the
  play log against the real mpv; `flint-notify` logs and reports; `flint-timer`
  parses durations; the keeper's offline block is syntax-checked only.
- **Needs the ThinkPad**: a camera for `flint-presence enrol` and the greeting;
  a microphone for the listener; `systemd-run --user` for the timers; the
  Telegram bot end to end (a token from @BotFather, `/start`, a voice note
  transcribed, `claude -p --output-format json` returning `session_id` so the
  conversation continues with `--resume`); KDE Connect pairing and
  `kdeconnect-cli` flags on 23.08 (`--photo`, `--send-sms`); `flint-say --to`
  through Home Assistant (the wav is served from HA's `www` folder to the
  player; `tts.speak` is the fallback); `flint-mail` against a real IMAP
  server; `flint-calendar` with a private ICS link; `flint-ingest` end to end
  (`claude -p` summarising, `yt-dlp` subtitles); `flint-guard` with sudo
  `arp-scan` and the fail2ban jail on noble's systemd backend; `flint-backup`
  with restic 0.16 (`setup` generating the password, `run`, `check`);
  Ollama's installer, the model pull and `flint-offline serve` reusing
  backtalk's `Ears`, `record_held`, `Mouth` and `PTTListener` (names verified
  against the clone at 84b3a6c).
- **Bulgarian** (added the same day): the matcher is Unicode-aware, the name
  is transliterated to Cyrillic for the wake words, Bulgarian summons and
  acknowledgements exist, and Cyrillic sentences are routed to a Piper voice
  by patching `backtalk.mouth.synth_stream`. Proven here: the six Bulgarian
  matcher cases, `flint-say` writing a 22 kHz Bulgarian wav through Piper
  1.7 in a virtualenv, and the routing (English stays on the Kokoro path,
  Cyrillic gets Piper audio) against a stub mouth. Needs the ThinkPad:
  whisper `small` hearing real Bulgarian speech (the doctor's optional
  espeak-ng sample test), and the two voices in one conversation.
- **Design choices to know**: the senses tools are bash heads that `exec` the
  senses virtualenv's Python on a heredoc body (so `bash -n` stays clean and
  no shebang has to know the path); `flint-telegram` obeys only the chat that
  sent `/start` first; `flint-mail send` refuses without `--confirm`;
  `flint-guard` learns the LAN for an hour before alerting; the backup
  password is generated and printed once (and kept in `backup.env`); the
  keeper never restarts the stack while the cloud is unreachable, it starts
  the offline loop instead and stops it when the cloud is back.

## Review findings deliberately left for later

- `16-doctor.sh`: the Timeshift snapshot moved to stage 17 (a check must not
  change the system); still unverified on LVM/BTRFS layouts.
- `10-flint-wire.sh`: `hasTrustDialogAccepted` in `~/.claude.json` is written on
  the reviewer's word; confirm on the box that `claude remote-control` in
  `~/my-agent` starts without a trust prompt (else accept it once in `tmux attach -t flint`).
- `07-accounts.sh`: `claude auth status` output format is undocumented; the
  helper also accepts a one-turn `claude -p` answer.
- The `.mcp.json` `${HA_TOKEN}` expansion is documented for `url` and `headers`;
  the doctor's mcp_test is the proof.

## Next session

1. On the ThinkPad: install Ubuntu (01, sections A to D), then the three lines
   from the README's quick start. Watch stages 04, 07, 08, 09 the first time.
2. Anything that fails: `~/.flint-setup/logs/NN-*.log`, fix, `setup.sh --only NN`.
3. Back here: fold what the real run taught into the stages, then merge the
   branch `claude/jarvis-thinkpad-setup-9a3aiv` into `main` so the clone no
   longer needs `-b`.
