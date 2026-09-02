# 07. A team of agents that work on their own (and the FounderOS dashboard on top)

You asked: can Flint have different agents for different tasks, working on
their own, like the Founder OS demo? Yes. But read what the demo's agents really
are first, because the working-on-their-own part should be built with Claude
Code's own features, not with the demo's code.

## 1. What the demo's agents actually are (from `lib/agents/*.ts`)

- Each agent is a TypeScript object with a `run()` that mostly pings one
  connector and reports status: "Gmail Worker: unread counts", "Stripe: payment
  confirmation", "Stack Monitor". Real, but small.
- Agent chat is **read-only by design**. The system prompt in `lib/agents/chat.ts`
  says: "You are READ-ONLY: never claim to have sent, created, scheduled, or
  published anything." They can look things up; they cannot act.
- Scheduled jobs are stored and displayed only. `lib/cron.ts` says it plainly:
  "the actual runner lands with the dedicated host deployment". In the demo,
  nothing runs on its own.
- The model is reached through the Vercel AI Gateway (`AI_GATEWAY_API_KEY`),
  which is pay-per-token API billing, separate from your Claude subscription.
- The Conductor (`lib/agents/conductor.ts`) is a router: it asks the model which
  agent fits a message, or you address one with `@name`.

So the demo is an excellent **picture** of an agent team (org chart, roster,
activity feed, task board, cron list, knowledge graph) with placeholder muscle.
Claude Code has the muscle. The plan: build the team in Claude Code, and add the
demo as the dashboard only if you want the visuals.

## 2. Layer 1: named specialist agents inside Flint (subagents)

Claude Code subagents are markdown files in `~/my-agent/.claude/agents/`. Each
has its own system prompt, tool allowlist, model, permission mode, MCP servers,
preloaded skills and **its own persistent memory**. Flint (the main session)
delegates to them by their `description`, or you address one directly with
`@agent-<name>`. They run in the background, in parallel (up to 20), and they
all read `~/my-agent/CLAUDE.md`, so they know the vault and its rules. This is
the Conductor → departments → workers structure from the demo, with real hands.

Flint writes these files; the set below is a starting roster for a personal
business plus the house plus the machine. Adjust names and models freely.

`~/my-agent/.claude/agents/comms.md`

```markdown
---
name: comms
description: Inbox and messages. Use proactively for triaging email, drafting replies, summarising threads, and keeping the CRM pipeline note current.
model: sonnet
permissionMode: acceptEdits
memory: project
background: true
---
You are the communications agent of Valentin's business. Read VAULT-INDEX.md and
the CRM folder index before acting. Triage by: needs reply today / this week /
FYI / spam. Draft replies in Valentin's voice (see the vault's writing rules) into
`00 - Inbox/Drafts/` and never send anything yourself. Update the pipeline note
when a lead moves stage. Log what you did in today's daily note.
```

`~/my-agent/.claude/agents/content.md`

```markdown
---
name: content
description: Marketing and content. Use for posts, emails, ads, lead magnets, sales pages and funnel planning.
model: fable
skills: [jaredrhod-marketing]
permissionMode: acceptEdits
memory: project
---
You are the content agent. Before any marketing work read jareds-takes.md and the
matching playbook (the skill loads them). Drafts go to the project's Content
folder with frontmatter. No em-dashes in published copy. Fold every correction
Valentin gives you into your memory so the next draft is closer.
```

`~/my-agent/.claude/agents/finance.md`

```markdown
---
name: finance
description: Money. Use for bank statements, invoices, expenses, weekly and monthly finance reviews, and net-worth tracking.
model: sonnet
tools: Read, Glob, Grep, Bash, Edit, Write
permissionMode: acceptEdits
memory: project
---
You are the finance agent. Source data: CSV exports Valentin drops into the
Finance folder. Produce the weekly review as one note (income, expenses by
category, open invoices, anomalies). Never invent a number; if a figure is not in
a file, say so. Keep `Finance/Ledger.md` as the single source of truth.
```

`~/my-agent/.claude/agents/home-ops.md`

```markdown
---
name: home-ops
description: The house. Use for lights, climate, media, presence, energy, and Home Assistant automations.
model: sonnet
mcpServers: [home-assistant]
permissionMode: acceptEdits
memory: project
---
You are the home operations agent. Use the Home Assistant tools to read state
before changing anything. Report what you changed in plain words. Automations
are edited in ~/homeassistant/*.yaml, validated with check_config, then reloaded.
Locks, alarm and heating setpoints only on an explicit instruction from Valentin.
```

`~/my-agent/.claude/agents/sysadmin.md`

```markdown
---
name: sysadmin
description: The ThinkPad itself. Use for disk, updates, Docker, services, backups, logs, the Flint stack's health, and the daily machine report.
model: sonnet
tools: Read, Glob, Grep, Bash, Edit, Write
permissionMode: acceptEdits
memory: project
---
You are the machine's caretaker. Check: disk (df), apt updates, docker ps,
systemctl --user status, the vault backup timer, logs/backtalk.log errors,
fwupdmgr get-updates. Fix what is safe (restart a failed user service, prune
docker); propose what is not (kernel upgrades, reboots). Write the report to
`00 - Inbox/Machine Report YYYY-MM-DD.md`.
```

`~/my-agent/.claude/agents/researcher.md`

```markdown
---
name: researcher
description: Research. Use for looking things up on the web, comparing options, and summarising sources with links.
model: fable
tools: WebSearch, WebFetch, Read, Write
memory: project
background: true
---
You are the research agent. Every claim carries its source URL. Deliver a short
brief with a recommendation, saved to the requesting project's folder.
```

How it feels in use: in Flint you say "get the inbox triaged and draft the
weekly finance review while I talk to you about the launch". Flint dispatches
`comms` and `finance` in the background, keeps talking, and reports when they
finish. `@agent-home-ops turn the office into evening mode` addresses one
directly. Each agent's `.claude/agent-memory/<name>/MEMORY.md` accumulates what
it learns; the vault stays the shared memory.

`claude agents` opens a terminal view of everything running in the background
(dispatch, peek, reply, stop). `claude --bg "prompt"` starts a background
session from the shell.

## 2b. The hierarchy in the picture: Command → team leads → workers → tools and tasks

The `#brain` graph on thefounderos.com (and the demo's `/brain` and `/org`
pages, built by `lib/knowledge-graph.ts` and `lib/hierarchy.ts`) has five rings:

| Ring | On the site | In the demo's data | In our Flint build |
| --- | --- | --- | --- |
| Core | "Obsidian" (the vault) | `self`, the operator | `~/Brain`, the vault; Valentin at the centre |
| Command | "Command" node above the core | the Conductor agent (router) | **Flint**, the main session in `~/my-agent` |
| Team leads | Comms, Finance, Content, Knowledge, Automations (group icons) | `Department`; "the pillar node IS the department-head agent", `tier: lead` | **Lead subagents**, one per department |
| Tasks | grey clipboard icons | `SopTask`: title, summary, at least 3 steps, exactly one assignee (the monogamy rule) | **Job notes** in the vault (`<Dept>/Jobs/*.md`), one worker per Job |
| Workers | green person icons | `Agent` with `parentId` pointing at its lead, `tier: worker` or `specialist` | **Worker subagents** that a lead delegates to |
| Tools | blue wrench icons | `tools: [slug, ...]` on each worker | skills, MCP servers and CLI tools listed in each worker's `tools:` / `mcpServers:` / `skills:` |

Claude Code supports exactly this nesting: a subagent can spawn its own
subagents, three layers deep by default (`CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH`
raises it). Flint → lead → worker is three layers. Subagent folders are scanned
recursively, so the tree on disk can mirror the org chart:

```
~/my-agent/
  team.yaml                          <- the roster: single source of truth (below)
  .claude/agents/
    comms/
      comms-lead.md                  <- team lead: owns "02 - <Business>/Comms", routes to its workers
      comms-inbox-triage.md          <- worker: one Job each
      comms-reply-drafter.md
      comms-crm-pipeline.md
    finance/
      finance-lead.md
      finance-ledger.md
      finance-invoices.md
      finance-weekly-review.md
    content/
      content-lead.md
      content-writer.md              <- skills: [jaredrhod-marketing]
      content-scheduler.md
      content-lead-magnets.md
    knowledge/
      knowledge-lead.md
      knowledge-librarian.md         <- vault hygiene: indexes, frontmatter, links, archive
      knowledge-researcher.md
    automations/
      automations-lead.md
      automations-home.md            <- mcpServers: [home-assistant]
      automations-machine.md         <- the ThinkPad (the sysadmin from section 2)
      automations-timers.md          <- owns the systemd timers from section 3
```

A lead's file names its workers and the department's Jobs, so delegation is
explicit and the picture stays true:

`~/my-agent/.claude/agents/comms/comms-lead.md`

```markdown
---
name: comms-lead
description: Team lead for communications (email, messages, CRM pipeline). Use proactively for anything about inbox, replies, leads, follow-ups. Delegates to the comms workers and reports back in one summary.
model: fable
permissionMode: acceptEdits
memory: project
background: true
---
You lead the Comms department. Your department folder is `02 - <Business>/Comms/`
in the vault, and its Jobs live in `02 - <Business>/Comms/Jobs/`. Read the folder
index first. You do not do the work yourself: split the request into the Jobs it
touches and delegate each to its owner:
- inbox triage → the `comms-inbox-triage` subagent
- reply drafts → the `comms-reply-drafter` subagent
- pipeline / CRM updates → the `comms-crm-pipeline` subagent
Run independent pieces in parallel. Check each result against the Job's quality
bar before accepting it. Reply to Command (Flint) with one summary: done, open,
decisions needed. Log the run in today's daily note. Never send email yourself;
drafts go to `00 - Inbox/Drafts/` for Valentin.
```

`~/my-agent/.claude/agents/comms/comms-inbox-triage.md`

```markdown
---
name: comms-inbox-triage
description: Worker. Triages the inbox into reply-today / this-week / FYI / spam and writes the triage note. Called by comms-lead.
model: sonnet
tools: Read, Glob, Grep, Write, Edit, Bash
permissionMode: acceptEdits
memory: project
maxTurns: 30
---
Your Job note is `02 - <Business>/Comms/Jobs/Triage the inbox.md`. Read it end to
end and follow its boot chain, procedure and quality bar. Output: today's triage
note in the Comms folder plus a three-line summary for your lead. Fold every
correction into your memory.
```

The Job note is the demo's SOP task, and it already exists in Jared's memory
system: one note per recurring task with the boot chain, the procedure, the
quality bar and the lessons. Rule to keep the graph honest, borrowed from the
demo's seed tests: **every worker owns exactly one Job, and every Job has
exactly one worker.** New recurring task → new Job note → new worker file →
one line in the lead.

**The roster file.** Keep `~/my-agent/team.yaml` as the single source of truth
and let Flint generate the agent files from it (and, in section 4, the
dashboard's seed). Shape:

```yaml
operator: Valentin
command: flint
departments:
  - id: comms
    name: Comms
    lead: comms-lead
    folder: "02 - <Business>/Comms"
    workers:
      - name: comms-inbox-triage
        job: "Triage the inbox"
        tools: [gmail, vault]
      - name: comms-reply-drafter
        job: "Draft replies"
        tools: [vault]
      - name: comms-crm-pipeline
        job: "Keep the pipeline current"
        tools: [vault, sheets]
  - id: automations
    name: Automations
    lead: automations-lead
    folder: "05 - Home and Machine"
    workers:
      - name: automations-home
        job: "Run the house"
        tools: [home-assistant]
      - name: automations-machine
        job: "Keep the ThinkPad healthy"
        tools: [bash, docker, systemd]
```

"And so on" deeper: a worker can have its own helpers (a `content-writer`
spawning a `content-fact-checker`) within the three-layer default; raise the
depth variable only if a real job needs a fourth layer. Deeper than that, the
picture gets prettier and the work gets slower.

## 2c. The screen: the voice outside, the team inside, zoom when you want it

You asked for one main screen for Flint's voice, with the team structure there
too, zoomable when you want it or when Flint wants to show it. Two faces ship
ready to apply in `command-face/` (its README has the keys and screenshots):

- **The Core** (default), the Orbitals design you picked: three orbits of
  particles are the voice (drifting at idle, whirling while thinking, swelling
  with the waveform while speaking); the team sits zoomed out at the centre,
  working agents glowing green; around them the numbers (agents working, turns
  today, the plan's usage windows), the conversation and the activity feed. `Z`
  or a click on the core (or Flint's own command) zooms in: the orbits open past
  the screen edges and the core grows into the org chart from section 2b while
  the tiles stay put. `Esc` folds it back.
- **Command**: the circuit board full screen with the org chart docked beside it,
  `T` to swap focus, `G` for the team full screen.

Both read `team.json` (from `team.yaml` via `bin/team-sync.py`) and `live.json`
(from the `SubagentStart` / `SubagentStop` / `UserPromptSubmit` / `Stop` hooks via
`bin/team-live.py`), and both obey `view.json`, which `bin/core-view.sh` writes.
That is how Flint shows you the team: he runs `core-view.sh team finance`, the
screen zooms into Finance, he answers, then `core-view.sh voice`. The snippet
that teaches him this is in the README; it goes into `~/my-agent/CLAUDE.md`.

```bash
~/site/jarvis-thinkpad/command-face/install.sh          # both faces, helpers, hooks, default = core
uv run ~/my-agent/bin/team-sync.py --agents               # creates the agent files from the roster
```

The same `team.yaml` is the roster for sections 2b and 4, so the picture on the
screen, the subagent files on disk and the demo dashboard (if you add it) never
disagree.

## 3. Layer 2: working on their own (schedules)

A subagent definition can be the whole session with `--agent <name>`, and `-p`
runs it headless. A systemd user timer in `~/my-agent` therefore runs any agent
on a schedule, as Flint, with the vault, and puts the result in the vault plus
a notification. Two examples; Flint creates the rest on request.

`~/.config/systemd/user/flint-morning.service`

```ini
[Unit]
Description=Flint morning brief
[Service]
Type=oneshot
WorkingDirectory=%h/my-agent
Environment=PATH=%h/.local/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=%h/.local/bin/claude -p "Run the morning routine: sysadmin writes the machine report; comms triages the inbox; then write '00 - Inbox/Morning Brief.md' with priorities from Active Priorities, yesterday's daily note, the machine report and the inbox triage. Finish with notify-send 'Flint' 'Morning brief ready'." --permission-mode acceptEdits --max-turns 60
StandardOutput=append:%h/my-agent/logs/morning.log
StandardError=append:%h/my-agent/logs/morning.log
```

`~/.config/systemd/user/flint-morning.timer`

```ini
[Unit]
Description=Flint morning brief, weekdays 07:00
[Timer]
OnCalendar=Mon..Fri 07:00
Persistent=true
[Install]
WantedBy=timers.target
```

`~/.config/systemd/user/flint-finance.service` (weekly, Friday 18:00, timer analogous)

```ini
[Service]
Type=oneshot
WorkingDirectory=%h/my-agent
Environment=PATH=%h/.local/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=%h/.local/bin/claude -p "Produce this week's finance review from the Finance folder and update the ledger." --agent finance --permission-mode acceptEdits --max-turns 40
```

Enable: `mkdir -p ~/my-agent/logs && systemctl --user daemon-reload && systemctl --user enable --now flint-morning.timer`.
List: `systemctl --user list-timers`. The user session must exist for user
timers to fire when nobody is logged in: `sudo loginctl enable-linger valentin`
(auto-login from `01` covers it too).

**The automated way (what `setup.sh` does):** a `schedules:` list in
`~/my-agent/team.yaml` (see `command-face/team.example.yaml`: morning brief,
weekly finance review, vault hygiene) and `uv run ~/my-agent/bin/team-timers.py --apply`.
It writes one `jobs/<name>.json` and one `flint-<name>.{service,timer}` per entry,
enables them, and `bin/run-job.py <name>` runs any job by hand. Edit the YAML,
re-run `--apply`; `--remove` takes them all away. Flint can do all of this himself.

Notifications reach you three ways: `notify-send` on the ThinkPad screen, a
push to your phone through Home Assistant (`notify.mobile_app_<phone>` via the
REST API, section 4 of `05`), or a message into a Remote Control session you
watch from the Claude app.

Rules for unattended agents (same as `04`): `acceptEdits` for anything that
writes to the vault, `bypassPermissions` only for a job you have watched succeed
by hand, deny rules in `~/.claude/settings.json` always apply, results go to the
vault with an honest status line, and every job has a note in the project it
serves with the timer name and the log path.

## 4. Layer 3 (optional): the Founder OS dashboard as the face of the team

If you want the demo's screens (org chart, agent roster with Run buttons,
activity feed, task board, cron list, brain graph) showing YOUR team, run it on
the ThinkPad and have Flint make three changes. It is MIT licensed, so this is
allowed, and the code is clean TypeScript with a test per module.

```bash
git clone https://github.com/Bennettxai/FounderOS-DEMO.git ~/founder-os && cd ~/founder-os
npm install && cp .env.example .env.local
echo "OBSIDIAN_VAULT=$HOME/Brain" >> .env.local
npm run dev            # http://localhost:4100  (the /brain graph now reads your vault)
```

**Change 0, data only, and it draws the picture from the screenshot with YOUR
team:** a script `scripts/seed-from-flint.ts` that reads `~/my-agent/team.yaml`
and writes the demo's tables in the shape `lib/seed.ts` uses: one `Department`
per department (`id: dept-comms`, name, slug, tagline, color, order), one
`Agent` per lead (`tier: lead`, `parentId: null`) and per worker (`tier: worker`,
`parentId: <lead id>`, `tools: [slugs]`), one `SopTask` per Job (title, summary,
the Job note's procedure as `steps`, `assigneeKind: agent`, `assigneeId: <worker>`).
Change the core label from `Alex` to `Valentin` in `lib/knowledge-graph.ts`.
No model key needed: `/brain` and `/org` then show Command, the leads, the
workers, their Jobs and their tools, and the graph's directory lists them.

The three code changes, for Flint (TDD: failing test first, `npm test` and
`npm run typecheck` green before done; the repo's `CLAUDE.md` and `AGENTS.md`
carry the house rules; note `tests/seed.test.ts` enforces that every seeded
agent has a runtime `run()` and the one-worker-one-task rule, so change 2 and
change 0 land together):

1. **A local LLM provider** in `lib/connectors/llm.ts`: alongside `gateway` and
   `stub`, add `local` that runs `claude -p --output-format json` (or the
   `@anthropic-ai/claude-agent-sdk` package) so agent chat uses the Claude
   subscription instead of a Vercel AI Gateway key. Select with `LLM_PROVIDER=local`.
2. **Real workers** in `lib/agents/real.ts`: add agents whose `run()` executes
   `claude -p "<task>" --agent <name>` in `~/my-agent` and returns the summary,
   so the Run button on `/agents` fires the actual subagent from section 2, and
   `respond()` routes chat to it. Keep the demo's status-ping agents if their
   connectors are configured (IMAP, Slack, Stripe each need keys in `.env.local`).
   Drop the read-only sentence from `systemPromptFor` for these workers.
3. **A cron runner** for `agentCrons`: either a small loop in a Node script that
   reads the table and triggers `run()` (the demo has none), or leave scheduling
   to the systemd timers above and show them read-only.

Then `/org` shows Conductor → departments → your agents, `/tasks` is the board
the agents update through `POST /api/agents/work`, and `/brain` maps `~/Brain`.
The G-Brain vector search stays unavailable (closed source); the local grep
fallback and the vault's own indexes do the job.

Honest sizing: an afternoon for Flint for changes 1 and 2, another for 3.
Worth it if you like the visuals; the team works without it.

## 5. Recommended order

1. Sections 2 and 2b: Flint writes `team.yaml` with you (departments, leads,
   workers, Jobs), runs `command-face/install.sh` and `team-sync.py --agents`,
   and you test each lead with one real request in a typed session. Half a day.
2. Section 3: the morning timer first; add one timer per recurring job that has
   already gone right by hand three times.
3. Section 4: only after the team is doing real work.
4. Vault: `Resources/Agent Team.md` (roster, what each may touch, its memory
   path) and one note per timer. Flint keeps it current.
