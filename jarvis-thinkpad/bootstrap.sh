#!/usr/bin/env bash
# bootstrap.sh: everything the Flint stack needs on Ubuntu/Debian, in one idempotent run.
#
#   ./bootstrap.sh            core only (apt deps, uv, Claude Code, sandbox deps)
#   ./bootstrap.sh --all      core + Obsidian + Chrome + Docker + Tailscale + Node + Claude Desktop
#   ./bootstrap.sh --with-obsidian --with-chrome --with-docker --with-tailscale --with-node --with-desktop
#
# Safe to re-run. Never run as root; it uses sudo where needed.
# Installs nothing from the Jared repos: the fullstack-agent wizard does that itself.
set -euo pipefail

WITH_OBSIDIAN=0; WITH_CHROME=0; WITH_DOCKER=0; WITH_TAILSCALE=0; WITH_NODE=0; WITH_DESKTOP=0
for a in "$@"; do
  case "$a" in
    --all) WITH_OBSIDIAN=1; WITH_CHROME=1; WITH_DOCKER=1; WITH_TAILSCALE=1; WITH_NODE=1; WITH_DESKTOP=1 ;;
    --with-obsidian) WITH_OBSIDIAN=1 ;;
    --with-chrome) WITH_CHROME=1 ;;
    --with-docker) WITH_DOCKER=1 ;;
    --with-tailscale) WITH_TAILSCALE=1 ;;
    --with-node) WITH_NODE=1 ;;
    --with-desktop) WITH_DESKTOP=1 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) echo "unknown flag: $a" >&2; exit 1 ;;
  esac
done

log()  { printf '\n\033[1;36m== %s\033[0m\n' "$*"; }
ok()   { printf '   \033[1;32m%s\033[0m\n' "$*"; }
warn() { printf '   \033[1;33m%s\033[0m\n' "$*"; }

if [ "$(id -u)" = 0 ]; then echo "Run this as your normal user, not root." >&2; exit 1; fi
if ! command -v apt-get >/dev/null 2>&1; then echo "This script is for Ubuntu/Debian (apt)." >&2; exit 1; fi

ARCH="$(dpkg --print-architecture)"        # amd64 or arm64
export DEBIAN_FRONTEND=noninteractive
export PATH="$HOME/.local/bin:$PATH"

# ---------------------------------------------------------------- 1. apt packages
log "apt packages"
sudo apt-get update -qq
sudo apt-get install -y -qq \
  git curl wget ca-certificates gnupg jq unzip tmux \
  python3 python3-venv \
  espeak-ng libportaudio2 portaudio19-dev ffmpeg \
  libsecret-tools gnome-keyring \
  bubblewrap socat \
  openssh-server \
  alsa-utils pulseaudio-utils v4l-utils \
  xdotool wmctrl playerctl libnotify-bin xclip \
  tlp
ok "system packages present"
#  espeak-ng + portaudio: backtalk's voice (Kokoro phonemizer, mic/speaker)
#  ffmpeg: ElevenLabs mastering chain, optional
#  libsecret-tools: `secret-tool` for the ElevenLabs key in the GNOME keyring
#  bubblewrap + socat: Claude Code's Bash sandbox on Linux
#  xdotool/wmctrl/playerctl/notify-send: app control for the agent (X11)

# ---------------------------------------------------------------- 2. uv (Python manager backtalk uses)
log "uv"
if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
  ok "uv installed to ~/.local/bin"
else
  ok "uv already present: $(uv --version)"
fi
# backtalk needs Python 3.11 or 3.12. Ubuntu 24.04 ships 3.12; newer distros ship 3.13+.
PYV="$(python3 -c 'import sys;print(f"{sys.version_info[0]}.{sys.version_info[1]}")')"
case "$PYV" in
  3.11|3.12) ok "system python $PYV is compatible with backtalk" ;;
  *) warn "system python is $PYV; backtalk needs <3.13. Pre-installing a managed 3.12 for uv."
     uv python install 3.12 ;;
esac

# ---------------------------------------------------------------- 3. Claude Code (native installer, auto-updates)
log "Claude Code"
if ! command -v claude >/dev/null 2>&1; then
  curl -fsSL https://claude.ai/install.sh | bash
  ok "Claude Code installed"
else
  ok "Claude Code already present: $(claude --version 2>/dev/null || echo '?')"
fi
if ! grep -q 'HOME/.local/bin' "$HOME/.bashrc" 2>/dev/null; then
  printf '\n# jarvis-thinkpad: uv and claude live here\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$HOME/.bashrc"
  ok "added ~/.local/bin to PATH in ~/.bashrc (re-login to apply everywhere)"
fi

# ---------------------------------------------------------------- 4. Sandbox: let bubblewrap use user namespaces (Ubuntu 24.04+)
log "sandbox (bubblewrap) AppArmor profile"
if [ "$(sysctl -n kernel.apparmor_restrict_unprivileged_userns 2>/dev/null || echo 0)" = "1" ]; then
  if [ ! -f /etc/apparmor.d/bwrap ]; then
    sudo tee /etc/apparmor.d/bwrap >/dev/null <<'PROFILE'
abi <abi/4.0>,
include <tunables/global>

profile bwrap /usr/bin/bwrap flags=(unconfined) {
  userns,
  include if exists <local/bwrap>
}
PROFILE
    sudo systemctl reload apparmor || true
    ok "bwrap AppArmor profile installed (from code.claude.com/docs/en/sandboxing)"
  else
    ok "bwrap AppArmor profile already present"
  fi
else
  ok "no AppArmor userns restriction on this kernel; nothing to do"
fi

# ---------------------------------------------------------------- 5. groups: input (Wayland PTT fallback), dialout (Zigbee/Z-Wave sticks)
log "group memberships"
for g in input dialout; do
  if getent group "$g" >/dev/null && ! id -nG "$USER" | tr ' ' '\n' | grep -qx "$g"; then
    sudo usermod -aG "$g" "$USER"; ok "added $USER to $g (takes effect after re-login)"
  fi
done

# ---------------------------------------------------------------- 6. Obsidian (.deb from the official GitHub releases)
# The .deb registers vaults in ~/.config/obsidian/obsidian.json, which is the path
# the ai-memory-vault wizard edits. Flatpak and Snap use different paths and break that step.
if [ "$WITH_OBSIDIAN" = 1 ]; then
  log "Obsidian"
  if command -v obsidian >/dev/null 2>&1; then
    ok "Obsidian already installed"
  else
    # "releases/latest" can be a mobile-only build (v1.13.8 shipped just an .apk while the
    # desktop .deb lived on v1.13.7), so scan recent releases for the first desktop asset.
    # Asset names, confirmed on obsidian.md/download: obsidian_<ver>_amd64.deb,
    # Obsidian-<ver>.AppImage, Obsidian-<ver>-arm64.AppImage.
    REL="$(curl -fsSL 'https://api.github.com/repos/obsidianmd/obsidian-releases/releases?per_page=15' || echo '[]')"
    pick() { printf '%s' "$REL" | python3 -c "
import json,sys
rels=json.load(sys.stdin)
for r in rels:
    for a in r.get('assets',[]):
        n=a['name']
        if n.startswith('$1') and n.endswith('$2') and ('$3'=='' or '$3' not in n):
            print(a['browser_download_url']); sys.exit()
print('')"; }
    DEB="$(pick obsidian_ "_${ARCH}.deb")"
    if [ -z "$DEB" ] && [ "$ARCH" = amd64 ]; then
      # API blocked or rate-limited: scrape the official download page instead.
      DEB="$(curl -fsSL https://obsidian.md/download | grep -oE 'https://github.com/obsidianmd/obsidian-releases/releases/download/v[0-9.]+/obsidian_[0-9.]+_amd64\.deb' | head -1 || true)"
    fi
    TMP="$(mktemp -d)"
    if [ -n "$DEB" ]; then
      curl -fL "$DEB" -o "$TMP/obsidian.deb"
      sudo apt-get install -y -qq "$TMP/obsidian.deb"
      ok "Obsidian installed from $DEB"
    else
      # No .deb for this architecture (arm64 ThinkPads): fall back to the AppImage.
      # It keeps its config in ~/.config/obsidian/ too, so the wizard's registry path still holds.
      SUFFIX="$([ "$ARCH" = arm64 ] && echo '-arm64.AppImage' || echo '.AppImage')"
      APP="$(pick Obsidian- "$SUFFIX" "$([ "$ARCH" = arm64 ] || echo arm64)")"
      if [ -z "$APP" ]; then warn "could not find an Obsidian download for $ARCH; install it by hand from https://obsidian.md/download"; fi
      sudo apt-get install -y -qq libfuse2t64 || sudo apt-get install -y -qq libfuse2 || true
      mkdir -p "$HOME/.local/bin" "$HOME/.local/share/applications"
      curl -fL "$APP" -o "$HOME/.local/bin/obsidian" && chmod +x "$HOME/.local/bin/obsidian"
      printf '[Desktop Entry]\nType=Application\nName=Obsidian\nExec=%s/.local/bin/obsidian --no-sandbox %%U\nIcon=obsidian\nCategories=Office;\n' "$HOME" > "$HOME/.local/share/applications/obsidian.desktop"
      ok "Obsidian AppImage installed to ~/.local/bin/obsidian from $APP"
    fi
    rm -rf "$TMP"
    warn "Do NOT launch Obsidian yet: the memory wizard creates and registers the vault first, then launches it."
  fi
fi

# ---------------------------------------------------------------- 7. Google Chrome (barehands' proven hand-tracking path)
if [ "$WITH_CHROME" = 1 ]; then
  log "Google Chrome"
  if command -v google-chrome >/dev/null 2>&1; then
    ok "Chrome already installed"
  elif [ "$ARCH" = amd64 ]; then
    TMP="$(mktemp -d)"; curl -fL https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -o "$TMP/chrome.deb"
    sudo apt-get install -y -qq "$TMP/chrome.deb"; rm -rf "$TMP"
    ok "Chrome installed (adds Google's apt repo for updates)"
  else
    warn "No Chrome build for $ARCH. Installing chromium (snap) instead; run: sudo snap connect chromium:camera"
    sudo snap install chromium || true
  fi
fi

# ---------------------------------------------------------------- 8. Docker Engine (Home Assistant Container and friends)
if [ "$WITH_DOCKER" = 1 ]; then
  log "Docker Engine"
  if command -v docker >/dev/null 2>&1; then
    ok "Docker already installed: $(docker --version)"
  else
    curl -fsSL https://get.docker.com | sh
    ok "Docker installed"
  fi
  if ! id -nG "$USER" | tr ' ' '\n' | grep -qx docker; then
    sudo usermod -aG docker "$USER"; ok "added $USER to docker group (re-login)"
  fi
  sudo systemctl enable --now docker
fi

# ---------------------------------------------------------------- 9. Tailscale
if [ "$WITH_TAILSCALE" = 1 ]; then
  log "Tailscale"
  if command -v tailscale >/dev/null 2>&1; then
    ok "Tailscale already installed"
  else
    curl -fsSL https://tailscale.com/install.sh | sh
    ok "Tailscale installed"
  fi
  warn "Finish it yourself (interactive login): sudo tailscale up --ssh"
fi

# ---------------------------------------------------------------- 10. Node.js 22 (Playwright MCP, FounderOS demo, npm-based MCP servers)
if [ "$WITH_NODE" = 1 ]; then
  log "Node.js 22"
  if command -v node >/dev/null 2>&1 && [ "$(node -p 'process.versions.node.split(".")[0]')" -ge 18 ]; then
    ok "Node already present: $(node --version)"
  else
    curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
    sudo apt-get install -y -qq nodejs
    ok "Node installed: $(node --version)"
  fi
fi

# ---------------------------------------------------------------- 11. Claude Desktop for Linux (beta; optional GUI)
if [ "$WITH_DESKTOP" = 1 ]; then
  log "Claude Desktop (Linux beta)"
  if command -v claude-desktop >/dev/null 2>&1; then
    ok "Claude Desktop already installed"
  else
    sudo curl -fsSLo /usr/share/keyrings/claude-desktop-archive-keyring.asc https://downloads.claude.ai/claude-desktop/key.asc
    if gpg --show-keys /usr/share/keyrings/claude-desktop-archive-keyring.asc 2>/dev/null | grep -q 31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE; then
      echo "deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/claude-desktop-archive-keyring.asc] https://downloads.claude.ai/claude-desktop/apt/stable stable main" \
        | sudo tee /etc/apt/sources.list.d/claude-desktop.list >/dev/null
      sudo apt-get update -qq && sudo apt-get install -y -qq claude-desktop
      sudo usermod -aG kvm "$USER" || true
      ok "Claude Desktop installed (Cowork needs KVM; you were added to the kvm group)"
    else
      warn "Signing key fingerprint did not match the documented one; skipped Claude Desktop."
    fi
  fi
fi

# ---------------------------------------------------------------- 12. Summary
log "summary"
for c in git curl python3 uv claude espeak-ng ffmpeg secret-tool bwrap socat obsidian google-chrome docker tailscale node; do
  if command -v "$c" >/dev/null 2>&1; then ok "$c"; else warn "$c: not installed (may be optional)"; fi
done
echo "   session: ${XDG_SESSION_TYPE:-unknown} (push-to-talk wants x11; see 03-linux-quirks.md)"
cat <<'NEXTSTEPS'

NEXT STEPS
1. Log out and back in (PATH and group changes).
2. claude            -> first-run login: "Claude account with subscription", then /exit
3. In a NEW terminal, Jared's installer:
   mkdir -p ~/my-agent && cd ~/my-agent && git clone https://github.com/jaredrhod/fullstack-agent && cd fullstack-agent && claude "set me up"
   Answers: 02-flint-install.md. Or let the conductor walk you: cd ~/site/jarvis-thinkpad && claude "set up my thinkpad"
NEXTSTEPS
