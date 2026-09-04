# Flint on the ThinkPad: the complete build

Everything needed to turn a Lenovo ThinkPad into an always-on Linux workstation
running "Flint": a Claude Code agent with persistent memory, a voice, a face,
optional hand tracking, and full control of the machine (apps, files, home
automation). Researched on 2026-09-02 from the sources listed at the bottom.

Read this file first. It is the map. The other files are the detail.

| File | What it is |
| --- | --- |
| `README.md` | This map: what Flint is, the OS decision, the install order, the quick start |
| `CLAUDE.md` | Boot file. Open Claude Code inside this folder on the ThinkPad and it becomes the setup conductor |
| `setup.sh` + `install/` | **The one command.** Eighteen numbered, idempotent stages with a check after each: system update, packages, desktop-as-server, remote access, tools, apps, the two logins, one reboot that continues by itself, Jared's wizard headless, the face, the team, Home Assistant, the doctor, the first hello. `install/README.md` explains it |
| `01-os-and-first-boot.md` | Installing Ubuntu on the ThinkPad (the only manual part) and the reference for what the first-boot stages do (BIOS, Xorg, power, SSH, Tailscale) |
| `bootstrap.sh` | The older single-script bootstrap (packages, uv, Claude Code, Obsidian, Chrome, Docker, Tailscale, Node). `setup.sh` supersedes it; kept for a manual install |
| `02-flint-install.md` | Running Jared's `fullstack-agent` installer on Linux, with the interview answers pre-decided and every config file explained |
| `make-launchers.sh` | Creates the Linux desktop launchers (Chat / Talk / Full stack / Barehands / Update / Stop) the installer only knows how to make for macOS and Windows |
| `bin/` | Flint's own tools, installed into `~/my-agent/bin` and the PATH. The stack: `flint-play` (music, likes, moods), `flint-voice` (28 voices), `flint-stack`, `flint-health.sh`, `flint-keeper.sh` (the watchdog, and the switch to the offline brain). The senses: `flint-look` (camera, screen, OCR), `flint-presence` (your face), `flint-ears` (doorbell, glass, smoke alarm, crying), `flint-say` (here or on any speaker in the house), `flint-notify`, `flint-timer`. The connections: `flint-telegram`, `flint-phone` (KDE Connect), `flint-mail`, `flint-calendar`, `flint-news`, `flint-ingest` (PDFs, links, videos into the vault), `flint-ha`. The ops: `flint-guard`, `flint-backup`, `flint-offline` |
| `voice/` | `flint_voice.py`: the wake phrase ("Flint, ...") and Linux music ducking, hooked into backtalk's virtualenv without touching Jared's files |
| `03-linux-quirks.md` | Every Linux-specific trap found in the code: push-to-talk on Wayland, Obsidian registry path, Python version, audio, keyring, ports |
| `04-full-power-agent.md` | Giving Flint full control of the machine safely: permission modes, sandbox, Remote Control from the phone, MCP servers, app control, scheduled work |
| `05-home-automation.md` | Home Assistant on the ThinkPad and wiring it into Flint through the Home Assistant MCP server |
| `06-founder-os-and-brain.md` | What thefounderos.com and the `#brain` link are, the open-source FounderOS demo, and how it overlaps with the memory vault |
| `command-face/` | Two ready-to-apply faces for the visualizer. The Core (Orbitals): the voice as three particle orbits, the team zoomed out at the centre, the numbers, the conversation and the activity around them; it zooms into the org chart on demand or on Flint's command. Command: the board with the team docked beside it. Plus the roster, hooks and helpers |
| `07-agent-team.md` | The agent org chart from the Founder OS brain graph rebuilt with Claude Code: Flint as Command, lead subagents per department, worker subagents owning one Job each, schedules that run them on their own, and the FounderOS dashboard as an optional face |

---

## 1. What "Flint" actually is

Jared Rhodenizer (`jaredrhod`) publishes five open repos. "Jarvis" is his name for
four of them assembled by the fifth, and the name of the personality that ships in
the memory piece. Ours is called **Flint**: the installer's identity door B keeps
Jared's personality and changes the name. (This folder and the git branch keep
`jarvis-thinkpad` in their names; only the agent is renamed.) All code was read end
to end for this guide.

| Piece | Repo | What it is, literally | Runs on | License |
| --- | --- | --- | --- | --- |
| The mind | `jaredrhod/ai-memory-vault` | A wizard (`ai-memory-vault.md`) that Claude Code executes. It installs Obsidian, creates a vault of plain markdown, writes a `CLAUDE.md` boot config with Jared's actual Flint personality, a `VAULT-INDEX.md`, daily notes, `Active Priorities.md`, folder indexes and "Jobs". No vector database. | Any file-reading AI; built for Claude Code | CC BY-SA 4.0 |
| The mouth | `jaredrhod/backtalk` | A Python program. Hold a key, speak, release. faster-whisper transcribes locally, the text goes to a live Claude Agent SDK session running in your agent's folder, the reply streams to Kokoro TTS (local, free) or ElevenLabs. Spoken permission checks, voice console phrases, interrupt handling. | Claude Code only (Agent SDK) | AGPL-3.0 |
| The face | `jaredrhod/ai-visualizer` | Four full-screen browser pages plus a stdlib Python server on port 8790. It reads three tiny files backtalk writes (`.voice_state`, `.voice_waveform`, `.voice_loading_pid`) and animates. Zero dependencies. | Any AI | AGPL-3.0 |
| The hands (optional) | `jaredrhod/barehands` | One HTML page plus a stdlib Python server on port 8794. Webcam hand tracking (MediaPipe from CDN) moves notes, images and 3D models on screen. Your AI drives it with `bin/board.sh` and reads it with `bin/board-state.sh`. Needs Chrome. | Any AI | AGPL-3.0 |
| The installer | `jaredrhod/fullstack-agent` | A Claude Code wizard (`fullstack-agent.md`) that interviews you once, clones the four pieces as siblings in `~/my-agent`, runs each piece's own wizard, wires the configs together, and speaks the first "Hello Valentin". | Claude Code only | AGPL-3.0 |

Also relevant and free: `jaredrhod/ai-marketing-skills` (a Claude skill plus vault
notes: Jared's marketing playbook) and `jaredrhod/prompts` (retired, superseded
by the repos above).

Everything is free, including commercial use inside your own business. The one
rule for the AGPL pieces is that if you redistribute a modified version it stays
open. Jared's site says the $20 Claude Pro plan is enough.

**How the pieces connect.** There is no message bus and no daemon. backtalk
writes a few files; the visualizer's server and the barehands ring read them.
Claude Code reads `~/my-agent/CLAUDE.md` when it starts in that folder, and that
file points at the vault. That is the whole integration.

```
~/my-agent/                     <- Flint's HOME. Open Claude Code HERE.
  CLAUDE.md                     <- identity + vault path + rules (survives compaction)
  .claude/settings.json         <- hooks that drive the barehands ring (optional)
  fullstack-agent/              <- the installer, start.sh, update.sh
  ai-memory-vault/              <- the memory wizard + templates
  backtalk/                     <- the voice (.venv, backtalk.json, logs/)
  ai-visualizer/                <- the face (ai-visualizer.json, faces/)
  barehands/                    <- the hands (barehands.json, media/, state/)
~/Brain/                        <- the Obsidian vault (NOT inside my-agent)
  VAULT-INDEX.md, Active Priorities.md, 00 - Inbox, 01 - Daily Notes, ...
```

---

## 2. The OS decision: Ubuntu 24.04 LTS Desktop

Linux is the right call, and specifically **Ubuntu 24.04 LTS (Desktop, GNOME)**.
Not the newer 26.04 LTS, not Fedora, not a server image. Reasons, all concrete:

1. **Every script in the stack has an apt branch.** `backtalk/install.sh` installs
   `espeak-ng`, `libportaudio2` and `portaudio19-dev` with `apt-get`. Claude Code,
   the Claude Desktop app, Docker, Tailscale and Obsidian all ship `.deb`
   packages or apt repos. Fedora works but is the second-class path everywhere.
2. **Python 3.12 out of the box.** backtalk pins `requires-python >=3.11,<3.13`.
   Ubuntu 24.04 ships 3.12. Ubuntu 26.04 ships 3.14 and uv has to download a
   separate interpreter (workable, but one more thing to go wrong).
3. **The "Ubuntu on Xorg" login session still exists.** backtalk's hold-to-talk
   key uses `pynput`, which on Linux only sees keys through X11. Ubuntu 26.04
   is Wayland-only and removed the Xorg session entirely. On 24.04 you pick
   "Ubuntu on Xorg" once at the login screen and push-to-talk just works.
   (`03-linux-quirks.md` has the Wayland workarounds if you ever need them.)
4. **Lenovo certifies ThinkPads for Ubuntu LTS** (24.04 and 26.04 both listed),
   so Wi-Fi, trackpoint, fingerprint, suspend and firmware updates via `fwupd`
   are supported paths, not community hacks.
5. **Supported until 2029**, with newer kernels arriving through the HWE stack,
   so a 2024 or 2025 ThinkPad is covered.
6. **Claude Desktop for Linux** (beta) officially supports Ubuntu 22.04+, and its
   Cowork feature needs KVM, which a ThinkPad has.

When to deviate: if the ThinkPad is a very new model (Intel Core Ultra series 3
or newer, 2026 hardware) and 24.04's kernel does not drive the Wi-Fi or GPU,
install 26.04 LTS instead and follow the Wayland notes in `03-linux-quirks.md`.

Why not Windows: backtalk on Windows is "the newest lane", has no `install.sh`
or `run.sh`, keeps the ElevenLabs key in a plaintext environment variable, and
the visualizer and barehands each need a workaround for the Microsoft Store
Python stub. Everything you want (SSH server, Docker, cron, systemd, Tailscale,
Home Assistant) is native on Linux.

Why Desktop and not Server: the voice needs a microphone and speakers, the
hold-to-talk listener needs a graphical session, the face needs a browser, and
the hands need a webcam in Chrome. A desktop session that is always logged in
gives you all of that plus SSH. Sections in `01-os-and-first-boot.md` turn the
laptop into a server that never sleeps with the lid closed.

---

## 3. Install order (setup.sh does 2 to 9 by itself)

1. **Install Ubuntu 24.04 LTS** on the ThinkPad: sections A to D of
   `01-os-and-first-boot.md` (USB stick, BIOS, the installer's questions).
2. **First boot**: updates, firmware, Xorg session, auto-login, never sleep,
   battery thresholds, SSH, firewall, Tailscale, timezone, hostname.
3. **Every package and tool**: python, uv, espeak-ng, PortAudio, ffmpeg, the
   sandbox, Claude Code, Node, GitHub CLI, Docker, Obsidian, Chrome, Claude Desktop.
4. **The two logins** only you can do (Claude with the Max plan, GitHub) and
   one reboot that continues on its own.
5. **Jared's installer**, headless, with every interview answer pre-supplied:
   the vault, the voice, the face, the hands, the marketing skill.
6. **The wiring**: launchers, Flint's tools (music, voices, stack control,
   health), the wake phrase, the Orbitals face, hooks, the permission profile,
   the Chrome-driving browser server, secrets, vault backups, Remote Control,
   the keeper, the stack at login.
7. **The agent team**: roster to subagents, schedules to timers.
8. **Home Assistant**, onboarded through its API, with the MCP server for Flint.
8b. **The senses**: the camera watcher (your face, enrolled once), the listener
    (doorbell, glass, smoke alarm), OCR, timers, the intercom. **The
    connections**: the phone (KDE Connect), the Telegram bot, mail and
    calendars, the news, the knowledge drop folder, the DJ's taste, the errands
    note. **The ops**: fail2ban and the LAN watch, restic backups, the offline
    brain.
9. **The doctor**: real tests (it speaks, it hears, it sees, it classifies a
   sound, the agent boots as Flint, the timers, the guard, the backup), the
   report, a Timeshift snapshot, and the first hello.
10. Afterwards, with Flint in a typed session: the vault notes from `04`, `05`,
    `07`; your real departments in `team.yaml`; optional FounderOS dashboard (`06`).

---

## 4. Quick start on the ThinkPad (copy-paste)

After Ubuntu is installed and you are logged into the desktop once with your
password, open a terminal:

```bash
sudo apt-get install -y git
git clone -b claude/jarvis-thinkpad-setup-9a3aiv https://github.com/Valentin-v-Todorov/Valentin-v-Todorov.github.io.git ~/site
~/site/jarvis-thinkpad/setup.sh
```

Then do only what it asks: your password once, the Claude login in the browser,
the GitHub login, the Tailscale link on your phone. It reboots once and carries
on by itself after the automatic login; at the end the doctor runs its tests,
the face opens and Flint says hello. About two to three hours, mostly downloads. To
change any default first, edit `~/.flint-setup/setup.env` after the first
seconds of the run (or `install/setup.env.example` before). `install/README.md`
lists every stage and every command (`--check`, `--only NN`, `--list`).

If something needs judgement, open Claude Code in this folder and it becomes
the setup conductor: `cd ~/site/jarvis-thinkpad && claude "set up my thinkpad"`.
It reads `CLAUDE.md`, runs `setup.sh --check`, and fixes what fails.

**Important distinction.** claude.ai/code in a browser runs Claude in Anthropic's
cloud, not on the ThinkPad. To control the ThinkPad, Claude Code must run ON the
ThinkPad (the CLI installed by `bootstrap.sh`, or the Desktop app). Once it
runs there, `claude remote-control` lets you drive that local session from your
phone or any browser. See `04-full-power-agent.md`.

---

## 4b. What Flint can do on the ThinkPad once installed

| You asked | The answer, and what makes it true |
| --- | --- |
| Full control of the ThinkPad | Yes. Claude Code in auto mode with passwordless sudo, the sandbox open for the machine tools, X11 tools for the screen (xdotool, wmctrl, screenshots he can read), systemd, Docker, Tailscale. The deny list keeps the few things that must never happen (wiping disks, `shutdown`, the secrets folder). `04`, sections 1, 2 and 5 |
| Create things that were not there and use them like a person | Yes. He installs packages (apt, uv, npm, Docker), writes and runs code, opens apps, types and clicks, reads the screen. New abilities land in `~/my-agent/bin` and in his `CLAUDE.md` so they survive updates |
| Replies within about 3 seconds | Mostly. The voice uses the fast model with the mic transcribed locally; simple answers come back in 2 to 3 seconds, tool-using ones take longer behind a spoken filler. The doctor measures ears + brain + mouth on your box and prints the budget. `VOICE_EFFORT=low` and `STT_MODEL=base.en` in `setup.env` make it faster still |
| Talk to him without a key; a wake word | Yes. The mic is always open; only "Flint, ..." / "hey Flint" / "..., Flint" / "Flint, question for you" / "I have a job for you, Flint" reach him (near-misses like "Clint" count). A bare "Flint?" gets "Yes?" and opens a 30-second window in which nothing needs the name. Holding Home always works |
| Control a browser like Chrome | Yes. The Playwright MCP server drives Google Chrome, visibly, with its own profile (logins persist); `xdg-open` puts any page on the screen; built-in web search |
| Different voices | Yes. 28 local Kokoro voices (`flint-voice list`, `try`, `set`; `audition` plays them all), plus ElevenLabs on your own key if you want the premium one |
| Comes back after the power was off | Yes, if "Power On with AC Attach" is enabled in the BIOS (`01`, section C); then auto-login starts the stack, Remote Control and the timers by themselves. Otherwise one press of the power button |
| Repairs itself | Yes, two layers. The keeper restarts a stack that died within two minutes (and stops after three tries in half an hour, telling you). The nightly doctor runs the installer's tests and repairs from each piece's troubleshooting guide; and "Flint, run the doctor and fix what fails" does it on demand |
| Diagnoses itself and the ThinkPad | Yes. `flint-health.sh`: load, temperature, memory, disk, battery, mains, network, Tailscale, audio, camera, services, Home Assistant, the stack, the login, updates, journal errors, a verdict. "Flint, how is the machine?" |
| Shows me things from the internet; finds an album | Yes. He searches, opens the page in Chrome on the screen, reads it back, and offers to play it |
| Plays the music I ask for | Yes. `flint-play`: the first YouTube match, a whole album, a queue, files in `~/Music`, any stream or URL; pause, next, volume, stop by voice. The music dips while he talks |
| Knows when I sit down (1) | Yes. `flint-presence`: your face enrolled once (six seconds at the camera), he greets you by name, pauses the music when the desk empties, resumes when you are back, flags a stranger with a snapshot. Local, OpenCV |
| What's on my desk, what's on the screen (2) | Yes. `flint-look desk` (camera), `flint-look screen`, `flint-look text` (OCR); he reads the picture back |
| Hears the house (3) | Yes. `flint-ears`: YAMNet on the open mic flags a doorbell, a knock, glass, a smoke or fire alarm, a siren, crying, a dog; he speaks the ones that matter and notifies the rest |
| A Telegram bot (5) | Yes. `flint-telegram`: text him from anywhere, voice notes transcribed locally, photos both ways, `/look`, `/status`, `/play`, `/say`; only your chat is obeyed. One manual step: a token from @BotFather |
| Phone mirroring (6) | Yes. `flint-phone` over KDE Connect: ring it, its battery, its notifications, send an SMS, share a file or link, the clipboard, a photo from its camera. Pair once on the phone |
| Intercom (7) | Yes. `flint-say --to media_player.kitchen "..."` or `--to all`: his own voice on any Home Assistant speaker |
| Email and calendar in his head (8) | Yes. The Gmail and Google Calendar connectors from claude.ai appear in Claude Code by themselves (one click on claude.ai); the morning brief reads them. Local fallbacks: `flint-mail` (IMAP, drafts, send only with `--confirm`) and `flint-calendar` (private ICS links) |
| Voice browsing with memory (12) | Yes. The Chrome profile keeps the logins; `Flint/Preferences.md` in the vault keeps the usual table, addresses, sizes and the rule "never pay without a yes" |
| Knowledge ingest (13) | Yes. `flint-ingest <pdf|link|video>` files a note with a summary, key points and quotes in `Knowledge/Inbox` and tells the gist; anything dropped into `Knowledge/Drop` is ingested every ten minutes |
| DJ with taste (16) | Yes. `flint-play like|dislike|taste|--for focus|me`: likes and dislikes in `Flint/Music Taste.md`, a play log, moods |
| Reads the news (18) | Yes. `flint-news --brief|--read`: your RSS feeds (a vault note), summarised by him, spoken. Part of the morning brief |
| Guard duty (20) | Yes. fail2ban on SSH; `flint-guard` every two minutes: SSH logins, bans, new devices on the wifi (named by you), motion while you are away with a camera snapshot |
| Backups (21) | Yes. restic, encrypted, nightly at 02:30 to an external disk or a cloud bucket, thinned; a real restore test on the first of the month; `flint-backup restore <path>` brings anything back |
| Offline mode (22) | Yes. Ollama with a small model; when the cloud is out the keeper starts `flint-offline` and timers, lights, music and the time still work by voice, with the same wake word |

---

## 5. Decisions already made for you (change any of them)

| Question the installer asks | Answer | Why |
| --- | --- | --- |
| Your name | Valentin | Used in the greeting "Hello Valentin, what are we working on today?" |
| Agent identity | Door B: Jared's personality, renamed **Flint** | Door B keeps Jared's exact personality (direct, swears freely, calls you "sir"/"boss", pushes back) and changes only the name. Pick door C if you want Flint with a calmer tone |
| Vault | Fresh vault at `~/Brain` | Home folder, not Documents, not cloud-synced. The installer registers it in `~/.config/obsidian/obsidian.json` so Obsidian opens straight into it |
| Microphone | Always listening, answers to his name; key `home` still works | "Flint, ..." or "..., Flint" reaches him; anything else in the room is dropped by the `flint_voice` hook (`03`, section 7). Follow-ups within 30 s of an exchange need no name. Holding Home always gets you heard. `MIC_MODE=ptt` in `setup.env` for key-only |
| Voice engine | Kokoro `bm_lewis` (free, local) first | Zero cost, offline. Audition ElevenLabs later if you want the natural voice; the key goes in the GNOME keyring via `secret-tool`, never in a file |
| Face | `board` in the wizard, then `command-face/install.sh` makes **The Core** the default | The Core is the Orbitals design you picked: the voice as particle orbits, the team zoomed out at the centre, the numbers, the conversation and the activity around them, zooming into the org chart on `Z` or on Flint's command. The board stays one page away |
| Hands | Yes, if the ThinkPad has a webcam | Needs Chrome; `bootstrap.sh` installs it |
| Permissions (voice) | `ask` for the first day, then `bypassPermissions` | You want full power. Start with spoken checks so you hear what it wants to do, then say "stop asking for permission" and "confirm" |
| Marketing skill | Yes | Free, useful for the personal business, installs as `~/.claude/skills/jaredrhod-marketing/` |

---

## 6. Costs and usage

- Jared's software: free. Obsidian: free (Sync add-on not needed).
- Claude: a Pro, Max or Team plan. Every spoken turn is a normal Claude Code
  turn. backtalk pins the voice to `claude-sonnet-5` on purpose (speed); the
  voice console's "switch to the deep model" flips to `claude-opus-5` for one
  session. Typed sessions use whatever you set (`/model`).
- ElevenLabs: optional. Free tier auditions it; daily use is the paid starter plan.
- Local models: about 1 GB downloaded once (Whisper `small.en` plus Kokoro).
  Runs on CPU; a ThinkPad without a GPU is fine. Drop `stt_model` to `base.en`
  if transcription feels slow.

---

## 7. Sources read for this guide

- https://github.com/jaredrhod/fullstack-agent (README, CLAUDE.md, fullstack-agent.md, start.sh, update.sh, TROUBLESHOOTING.md)
- https://github.com/jaredrhod/ai-memory-vault (README, ai-memory-vault.md v3.3, templates/, TROUBLESHOOTING.md)
- https://github.com/jaredrhod/backtalk (README, backtalk.md, install.sh, run.sh, pyproject.toml, backtalk/*.py, TROUBLESHOOTING.md)
- https://github.com/jaredrhod/ai-visualizer (README, ai-visualizer.md, server.py, run.sh, TROUBLESHOOTING.md)
- https://github.com/jaredrhod/barehands (README, barehands.md, server.py, bin/*.sh, TROUBLESHOOTING.md)
- https://github.com/jaredrhod/ai-marketing-skills and https://github.com/jaredrhod/prompts
- https://jaredrhod.com (the 3-step install page)
- https://www.thefounderos.com and https://github.com/Bennettxai/FounderOS-DEMO
- https://code.claude.com/docs/en/setup, /permission-modes, /sandboxing, /remote-control, /desktop-linux, /mcp
- https://www.home-assistant.io/integrations/mcp_server/ and /installation/linux
- https://obsidian.md/help/install, https://pynput.readthedocs.io/en/latest/limitations.html
- Ubuntu 26.04 release notes (Wayland-only, Python 3.14, kernel 7.0); Lenovo Linux certification pages
