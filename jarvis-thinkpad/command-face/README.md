# The Command face: voice front and centre, the team on the side

A fifth face for Jared's ai-visualizer, built for this ThinkPad setup. The circuit
board (or any other face) runs full screen as Jarvis's voice, and the agent org
chart from `07-agent-team.md` sits docked beside it: Command at the centre, team
leads around it, their workers, each worker's Job, and the tools they use. Agents
light up while they work. One key swaps the focus; another zooms the team full
screen.

```
+--------------------------------------------+-----------------+
|                                            | TEAM 5 · 14 · 2 |
|            the circuit board               |                 |
|         (Jarvis speaking, live)            |    o   o   o    |
|                                            |  o   (J)   o    |
|                                            |    o   o   o    |
+--------------------------------------------+-----------------+
   T -> the team takes 72% and the board 28%.  G -> team full screen.
```

## Install (after Jarvis exists)

```bash
~/site/jarvis-thinkpad/command-face/install.sh          # or: install.sh ~/my-agent
```

It copies the face to `~/my-agent/ai-visualizer/faces/command/`, the two helper
scripts to `~/my-agent/bin/`, seeds `~/my-agent/team.yaml` from
`team.example.yaml` if you have none, generates `team.json`, wires four hooks
into `~/my-agent/.claude/settings.json` (merged; nothing of yours is removed),
and sets `"face": "command"` in `ai-visualizer.json` (previous copy kept as
`.bak`). Restart the stack and the browser opens on it. Idempotent; re-run after
pulling a newer copy of this repo.

Try it with no voice line: `cd ~/my-agent/ai-visualizer && ./run.sh --mock speaking`,
or open `http://127.0.0.1:8790/faces/command/?demo=1`.

## Keys and mouse

| Key | Does |
| --- | --- |
| `T` | swap focus: voice big / team big (buttons in the pane do the same) |
| `G` | team full screen; `G` or `Esc` brings the voice back |
| `H` | hide the team pane entirely (voice only); `H` again to show it |
| `R` | reload the roster after editing `team.yaml` and re-running team-sync |
| `F` | browser full screen |
| wheel | zoom the graph around the cursor; drag pans |
| click a lead | zoom into that department (its workers and tools, the rest dimmed); click again or double-click to reset |
| click a worker or job | detail card: job, tools, how to address it (`@agent-<name>`), where its memory lives |
| `?voice=neural` | run another inner face (`board`, `neural`, `radial`, `rain`) |

The inner face keeps its own keys (Space for the board's flythrough) when it has
focus; moving the mouse into the team pane gives the keys back to the Command page.

## What lights up

- **Command** mirrors the voice bus (amber listening, green thinking with a
  rotating arc, ripples while speaking) and, when the voice is idle, the typed
  session's state from the `UserPromptSubmit` / `Stop` hooks.
- **Workers and leads** turn green and pulse while a subagent with that name is
  running (`SubagentStart` / `SubagentStop` hooks). Their edges carry a moving
  pulse. A worker that never reported stop clears after an hour.
- The header counts leads, workers and how many are working right now.

## Files

| File | Where it lands | Job |
| --- | --- | --- |
| `face/index.html`, `face/face.json` | `ai-visualizer/faces/command/` | the face itself; appears in the gallery automatically |
| `team-sync.py` | `~/my-agent/bin/` | `team.yaml` → `faces/command/team.json`; `--agents` creates missing `.claude/agents/<dept>/<name>.md` (never overwrites) |
| `team-live.py` | `~/my-agent/bin/` | hook helper that writes `faces/command/live.json` |
| `team.example.yaml` | `~/my-agent/team.yaml` (if missing) | the starter roster: Comms, Finance, Content, Knowledge, Automations |
| `install.sh` | run from this folder | the whole install, idempotent |

`team.yaml` shape: `operator`, `command`, and `departments[]` each with `id`,
`name`, `lead`, `folder` and `workers[]` of `name`, `job`, `description`, `tools[]`.
Worker names are lowercase-with-hyphens and unique; one worker owns one Job.
`team-sync.py --check` validates without writing.

## Updating

`faces/command/` is untracked in ai-visualizer's git, so Jared's `update.sh`
never touches it. To update the face, pull this repo and run `install.sh` again.
`team.json` and `live.json` are regenerated, never edited by hand.

## Troubleshooting

- Pane says "no team.json here yet": run `uv run ~/my-agent/bin/team-sync.py`.
- Nothing lights up while agents work: `cat ~/my-agent/ai-visualizer/faces/command/live.json`
  after a subagent ran. Empty means the hooks are not firing: check
  `~/my-agent/.claude/settings.json` has the four `team-live.py` entries and that
  the session runs in `~/my-agent` (hooks are per project).
- The team shows but Command never changes with the voice: the visualizer's
  `bus_dir` is not pointed at the backtalk folder; that is the same wiring the
  board face needs (`fullstack-agent/TROUBLESHOOTING.md`).
- Board keys stopped working: click the board once; keys go to whichever pane
  has focus.

License: the face is a plugin for ai-visualizer and carries the same
AGPL-3.0-or-later terms; the helper scripts too.
