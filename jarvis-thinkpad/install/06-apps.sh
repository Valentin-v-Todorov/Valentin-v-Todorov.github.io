#!/usr/bin/env bash
# 06: the desktop apps: Obsidian (the memory), Chrome (the hands), Claude Desktop, VS Code (optional).
. "$(dirname "$0")/lib.sh"
ARCH="$(dpkg --print-architecture)"

pick_asset() {  # pick_asset <json> <prefix> <suffix> [exclude]
  printf '%s' "$1" | python3 -c "
import json,sys
rels=json.load(sys.stdin)
for r in rels:
    for a in r.get('assets',[]):
        n=a['name']
        if n.startswith('$2') and n.endswith('$3') and ('$4'=='' or '$4' not in n):
            print(a['browser_download_url']); sys.exit()
print('')"
}

run() {
  log "Obsidian (.deb from the official releases; the memory wizard needs this exact install path)"
  if has obsidian; then ok "already installed"; else
    if pgrep -x obsidian >/dev/null; then die "Obsidian is running; close it and re-run"; fi
    local rel deb tmp
    rel="$(curl -fsSL 'https://api.github.com/repos/obsidianmd/obsidian-releases/releases?per_page=15' 2>/dev/null || echo '[]')"
    deb="$(pick_asset "$rel" obsidian_ "_${ARCH}.deb")"
    if [ -z "$deb" ] && [ "$ARCH" = amd64 ]; then
      deb="$(curl -fsSL https://obsidian.md/download | grep -oE 'https://github.com/obsidianmd/obsidian-releases/releases/download/v[0-9.]+/obsidian_[0-9.]+_amd64\.deb' | head -1 || true)"
    fi
    tmp="$(mktemp -d)"
    if [ -n "$deb" ]; then
      curl -fL "$deb" -o "$tmp/obsidian.deb" && sudo apt-get install -y -qq "$tmp/obsidian.deb"
      ok "installed from $deb"
    else
      local suffix app
      suffix="$([ "$ARCH" = arm64 ] && echo '-arm64.AppImage' || echo '.AppImage')"
      app="$(pick_asset "$rel" Obsidian- "$suffix" "$([ "$ARCH" = arm64 ] || echo arm64)")"
      [ -n "$app" ] || die "no Obsidian download found for $ARCH; install it from https://obsidian.md/download and re-run"
      mkdir -p "$HOME/.local/bin" "$HOME/.local/share/applications"
      curl -fL "$app" -o "$HOME/.local/bin/obsidian" && chmod +x "$HOME/.local/bin/obsidian"
      printf '[Desktop Entry]\nType=Application\nName=Obsidian\nExec=%s/.local/bin/obsidian --no-sandbox %%U\nIcon=obsidian\nCategories=Office;\n' "$HOME" > "$HOME/.local/share/applications/obsidian.desktop"
      ok "AppImage installed to ~/.local/bin/obsidian"
    fi
    rm -rf "$tmp"
  fi
  say "not launched on purpose: the memory wizard creates and registers the vault first"

  log "Google Chrome (barehands' hand tracking runs there)"
  if has google-chrome; then ok "already installed"
  elif [ "$ARCH" = amd64 ]; then
    local tmp; tmp="$(mktemp -d)"
    curl -fL https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -o "$tmp/chrome.deb" && sudo apt-get install -y -qq "$tmp/chrome.deb"; rm -rf "$tmp"
    ok "installed (Google's apt repo keeps it updated)"
  else
    sudo snap install chromium >/dev/null 2>&1 && sudo snap connect chromium:camera >/dev/null 2>&1 || true
    warn "no Chrome for $ARCH: chromium snap installed instead"
  fi

  if [ "$CLAUDE_DESKTOP" = 1 ]; then
    log "Claude Desktop for Linux (beta)"
    if has claude-desktop; then ok "already installed"; else
      sudo curl -fsSLo /usr/share/keyrings/claude-desktop-archive-keyring.asc https://downloads.claude.ai/claude-desktop/key.asc
      if gpg --show-keys /usr/share/keyrings/claude-desktop-archive-keyring.asc 2>/dev/null | grep -q 31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE; then
        echo "deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/claude-desktop-archive-keyring.asc] https://downloads.claude.ai/claude-desktop/apt/stable stable main" | sudo tee /etc/apt/sources.list.d/claude-desktop.list >/dev/null
        sudo apt-get update -qq && apt_install_full claude-desktop && ok "installed" || warn "claude-desktop package not installable right now; optional, skipped"
      else warn "signing key fingerprint did not match the documented one; skipped (optional)"; fi
    fi
  fi

  if [ "$VSCODE" = 1 ]; then
    log "VS Code"
    has code || { sudo snap install code --classic >/dev/null 2>&1 && ok "installed (snap)"; }
  fi
}

check() {
  chk "obsidian" has obsidian
  chk "obsidian is not running yet" bash -c '! pgrep -x obsidian >/dev/null'
  chk "google-chrome or chromium" bash -c 'command -v google-chrome >/dev/null || command -v chromium >/dev/null'
  [ "$CLAUDE_DESKTOP" = 1 ] && chk_warn "claude-desktop" has claude-desktop
  checks_done
}
stage_main "$@"
