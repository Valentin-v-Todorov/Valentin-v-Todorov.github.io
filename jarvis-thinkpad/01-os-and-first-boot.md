# 01. Installing Ubuntu on the ThinkPad and the first-boot checklist

Target: **Ubuntu 24.04 LTS Desktop** (see README section 2 for why). Time: about
an hour including downloads.

## A. Before you wipe anything

- Back up whatever is on the ThinkPad now. The install below uses the whole disk.
- Know the model (sticker on the bottom, or `Fn+Esc` at the Lenovo logo shows it).
  Any ThinkPad from about 2018 onward is fine. 16 GB RAM is comfortable (Claude
  Code needs 4 GB, Whisper plus Kokoro plus Chrome plus Obsidian want a few more).
- You need: a USB stick of 8 GB or more, and another computer to write it.

## B. Make the installer USB

1. Download the ISO from https://ubuntu.com/download/desktop (pick 24.04.x LTS).
2. Verify it: compare `sha256sum ubuntu-24.04.*-desktop-amd64.iso` with the
   SHA256SUMS file on the same download page.
3. Write it with balenaEtcher (any OS) or, on Linux/macOS:
   `sudo dd if=ubuntu-24.04.x-desktop-amd64.iso of=/dev/sdX bs=4M status=progress oflag=sync`
   (replace `/dev/sdX` with the USB device; double check with `lsblk`).

## C. BIOS settings (press F1 at the Lenovo logo)

- Security → Secure Boot: can stay **on**. Ubuntu is signed. Turn it off only if
  you later install an NVIDIA driver and the installer asks you to enroll a key
  and you would rather not.
- Security → Virtualization: **Intel VT-x / AMD-V on** and VT-d on. Needed for
  Docker performance, Claude Desktop's Cowork (KVM), and any Home Assistant VM.
- Config → Power → "Always on USB" as you like; Config → Network → wake on LAN
  is useful for a server.
- Startup → boot order: USB first for the install, then back to the SSD.
- Optional: Config → Display → set the internal display as primary if you use an
  external monitor. Save with F10.

## D. Install

Boot from the USB (F12 at the logo picks the device). In the installer:

- Language, keyboard, Wi-Fi.
- "Interactive installation", **Extended selection** (the full desktop).
- Tick "Install third-party software for graphics and Wi-Fi hardware" and
  "Download and install support for additional media formats".
- Disk: "Erase disk and install Ubuntu". Advanced features:
  - **LVM without encryption** if the laptop stays at home and must reboot
    unattended (a power cut, a kernel update). This is the always-on-server choice.
  - **LVM with encryption (LUKS)** if theft matters more than unattended reboots.
    You will have to type the passphrase on a keyboard after every reboot; SSH and
    Tailscale are not up yet at that point.
- Your name: Valentin. Computer name: `thinkpad` (or `flint`). Username:
  `valentin`. Password: a real one; it is also your sudo password. Do NOT tick
  "Log in automatically" here; we set that up properly in step F.
- Timezone, then install and reboot. Remove the USB when asked.

## E0. From here, one command does everything below

Log in once with your password, open a terminal, and run:

```bash
sudo apt-get install -y git
git clone -b claude/jarvis-thinkpad-setup-9a3aiv https://github.com/Valentin-v-Todorov/Valentin-v-Todorov.github.io.git ~/site
~/site/jarvis-thinkpad/setup.sh
```

`setup.sh` performs sections E to K of this file (updates, firmware, the Xorg
session and auto-login, never-sleep, battery thresholds, SSH, firewall,
Tailscale, timezone, hostname, Timeshift) and then the whole Flint install,
with a check after every stage (`install/README.md`). The sections below stay
as the reference for what it does and how to redo any single piece by hand.

## E. First boot: updates and firmware

```bash
sudo apt-get update && sudo apt-get full-upgrade -y
sudo fwupdmgr refresh && sudo fwupdmgr get-updates && sudo fwupdmgr update
sudo reboot
```

`fwupd` updates the ThinkPad's BIOS, Thunderbolt and fingerprint firmware from
Lenovo's LVFS feed. It may reboot twice. This is the single most useful step for
suspend, battery and Wi-Fi stability.

## F. Log in with "Ubuntu on Xorg" and make it stick

Push-to-talk (backtalk's `pynput` listener) only sees keys under X11. At the login
screen, click your name, click the **gear icon** bottom right, choose
**Ubuntu on Xorg**, then log in. To make it the only option and to auto-login
(the machine is a server; the voice and face need a logged-in desktop):

```bash
sudo sed -i 's/^#\?WaylandEnable=.*/WaylandEnable=false/' /etc/gdm3/custom.conf
sudo sed -i 's/^#\?AutomaticLoginEnable.*/AutomaticLoginEnable=true/; s/^#\?AutomaticLogin=.*/AutomaticLogin=valentin/' /etc/gdm3/custom.conf
grep -E 'WaylandEnable|AutomaticLogin' /etc/gdm3/custom.conf
```

If the `AutomaticLogin` lines were not present (some images comment them out
differently), add under `[daemon]`:

```
AutomaticLoginEnable=true
AutomaticLogin=valentin
WaylandEnable=false
```

Reboot and confirm `echo $XDG_SESSION_TYPE` prints `x11`.

Auto-login has one side effect: the GNOME login keyring is not unlocked by your
password, so the first `secret-tool` call (ElevenLabs key) pops a keyring
password dialog. `03-linux-quirks.md` section 6 covers the fix.

## G. Never sleep, lid closed or not

```bash
sudo mkdir -p /etc/systemd/logind.conf.d
sudo tee /etc/systemd/logind.conf.d/server.conf >/dev/null <<'CONF'
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
IdleAction=ignore
CONF
sudo systemctl restart systemd-logind
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing'
gsettings set org.gnome.desktop.session idle-delay 0
gsettings set org.gnome.desktop.screensaver lock-enabled false
```

Restarting `systemd-logind` can log you out on some systems; if it does, log
back in. Keep the screen lock off only if the laptop is in a place you trust; SSH
and Tailscale are the access path anyway.

## H. Battery: it will live on the charger

ThinkPads support charge thresholds in the kernel. Keeping the battery between
about 75 and 80 percent stops it from cooking:

```bash
sudo apt-get install -y tlp
sudo tee /etc/tlp.d/01-thinkpad-server.conf >/dev/null <<'CONF'
START_CHARGE_THRESH_BAT0=75
STOP_CHARGE_THRESH_BAT0=80
CPU_ENERGY_PERF_POLICY_ON_AC=balance_performance
CONF
sudo systemctl enable --now tlp
sudo tlp-stat -b | grep -i thresh
```

TLP replaces `power-profiles-daemon` on 24.04; that is expected.

## I. Remote access: SSH now, Tailscale for everywhere

```bash
sudo apt-get install -y openssh-server
sudo systemctl enable --now ssh
sudo ufw allow OpenSSH && sudo ufw enable
```

Copy your key from your other computer: `ssh-copy-id valentin@thinkpad.local`.
Then disable password logins in `/etc/ssh/sshd_config.d/hardening.conf`:

```
PasswordAuthentication no
KbdInteractiveAuthentication no
```

and `sudo systemctl restart ssh`.

Tailscale (free for personal use) gives you the ThinkPad from your phone or any
network without opening router ports. `bootstrap.sh --all` installs it; you
still run the interactive login once:

```bash
sudo tailscale up --ssh
```

Open the printed link on any device, approve, and the ThinkPad gets a stable
`100.x.y.z` address and a `thinkpad.<tailnet>.ts.net` name. `--ssh` lets you
`ssh valentin@thinkpad` from any Tailscale device using Tailscale's own auth.

## J. Timezone, hostname, and a system backup tool

```bash
sudo timedatectl set-timezone Europe/Sofia       # or your zone: timedatectl list-timezones
sudo hostnamectl set-hostname thinkpad
sudo apt-get install -y timeshift                # snapshots of the OS, not of your data
```

Take a Timeshift snapshot after the Flint install works, so a bad update is a
one-click rollback. The vault (`~/Brain`) is backed up separately: Flint can
push it to a private GitHub repo on a schedule (see `04-full-power-agent.md`).

## K. Now run the bootstrap

```bash
sudo apt-get install -y git curl
git clone https://github.com/Valentin-v-Todorov/Valentin-v-Todorov.github.io.git ~/site
cd ~/site && git checkout claude/jarvis-thinkpad-setup-9a3aiv   # skip if already on main
cd jarvis-thinkpad && chmod +x *.sh && ./bootstrap.sh --all
```

Log out and in, then continue with `02-flint-install.md`.

## Known ThinkPad-on-Linux notes

- Fingerprint readers: most Synaptics and Goodix readers work via `fprintd`
  (Settings → Users → Fingerprint). Irrelevant for a server; skip.
- Trackpoint too fast or slow: Settings → Mouse & Touchpad.
- Fan noise under load: `sudo apt-get install thinkfan` is optional; TLP is enough.
- NVIDIA discrete GPU (P-series): Software & Updates → Additional Drivers → the
  recommended proprietary driver. faster-whisper then uses CUDA automatically
  (`stt_device: "auto"`). Intel and AMD iGPUs need nothing.
- External monitor closed-lid use: with the logind config above the laptop stays
  on; set the external monitor as primary in Settings → Displays.
