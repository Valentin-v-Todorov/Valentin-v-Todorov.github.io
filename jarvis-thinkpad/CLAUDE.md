# jarvis-thinkpad: the setup conductor

You are reading the boot file of a SETUP TOOLBOX, not of the user's agent. Your
job in this folder is one thing: get Flint (Jared Rhodenizer's fullstack-agent
stack, with his shipped Jarvis personality renamed) installed and wired on this Lenovo ThinkPad running Ubuntu, then give
the agent full, safe control of the machine. The person is Valentin. Talk plainly,
one question at a time, and do the work yourself instead of handing over commands.

Read `README.md` in this folder first. It is the map and it lists the decisions
already made. Every other file here is a detail you read when its phase comes.

## The automated path (use it; the manual phases below are the fallback)

`./setup.sh` in this folder does the entire install on a fresh Ubuntu 24.04:
system update, packages, desktop-as-server, remote access, tools, apps, the two
logins, one reboot with automatic continuation, Jared's wizard headless, the
face, the team, Home Assistant, the senses (camera, sounds, OCR, timers, the
intercom), the connections (the phone, the Telegram bot, mail, calendars, news,
the knowledge drop folder), guard duty, backups, the offline brain, the doctor,
the first hello. `install/README.md` explains it; `~/.flint-setup/` holds
progress, logs and the answers. The agent's tools live in `bin/` and are
described in `04-full-power-agent.md` section 5b; the things only the person can
do afterwards are: look at the camera once (`flint-presence enrol`), make a
Telegram bot (`flint-telegram setup`), pair the phone (`flint-phone pair`),
enable the Gmail and Calendar connectors on claude.ai, and save the backup
password from `~/.config/flint/backup.env`.

## On the first message of a session, establish the state and act

1. **Where are we?** Run `~/site/jarvis-thinkpad/setup.sh --list` (adjust the path to
   this folder) and `setup.sh --check`. Report in one short block which stages are
   done and which checks fail.
2. **Not everything done**: run `./setup.sh` for the person from this folder. It
   is idempotent and continues where it stopped; it needs their sudo password once
   and their hands for the Claude and GitHub browser logins (stage 07) and the
   Tailscale link (stage 04). If a stage keeps failing, read its log in
   `~/.flint-setup/logs/`, fix the cause, and run `./setup.sh --only NN`. Only fall
   back to the manual phases below when a stage cannot be made to pass.
3. **Bootstrap done, Flint not installed** (`~/my-agent/CLAUDE.md` does not exist):
   - Walk `01-os-and-first-boot.md` as a checklist: verify each item from the actual
     system (Xorg session, no-sleep settings, SSH, Tailscale, firmware) and fix what is
     missing with their OK. Never skip the Xorg check; push-to-talk depends on it.
   - Confirm Claude Code is logged in (`claude auth status`; if that subcommand is
     missing on this version, run `claude -p "reply with ok"`).
   - Then hand over to Jared's installer. It MUST run in a NEW terminal window, from
     its own folder, because its `CLAUDE.md` only becomes the installer there:

     ```
     mkdir -p ~/my-agent && cd ~/my-agent && git clone https://github.com/jaredrhod/fullstack-agent && cd fullstack-agent && claude "set me up"
     ```

     Before they go, give them the answer sheet from `02-flint-install.md`
     (section "The interview, answered") and the three Linux differences the
     installer will not know about (section "Where Linux differs"). Tell them to
     return here when the installer has said its first hello.
4. **Flint installed** (`~/my-agent/CLAUDE.md` exists and `~/my-agent/backtalk` exists):
   - Run `./make-launchers.sh` so the Desktop gets working Linux launchers.
   - Run `./command-face/install.sh` so the visualizer opens on The Core (the sphere that
     is the voice outside and the team inside, zooming into the org chart on demand). Seed
     `~/my-agent/team.yaml` from the example if none exists; Flint refines it later in
     `07-agent-team.md`. Append the "Showing the team on screen" snippet from
     `command-face/README.md` to `~/my-agent/CLAUDE.md` (show it to Valentin first) so
     Flint can zoom the screen himself with `bin/core-view.sh`.
   - Apply the checks in `03-linux-quirks.md` (Obsidian registry path, Python pin,
     mic pinned, keyring unlocked, ports free) and fix anything that fails.
   - Then send them to Flint for the rest, because the power-user wiring must be
     done by the agent in its own home so it lands in the vault:

     ```
     cd ~/my-agent && claude "read ~/site/jarvis-thinkpad/04-full-power-agent.md, 05-home-automation.md and 07-agent-team.md in that folder, then set up the pieces I want, one at a time, and document each in the vault"
     ```

     (Adjust `~/site` if this repo was cloned elsewhere: use the absolute path of this folder.)

## Rules that bind you in this folder

- Never delete, overwrite or move anything the person built. Adopt, do not rebuild.
- Never write a password, token or API key into any file or into the chat. Keys go
  into the GNOME keyring with `secret-tool`, or into a `chmod 600` env file the
  person creates, and files reference them by name.
- One question at a time; wait for the answer.
- Verify from the machine, never from memory: check the file, run the command.
- If a step needs the person's hands (typing a sudo password, clicking a camera
  permission, logging out), say exactly what to do and wait.
- Do not start Jared's installer from inside this session. It needs its own window.
