# Two faces for Flint: The Core, and Command

Both plug into Jared's ai-visualizer as extra faces and share one roster and one
live-activity file. `install.sh` installs both; The Core is the default.

## The Core (default): the voice outside, the team inside, the data around them

The chosen design from the mockup rounds (`mockups/r4-4-out.jpg` and `r4-4-in.jpg`),
running for real: `core-out.jpg` (resting, speaking), `core-in.jpg` (zoomed into the
core), `core-thinking.jpg`, `core-listening.jpg` (shot on the visualizer's mock bus
with the example roster; the name reads Jarvis there because that is the mock's
config, yours says Flint).

- **The outer layer is the voice.** Three tilted orbits of particles drift at
  idle, whirl while Flint thinks, tint amber and follow the mic while he
  listens, and their particles swell with the waveform while he speaks. Under
  them, his name in serif and the state word.
- **The core is the team, zoomed out.** Command glows at the centre with the
  state, the five leads sit around it, the workers are points, and whoever is
  working right now is green. A line under it counts leads, workers, working.
- **The data sits around them.** Agents working and turns today (top left), the
  plan's 5-hour and 7-day usage windows with when they reset (top right; backtalk
  publishes them when `"show_usage": true` is in `backtalk.json`, otherwise the
  tiles say so), the conversation with the live waveform (bottom left: what you
  said, typed or spoken, and what Flint answered), and the activity feed (bottom
  right: agents starting and finishing, what they reported, your turns).
  The four sparklines fill in over the first hours (one point every ten minutes,
  kept in the browser).

Zoom in and the orbits open past the edges of the screen while the core grows
into the org chart: Command, team leads, workers, each worker's Job, and their
tools, lit live. The tiles stay where they are. Zoom out and it folds back.

| Key | Does |
| --- | --- |
| `Z`, `Enter`, click the core, wheel up | zoom into the team |
| `Esc`, `Z`, wheel down past minimum | back to the sphere |
| wheel / drag | zoom and pan the chart; click a lead to focus its department; double-click resets |
| click a worker or job | detail card: job, tools, how to address it, where its memory lives |
| `F` | browser full screen; `R` reloads the roster |
| `?view=team` | open already zoomed in |
| `?demo=1` | performs with a sample roster, conversation and numbers (no voice line, no hooks needed) |

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
The usage tiles need `"show_usage": true` in `~/my-agent/backtalk/backtalk.json`
(off by default in backtalk; it is your own plan's usage, shown on your own screen).

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
- **The conversation and the feed** come from the same hooks: `UserPromptSubmit`
  carries what you said, `Stop` reads Flint's answer from the session transcript,
  `SubagentStop` reads what a worker reported. The voice session is a Claude
  Agent SDK session in `~/my-agent`, so it fires them too. All of it stays in
  `live.json` on this machine, served to 127.0.0.1 only. To keep the words out of
  the file (only who is working), give the hooks `COMMAND_FACE_WORDS=0`:
  `"command": "COMMAND_FACE_WORDS=0 python3 ~/my-agent/bin/team-live.py"`.
- **Usage** (5-hour and 7-day windows) is the visualizer's own readout, published
  by backtalk when `"show_usage": true`.
- The core's count line shows leads, workers and how many are working right now.

## Files

| File | Where it lands | Job |
| --- | --- | --- |
| `core/index.html`, `core/face.json` | `ai-visualizer/faces/core/` | The Core face; appears in the gallery automatically |
| `face/index.html`, `face/face.json` | `ai-visualizer/faces/command/` | the Command face |
| `core-view.sh` | `~/my-agent/bin/` | the agent's zoom control; writes `faces/command/view.json` |
| `team-sync.py` | `~/my-agent/bin/` | `team.yaml` → `faces/command/team.json`; `--agents` creates missing `.claude/agents/<dept>/<name>.md` (never overwrites) |
| `team-live.py` | `~/my-agent/bin/` | hook helper that writes `faces/command/live.json`: who works, the conversation, the feed, turns today |
| `team.example.yaml` | `~/my-agent/team.yaml` (if missing) | the starter roster: Comms, Finance, Content, Knowledge, Automations |
| `install.sh` | run from this folder | the whole install, idempotent |

`team.yaml` shape: `operator`, `command`, and `departments[]` each with `id`,
`name`, `lead`, `folder` and `workers[]` of `name`, `job`, `description`, `tools[]`.
Worker names are lowercase-with-hyphens and unique; one worker owns one Job.
`team-sync.py --check` validates without writing. An optional `schedules[]`
list (`name`, `on_calendar`, `agent`, `prompt`, `permission_mode`, `max_turns`,
`enabled`) becomes systemd user timers through `install/team-timers.py`
(`07-agent-team.md`, section 3).

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
