#!/usr/bin/env -S uv run --quiet --script
# /// script
# requires-python = ">=3.9"
# dependencies = ["pyyaml"]
# ///
"""team-sync.py: turn ~/my-agent/team.yaml (the roster) into what the Command face
and Claude Code need.

  uv run ~/my-agent/bin/team-sync.py            # writes faces/command/team.json
  uv run ~/my-agent/bin/team-sync.py --agents   # also creates missing .claude/agents/<dept>/<name>.md
  uv run ~/my-agent/bin/team-sync.py --check    # validate only

Runs with plain python3 too when PyYAML is installed, or when the roster is team.json.
Never overwrites an agent file that already exists.
"""
import argparse, json, os, re, sys

HOME_DEFAULT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # ~/my-agent when installed in bin/

LEAD_TEMPLATE = """---
name: {lead}
description: Team lead for {name}. Use proactively for anything about {topics}. Delegates to the {name} workers and reports back in one summary.
model: fable
permissionMode: acceptEdits
memory: project
background: true
---
You lead the {name} department of {operator}'s operation. Your department folder is
`{folder}` in the vault and its Jobs live in `{folder}/Jobs/`. Read the folder index
first. You do not do the work yourself: split the request into the Jobs it touches
and delegate each to its owner, in parallel when independent:
{worker_lines}
Check each result against the Job's quality bar before accepting it. Reply to
Command with one summary: done, open, decisions needed. Log the run in today's
daily note. Never send, publish or pay for anything yourself; leave drafts and
proposals for {operator}.
"""

WORKER_TEMPLATE = """---
name: {name}
description: Worker in {dept}. {desc} Called by {lead}.
model: sonnet
permissionMode: acceptEdits
memory: project
maxTurns: 40
---
Your Job note is `{folder}/Jobs/{job}.md`. Read it end to end and follow its boot
chain, procedure and quality bar. Tools you use: {tools}. Output goes where the
Job note says, with frontmatter, plus a three-line summary for your lead. Fold
every correction into your memory so the next run is closer.
"""


def load_roster(path):
    with open(path, encoding="utf-8") as f:
        text = f.read()
    if path.endswith(".json"):
        return json.loads(text)
    try:
        import yaml  # type: ignore
    except ImportError:
        sys.exit("PyYAML is not installed. Run this script with: uv run team-sync.py  (or rename the roster to team.json)")
    return yaml.safe_load(text)


def slug(s):
    return re.sub(r"[^a-z0-9]+", "-", str(s).lower()).strip("-")


def validate(team):
    problems, seen_workers, seen_jobs = [], {}, {}
    if not isinstance(team, dict):
        return ["roster is not a mapping"]
    team.setdefault("operator", "Valentin")
    team.setdefault("command", "flint")
    depts = team.get("departments") or []
    if not depts:
        problems.append("no departments")
    for d in depts:
        if not d.get("id"):
            d["id"] = slug(d.get("name", ""))
        if not d.get("name"):
            problems.append(f"department {d['id']} has no name")
        d.setdefault("lead", f"{d['id']}-lead")
        d.setdefault("folder", d["name"])
        d.setdefault("workers", [])
        for w in d["workers"]:
            if not w.get("name"):
                problems.append(f"a worker in {d['id']} has no name"); continue
            if w["name"] != slug(w["name"]):
                problems.append(f"worker name '{w['name']}' must be lowercase-with-hyphens (subagent rule)")
            if w["name"] in seen_workers:
                problems.append(f"worker '{w['name']}' appears in {seen_workers[w['name']]} and {d['id']}")
            seen_workers[w["name"]] = d["id"]
            job = w.get("job")
            if not job:
                problems.append(f"worker '{w['name']}' has no job (one worker, one Job note)")
            elif job in seen_jobs:
                problems.append(f"job '{job}' is owned by both {seen_jobs[job]} and {w['name']} (one Job, one worker)")
            else:
                seen_jobs[job] = w["name"]
            w.setdefault("tools", [])
            w["tools"] = [slug(t) for t in w["tools"]]
    return problems


def write_json(team, out):
    os.makedirs(os.path.dirname(out), exist_ok=True)
    tmp = out + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(team, f, indent=2, ensure_ascii=False)
    os.replace(tmp, out)


def write_agents(team, home):
    created = []
    root = os.path.join(home, ".claude", "agents")
    for d in team["departments"]:
        ddir = os.path.join(root, d["id"])
        os.makedirs(ddir, exist_ok=True)
        lead_path = os.path.join(ddir, d["lead"] + ".md")
        if not os.path.exists(lead_path):
            topics = ", ".join(w.get("job", w["name"]).lower() for w in d["workers"]) or d["name"].lower()
            worker_lines = "\n".join(f"- {w.get('job', w['name'])} -> the `{w['name']}` subagent" for w in d["workers"]) or "- (add workers to team.yaml)"
            with open(lead_path, "w", encoding="utf-8") as f:
                f.write(LEAD_TEMPLATE.format(lead=d["lead"], name=d["name"], topics=topics, operator=team["operator"],
                                             folder=d["folder"], worker_lines=worker_lines))
            created.append(lead_path)
        for w in d["workers"]:
            wp = os.path.join(ddir, w["name"] + ".md")
            if os.path.exists(wp):
                continue
            with open(wp, "w", encoding="utf-8") as f:
                f.write(WORKER_TEMPLATE.format(name=w["name"], dept=d["name"], desc=w.get("description", w.get("job", "")),
                                               lead=d["lead"], folder=d["folder"], job=w.get("job", w["name"]),
                                               tools=", ".join(w["tools"]) or "the vault"))
            created.append(wp)
    return created


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--home", default=HOME_DEFAULT, help="the agent's home (default: the folder above this script)")
    ap.add_argument("--roster", help="team.yaml or team.json (default: <home>/team.yaml, then team.json)")
    ap.add_argument("--out", help="where the face reads the roster (default: <home>/ai-visualizer/faces/command/team.json)")
    ap.add_argument("--agents", action="store_true", help="create missing .claude/agents files from the roster")
    ap.add_argument("--check", action="store_true", help="validate only, write nothing")
    a = ap.parse_args()
    home = os.path.expanduser(a.home)
    roster = a.roster or next((p for p in (os.path.join(home, "team.yaml"), os.path.join(home, "team.json")) if os.path.exists(p)), None)
    if not roster or not os.path.exists(roster):
        sys.exit(f"no roster found: create {os.path.join(home, 'team.yaml')} (see team.example.yaml)")
    team = load_roster(roster)
    problems = validate(team)
    for p in problems:
        print("problem:", p, file=sys.stderr)
    if problems:
        sys.exit(1)
    n_w = sum(len(d["workers"]) for d in team["departments"])
    print(f"roster ok: {len(team['departments'])} departments, {n_w} workers ({roster})")
    if a.check:
        return
    out = a.out or os.path.join(home, "ai-visualizer", "faces", "command", "team.json")
    write_json(team, out)
    print("wrote", out)
    if a.agents:
        created = write_agents(team, home)
        print(f"agent files created: {len(created)}")
        for c in created:
            print("  ", c)
        if not created:
            print("   (all present already; nothing overwritten)")


if __name__ == "__main__":
    main()
