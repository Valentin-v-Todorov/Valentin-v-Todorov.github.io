#!/usr/bin/env bash
# 14: the connections. The phone (KDE Connect), the Telegram bot, mail and calendars (the connectors in
# claude.ai plus the local IMAP/ICS tools), the intercom, the news, the knowledge drop folder, the DJ's
# taste notes and the errands preferences in the vault, and what the agent knows about all of it.
. "$(dirname "$0")/lib.sh"
SECRETS="$HOME/.config/flint"

run() {
  [ -f "$AGENT_HOME/CLAUDE.md" ] || die "no agent in $AGENT_HOME (stage 09 first)"
  mkdir -p "$AGENT_HOME/bin" "$HOME/.local/bin" "$HOME/.config/systemd/user" "$SECRETS"; chmod 700 "$SECRETS"
  cp "$GUIDE_DIR"/bin/flint-* "$AGENT_HOME/bin/" && chmod +x "$AGENT_HOME"/bin/flint-*
  for t in "$GUIDE_DIR"/bin/flint-*; do ln -sfn "$AGENT_HOME/bin/$(basename "$t")" "$HOME/.local/bin/$(basename "$t")"; done

  if [ "$PHONE" = 1 ]; then
    log "the phone: KDE Connect (install the KDE Connect app on the phone, same wifi, then: flint-phone pair)"
    apt_install_full kdeconnect
    if [ "$UFW" = 1 ] && has ufw; then sudo ufw allow 1714:1764/tcp >/dev/null 2>&1; sudo ufw allow 1714:1764/udp >/dev/null 2>&1; fi
    ok "kdeconnect installed; ports 1714-1764 open on the LAN"
  fi

  if [ "$TELEGRAM" = 1 ]; then
    log "the Telegram bot (you on the phone, him on the ThinkPad)"
    if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ ! -f "$SECRETS/telegram.env" ]; then
      printf 'TELEGRAM_BOT_TOKEN=%s\n' "$TELEGRAM_BOT_TOKEN" > "$SECRETS/telegram.env"; chmod 600 "$SECRETS/telegram.env"
      sed -i 's|^TELEGRAM_BOT_TOKEN=.*|TELEGRAM_BOT_TOKEN=""   # moved to ~/.config/flint/telegram.env|' "$ENV_FILE" 2>/dev/null || true
      ok "token moved from setup.env to $SECRETS/telegram.env (600)"
    fi
    cat > "$HOME/.config/systemd/user/flint-telegram.service" <<EOF
[Unit]
Description=$AGENT_NAME on Telegram
After=network-online.target
[Service]
Environment=PATH=%h/.local/bin:/usr/local/bin:/usr/bin:/bin
ExecStartPre=-/usr/bin/nm-online -q -t 60
ExecStart=$AGENT_HOME/bin/flint-telegram serve
Restart=always
RestartSec=15
[Install]
WantedBy=default.target
EOF
    systemctl --user daemon-reload 2>/dev/null || true
    if [ -f "$SECRETS/telegram.env" ]; then
      systemctl --user enable --now flint-telegram.service >/dev/null 2>&1 && ok "bot running: open it on the phone and send /start once (it learns your chat)" || warn "could not start flint-telegram.service"
    else
      warn "no bot token yet. Later: flint-telegram setup  (a token from @BotFather), then: systemctl --user enable --now flint-telegram.service"
    fi
  fi

  log "mail and calendars"
  say "Gmail and Google Calendar: enable the connectors at claude.ai > Settings > Connectors; they appear in Claude Code by themselves (claude mcp list)."
  say "Local fallbacks: flint-mail setup (IMAP/SMTP, an app password) and flint-calendar setup (the private ICS link). Both write chmod 600 files in $SECRETS."
  ok "documented for the agent in CLAUDE.md"

  log "the vault: news sources, the knowledge drop folder, the DJ's taste, your errand preferences"
  mkdir -p "$VAULT_DIR/Flint" "$VAULT_DIR/Knowledge/Drop" "$VAULT_DIR/Knowledge/Inbox"
  if [ -x "$AGENT_HOME/senses/.venv/bin/python" ]; then "$AGENT_HOME/bin/flint-news" --sources >/dev/null 2>&1 || true; fi
  [ -f "$VAULT_DIR/Flint/News Sources.md" ] || printf '# News sources\n\nOne feed link per line; Flint reads these for the news.\n\n- http://feeds.bbci.co.uk/news/world/rss.xml\n- https://hnrss.org/frontpage\n- https://feeds.arstechnica.com/arstechnica/index\n- https://www.theverge.com/rss/index.xml\n' > "$VAULT_DIR/Flint/News Sources.md"
  [ -f "$VAULT_DIR/Flint/Music Taste.md" ] || cat > "$VAULT_DIR/Flint/Music Taste.md" <<EOF
# Music taste

Flint keeps this from what you play, skip, like and dislike (flint-play like / dislike). Edit freely.

## Liked
- Eminem

## Disliked

## Moods
- focus: deep focus instrumental
- morning: upbeat morning playlist
- dinner: dinner jazz
- party: party hits
- sleep: sleep ambient
- workout: workout mix
EOF
  [ -f "$VAULT_DIR/Flint/Preferences.md" ] || cat > "$VAULT_DIR/Flint/Preferences.md" <<EOF
# Preferences for errands

What Flint reads before booking, ordering or filling a form in the browser, and updates afterwards. Names and
habits only: never a password, a card number or a token (those stay in the browser profile and the keyring).

## The usual
- Restaurant: (name, the usual table, how many)
- Groceries: (the shop, the delivery slot you prefer)
- Coffee / lunch: (the order)

## Addresses
- Home:
- Work:

## Sizes and details
- Clothes / shoes:
- Car plate:

## Rules
- Ask before anything that costs more than 50 (or whatever you set).
- Never pay without a spoken yes.
- Say what was booked and where the confirmation is.
EOF
  cp "$GUIDE_DIR/WHAT-FLINT-CAN-DO.md" "$VAULT_DIR/Flint/What I Can Do.md"
  ok "Flint/News Sources.md, Flint/Music Taste.md, Flint/Preferences.md, Flint/What I Can Do.md, Knowledge/Drop, Knowledge/Inbox"

  log "the knowledge drop folder: anything put in $VAULT_DIR/Knowledge/Drop is ingested every ten minutes"
  cat > "$HOME/.config/systemd/user/flint-ingest.service" <<EOF
[Unit]
Description=$AGENT_NAME ingests the Knowledge/Drop folder
[Service]
Type=oneshot
Environment=PATH=%h/.local/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=$AGENT_HOME/bin/flint-ingest --sweep
EOF
  cat > "$HOME/.config/systemd/user/flint-ingest.timer" <<'EOF'
[Unit]
Description=Knowledge drop folder, every ten minutes
[Timer]
OnStartupSec=5min
OnUnitActiveSec=10min
[Install]
WantedBy=timers.target
EOF
  systemctl --user daemon-reload 2>/dev/null; systemctl --user enable --now flint-ingest.timer >/dev/null 2>&1 && ok "flint-ingest.timer active" || warn "could not enable flint-ingest.timer"

  log "the sandbox: the new tools run on the host (network, phone, speakers)"
  python3 - "$HOME/.claude/settings.json" "$AGENT_HOME" <<'PY'
import json, os, sys
p, home = sys.argv[1], sys.argv[2]
try: cfg = json.load(open(p))
except Exception: cfg = {}
exc = cfg.setdefault("sandbox", {}).setdefault("excludedCommands", [])
tools = ["flint-say", "flint-notify", "flint-timer", "flint-look", "flint-presence", "flint-ears", "flint-telegram", "flint-phone",
         "flint-mail", "flint-calendar", "flint-news", "flint-ingest", "flint-guard", "flint-backup", "flint-offline", "flint-ha"]
for c in [f"{t} *" for t in tools] + [f"{home}/bin/{t} *" for t in tools] + ["kdeconnect-cli *", "restic *", "ollama *", "tesseract *", "pdftotext *", "ffmpeg *", "systemd-run *", "journalctl *"]:
    if c not in exc: exc.append(c)
tmp = p + ".tmp"; json.dump(cfg, open(tmp, "w"), indent=2); os.replace(tmp, p)
PY
  ok "excludedCommands extended"

  append_once "$AGENT_HOME/CLAUDE.md" "## Reaching $YOUR_NAME and the world" <<EOF
## Reaching $YOUR_NAME and the world
- Telegram: messages from the phone arrive as prompts (the bot runs \`flint-telegram serve\`); to reach $YOUR_NAME
  yourself, \`flint-notify "Title" "message"\` (screen, Telegram, phone push, all that exist) or \`flint-telegram send "text" --photo file\`.
- The phone (KDE Connect): \`flint-phone ring|battery|notifications\`, \`flint-phone sms <number> "text"\`, \`flint-phone send <file|url>\`,
  \`flint-phone clip "text"\`, \`flint-phone photo\`. Pairing is $YOUR_NAME's job on the phone: \`flint-phone pair\` asks.
- Mail and calendar: prefer the Gmail and Google Calendar connectors when \`claude mcp list\` shows them connected;
  otherwise \`flint-mail unread|read <id>|search|draft\` and \`flint-calendar today|tomorrow|week|next\`.
  Never send mail without \`--confirm\` after $YOUR_NAME said yes to the exact draft; never delete mail.
- Intercom: \`flint-say --to media_player.<room> "text"\` or \`--to all\`; \`flint-say --players\` lists the speakers.
- News: \`flint-news --brief\` (written), \`flint-news --read\` (spoken); the feeds live in the vault, Flint/News Sources.md.
- Knowledge: \`flint-ingest <pdf|url|youtube|file> [--say]\` files a summary note in Knowledge/Inbox and tells the gist;
  anything $YOUR_NAME drops into Knowledge/Drop gets the same treatment every ten minutes.
- Music taste: \`flint-play like\` / \`flint-play dislike\` record the current song in Flint/Music Taste.md; \`flint-play --for focus\`
  (or morning, dinner, party, sleep, workout) plays a mood; \`flint-play --for me\` plays from the liked list; \`flint-play taste\`
  says what $YOUR_NAME replays and skips. Update the note when you learn something ("I hate that song" counts).
- Errands in the browser: read Flint/Preferences.md first, do it in the Playwright browser (logins persist in its profile),
  update the note after. Ask before paying, ever. Say what was booked and where the confirmation is.
- "What can you do?": answer from the vault note Flint/What I Can Do.md (every ability, the words that trigger it, the
  tool, and what is not built yet). When $YOUR_NAME asks for something you cannot do, offer to build it: a script in
  bin/, a line in this file, a check for the doctor; then add a row to that note.
EOF
  ok "CLAUDE.md: reaching you and the world"
}

check() {
  [ "$PHONE" = 1 ] && chk "kdeconnect-cli installed" has kdeconnect-cli
  [ "$PHONE" = 1 ] && [ "$UFW" = 1 ] && chk_warn "ufw lets KDE Connect through" bash -c "sudo ufw status | grep -q 1714:1764"
  [ "$TELEGRAM" = 1 ] && chk_warn "Telegram bot running (needs the token, then /start)" systemctl --user is-active flint-telegram.service
  chk "tools on PATH (telegram, phone, mail, calendar, news, ingest, ha)" bash -c "for t in flint-telegram flint-phone flint-mail flint-calendar flint-news flint-ingest flint-ha; do [ -x '$HOME/.local/bin/'\$t ] || exit 1; done"
  chk "vault seeds (news sources, music taste, preferences, drop folder)" bash -c "[ -f '$VAULT_DIR/Flint/News Sources.md' ] && [ -f '$VAULT_DIR/Flint/Music Taste.md' ] && [ -f '$VAULT_DIR/Flint/Preferences.md' ] && [ -d '$VAULT_DIR/Knowledge/Drop' ]"
  chk "ingest timer active" systemctl --user is-active flint-ingest.timer
  chk "CLAUDE.md has the connections section" grep -q "flint-telegram" "$AGENT_HOME/CLAUDE.md"
  chk "flint-mail and flint-telegram parse" bash -c "python3 -m py_compile '$AGENT_HOME/bin/flint-mail' '$AGENT_HOME/bin/flint-telegram'"
  [ "$HOME_ASSISTANT" = 1 ] && chk_warn "intercom: Home Assistant lists media players" bash -c "flint-say --players | grep -q media_player"
  checks_done
}
stage_main "$@"
