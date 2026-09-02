# 05. Home automation: Home Assistant on the ThinkPad, wired into Jarvis

Home Assistant (HA) is the hub; Jarvis talks to it through HA's own **Model
Context Protocol Server** integration, so "turn off the kitchen lights" from the
voice line becomes a tool call, and Jarvis can also edit HA's YAML because he has
the files.

## 1. Install Home Assistant Container (Docker)

The ThinkPad is a general-purpose server, so the Container install is right
(Home Assistant OS wants the whole machine or a VM). `bootstrap.sh --with-docker`
installed Docker Engine and added you to the `docker` group (re-login required).

```bash
mkdir -p ~/homeassistant
docker run -d \
  --name homeassistant \
  --privileged \
  --restart=unless-stopped \
  -e TZ=Europe/Sofia \
  -v $HOME/homeassistant:/config \
  -v /run/dbus:/run/dbus:ro \
  --network=host \
  ghcr.io/home-assistant/home-assistant:stable
```

(Command from home-assistant.io/installation/linux; adjust `TZ`.) Open
`http://thinkpad.local:8123` or `http://127.0.0.1:8123`, create the owner account,
set the home location. `--privileged` plus host networking lets HA see USB
Zigbee/Z-Wave sticks and do mDNS discovery. Allow the LAN in: `sudo ufw allow 8123`.
Update later with `docker pull ghcr.io/home-assistant/home-assistant:stable && docker rm -f homeassistant` and the same `run`.

Container has no "add-ons". The two you would miss come as containers too:

```bash
# MQTT broker
docker run -d --name mosquitto --restart=unless-stopped -p 1883:1883 -v $HOME/mosquitto:/mosquitto eclipse-mosquitto
# Zigbee2MQTT (if you have a Zigbee USB coordinator; find it with ls /dev/serial/by-id/)
docker run -d --name zigbee2mqtt --restart=unless-stopped -p 8080:8080 \
  -v $HOME/zigbee2mqtt:/app/data --device=/dev/serial/by-id/<your-stick>:/dev/ttyACM0 koenkk/zigbee2mqtt
```

Prefer add-ons and the supervisor? Run Home Assistant OS in a KVM virtual
machine instead (`virt-manager`, the official `haos_ova-*.qcow2` image); the
ThinkPad's VT-x is on from `01` section C.

## 2. Turn on the MCP server in Home Assistant

1. Settings → Devices & services → Add integration → **Model Context Protocol Server**.
2. Settings → Voice assistants → **Expose**: tick every entity Jarvis may control.
   The MCP server only ever sees exposed entities. Start with lights, switches,
   climate, media players; leave locks and alarms unexposed until you trust it.
3. Your profile (bottom left) → Security → **Long-lived access tokens** → create
   one named `jarvis`. Copy it once; it is shown once.
4. Store it outside any file Jarvis writes docs into:
   ```bash
   mkdir -p ~/.config/jarvis && chmod 700 ~/.config/jarvis
   printf 'HA_TOKEN=%s\n' '<paste>' > ~/.config/jarvis/ha.env && chmod 600 ~/.config/jarvis/ha.env
   grep -q 'jarvis/ha.env' ~/.bashrc || echo 'set -a; . ~/.config/jarvis/ha.env; set +a' >> ~/.bashrc
   ```
   (Valentin types the paste, not Jarvis. The token never goes in the chat.)

## 3. Connect Jarvis to it

HA serves MCP at `http://127.0.0.1:8123/api/mcp` over streamable HTTP with a
bearer token. In `~/my-agent/.mcp.json` (project scope, so only Jarvis has it),
with the token pulled from the environment:

```json
{
  "mcpServers": {
    "home-assistant": {
      "type": "http",
      "url": "http://127.0.0.1:8123/api/mcp",
      "headers": { "Authorization": "Bearer ${HA_TOKEN}" }
    }
  }
}
```

Restart Claude Code in `~/my-agent`, approve the project MCP server when asked,
run `/mcp` and confirm `home-assistant` is connected and lists tools
(`HassTurnOn`, `HassTurnOff`, `HassLightSet`, `HassSetPosition`, climate and
media tools, and a `GetLiveContext` tool that returns the state of exposed entities).

Fallback if the HTTP transport misbehaves on your HA version (the HA docs show
this path): `uv tool install git+https://github.com/sparfenyuk/mcp-proxy`, then

```json
"home-assistant": { "command": "mcp-proxy",
  "args": ["--transport=streamablehttp", "--stateless", "http://127.0.0.1:8123/api/mcp"],
  "env": { "API_ACCESS_TOKEN": "${HA_TOKEN}" } }
```

The voice session (backtalk) runs the Agent SDK in `~/my-agent`, so it loads the
same `.mcp.json`: "Jarvis, kill the lights in the office" works by voice once the
typed session works.

## 4. Beyond the MCP tools

- **REST API** for anything the Assist tools do not cover:
  `curl -s -H "Authorization: Bearer $HA_TOKEN" http://127.0.0.1:8123/api/states | jq '.[].entity_id'`.
- **Automations and dashboards as files**: `~/homeassistant/automations.yaml`,
  `scripts.yaml`, `configuration.yaml`. Jarvis can write them, then reload with
  a REST call (`POST /api/services/automation/reload`). Validate first:
  `docker exec homeassistant python -m homeassistant --script check_config -c /config`.
- **Presence and phone**: install the HA companion app on the phone for
  location and notifications; Jarvis can `notify.mobile_app_<phone>` through the
  REST API.
- **Vault**: a `Home Automation` project folder with an index, an inventory of
  entities (exposed vs not), and a Job note "Add a new device" with the procedure.

## 5. Safety rules for the house

- Expose read-only or low-risk entities first. Locks, garage doors, alarm panels
  and heating setpoints only after a week of correct behaviour.
- Keep the voice in `ask` mode for a while: you hear "I want to turn off the
  boiler" before it happens.
- HA's own permission model is the backstop: an unexposed entity cannot be
  touched through MCP even in bypass mode.
- Never put the token in the vault, a daily note, or `CLAUDE.md`. Reference
  `~/.config/jarvis/ha.env` by name.
