# Two faces for Flint: The Core, and Command

Both plug into Jared's ai-visualizer as extra faces and share one roster and one
live-activity file. `install.sh` installs both; The Core is the default.

## The Core (default): one sphere, the voice outside, the team inside

A blue wireframe sphere with drifting particles is the voice and the personality:
it turns slowly at idle, whirls and carries pulses along its edges while Flint
thinks, and its vertices push outward with the waveform while he speaks
(listening tints it amber and pulls it inward with the mic level). Inside it, a
dense particle sphere is the team, zoomed out: leads and workers are the brighter
points on the shell, Command is the glowing cluster at the very centre, and any
agent that is working right now glows green even from out here.

Zoom in and the outer sphere opens past the edges of the screen while the core
resolves into the org chart: Command, team leads, workers, each worker's Job,
and their tools, lit live. Zoom back out and it folds into the sphere again.

| Key | Does |
| --- | --- |
| `Z`, `Enter`, click the core, wheel up | zoom into the team |
| `Esc`, `Z`, wheel down past minimum | back to the sphere |
| wheel / drag | zoom and pan the chart; click a lead to focus its department; double-click resets |
| click a worker or job | detail card: job, tools, how to address it, where its memory lives |
| `F` | browser full screen; `R` reloads the roster |
| `?view=team` | open already zoomed in |

**Flint zooms it himself.** `~/my-agent/bin/core-view.sh team finance` zooms
in and focuses Finance; `core-view.sh team` zooms in; `core-view.sh voice` goes
back. It writes a tiny `view.json` both faces poll twice a second. Give Flint
the habit by appending this to `~/my-agent/CLAUDE.md` (the conductor does it):

```markdown
## Showing the team on screen
The face on the visualizer can zoom into the agent team. When Valentin asks to see the
team, the structure, who is working, or one department, run
`~/my-agent/bin/core-view.sh team [department-id]` (ids from team.yaml: comms, finance,
content, knowledge, automations) and then answer. When the conversation moves on, run
`~/my-agent/bin/core-view.sh voice`. Say what you put on screen in one short sentence.
```

## Command: the board full screen, the team docked beside it

A fifth face for Jared's ai-visualizer, built for this ThinkPad setup. The circuit
board (or any other face) runs full screen as Flint's voice, and the agent org
chart from `07-agent-team.md` sits docked beside it: Command at the centre, team
leads around it, their workers, each worker's Job, and the tools they use. Agents
light up while they work. One key swaps the focus; another zooms the team full
screen.

```
+--------------------------------------------+-----------------+
|                                            | TEAM 5 · 14 · 2 |
|            the circuit board               |                 |
|         (Flint speaking, live)            |    o   o   o    |
|                                            |  o   (J)   o    |
|                                            |    o   o   o    |
+--------------------------------------------+-----------------+
   T -> the team takes 72% and the board 28%.  G -> team full screen.
```

## Install (after Flint exists)

```bash
~/site/jarvis-thinkpad/command-face/install.sh          # or: install.sh ~/my-agent
```

It copies both faces to `~/my-agent/ai-visualizer/faces/{core,command}/`, the
three helper scripts to `~/my-agent/bin/`, seeds `~/my-agent/team.yaml` from
`team.example.yaml` if you have none, generates `team.json`, wires four hooks
into `~/my-agent/.claude/settings.json` (merged; nothing of yours is removed),
and sets `"face": "core"` in `ai-visualizer.json` (previous copy kept as `.bak`;
`install.sh --default=command` picks the other one). Restart the stack and the browser opens on it. Idempotent; re-run after
pulling a newer copy of this repo.

Try it with no voice line: `cd ~/my-agent/ai-visualizer && ./run.sh --mock speaking`,
or open `http://127.0.0.1:8790/faces/core/?demo=1` (and `/faces/command/?demo=1`).

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
| `core/index.html`, `core/face.json` | `ai-visualizer/faces/core/` | The Core face; appears in the gallery automatically |
| `face/index.html`, `face/face.json` | `ai-visualizer/faces/command/` | the Command face |
| `core-view.sh` | `~/my-agent/bin/` | the agent's zoom control; writes `faces/command/view.json` |
| `team-sync.py` | `~/my-agent/bin/` | `team.yaml` → `faces/command/team.json`; `--agents` creates missing `.claude/agents/<dept>/<name>.md` (never overwrites) |
| `team-live.py` | `~/my-agent/bin/` | hook helper that writes `faces/command/live.json` |
| `team.example.yaml` | `~/my-agent/team.yaml` (if missing) | the starter roster: Comms, Finance, Content, Knowledge, Automations |
| `install.sh` | run from this folder | the whole install, idempotent |

`team.yaml` shape: `operator`, `command`, and `departments[]` each with `id`,
`name`, `lead`, `folder` and `workers[]` of `name`, `job`, `description`, `tools[]`.
Worker names are lowercase-with-hyphens and unique; one worker owns one Job.
`team-sync.py --check` validates without writing.

## Updating

`faces/core/` and `faces/command/` are untracked in ai-visualizer's git, so Jared's
`update.sh` never touches them. To update the faces, pull this repo and run
`install.sh` again. `team.json`, `live.json` and `view.json` are generated, never
edited by hand.

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
