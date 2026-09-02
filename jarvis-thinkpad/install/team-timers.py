#!/usr/bin/env -S uv run --quiet --script
# /// script
# requires-python = ">=3.9"
# dependencies = ["pyyaml"]
# ///
"""team-timers.py: the `schedules:` list in ~/my-agent/team.yaml becomes systemd user timers
that run the agent (or one of its subagents) headless, as Flint, with the vault.

  uv run ~/my-agent/bin/team-timers.py --apply     # write jobs/*.json + units, daemon-reload, enable
  uv run ~/my-agent/bin/team-timers.py --list      # what is scheduled
  uv run ~/my-agent/bin/team-timers.py --remove    # disable and delete every timer this made
  ~/my-agent/bin/run-job.py <name>                 # run one job now, by hand (same as the timer)

team.yaml:
  schedules:
    - name: morning-brief            # unit flint-morning-brief.{service,timer}; job file jobs/morning-brief.json
      on_calendar: "Mon..Fri 07:00"  # systemd OnCalendar
      agent: ""                      # "" = the agent itself; or a subagent name from the roster
      prompt: "..."                  # what to do
      permission_mode: acceptEdits   # acceptEdits | bypassPermissions | default
      max_turns: 60
      enabled: true

Each job's prompt lives in jobs/<name>.json and a tiny runner (bin/run-job.py) execs
claude with it, so no quoting ever passes through systemd.
"""
import argparse, json, os, re, subprocess

HOME_DEFAULT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UNIT_DIR = os.path.expanduser("~/.config/systemd/user")
RUNNER = '''#!/usr/bin/env python3
"""run-job.py <name>: run jobs/<name>.json as the agent, headless. Written by team-timers.py."""
import json, os, sys, glob
home = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
job = json.load(open(os.path.join(home, "jobs", sys.argv[1] + ".json")))
os.chdir(home)
os.environ["PATH"] = os.path.expanduser("~/.local/bin") + ":/usr/local/bin:/usr/bin:/bin"
for f in glob.glob(os.path.expanduser("~/.config/flint/*.env")):      # secrets by name
    for line in open(f):
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            k, v = line.split("=", 1); os.environ.setdefault(k, v.strip().strip("'\\""))
args = ["claude", "-p", job["prompt"], "--permission-mode", job.get("permission_mode") or "acceptEdits", "--max-turns", str(job.get("max_turns") or 60), "--output-format", "text"]
if job.get("agent"):
    args += ["--agent", job["agent"]]
os.execvp("claude", args)
'''


def load_roster(home):
    p = os.path.join(home, "team.yaml")
    if os.path.exists(p):
        import yaml
        return yaml.safe_load(open(p)) or {}
    p = os.path.join(home, "team.json")
    return json.load(open(p)) if os.path.exists(p) else {}


def slug(s):
    return re.sub(r"[^a-z0-9]+", "-", str(s).lower()).strip("-")


def sysctl(*args, quiet=True):
    return subprocess.call(["systemctl", "--user", *args], stdout=subprocess.DEVNULL if quiet else None, stderr=subprocess.DEVNULL if quiet else None)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--home", default=HOME_DEFAULT)
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--apply", action="store_true"); g.add_argument("--list", action="store_true"); g.add_argument("--remove", action="store_true")
    a = ap.parse_args()
    home = os.path.abspath(os.path.expanduser(a.home))
    os.makedirs(UNIT_DIR, exist_ok=True)
    if a.list:
        sysctl("list-timers", "--all", "flint-*", quiet=False); return
    if a.remove:
        for f in sorted(os.listdir(UNIT_DIR)):
            if f.startswith("flint-") and f.endswith(".timer") and os.path.exists(os.path.join(UNIT_DIR, f + ".made-by-team-timers")):
                sysctl("disable", "--now", f)
                for path in (f, f + ".made-by-team-timers", f[:-6] + ".service"):
                    try: os.remove(os.path.join(UNIT_DIR, path))
                    except FileNotFoundError: pass
                print("removed", f)
        sysctl("daemon-reload"); return

    for d in ("jobs", "logs", "bin"):
        os.makedirs(os.path.join(home, d), exist_ok=True)
    runner = os.path.join(home, "bin", "run-job.py")
    if not os.path.exists(runner) or open(runner).read() != RUNNER:
        open(runner, "w").write(RUNNER); os.chmod(runner, 0o755)
    sched = load_roster(home).get("schedules") or []
    made = []
    for s in sched:
        name = slug(s.get("name") or "job")
        if not s.get("prompt") or not s.get("on_calendar"):
            print(f"  skip {name}: needs prompt and on_calendar"); continue
        json.dump({"prompt": s["prompt"], "agent": s.get("agent") or "", "permission_mode": s.get("permission_mode") or "acceptEdits",
                   "max_turns": int(s.get("max_turns") or 60), "description": s.get("description") or s.get("name")},
                  open(os.path.join(home, "jobs", name + ".json"), "w"), indent=2)
        unit = "flint-" + name
        who = f"agent {s['agent']}" if s.get("agent") else "the agent"
        open(os.path.join(UNIT_DIR, unit + ".service"), "w").write(f"""[Unit]
Description={s.get('description') or s.get('name')} ({who})
After=network-online.target

[Service]
Type=oneshot
WorkingDirectory={home}
ExecStart=/usr/bin/python3 {home}/bin/run-job.py {name}
StandardOutput=append:{home}/logs/{unit}.log
StandardError=append:{home}/logs/{unit}.log
""")
        open(os.path.join(UNIT_DIR, unit + ".timer"), "w").write(f"""[Unit]
Description={s.get('name')} on {s['on_calendar']}

[Timer]
OnCalendar={s['on_calendar']}
Persistent=true
RandomizedDelaySec=2m

[Install]
WantedBy=timers.target
""")
        open(os.path.join(UNIT_DIR, unit + ".timer.made-by-team-timers"), "w").write("")
        made.append((unit, s.get("enabled", True) is not False))
    sysctl("daemon-reload")
    for unit, enabled in made:
        if enabled:
            r = sysctl("enable", "--now", unit + ".timer")
            print(f"  {'enabled' if r == 0 else 'FAILED '} {unit}.timer")
        else:
            sysctl("disable", "--now", unit + ".timer"); print(f"  disabled {unit}.timer (enabled: false)")
    if not made:
        print("  no schedules in team.yaml")


if __name__ == "__main__":
    main()
