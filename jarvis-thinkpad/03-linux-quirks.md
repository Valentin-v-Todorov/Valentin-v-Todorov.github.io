# 03. Linux quirks found in the code, and the fix for each

Every item below comes from reading the actual source, not from guessing.
Ordered by how likely it is to bite.

## 1. Push-to-talk does nothing on Wayland

`backtalk/backtalk/ptt.py` uses `pynput`. On Linux pynput listens through X11.
Under Wayland it only sees keys typed into XWayland apps, so the Home key held
anywhere else never reaches backtalk and the mic never opens. No error, just silence.

Fixes, best first:

- **Log in with "Ubuntu on Xorg"** (gear icon at the login screen). `01` section F
  makes it permanent. Check with `echo $XDG_SESSION_TYPE` → `x11`. Ubuntu 26.04
  removed this session, which is a main reason this guide picks 24.04.
- **Wayland stays, use the kernel input backend.** pynput can read `/dev/input`
  directly. Add yourself to the `input` group (`bootstrap.sh` does), log out and
  in, then launch the voice with the backend forced:
  `PYNPUT_BACKEND_KEYBOARD=uinput ./run.sh` (put the export into
  `~/my-agent/bin/launch.sh` if it works). pynput's docs say this backend may
  need root; on Ubuntu the `input` group is usually enough for listening.
- **Hands-free listening needs no key at all.** `"mic_mode": "open"` in
  `backtalk.json`, or say "go hands free". Headphones recommended; room audio can
  trigger it.

## 2. Obsidian's registry file lives in three different places

The memory wizard registers the vault by editing `~/.config/obsidian/obsidian.json`
so the first launch opens straight into `~/Brain`. That path is only right for the
`.deb` (which `bootstrap.sh` installs from the official GitHub release).

| Install | Registry path |
| --- | --- |
| `.deb` (use this) | `~/.config/obsidian/obsidian.json` |
| Flatpak | `~/.var/app/md.obsidian.Obsidian/config/obsidian/obsidian.json` |
| Snap | `~/snap/obsidian/current/.config/obsidian/obsidian.json` |

If you already have the Flatpak or Snap, tell the installer the real path, or
just open Obsidian once, choose "Open folder as vault", and pick `~/Brain`.
The wizard also writes `~/Brain/.obsidian/app.json` with
`{"alwaysUpdateLinks": true}` so renames inside Obsidian repair `[[links]]`.

## 3. Python version

backtalk's `pyproject.toml`: `requires-python = ">=3.11,<3.13"`. Ubuntu 24.04 has
3.12 and everything just works. On a distro with 3.13 or newer (Ubuntu 26.04 has
3.14), before `install.sh` runs:

```bash
cd ~/my-agent/backtalk
uv python install 3.12
echo 3.12 > .python-version        # deliberately gitignored by backtalk
uv venv --python 3.12 .venv
./install.sh
```

`run.sh` runs `uv sync -q --inexact` on every launch, which self-heals the
environment and respects the pin.

## 4. espeak-ng and PortAudio

Kokoro phonemizes through the system `espeak-ng`. `backtalk/mouth.py` looks for
`/usr/lib/x86_64-linux-gnu/libespeak-ng.so.1`, which is exactly where Ubuntu's
package puts it. `sounddevice` needs `libportaudio2`. Both installed by `bootstrap.sh`.
If the voice ever says `espeak` errors: `sudo apt-get install --reinstall espeak-ng`.

## 5. Audio devices (PipeWire) and the microphone

Ubuntu 24.04 runs PipeWire with a PulseAudio shim; PortAudio talks to it through
ALSA's `pulse` device. List what backtalk sees:

```bash
cd ~/my-agent/backtalk && .venv/bin/python -m sounddevice
```

Pin the built-in mic by NAME so a Bluetooth headset cannot steal input and drop
into the narrowband call profile mid-sentence:

```json
"mic_device": "Built-in Audio Analog Stereo"
```

(exact name first, then case-insensitive substring; a wrong name falls back to
default and logs the list). Test the raw path: `arecord -d 3 -f cd t.wav && aplay t.wav`.
Choose default output in Settings → Sound.

## 6. The ElevenLabs key and the GNOME keyring under auto-login

backtalk reads the key with `secret-tool lookup service backtalk-elevenlabs`
(libsecret). Store it once:

```bash
secret-tool store --label backtalk service backtalk-elevenlabs
```

With auto-login (01 section F) the "Login" keyring is not unlocked by your
password, so `secret-tool` pops a dialog on every boot. Two fixes:

- Open **Passwords and Keys** (Seahorse), right-click the Login keyring → Change
  Password → set an empty password. The keyring is then stored unencrypted on a
  disk only you use; acceptable for this box, your call.
- Or keep a passworded keyring and unlock it once per boot when the dialog appears.

The `ELEVENLABS_API_KEY` environment variable is the last-resort fallback backtalk
checks; an export in `.bashrc` is a plaintext key on disk, so prefer the keyring.
ElevenLabs also needs `ffmpeg` (installed).

## 7. Spotify ducking is macOS only

`backtalk/ducking.py` uses AppleScript; on Linux every call is a no-op, by
design. If you want music to dip while Flint talks, ask him to add a `playerctl`
equivalent (`playerctl volume 0.3` / restore) in `ducking.py`; the file invites
that PR.

## 8. Ports

| Service | Port | Binds to |
| --- | --- | --- |
| ai-visualizer | 8790 | 127.0.0.1 only |
| barehands | 8794 | 127.0.0.1 only |
| Home Assistant (05) | 8123 | all interfaces (host network) |
| FounderOS demo (06) | 4100 | localhost |

Two stacks cannot run at once. `start.sh` prints which piece failed to bind;
`ai-visualizer/server.py` detects its own earlier instance and just opens the
browser instead of failing.

## 9. Launchers

No `.command` on Linux. `make-launchers.sh` writes `.desktop` files with
`Terminal=true` and a wrapper that exports `~/.local/bin` into PATH (a desktop
session does not source `.bashrc`, so without it `claude` and `uv` are "not
found" and the window flashes shut). Jared's advice stands: do not autostart the
voice at login. If you want the face always on screen, a user service for the
visualizer alone is harmless (it binds localhost):

```bash
mkdir -p ~/.config/systemd/user
cat > ~/.config/systemd/user/ai-visualizer.service <<'UNIT'
[Unit]
Description=Flint face (ai-visualizer)
After=graphical-session.target
[Service]
WorkingDirectory=%h/my-agent/ai-visualizer
ExecStart=/usr/bin/python3 server.py --no-open
Restart=on-failure
[Install]
WantedBy=default.target
UNIT
systemctl --user enable --now ai-visualizer
```

Then keep `http://127.0.0.1:8790/faces/board/` open in a browser window (F for fullscreen).

## 10. Chrome and the webcam for barehands

Hand tracking loads MediaPipe and three.js from CDNs on first load (internet once,
then cached). Open `http://127.0.0.1:8794/stage.html` in **Chrome**, never the
`file://` path. Allow the camera; `C` cycles cameras; `?res=1280x720` helps a slow
machine. If you used Snap chromium instead of Chrome: `sudo snap connect chromium:camera`.
The ring state file `barehands/state/state` is written by backtalk (`barehands_state_dir`)
and by the two hooks in `~/my-agent/.claude/settings.json`.

## 11. The "mechanic" rule and where the guides live

`~/my-agent/CLAUDE.md` tells Flint to fix the stack himself. The guides he reads:
`fullstack-agent/TROUBLESHOOTING.md` (cross-piece), `backtalk/TROUBLESHOOTING.md`
(voice, with the architecture and the five land mines), `ai-visualizer/TROUBLESHOOTING.md`,
`barehands/TROUBLESHOOTING.md` (gesture tuning clinic), `ai-memory-vault/TROUBLESHOOTING.md`.
Say "read your troubleshooting guide for the voice and fix it" and get out of the way.

## 12. Auto mode, bypass, and what the voice session actually boots with

The voice session is a Claude Agent SDK session (`backtalk/brain.py`) with
`cwd = agent_dir`, `add_dirs = extra_dirs`, the `claude_code` system prompt
preset, `model = claude-sonnet-5`, and `permission_mode` from `backtalk.json`.
`"ask"` routes gated tools to a spoken yes/no; `"bypassPermissions"` boots the SDK
in real bypass. The voice console's "stop asking for permission" flips a live
gate flag and saves the config. Typed sessions in `~/my-agent` use Claude Code's
own permission mode (see `04`). The two are independent.

## 13. Firewall

`ufw` from `01` allows only SSH (and 8123 if you open it for Home Assistant on
the LAN). The Flint servers bind to localhost, so nothing else is exposed.
Tailscale traffic bypasses `ufw` rules for its own interface.
