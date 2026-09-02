# 06. thefounderos.com, the `#brain` link, and how it relates to Jarvis

## What the site is

thefounderos.com sells **The Founder OS**, a paid live cohort by Bennett
(`@bennettx.ai`) that teaches solo founders to run their business from "one
folder your AI runs, that already knows your offer, your customers, your
pipeline". Cohort 2 starts 14 September 2026 (6 live sessions, Mon/Wed/Fri
1 PM ET). A VIP track is $5,000. The site quotes about $260/month as Bennett's
own AI runtime cost across two companies. 14-day refund after start.

The curriculum: a `context.md` foundation (offer, customers, calendar, judgment),
"encoded workspaces" (agency templates), "encoded tools" (CRM-OS, Finance-OS,
Second-Brain-OS and so on, 20 in total), then go-to-market and automation.

## What `#brain` is

The `#brain` anchor scrolls to the section "a live map of everything my
businesses know: every dot is a real note, task, or decision". That is the
**G-Brain** knowledge graph: markdown notes chunked and embedded into a vector
store with hybrid (keyword + semantic) search, plus a governed memory runtime
they call **Optimal Engine** with a `Source → Signal → Claim → Fact → Memory`
promotion pipeline where agents can write claims but facts are review-gated.

## The open-source piece: FounderOS-DEMO

https://github.com/Bennettxai/FounderOS-DEMO (MIT, 600+ stars). Read in full:

- Next.js 14 + TypeScript + Tailwind + better-sqlite3 + Zod + Vitest. `npm run dev`
  serves `http://localhost:4100`, seeded with fake data so every page is alive
  without any keys.
- Routes: `/` operator console, `/comms` unified inbox (IMAP, Slack, WhatsApp
  lanes), `/funnel`, `/social`, `/content`, `/finances`, `/agents` (each seeded
  agent has a real `run()`), `/tasks`, `/skills`, `/org`, `/brain` (the graph
  from the site), `/workflows`, `/integrations`, `/analytics`, `/roadmap`, `/personas`.
- 20+ connectors (`lib/connectors/`): IMAP email, Slack, Stripe, Notion, Google
  Calendar, Beehiiv, ManyChat, GoHighLevel, WebinarJam, WhatsApp, Obsidian
  (reads a vault folder), and `gbrain.ts` which shells out to a `gbrain` CLI.
  Every connector returns an honest `connected | not_configured | error`.
- **What is NOT in the repo:** the `gbrain` CLI itself (GBrain v0.41: markdown
  store in `~/knowledge/brain-store/` + Supabase + ZeroEntropy embeddings) and
  Optimal Engine. Without them `/brain` falls back to a local grep over
  markdown and a generated demo graph. The knowledge layer is the paid part.
- `.env.example` lists every credential slot; `.env.local` is gitignored.

Run it on the ThinkPad if you want to explore the UI ideas:

```bash
# needs Node 18+: bootstrap.sh --with-node installs Node 22
git clone https://github.com/Bennettxai/FounderOS-DEMO.git ~/founder-os && cd ~/founder-os
npm install && cp .env.example .env.local && npm run dev     # http://localhost:4100
npm test && npm run typecheck                                 # the suite must stay green
```

Point its Obsidian connector at `~/Brain` and the `/brain` page reads your real
vault. It is a dashboard, not an agent: Jarvis stays the agent.

## How it overlaps with Jarvis, and the recommendation

| | ai-memory-vault (Jared) | Founder OS (Bennett) |
| --- | --- | --- |
| Memory | Plain markdown in Obsidian, indexes and wikilinks, no database, any AI reads it | Markdown plus a vector index and a review-gated fact store (closed), surfaced in a web graph |
| Agent | Claude Code in `~/my-agent`, one identity (Jarvis), voice and face | Named agent personas per department, run from a web app, LLM via Vercel AI Gateway |
| Business ops | "Jobs" notes per recurring task; the marketing skill | 20 "encoded tools" (CRM, finance, PM) taught live |
| Cost | Free + your Claude plan | Cohort price (not listed) or $5,000 VIP + about $260/month runtime |

Both are the same idea: markdown as the business's memory, an AI that reads it
before acting. Jared's stack gives you the memory, the voice and the hands
today, for free, and it is what this whole guide builds. The Founder OS demo
is worth an evening for its UI and its connector list; the cohort is a
teaching product, worth it only if you want the live sessions. The "encoded
tools" (CRM-OS, Finance-OS) are exactly what Jared's "Jobs" and project folders
become once Jarvis has your real business in the vault.

Suggested first business "Jobs" for Jarvis, modelled on Founder OS's tool list:
CRM (contacts, deals, pipeline in `02 - <Business>/CRM/`), weekly finance
review, content pipeline, client delivery checklist, and a `context.md`-style
one-pager (offer, customers, calendar, how I decide) that Jarvis reads before
any business decision. The `ai-marketing-skills` files already cover funnels,
copy, email and ads.

## About the link you pasted

The URL contained `?mcp_token=…`, a signed token issued to your profile on that
site (it encodes a profile id, a session id, an issue time of 1 September 2026
and an expiry at the end of September). It was not used or sent anywhere while
researching this; the site was fetched without it. Treat it like a password: do
not paste that link into chats, notes, or the vault. The `fbclid` part is a
Facebook click tracker and is harmless.
