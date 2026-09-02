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
| `01-os-and-first-boot.md` | Installing Ubuntu on the ThinkPad and the first-boot checklist (BIOS, Xorg, power, SSH, Tailscale) |
| `bootstrap.sh` | One idempotent script: every system package, uv, Claude Code, Obsidian, Chrome, Docker, Tailscale, Node |
| `02-flint-install.md` | Running Jared's `fullstack-agent` installer on Linux, with the interview answers pre-decided and every config file explained |
| `make-launchers.sh` | Creates the Linux desktop launchers (Chat / Talk / Barehands / Update) the installer only knows how to make for macOS and Windows |
| `03-linux-quirks.md` | Every Linux-specific trap found in the code: push-to-talk on Wayland, Obsidian registry path, Python version, audio, keyring, ports |
| `04-full-power-agent.md` | Giving Flint full control of the machine safely: permission modes, sandbox, Remote Control from the phone, MCP servers, app control, scheduled work |
| `05-home-automation.md` | Home Assistant on the ThinkPad and wiring it into Flint through the Home Assistant MCP server |
| `06-founder-os-and-brain.md` | What thefounderos.com and the `#brain` link are, the open-source FounderOS demo, and how it overlaps with the memory vault |
| `command-face/` | Two ready-to-apply faces for the visualizer. The Core: a sphere whose outer wireframe is the voice and whose core is the team, zooming into the org chart on demand or on Flint's command. Command: the board with the team docked beside it. Plus the roster, hooks and helpers |
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

## 3. Install order (do not reorder)

1. **Install Ubuntu 24.04 LTS** on the ThinkPad. `01-os-and-first-boot.md`.
2. **First boot checklist**: updates, firmware, Xorg session, no-sleep, SSH,
   Tailscale, auto-login. Same file.
3. **Clone this repo and run `bootstrap.sh`.** It installs every dependency
   (git, curl, python3, uv, espeak-ng, portaudio, ffmpeg, libsecret-tools,
   bubblewrap, socat, Chrome, Obsidian `.deb`, Docker, Tailscale, Node) and
   Claude Code itself. Safe to re-run.
4. **Log in to Claude Code once** (`claude`, pick "Claude account with
   subscription", `/exit`).
5. **Run Jared's installer** in a fresh terminal:
   `mkdir -p ~/my-agent && cd ~/my-agent && git clone https://github.com/jaredrhod/fullstack-agent && cd fullstack-agent && claude "set me up"`.
   Answer the interview with the sheet in `02-flint-install.md`.
6. **Run `make-launchers.sh`** for the Linux desktop icons.
7. **Give Flint full power**: `04-full-power-agent.md` (permission mode,
   sandbox, Remote Control, MCP servers).
8. **Home automation**: `05-home-automation.md`.
9. **The agent team and the Command screen**: named specialists that work on
   their own, on schedules, and the face that shows the voice with the team
   beside it: `07-agent-team.md`, `command-face/install.sh`.
10. Optional: marketing skill, FounderOS demo as the team's dashboard (`06`, `07`).

---

## 4. Quick start on the ThinkPad (copy-paste)

After Ubuntu is installed and you are logged into the desktop, open a terminal:

```bash
sudo apt-get update && sudo apt-get install -y git curl
git clone https://github.com/Valentin-v-Todorov/Valentin-v-Todorov.github.io.git ~/site
cd ~/site
git checkout claude/jarvis-thinkpad-setup-9a3aiv   # skip if this folder is already on main
cd jarvis-thinkpad
chmod +x bootstrap.sh make-launchers.sh
./bootstrap.sh --all
```

Then log out and back in (group memberships and PATH), open a terminal again, and:

```bash
claude            # first-run login: "Claude account with subscription", then /exit
cd ~/site/jarvis-thinkpad && claude "set up my thinkpad"
```

That second command opens Claude Code with `CLAUDE.md` in this folder as the
boot file. It becomes the setup conductor: it verifies the bootstrap, walks the
first-boot checklist with you, then hands you the exact fullstack-agent command
and the answer sheet, and after Flint exists it wires the power-user pieces.

**Important distinction.** claude.ai/code in a browser runs Claude in Anthropic's
cloud, not on the ThinkPad. To control the ThinkPad, Claude Code must run ON the
ThinkPad (the CLI installed by `bootstrap.sh`, or the Desktop app). Once it
runs there, `claude remote-control` lets you drive that local session from your
phone or any browser. See `04-full-power-agent.md`.

---

## 5. Decisions already made for you (change any of them)

| Question the installer asks | Answer | Why |
| --- | --- | --- |
| Your name | Valentin | Used in the greeting "Hello Valentin, what are we working on today?" |
| Agent identity | Door B: Jared's personality, renamed **Flint** | Door B keeps Jared's exact personality (direct, swears freely, calls you "sir"/"boss", pushes back) and changes only the name. Pick door C if you want Flint with a calmer tone |
| Vault | Fresh vault at `~/Brain` | Home folder, not Documents, not cloud-synced. The installer registers it in `~/.config/obsidian/obsidian.json` so Obsidian opens straight into it |
| Microphone | Push to talk, key `home` | Mic is closed unless the key is held. ThinkPads have a physical Home key. Say "go hands free" later to switch |
| Voice engine | Kokoro `bm_lewis` (free, local) first | Zero cost, offline. Audition ElevenLabs later if you want the natural voice; the key goes in the GNOME keyring via `secret-tool`, never in a file |
| Face | `board` (the circuit board) | The one from the videos. Switch by opening another page |
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
