#!/usr/bin/env bash
# 12: Home Assistant Container, onboarded without a browser, a long-lived token for the
# agent, the MCP server integration switched on, and the agent connected to it.
. "$(dirname "$0")/lib.sh"
HA_DIR="$HOME/homeassistant"
HA_ENV="$HOME/.config/flint/ha.env"
dk() { docker "$@" 2>/dev/null || sg docker -c "docker $*" 2>/dev/null || sudo docker "$@"; }

run() {
  [ "$HOME_ASSISTANT" = 1 ] || { ok "HOME_ASSISTANT=0: skipped"; return 0; }
  has docker || die "docker missing (stage 05)"
  log "Home Assistant Container (docker compose)"
  mkdir -p "$HA_DIR"
  cat > "$HA_DIR/compose.yaml" <<EOF
services:
  homeassistant:
    container_name: homeassistant
    image: "ghcr.io/home-assistant/home-assistant:stable"
    volumes:
      - $HA_DIR:/config
      - /etc/localtime:/etc/localtime:ro
      - /run/dbus:/run/dbus:ro
    restart: unless-stopped
    stop_grace_period: 60s
    privileged: true
    network_mode: host
    environment:
      TZ: $(timedatectl show -p Timezone --value)
EOF
  ( cd "$HA_DIR" && dk compose up -d ) >/dev/null 2>&1 || ( cd "$HA_DIR" && dk compose up -d )
  say "waiting for http://127.0.0.1:8123 (first start pulls the image and initialises; a few minutes)"
  local i=0; until curl -fsS -m 3 -o /dev/null http://127.0.0.1:8123/api/onboarding 2>/dev/null || curl -sS -m 3 -o /dev/null -w '%{http_code}' http://127.0.0.1:8123/ 2>/dev/null | grep -q '^\(200\|302\|404\)$'; do
    sleep 5; i=$((i+5)); [ $i -ge 900 ] && die "Home Assistant did not come up in 15 minutes: docker logs homeassistant"
  done
  ok "Home Assistant answers on 8123"

  log "onboarding, long-lived token, MCP server integration (no browser needed)"
  python3 "$GUIDE_DIR/install/ha-setup.py" --url http://127.0.0.1:8123 --name "$YOUR_NAME" --user "${HA_USER:-$USER}" --agent "$AGENT_NAME" --env "$HA_ENV" || die "ha-setup.py failed; see above. Re-run: setup.sh --only 12"

  log "the agent's connection (.mcp.json, token from the environment)"
  python3 - "$AGENT_HOME/.mcp.json" <<'PY'
import json, os, sys
p = sys.argv[1]
try: d = json.load(open(p))
except Exception: d = {}
d.setdefault("mcpServers", {})["home-assistant"] = {"type": "http", "url": "http://127.0.0.1:8123/api/mcp", "headers": {"Authorization": "Bearer ${HA_TOKEN}"}}
tmp = p + ".tmp"; json.dump(d, open(tmp, "w"), indent=2); os.replace(tmp, p)
print("   .mcp.json: home-assistant -> http://127.0.0.1:8123/api/mcp with ${HA_TOKEN}")
# approve it once, so no session asks and the doctor can see it connect
us = os.path.expanduser("~/.claude/settings.json")
try: u = json.load(open(us))
except Exception: u = {}
en = u.setdefault("enabledMcpjsonServers", [])
if "home-assistant" not in en: en.append("home-assistant")
os.makedirs(os.path.dirname(us), exist_ok=True); t = us + ".tmp"; json.dump(u, open(t, "w"), indent=2); os.replace(t, us)
PY
  # the voice session and the launchers get the token from the same file
  grep -q 'flint/\*.env' "$AGENT_HOME/bin/launch.sh" 2>/dev/null || sed -i '2a for f in "$HOME"/.config/flint/*.env; do [ -f "$f" ] \&\& { set -a; . "$f"; set +a; }; done' "$AGENT_HOME/bin/launch.sh"
  [ "$UFW" = 1 ] && sudo ufw allow 8123/tcp >/dev/null 2>&1 || true
  ok "done. Expose entities to Assist in HA (Settings → Voice assistants → Expose) as devices arrive; the MCP server only sees exposed ones"
}

check() {
  [ "$HOME_ASSISTANT" = 1 ] || return 0
  chk "container running" bash -c "docker ps --format '{{.Names}}' 2>/dev/null | grep -qx homeassistant || sudo docker ps --format '{{.Names}}' | grep -qx homeassistant"
  chk "ha.env with HA_TOKEN (600)" bash -c "grep -q '^HA_TOKEN=' '$HA_ENV' && [ \"\$(stat -c %a '$HA_ENV')\" = 600 ]"
  chk "API answers with the token" bash -c ". '$HA_ENV'; curl -fsS -m 5 -H \"Authorization: Bearer \$HA_TOKEN\" http://127.0.0.1:8123/api/ | grep -q 'API running'"
  chk "MCP endpoint answers" bash -c ". '$HA_ENV'; curl -sS -m 8 -o /dev/null -w '%{http_code}' -X POST -H \"Authorization: Bearer \$HA_TOKEN\" -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' -d '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2025-03-26\",\"capabilities\":{},\"clientInfo\":{\"name\":\"doctor\",\"version\":\"1\"}}}' http://127.0.0.1:8123/api/mcp | grep -q '^200$'"
  chk ".mcp.json has home-assistant" grep -q '"home-assistant"' "$AGENT_HOME/.mcp.json"
  checks_done
}
stage_main "$@"
