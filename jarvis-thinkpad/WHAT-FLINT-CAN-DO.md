# What Flint can do, and how to ask

Every ability on the ThinkPad, the words that trigger it, the tool behind it, and its state.
The installer copies this file into the vault (`Flint/What I Can Do.md`), so "Flint, what can you do?"
is answered from it.

Legend: **✓** built and installed by `setup.sh` · **⚙** built, needs one step only you can do (listed at the end) ·
**○** an idea, not built: say "build yourself a way to ..." and he adds it to `~/my-agent/bin`.

**The one rule.** If he cannot do something, ask him to build it. Every tool below started as a "can't".
The exceptions are things that need your hands or your accounts, hardware that is not there, a provider that
blocks it, or something harmful.

## 1. Talking to him

| Say | What happens | Tool | State |
| --- | --- | --- | --- |
| "Flint, ..." / "Hey Flint, ..." / "..., Flint" | He hears you without a key. Anything not addressed to him is dropped. | `flint_voice` wake filter | ✓ |
| "Flint?" / "Flint, question for you" / "I have a job for you, Flint" | "Yes?" and a thirty-second window where nothing needs the name | `flint_voice` | ✓ |
| (hold the Home key and talk) | Push-to-talk, always works, interrupts him mid-sentence | backtalk | ✓ |
| (type a line in his window) | Same conversation, spoken reply | backtalk | ✓ |
| (a Telegram message, voice note or photo from your phone) | He answers there, as himself, with the vault; `/look`, `/status`, `/play`, `/say`, `/new` | `flint-telegram` | ⚙ |
| (the Claude app on the phone) | Remote Control: drive his typed session from anywhere | `flint-rc.service` | ✓ |
| "go hands free" / "push to talk mode" | Switch the microphone mode live | voice console | ✓ |
| "switch to the deep model" / "back to the fast model" / "set effort to low" | Brains and speed | voice console | ✓ |
| "stop asking for permission" then "confirm" / "start asking again" | Spoken permission checks on or off | voice console | ✓ |
| "clear the session" / "compact the session" / "usage report" | Housekeeping | voice console | ✓ |
| "goodbye Flint" | He hangs up and stays down until started (launcher, or `flint-stack start`) | `flint-stack` | ✓ |
| "Flint, switch your voice to af_heart" / "talk faster" | 28 local voices, speed; applies after `flint-stack restart` | `flint-voice` | ✓ |
| "Флинт, колко е часът?" (Bulgarian, any time, mixed with English) | He hears Bulgarian (multilingual whisper, language detected per sentence) and answers in Bulgarian with a second local voice (Piper); English keeps his Kokoro voice. "Флинт?" gets "Да?" | `flint_voice` + Piper | ✓ |
| "Flint, answer me in Bulgarian from now on" / "говори на английски" | The rule in his CLAUDE.md: answer in the language spoken, unless told otherwise | CLAUDE.md | ✓ |
| "use one voice for both languages" | ElevenLabs speaks English and Bulgarian in the same voice (paid, your key) | `flint-voice elevenlabs` | ⚙ |
| "use the premium voice" | ElevenLabs on your key (key in `~/.config/flint/elevenlabs.env`) | `flint-voice elevenlabs` | ⚙ |

## 2. The machine

| Say | What happens | Tool | State |
| --- | --- | --- | --- |
| "open Chrome / Obsidian / the terminal" | Launches apps, focuses windows | `gio`, `xdg-open`, `wmctrl` | ✓ |
| "type this into the window" / "press ctrl-s" / "click there" | Keyboard and mouse on the X11 desktop | `xdotool` | ✓ |
| "install X" / "write me a script that ..." / "set up a cron job" | apt, uv, npm, Docker, code, systemd; passwordless sudo | Claude Code, auto mode | ✓ |
| "how is the machine?" | Load, temperature, memory, disk, battery, mains, network, Tailscale, audio, camera, services, HA, the stack, updates, errors, a verdict | `flint-health.sh` | ✓ |
| "run the doctor" / "run the doctor and fix what fails" | The installer's real tests; he repairs from each piece's troubleshooting guide | `flint-doctor.sh` | ✓ |
| (nothing: 03:30 every night) | The nightly doctor checks, repairs, writes `Doctor Log.md` in the vault | `team.yaml` schedule | ✓ |
| (nothing: every two minutes) | The keeper restarts a dead stack, leaves a stopped one alone, gives up after three tries and tells you | `flint-keeper.sh` | ✓ |
| "restart yourself" / "stop" / "are you running?" | Stack control | `flint-stack` | ✓ |
| "update everything and tell me what changed" | Pulls every piece, keeps your configs | `update.sh` | ✓ |
| "reboot" | Only when asked; sleep is disabled on purpose | systemd | ✓ |
| (a power cut) | The machine comes back on its own, then everything else does | BIOS "Power On with AC Attach" | ⚙ |
| "what's on the screen?" / "read me the error" | Screenshot he reads, or OCR to text | `flint-look screen` / `text` | ✓ |
| "drive me from my phone by SSH" | Tailscale SSH from anywhere, firewall on | stage 04 | ⚙ |

## 3. Senses

| Say | What happens | Tool | State |
| --- | --- | --- | --- |
| "what's on my desk?" | A webcam frame, read back | `flint-look desk` | ✓ |
| (sit down at the desk) | "Welcome back, Valentin." The music he paused resumes. | `flint-presence` | ⚙ |
| (leave the desk for a minute) | The music pauses; the desk is marked empty; motion alerts arm | `flint-presence` | ⚙ |
| (a stranger at the desk while you are away) | A snapshot and a quiet notification | `flint-presence` | ⚙ |
| "who is here?" | Presence status | `flint-presence status` | ⚙ |
| (a doorbell, a knock, glass, a smoke or fire alarm, a siren, crying, a dog) | He says the ones that matter, notifies the rest, with cool-downs | `flint-ears` | ✓ |
| "what happened while I was out?" | The event log: sounds, arrivals, guard alerts, backups, timers | `flint-notify --log` | ✓ |
| "timer ten minutes, the pasta" / "remind me at half past seven" | Spoken and notified when it fires; survives everything | `flint-timer` | ✓ |
| "what timers are running?" / "cancel the pasta timer" | List and cancel | `flint-timer list` / `cancel` | ✓ |
| "take a photo with my phone" | The phone's camera | `flint-look phone` | ⚙ |

## 4. Music and media

| Say | What happens | Tool | State |
| --- | --- | --- | --- |
| "play Lose Yourself by Eminem" | The first YouTube match, audio only; he says the title | `flint-play` | ✓ |
| "play the album The Marshall Mathers LP" | A full-album upload | `flint-play --album` | ✓ |
| "play some nineties hip hop" | A queue of ten | `flint-play --queue` | ✓ |
| "play my Beatles files" | From `~/Music` | `flint-play --local` | ✓ |
| "play this stream / this link" | Any URL or file | `flint-play <url>` | ✓ |
| "pause" / "next" / "louder" / "volume forty" / "stop the music" | Controls | `flint-play` | ✓ |
| "I like this" / "never play this again" | Noted in `Flint/Music Taste.md` | `flint-play like` / `dislike` | ✓ |
| "play something for focus" (morning, dinner, party, sleep, workout, chill) | A mood, from the taste note | `flint-play --for` | ✓ |
| "play something I like" | From the liked list | `flint-play --for me` | ✓ |
| "what do I listen to most?" | Replays, early skips, likes, dislikes | `flint-play taste` | ✓ |
| (he speaks while music plays) | The music dips and comes back | `flint_voice` ducker | ✓ |
| "tell the kitchen dinner is ready" / "say it everywhere" | His voice on any Home Assistant speaker | `flint-say --to` | ⚙ |
| "cast this to the TV" / "show my photos on the TV" | Chromecast or HA media players | ○ |
| "DJ mode: learn what I like by yourself over time" | Automatic taste from listening habits, without like/dislike | ○ |

## 5. The internet and the browser

| Say | What happens | Tool | State |
| --- | --- | --- | --- |
| "find me the album The Eminem Show and show me the tracklist" | Searches, opens it on the screen in Chrome, reads it back, offers to play it | web search, `xdg-open`, Playwright | ✓ |
| "log into X and do Y" / "book the usual table" / "order the toner again" | The Playwright browser drives Google Chrome, visibly, with its own profile (logins persist); he reads `Flint/Preferences.md` first and never pays without a yes | Playwright MCP, the vault | ✓ |
| "read this PDF / this link / this video and tell me the gist" | A vault note with summary, key points, quotes, why it matters; the gist spoken | `flint-ingest` | ✓ |
| (drop a file or a link into `Knowledge/Drop`) | Ingested within ten minutes | `flint-ingest.timer` | ✓ |
| "the news" / "what happened overnight?" | Your RSS feeds, summarised into a two-minute briefing, spoken | `flint-news` | ✓ |
| "add this feed" | Edits `Flint/News Sources.md` | `flint-news --add` | ✓ |
| "what's the weather?" | Web search, or Home Assistant's weather entity | built in | ✓ |
| "translate this" / "teach me Bulgarian words" | The model; multilingual speech recognition needs the non-`.en` whisper model | ○ |

## 6. Reaching you and the world

| Say | What happens | Tool | State |
| --- | --- | --- | --- |
| "notify me when ..." / (any alert) | Screen, Telegram, the phone through Home Assistant, the voice; everything logged | `flint-notify` | ✓ |
| "send me a photo of the desk on Telegram" | A picture in the chat | `flint-telegram send --photo` | ⚙ |
| "where's my phone?" | It rings | `flint-phone ring` | ⚙ |
| "how much battery does my phone have?" / "what's on my phone's notifications?" | KDE Connect reads it | `flint-phone battery` / `notifications` | ⚙ |
| "text Maria that I'm late" | An SMS from your phone | `flint-phone sms` | ⚙ |
| "send this file / this link to my phone" / "put this on my phone's clipboard" | Shared instantly | `flint-phone send` / `clip` | ⚙ |
| "anything urgent in the mail?" / "read me the last one from the bank" | The Gmail connector, or the local IMAP tool | connector / `flint-mail` | ⚙ |
| "draft a reply saying ..." then "send it" | A draft shown first; sent only after your yes | `flint-mail draft` / `send --confirm` | ⚙ |
| "what's on today?" / "when is the dentist?" | The Calendar connector, or your private ICS links | connector / `flint-calendar` | ⚙ |
| "put a meeting in my calendar" | Creating events needs the Calendar connector | connector | ⚙ |
| "call someone" / "answer the phone" | Voice calls over the phone | ○ |
| "send a WhatsApp / Signal message" | Another messenger bridge | ○ |

## 7. The home

| Say | What happens | Tool | State |
| --- | --- | --- | --- |
| "lights off in the kitchen" / "set the thermostat to 21" / "is the garage door open?" | Home Assistant through its MCP server (online) or `flint-ha` (any time) | HA MCP, `flint-ha` | ✓ |
| "movie mode" / "goodnight" | Scenes: lights, TV, locks, alarm, music, in one word | HA scenes + a line in his CLAUDE.md | ○ |
| (motion in the house while you are away) | A notification with a camera snapshot | `flint-guard` + HA | ⚙ |
| "who's at the door?" | The doorbell sound, then a camera snapshot from HA | `flint-ears` + `flint-look` | ⚙ |
| (a smoke alarm) | He says it, notifies the phone, logs it | `flint-ears` | ✓ |
| "Flint" from another room | Satellite microphones (ESP32-S3 + Wyoming) | ○ |
| "what's the energy use / the weather forecast?" | HA sensors | HA MCP | ✓ |

## 8. Memory, work and the team

| Say | What happens | Tool | State |
| --- | --- | --- | --- |
| "remember that ..." / "what do you know about X?" | The Obsidian vault is his memory; plain markdown you can read | ai-memory-vault | ✓ |
| "write today's daily note" / "what are my priorities?" | Daily notes, Active Priorities, Jobs | the vault | ✓ |
| (07:00 on weekdays) | The morning brief: priorities, calendar, mail triage, news, the machine, overnight events; written and spoken | `team.yaml` schedule | ✓ |
| "show me the team" / "zoom into finance" | The Orbitals face zooms into the org chart | `core-view.sh` | ✓ |
| "ask the finance lead to ..." / "run the weekly finance review" | Subagents per department, each with its Jobs | `team.yaml`, subagents | ✓ |
| "schedule X every Friday at six" | A systemd timer that runs him headless | `team-timers.py` | ✓ |
| (every hour) | The vault is committed to git; push to a private repo when you say so | `flint-vault-backup.timer` | ✓ |
| "write the invoice for X" / "make a document / a slide deck / a spreadsheet" | Files in your templates, filed in the vault | Claude Code skills | ✓ |
| "record this meeting and give me the action items" | Recording, local transcription, notes | ○ |
| "type what I say into this window" | System-wide dictation on a second key | ○ |
| "what are this week's numbers?" | Revenue, invoices, subscriptions from a sheet, Stripe or Notion | ○ |
| "show me on the board" | The barehands board: notes, images, 3D models moved by hand tracking | barehands | ✓ |

## 9. Safety and keeping it running

| Say | What happens | Tool | State |
| --- | --- | --- | --- |
| "anything unusual?" / "who logged in?" | SSH logins, fail2ban bans, new devices on the wifi, motion while away | `flint-guard` | ✓ |
| "that device is my phone" | Names a LAN device so it stops being "unknown" | `flint-guard name` | ✓ |
| (02:30 every night) | An encrypted restic backup, thinned; the first of the month a real restore test | `flint-backup` | ⚙ |
| "bring back yesterday's version of that note" | Restores into `~/Restored` | `flint-backup restore` | ⚙ |
| (the internet or the plan is out) | The keeper starts the offline brain: timers, lights, music, the time still work by voice | `flint-offline` | ✓ |
| "what are your rules?" | Deny list (no wiping disks, no shutdown, no reading the secrets folder), spoken permission checks, the sandbox | `~/.claude/settings.json` | ✓ |
| (a secret) | Never in a file he reads, never in the vault, never in the chat: `~/.config/flint/*.env` (600) or the keyring | the rule | ✓ |
| "roll the system back" | Timeshift snapshot of the working OS | Timeshift | ✓ |
| "watch the auth logs and ban attackers" | fail2ban | ✓ |

## 10. Not built yet, ask and he builds it

Say "build yourself a way to ..." and it lands in `~/my-agent/bin`, in his `CLAUDE.md`, and survives updates.

- Satellite microphones in every room (ESP32-S3, Wyoming, Home Assistant).
- Scenes by voice: "movie mode", "goodnight" (Home Assistant scenes, one line each).
- Energy- and weather-aware advice in the morning brief.
- Meeting recorder with action items into the vault.
- System-wide dictation on a second key.
- The week's business numbers, spoken.
- Casting to the TV, a photo slideshow of the day.
- Storyteller with a voice per character, quizzes, a language tutor.
- Voice calls and a WhatsApp or Signal bridge.
- Automatic taste learning without like/dislike.
- Anything else you can describe in a sentence.

## 11. The steps only you can do, once each

| Step | Why | How |
| --- | --- | --- |
| Look at the camera for six seconds | So he knows your face (presence, greetings) | during the install, or `flint-presence enrol Valentin` |
| Make a Telegram bot | Telegram gives tokens to people, not machines | `@BotFather` on the phone, then `flint-telegram setup`, then `/start` in the chat |
| Pair the phone | KDE Connect asks on the phone | install the app, same wifi, `flint-phone pair`, accept |
| Enable Gmail and Google Calendar | Your Google account | claude.ai > Settings > Connectors; they appear in Claude Code by themselves |
| Save the backup password | Without it the backup is unreadable | copy it from `~/.config/flint/backup.env` to your password manager |
| "Power On with AC Attach" in the BIOS | Linux cannot set it | F1 at the Lenovo logo > Config > Power |
| Log in to Claude and GitHub, open the Tailscale link | Your accounts | stage 07 and stage 04 of the install |
| Add a Home Assistant speaker / TTS integration | For the intercom | HA > Settings > Devices & services |
