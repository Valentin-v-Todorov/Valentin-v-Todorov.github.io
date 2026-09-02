# 07. A team of agents that work on their own (and the FounderOS dashboard on top)

You asked: can Jarvis have different agents for different tasks, working on
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

## 2. Layer 1: named specialist agents inside Jarvis (subagents)

Claude Code subagents are markdown files in `~/my-agent/.claude/agents/`. Each
has its own system prompt, tool allowlist, model, permission mode, MCP servers,
preloaded skills and **its own persistent memory**. Jarvis (the main session)
delegates to them by their `description`, or you address one directly with
`@agent-<name>`. They run in the background, in parallel (up to 20), and they
all read `~/my-agent/CLAUDE.md`, so they know the vault and its rules. This is
the Conductor → departments → workers structure from the demo, with real hands.

Jarvis writes these files; the set below is a starting roster for a personal
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
description: The ThinkPad itself. Use for disk, updates, Docker, services, backups, logs, the Jarvis stack's health, and the daily machine report.
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

How it feels in use: in Jarvis you say "get the inbox triaged and draft the
weekly finance review while I talk to you about the launch". Jarvis dispatches
`comms` and `finance` in the background, keeps talking, and reports when they
finish. `@agent-home-ops turn the office into evening mode` addresses one
directly. Each agent's `.claude/agent-memory/<name>/MEMORY.md` accumulates what
it learns; the vault stays the shared memory.

`claude agents` opens a terminal view of everything running in the background
(dispatch, peek, reply, stop). `claude --bg "prompt"` starts a background
session from the shell.

## 3. Layer 2: working on their own (schedules)

A subagent definition can be the whole session with `--agent <name>`, and `-p`
runs it headless. A systemd user timer in `~/my-agent` therefore runs any agent
on a schedule, as Jarvis, with the vault, and puts the result in the vault plus
a notification. Two examples; Jarvis creates the rest on request.

`~/.config/systemd/user/jarvis-morning.service`

```ini
[Unit]
Description=Jarvis morning brief
[Service]
Type=oneshot
WorkingDirectory=%h/my-agent
Environment=PATH=%h/.local/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=%h/.local/bin/claude -p "Run the morning routine: sysadmin writes the machine report; comms triages the inbox; then write '00 - Inbox/Morning Brief.md' with priorities from Active Priorities, yesterday's daily note, the machine report and the inbox triage. Finish with notify-send 'Jarvis' 'Morning brief ready'." --permission-mode acceptEdits --max-turns 60
StandardOutput=append:%h/my-agent/logs/morning.log
StandardError=append:%h/my-agent/logs/morning.log
```

`~/.config/systemd/user/jarvis-morning.timer`

```ini
[Unit]
Description=Jarvis morning brief, weekdays 07:00
[Timer]
OnCalendar=Mon..Fri 07:00
Persistent=true
[Install]
WantedBy=timers.target
```

`~/.config/systemd/user/jarvis-finance.service` (weekly, Friday 18:00, timer analogous)

```ini
[Service]
Type=oneshot
WorkingDirectory=%h/my-agent
Environment=PATH=%h/.local/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=%h/.local/bin/claude -p "Produce this week's finance review from the Finance folder and update the ledger." --agent finance --permission-mode acceptEdits --max-turns 40
```

Enable: `mkdir -p ~/my-agent/logs && systemctl --user daemon-reload && systemctl --user enable --now jarvis-morning.timer`.
List: `systemctl --user list-timers`. The user session must exist for user
timers to fire when nobody is logged in: `sudo loginctl enable-linger valentin`
(auto-login from `01` covers it too).

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
the ThinkPad and have Jarvis make three changes. It is MIT licensed, so this is
allowed, and the code is clean TypeScript with a test per module.

```bash
git clone https://github.com/Bennettxai/FounderOS-DEMO.git ~/founder-os && cd ~/founder-os
npm install && cp .env.example .env.local
echo "OBSIDIAN_VAULT=$HOME/Brain" >> .env.local
npm run dev            # http://localhost:4100  (the /brain graph now reads your vault)
```

The three changes, for Jarvis (TDD: failing test first, `npm test` and
`npm run typecheck` green before done; the repo's `CLAUDE.md` and `AGENTS.md`
carry the house rules):

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

Honest sizing: an afternoon for Jarvis for changes 1 and 2, another for 3.
Worth it if you like the visuals; the team works without it.

## 5. Recommended order

1. Section 2: Jarvis writes the six agent files, then you test each with one
   real task in a typed session. Half a day.
2. Section 3: the morning timer first; add one timer per recurring job that has
   already gone right by hand three times.
3. Section 4: only after the team is doing real work.
4. Vault: `Resources/Agent Team.md` (roster, what each may touch, its memory
   path) and one note per timer. Jarvis keeps it current.
