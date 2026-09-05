# Start here: from a Fedora ThinkPad to Flint, step by step

The whole path in order. Sections 3 to 5 are the only parts that need your hands; everything after the
three-line clone is `setup.sh`. Time: about an hour for Ubuntu, two to three hours for the setup (downloads).

## 1. Before you wipe the ThinkPad (do these on the phone or on Fedora now)

- **Back up** anything on the Fedora install you want to keep (an external disk, or the cloud). The install erases the whole disk.
- **A USB stick**, 8 GB or more. It gets erased too.
- **Mains power** and the Wi-Fi password.
- **Accounts you will log into during the setup** (have the passwords ready):
  - Claude (the Max plan), in a browser.
  - GitHub (the account that owns this repo).
  - Tailscale: install the Tailscale app on your phone and sign in once (Google, GitHub or Microsoft login; free). The setup shows a QR code you scan with it.
- **Optional, but they make the first run complete**:
  - Telegram: talk to `@BotFather` on the phone, `/newbot`, pick a name and a username ending in `bot`, copy the token. You can paste it into the answer sheet before the run (step 6) or do `flint-telegram setup` afterwards.
  - The KDE Connect app on the phone (for `flint-phone`), the Home Assistant Companion app (for pushes to the phone).
  - An external USB disk for the backups: plug it in before the run and the backup repository goes there by itself; otherwise it goes to `~/Backups/restic` and you can move it later with `flint-backup setup`.
- **Check the hardware once** (on Fedora, in a terminal): `free -h` (8 GB RAM minimum, 16 comfortable), `lsblk` (60 GB disk minimum), `ls /dev/video*` (a webcam for the presence and the hands), `arecord -l` (a microphone).

## 2. Get Ubuntu 24.04 LTS Desktop

1. Download the ISO from https://ubuntu.com/download/desktop: **Ubuntu 24.04.x LTS** (the LTS, not 26.04, not Server). The file is `ubuntu-24.04.x-desktop-amd64.iso`, about 6 GB.
2. Verify it (optional): `sha256sum ubuntu-24.04.*-desktop-amd64.iso` and compare with the SHA256SUMS on the download page.
3. Write it to the USB stick. On Fedora: open **Disks** (GNOME Disks), select the USB stick, menu → **Restore Disk Image…**, pick the ISO, Start Restoring. Or in a terminal: `lsblk` to find the stick (e.g. `/dev/sda`), then `sudo dd if=ubuntu-24.04.*-desktop-amd64.iso of=/dev/sdX bs=4M status=progress oflag=sync`. Any other computer works too (balenaEtcher, Rufus).

## 3. BIOS (press F1 at the Lenovo logo; F12 is the one-time boot menu)

- Security → Secure Boot: **on** is fine (Ubuntu is signed).
- Security → Virtualization: **Intel VT-x / AMD-V on**, VT-d on.
- Config → Power → **"Power On with AC Attach"** (on some models "Wake on AC"): **Enabled**. This is what brings him back after a power cut.
- Config → Network → Wake on LAN: on (or "AC only").
- Startup → UEFI only, CSM off (the default on any recent ThinkPad).
- Save with F10. At the next Lenovo logo press **F12** and pick the USB stick.

## 4. Install Ubuntu (the installer's screens, in order)

1. Language, accessibility, keyboard layout.
2. Connect to Wi-Fi.
3. "Install Ubuntu" → **Interactive installation** → **Extended selection**.
4. Tick both: "Install third-party software for graphics and Wi-Fi hardware" and "Download and install support for additional media formats".
5. Disk: **Erase disk and install Ubuntu**. Advanced features: **LVM, without encryption**. No encryption, on purpose: an encrypted disk asks for a passphrase at every boot, and this machine must come back on its own after a power cut.
6. Your name: Valentin. Computer name: `thinkpad`. Username: `valentin` (lowercase). Password: a real one (it is your sudo password). Leave "Log in automatically" unticked; the setup configures it properly.
7. Timezone, review, Install. Reboot when asked and pull the USB stick out.

## 5. First login

- Log in with your password. The welcome wizard: skip Ubuntu Pro, say no to sending data, location off, done.
- Check the Wi-Fi is connected (top right).
- Open a terminal: **Ctrl+Alt+T**.

## 6. Get the repo and answer the sheet

```bash
sudo apt-get install -y git
git clone -b claude/jarvis-thinkpad-setup-9a3aiv https://github.com/Valentin-v-Todorov/Valentin-v-Todorov.github.io.git ~/site
nano ~/site/jarvis-thinkpad/install/setup.env.example
```

In the file, set what is yours (every other line has a sensible default): `GIT_EMAIL` (your address, for git commits),
`KEY_PEOPLE` (the people in your work, "Name (role); Name (role)"), `TELEGRAM_BOT_TOKEN` if you made the bot,
`TIMEZONE` only if the installer got it wrong. Ctrl+O, Enter, Ctrl+X to save. The install copies this file to
`~/.flint-setup/setup.env` on its first run; that copy is the one to edit from then on.

## 7. Run it

```bash
~/site/jarvis-thinkpad/setup.sh
```

What it asks, and when (everything else is automatic):

| When | What you do |
| --- | --- |
| Stage 00, at the start | Type your password once (sudo). After that it is passwordless. |
| Stage 04, about 20 minutes in | A Tailscale link and a QR code: scan it with the Tailscale app on your phone, approve. (Or put a `TS_AUTHKEY` in setup.env beforehand and it needs nothing.) |
| Stage 07 | The browser opens for the Claude login (your Max account), then for GitHub (a one-time code shown in the terminal; paste it in the browser). |
| Stage 08 | It reboots. Leave it. After the automatic login a terminal reopens by itself and the setup continues. |
| Stage 09, 20 to 40 minutes | Jared's wizard runs headless: it builds the vault, installs the voice, downloads about 1 GB of speech models. Watch; type nothing. If it ends incomplete, it opens a window where you can finish by typing. |
| Stage 12 | Home Assistant starts in Docker and onboards itself (a few minutes). |
| Stage 13 | "Enrol now?": look at the camera for six seconds, turn your head a little. |
| Stage 15 | The backup password is printed once: copy it to your password manager now. Ollama downloads about 3 GB. |
| Stage 16 | The doctor: he speaks a line through the speakers (turn the volume up), listens, measures the reply budget, plays a tone, tests everything. |
| Stage 17 | The map of what exists is printed, the face opens, Flint says hello. |

If a stage fails: read the reason and the log path it prints, then run `~/site/jarvis-thinkpad/setup.sh` again (it
continues where it stopped). Once Claude is logged in (after stage 07) you can also let the conductor drive:
`cd ~/site/jarvis-thinkpad && claude "set up my thinkpad"`.

## 8. The first five minutes with Flint

- Say **"Flint, are you there?"** He answers "Yes?". Then "what can you do?" (he reads the vault note).
- "Flint, how is the machine?" · "Flint, play Lose Yourself by Eminem" · "Flint, what's on my desk?" · "Flint, timer one minute, test" · "Flint, the news".
- The face: http://127.0.0.1:8790/faces/core/ (Z zooms into the team). The launchers are on the Desktop.

## 9. The once-only steps still yours (any time later)

| Step | How |
| --- | --- |
| Telegram | `flint-telegram setup` (the token), then open the bot on the phone and send `/start`. |
| The phone | Open KDE Connect on the phone, same wifi; `flint-phone pair`; accept on the phone. |
| Gmail and Google Calendar | claude.ai → Settings → Connectors → connect both. They appear in Claude Code by themselves. Local fallbacks: `flint-mail setup`, `flint-calendar setup`. |
| Home Assistant | http://127.0.0.1:8123 (login in `~/.config/flint/ha.env`): add your devices, expose the ones Flint may control to Assist, add a speaker for the intercom. |
| The phone push | In the Home Assistant Companion app on the phone, then `HA_NOTIFY=notify.mobile_app_<phone>` in `~/.config/flint/ha.env`. |
| The vault on GitHub | Tell Flint: "push the vault to a private GitHub repo". |
| Your real team | Tell Flint: "read 07-agent-team.md in ~/site/jarvis-thinkpad and interview me about my departments". |

Everything else, including what to say to him for each ability, is in `WHAT-FLINT-CAN-DO.md`.
