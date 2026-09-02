#!/usr/bin/env python3
"""ha-setup.py: finish Home Assistant's onboarding without a browser, mint a long-lived
token for the agent, switch on the Model Context Protocol Server integration.

  ha-setup.py --url http://127.0.0.1:8123 --name Valentin --user valentin --agent Flint --env ~/.config/flint/ha.env

Standard library only. Idempotent: an already-onboarded instance is fine as long as
the env file (or --password) has the owner's password or an existing HA_TOKEN.
Writes HA_URL, HA_USER, HA_PASSWORD, HA_TOKEN into the env file (chmod 600).
Endpoints from the Home Assistant source (components/onboarding, auth, mcp_server, config).
"""
import argparse, base64, json, os, secrets, socket, struct, sys, time, urllib.error, urllib.parse, urllib.request

CLIENT_ID = None  # set from --url: "http://127.0.0.1:8123/"


def http(method, url, data=None, token=None, form=False, ok=(200, 201)):
    body = None
    headers = {"Accept": "application/json"}
    if data is not None:
        if form:
            body = urllib.parse.urlencode(data).encode(); headers["Content-Type"] = "application/x-www-form-urlencoded"
        else:
            body = json.dumps(data).encode(); headers["Content-Type"] = "application/json"
    if token:
        headers["Authorization"] = "Bearer " + token
    req = urllib.request.Request(url, data=body, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            raw = r.read().decode()
            return r.status, (json.loads(raw) if raw.strip() else {})
    except urllib.error.HTTPError as e:
        raw = e.read().decode(errors="replace")
        try: return e.code, json.loads(raw)
        except Exception: return e.code, {"raw": raw}


def read_env(p):
    d = {}
    if os.path.exists(p):
        for line in open(p):
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1); d[k] = v.strip().strip("'\"")
    return d


def write_env(p, d):
    os.makedirs(os.path.dirname(p), exist_ok=True)
    tmp = p + ".tmp"
    with open(tmp, "w") as f:
        for k, v in d.items():
            f.write(f"{k}={v}\n")
    os.chmod(tmp, 0o600); os.replace(tmp, p)


def onboarding_status(base):
    code, data = http("GET", base + "/api/onboarding")
    if code == 404:
        return None                     # views unregistered: fully onboarded
    if code != 200:
        raise SystemExit(f"GET /api/onboarding -> {code} {data}")
    return {s["step"]: s["done"] for s in data}


def exchange_code(base, code):
    st, tok = http("POST", base + "/auth/token", {"grant_type": "authorization_code", "code": code, "client_id": CLIENT_ID}, form=True)
    if st != 200 or "access_token" not in tok:
        raise SystemExit(f"token exchange failed: {st} {tok}")
    return tok


def login_flow(base, username, password):
    """The frontend's login: /auth/login_flow -> auth code -> tokens."""
    st, flow = http("POST", base + "/auth/login_flow", {"client_id": CLIENT_ID, "handler": ["homeassistant", None], "redirect_uri": CLIENT_ID + "?auth_callback=1"})
    if st != 200 or "flow_id" not in flow:
        raise SystemExit(f"login flow start failed: {st} {flow}")
    st, res = http("POST", base + f"/auth/login_flow/{flow['flow_id']}", {"username": username, "password": password, "client_id": CLIENT_ID})
    if st != 200 or res.get("type") != "create_entry":
        raise SystemExit(f"login failed for {username}: {st} {res}")
    return exchange_code(base, res["result"])


# ---------------------------------------------------------------- minimal websocket client (RFC 6455)
class WS:
    def __init__(self, url):
        u = urllib.parse.urlparse(url)
        self.sock = socket.create_connection((u.hostname, u.port or 80), timeout=30)
        key = base64.b64encode(secrets.token_bytes(16)).decode()
        req = (f"GET {u.path} HTTP/1.1\r\nHost: {u.hostname}:{u.port}\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n"
               f"Sec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n\r\n")
        self.sock.sendall(req.encode())
        resp = b""
        while b"\r\n\r\n" not in resp:
            chunk = self.sock.recv(4096)
            if not chunk: raise SystemExit("websocket handshake: connection closed")
            resp += chunk
        head, _, rest = resp.partition(b"\r\n\r\n")
        if b" 101 " not in head.split(b"\r\n")[0]:
            raise SystemExit("websocket handshake failed: " + head.decode(errors="replace").splitlines()[0])
        self.buf = rest

    def _recv(self, n):
        while len(self.buf) < n:
            chunk = self.sock.recv(65536)
            if not chunk: raise SystemExit("websocket closed")
            self.buf += chunk
        out, self.buf = self.buf[:n], self.buf[n:]
        return out

    def send(self, obj):
        payload = json.dumps(obj).encode()
        mask = secrets.token_bytes(4)
        head = bytes([0x81])
        n = len(payload)
        if n < 126: head += bytes([0x80 | n])
        elif n < 65536: head += bytes([0x80 | 126]) + struct.pack(">H", n)
        else: head += bytes([0x80 | 127]) + struct.pack(">Q", n)
        masked = bytes(b ^ mask[i % 4] for i, b in enumerate(payload))
        self.sock.sendall(head + mask + masked)

    def recv(self):
        while True:
            b0, b1 = self._recv(2)
            op, n = b0 & 0x0F, b1 & 0x7F
            if n == 126: n = struct.unpack(">H", self._recv(2))[0]
            elif n == 127: n = struct.unpack(">Q", self._recv(8))[0]
            if b1 & 0x80: mask = self._recv(4)
            else: mask = None
            data = self._recv(n)
            if mask: data = bytes(b ^ mask[i % 4] for i, b in enumerate(data))
            if op == 0x8: raise SystemExit("websocket closed by server")
            if op == 0x9: self.sock.sendall(bytes([0x8A, 0x80]) + secrets.token_bytes(4)); continue
            if op == 0x1: return json.loads(data.decode())


def long_lived_token(base, access_token, name):
    ws = WS(base.replace("http://", "ws://").replace("https://", "wss://") + "/api/websocket")
    msg = ws.recv()
    if msg.get("type") != "auth_required":
        raise SystemExit(f"unexpected websocket greeting: {msg}")
    ws.send({"type": "auth", "access_token": access_token})
    msg = ws.recv()
    if msg.get("type") != "auth_ok":
        raise SystemExit(f"websocket auth failed: {msg}")
    ws.send({"id": 1, "type": "auth/long_lived_access_token", "client_name": name, "client_icon": None, "lifespan": 3650})
    while True:
        msg = ws.recv()
        if msg.get("id") == 1:
            if not msg.get("success"): raise SystemExit(f"long-lived token refused: {msg}")
            return msg["result"]


def enable_mcp(base, token):
    st, res = http("POST", base + "/api/config/config_entries/flow", {"handler": "mcp_server"}, token=token)
    if st != 200:
        raise SystemExit(f"mcp_server flow start: {st} {res}")
    if res.get("type") == "abort":
        return "already configured" if res.get("reason") == "already_configured" else f"aborted: {res.get('reason')}"
    if res.get("type") == "form":
        st, res = http("POST", base + f"/api/config/config_entries/flow/{res['flow_id']}", {"llm_hass_api": ["assist"]}, token=token)
    if res.get("type") == "create_entry":
        return "enabled"
    raise SystemExit(f"mcp_server flow ended unexpectedly: {st} {res}")


def main():
    global CLIENT_ID
    ap = argparse.ArgumentParser()
    ap.add_argument("--url", default="http://127.0.0.1:8123")
    ap.add_argument("--name", required=True); ap.add_argument("--user", required=True); ap.add_argument("--agent", default="Flint")
    ap.add_argument("--env", default=os.path.expanduser("~/.config/flint/ha.env")); ap.add_argument("--password", default="")
    a = ap.parse_args()
    base = a.url.rstrip("/"); CLIENT_ID = base + "/"
    env = read_env(a.env)
    password = a.password or env.get("HA_PASSWORD") or secrets.token_urlsafe(18)
    username = env.get("HA_USER") or a.user

    status = onboarding_status(base)
    tokens = None
    if status is None:
        print("   onboarding already complete")
    else:
        if not status.get("user"):
            st, res = http("POST", base + "/api/onboarding/users", {"client_id": CLIENT_ID, "name": a.name, "username": username, "password": password, "language": "en"})
            if st != 200 or "auth_code" not in res:
                raise SystemExit(f"creating the owner failed: {st} {res}")
            tokens = exchange_code(base, res["auth_code"])
            print(f"   owner account created: {username}")
        else:
            if not (env.get("HA_PASSWORD") or a.password):
                raise SystemExit("the owner exists but I have no password for it (HA_PASSWORD in the env file or --password)")
            tokens = login_flow(base, username, password)
        at = tokens["access_token"]
        for step, body in (("core_config", {}), ("analytics", {}), ("integration", {"client_id": CLIENT_ID, "redirect_uri": CLIENT_ID + "?auth_callback=1"})):
            if status.get(step): continue
            st, res = http("POST", base + f"/api/onboarding/{step}", body, token=at)
            if st not in (200, 201):
                print(f"   warning: onboarding step {step} -> {st} {res}")
        print("   onboarding steps done")

    llat = env.get("HA_TOKEN", "")
    st, _ = http("GET", base + "/api/", token=llat) if llat else (401, None)
    if st != 200:
        if tokens is None:
            if not (env.get("HA_PASSWORD") or a.password):
                raise SystemExit("no valid HA_TOKEN and no HA_PASSWORD: create a long-lived token in HA (profile → Security) and put HA_TOKEN=... into " + a.env)
            tokens = login_flow(base, username, password)
        llat = long_lived_token(base, tokens["access_token"], a.agent.lower())
        print("   long-lived token created")
    else:
        print("   existing long-lived token still valid")

    print("   MCP server integration:", enable_mcp(base, llat))
    env.update({"HA_URL": base, "HA_USER": username, "HA_PASSWORD": password, "HA_TOKEN": llat})
    write_env(a.env, env)
    print(f"   credentials in {a.env} (chmod 600). Owner login for the HA web UI: {username} / the HA_PASSWORD in that file")


if __name__ == "__main__":
    main()
