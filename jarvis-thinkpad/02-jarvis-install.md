# 02. Installing Flint with Jared's fullstack-agent on Linux

> `setup.sh` (stage 09) runs this wizard headless with every answer below
> pre-supplied, then pins the configs. This file is the reference for what it
> does, and the manual path if you ever want to watch the wizard work
> (`WIZARD_MODE=interactive` in `~/.flint-setup/setup.env`).

## Pre-flight (two minutes, saves an hour)

```bash
echo $XDG_SESSION_TYPE                 # must print x11 (see 01, section F)
python3 --version                      # 3.12.x on Ubuntu 24.04
command -v claude uv espeak-ng obsidian google-chrome
claude auth status || claude -p "reply with ok"   # logged in with the subscription
arecord -d 3 -f cd /tmp/mic.wav && aplay /tmp/mic.wav    # mic and speakers work
ls /dev/video*                         # a webcam exists (for the hands)
pgrep -x obsidian && echo "CLOSE OBSIDIAN FIRST" || echo "obsidian not running: good"
```

Obsidian must be installed but never launched yet: the memory wizard creates the
vault, registers it in `~/.config/obsidian/obsidian.json`, and only then opens the
app so the first thing you see is your vault.

## The command (in a NEW terminal window, not inside another Claude session)

```bash
mkdir -p ~/my-agent && cd ~/my-agent && git clone https://github.com/jaredrhod/fullstack-agent && cd fullstack-agent && claude "set me up"
```

Claude Code opens with `fullstack-agent/CLAUDE.md` as its boot file, reads
`fullstack-agent.md`, and runs six phases. It does the cloning, the configs and
the wiring itself. You answer questions. If the window dies mid-way:
`cd ~/my-agent/fullstack-agent && claude --continue` and say "we got cut off,
keep going with the setup".

## What each phase does (so nothing surprises you)

| Phase | What happens | Your part |
| --- | --- | --- |
| 0. Find home | Confirms `~/my-agent` is the agent's home. Looks for an existing `CLAUDE.md`, old Claude memory in `~/.claude/projects/*/memory/`, existing Obsidian vaults in the registry. | Say it is a fresh install. Allow it to migrate old Claude Code memory if any (it copies, never deletes). |
| 1. Menu | Offers the stack (memory + voice + face) and the optional hands. | Take all four (hands only if a webcam exists). |
| 2. Interview | Name, identity, vault, mic mode and key, voice engine, face, permissions. | The answer sheet below. |
| 3. Install | Clones `ai-memory-vault`, `backtalk`, `ai-visualizer`, `barehands` next to `fullstack-agent`, then runs each wizard. backtalk's `install.sh` creates `.venv` and downloads about 1 GB of models. The memory wizard interviews you about your work (10 minutes) and builds the vault. | Answer the vault interview honestly; it becomes Flint's profile of you. Type your sudo password when `install.sh` installs `espeak-ng`/`portaudio` (already present, so it should skip). |
| 4. Wire | Writes `backtalk.json`, `ai-visualizer.json`, `barehands.json`, the barehands hooks in `~/my-agent/.claude/settings.json`, and appends "You are the mechanic" and "The barehands board" to `~/my-agent/CLAUDE.md`. | Nothing. Read the configs back if curious (reference below). |
| 5. First hello | Runs `./fullstack-agent/start.sh`: the face opens in the browser, the voice says "Hello Valentin, what are we working on today?" | Hold the key, ask something, watch the face. |
| 6. Hand over | Kills the test stack, offers the marketing skill, makes Desktop launchers, explains updates and `claude --continue`. | Say yes to the marketing skill. Then run `make-launchers.sh` from this folder because the wizard only knows macOS `.command` and Windows `.bat` files. |

## The interview, answered

| Question | Answer to give | Notes |
| --- | --- | --- |
| Your name | Valentin | Goes in the greeting. |
| Identity: A Jarvis as-is / B Jarvis renamed / C build your own | **B**, name **Flint** | Door B keeps Jared's real boot config (chief of staff, direct, curses freely, "sir"/"boss", pushes back) and swaps only the name. Want Flint without the swearing? Say **C**, name "Flint", role "chief of staff and operating partner", tone "direct, dry British butler wit, no profanity, pushes back hard when my ideas don't add up", welcome line "All systems online, sir. What are we working on today?" |
| Vault: existing or new | **New**, at `~/Brain` | Any name; keep it in the home folder. It says the full path aloud and registers it in Obsidian. |
| Vault interview (memory wizard) | Your real answers | Name, what you do, projects (each becomes a numbered folder), key people, current priorities, recurring tasks (each becomes a "Job" note). Optional sections are optional. Mention the personal business, home automation, and this ThinkPad as projects so folders exist for them. |
| Old Claude Code memory migration | Yes, migrate | Only if `~/.claude/projects/` has content on this machine (fresh machine: nothing). |
| Mic mode: push to talk / hands-free | **Push to talk** | Mic closed unless the key is held. Switch live later: "go hands free" / "push to talk mode". |
| Talk key | **home** | Physical Home key on ThinkPads (top right cluster; on some models it is Fn+Left). Alternatives: `end`, `right_ctrl`, `f12`. |
| Voice engine: built-in / ElevenLabs | **Built-in (Kokoro)** | `bm_lewis`, free, offline. Audition ElevenLabs later; see `03-linux-quirks.md` section 6 for the keyring. |
| Face | **board** | The circuit board. |
| Permissions: ask / auto-approve | **ask** | Spoken permission checks. Once you trust it: say "stop asking for permission" then "confirm" in a voice session, or tell Flint to set `"permission_mode": "bypassPermissions"`. |
| Marketing skill (phase 6) | **Yes** | Installs `~/.claude/skills/jaredrhod-marketing/`. |

## Where Linux differs from what the wizard expects

The wizards were written for macOS first. Three places need a Linux answer:

1. **Launchers.** The wizard makes macOS `.command` files or Windows `.bat`. On
   Linux it will improvise. Let it, then run `~/site/jarvis-thinkpad/make-launchers.sh`
   which writes proper `.desktop` launchers to `~/Desktop` and the app grid.
2. **Opening Obsidian.** The wizard's Linux instruction is "however it was
   installed". With the `.deb`, that is `obsidian &` (or `setsid obsidian >/dev/null 2>&1 &`).
   The registry it must edit is `~/.config/obsidian/obsidian.json`. Confirm after:
   `python3 -c "import json;print(json.load(open('$HOME/.config/obsidian/obsidian.json'))['vaults'])"`.
3. **The ElevenLabs key** goes in the GNOME keyring:
   `secret-tool store --label backtalk service backtalk-elevenlabs` (paste the key at
   the prompt). Never in a file, never in the chat. Only if you pick ElevenLabs.

Everything else (`install.sh`, `run.sh`, `start.sh`, `update.sh`) is plain bash and
runs on Linux unchanged, whatever the READMEs say about "macOS".

## The configs the wizard writes (reference, so you can check them)

`~/my-agent/backtalk/backtalk.json` (untracked, updates never touch it):

```json
{
  "agent_dir": "/home/valentin/my-agent",
  "name": "Flint",
  "ptt_key": "home",
  "mic_mode": "ptt",
  "voice": "bm_lewis",
  "stt_model": "small.en",
  "permission_mode": "ask",
  "extra_dirs": ["/home/valentin/Brain"],
  "barehands_state_dir": "/home/valentin/my-agent/barehands/state",
  "greeting": "Hello Valentin, what are we working on today?",
  "resume_last_session": false,
  "show_usage": true
}
```

`show_usage` is off in backtalk's own defaults; turn it on so the face's usage
tiles (the plan's 5-hour and 7-day windows) show real numbers. It is your own
usage, published on your own machine only.

Other keys you may add later (defaults live in `backtalk/backtalk/config.py`):
`"speed": 1.15` (brisker voice), `"mic_device": "<name from python -m sounddevice>"`,
`"deep_model": "claude-opus-5"`, `"effort": "low"`, `"thinking_sound": ""`,
`"elevenlabs": {"enabled": true, "voice_id": "...", "voice_note": "Tarquin"}`,
`"signals_dir": ""` (leave empty; the face points at this folder instead).
The voice model is `claude-sonnet-5` on purpose; do not swap it for a slower one.

`~/my-agent/ai-visualizer/ai-visualizer.json`:

```json
{ "name": "FLINT", "badge": "", "face": "board", "port": 8790,
  "bus_dir": "/home/valentin/my-agent/backtalk", "thinking_sound": true }
```

`~/my-agent/barehands/barehands.json`:

```json
{ "name": "Flint", "port": 8794,
  "orbs": [ { "title": "Brain", "path": "/home/valentin/Brain", "kind": "notes" },
            { "title": "Props", "path": "media", "kind": "media" } ] }
```

`~/my-agent/.claude/settings.json` (the ring follows typed sessions too):

```json
{ "hooks": {
    "UserPromptSubmit": [ { "hooks": [ { "type": "command", "command": "printf thinking > /home/valentin/my-agent/barehands/state/state" } ] } ],
    "Stop":             [ { "hooks": [ { "type": "command", "command": "printf idle > /home/valentin/my-agent/barehands/state/state" } ] } ] } }
```

`~/my-agent/CLAUDE.md`: the boot config from ai-memory-vault (identity, vault path,
startup sequence, the rules that can't lapse) plus two appended sections: "The
barehands board" (the `present` verb) and "You are the mechanic" (Flint fixes the
stack himself from each repo's `TROUBLESHOOTING.md`).

## Verify it works (backtalk's own checklist)

1. `cd ~/my-agent && ./fullstack-agent/start.sh` → face opens, greeting speaks.
2. Hold Home, ask something, release → answer within about 2 seconds.
3. Interrupt mid-reply with the key → it stops within a syllable.
4. Interrupt, then ask something NEW → the answer matches the new question. Three times.
5. Ask for something that needs a tool ("what is in my notes about the ThinkPad") → filler, then answer.
6. Type a line in the terminal → spoken reply, same conversation.
7. "usage report" → speaks turns and tokens.
8. "go hands free" → hands-free on; "push to talk mode" → back.
9. Ask it to write a small note → hear the spoken permission check; "details"; "yes". Again with "no".
10. "goodbye flint" → sign-off, clean exit. Ctrl-C in the terminal also stops everything.

Log: `~/my-agent/backtalk/logs/backtalk.log`. Every failure mode has an entry in
`backtalk/TROUBLESHOOTING.md`; tell Flint "read your troubleshooting guide and fix it".

## Daily use

- **Flint only exists in `~/my-agent`.** Open Claude Code there (the "Chat with
  Flint" launcher, or `cd ~/my-agent && claude`). Anywhere else, Claude is a stranger.
- `claude --continue` in `~/my-agent` reopens the last session mid-thought.
- `./fullstack-agent/start.sh` (voice + face + hands server), `start.sh voice`
  (voice + face), `start.sh hands` (voice + board). Ctrl-C stops all of it.
- The face opens on `command` once `command-face/install.sh` has run: the board
  full screen, the team on the right; `T` swaps focus, `G` zooms the team.
- Voice console, exact phrases spoken alone: "clear the session", "compact the
  session", "switch to the deep model", "back to the fast model", "set effort to
  low|medium|high|max", "usage report", "go hands free", "push to talk mode",
  "stop asking for permission" (then "confirm"), "start asking again".
- Updates: `~/my-agent/fullstack-agent/update.sh` pulls every piece and never
  touches your configs, vault or CLAUDE.md. Or say "update everything and tell me
  what changed" to Flint.
- Anything broken: tell Flint. Every repo ships a TROUBLESHOOTING.md written for
  the agent to read.
