# Agore

**Agora + Agent** — 让所有 coding agent 聚集、彼此可见的数字广场。

Agore is a macOS menu bar companion that turns the coding agents working on your machine
into pixel people milling about a Greek plaza. When an agent reads a file it sits down with
a scroll; when it runs a command it paces around; when nothing is running, the plaza's
caretaker takes a nap by the fountain.

![The Agore plaza strip](docs/preview.png)

The strip is translucent and can be pinned above every window, so the plaza stays in the
corner of your eye while you work.

## Status

Cursor is the only agent provider so far. Each running Agore client is one pixel person.
A Go plaza server can broadcast those people to every other client over WebSocket.

## Requirements

- macOS 14 or later
- Xcode command line tools (`xcodebuild`)
- [Cursor](https://cursor.com) with user hooks support, for live activity
- Python 3 (ships with macOS) for the hook forwarder and the build scripts

## Getting started

```bash
make build     # compile the app
make run       # (re)launch it
make test      # run the unit tests
```

On first launch Agore opens a small window so you can see it exists, and installs its
Cursor hook into `~/.cursor/hooks.json`. Close the window and the app moves into the menu
bar. Cursor needs to be restarted once for a freshly installed hook to take effect.

### Using it

- **Left-click** the menu bar icon: show or hide the plaza
- **Right-click** (or Control-click): **Style**, **Always on Top**, nickname, plaza token, show/hide, hooks, quit
- **Drag** the strip anywhere; Agore remembers where you put it
- With **Always on Top** enabled the plaza joins every Space, survives clicks elsewhere, and
  comes back automatically on the next launch

The bar along the bottom shows how many people are on the plaza, what your own agent is up
to, whether hooks are installed, and when the last event arrived.

### Styles

Two worlds, picked from **Style** in the status item menu or **View → Style** in the menu
bar, and remembered across launches:

| Style | The plaza is |
| --- | --- |
| Greek Agora | Marble paving under a colonnade, a fountain, olive trees, stone benches |
| Sunny Seaside | A beach under a big sky, surf and a bay, palms, a parasol, beach towels |

Both keep the same daylight cycle, and both have a couple of pixel cats loafing about
where nobody is walking. Switching styles repaints the plaza and everyone walks back in.

### What the pixel people are doing

| On screen | Activity | Comes from |
| --- | --- | --- |
| Sitting with a scroll | reading | `Read`, `Grep`, `Glob`, `WebSearch`, … |
| Scribbling | writing | `Write`, `StrReplace`, `ApplyPatch`, `afterFileEdit`, … |
| Pacing the plaza | running | `Shell`, `Task`, MCP calls, `beforeShellExecution`, … |
| Strolling, head down | thinking | `afterAgentThought`, anything unrecognised |
| Standing with a bubble | waiting | `stop`, `sessionStart`, a user turn |
| Resting on a bench, dimmed | idle | `sessionEnd`, or two minutes of silence with no tool call open |
| Walking out through a gate | gone | that client disconnected from the plaza |

One pixel person per Agore client (one Cursor instance on one Mac), not per conversation.
Yours is on the plaza from the moment Agore starts, resting until an agent wakes up.
The name under the person is your nickname (default: this Mac's hostname). Local Cursor
activity is folded into a single pose: running beats writing, which beats reading, and so
on. Up to eight people hold distinct spots around the fountain; beyond that the plaza
fills a second row.

## How it works

```
Cursor agent
   │  user hook (~/.cursor/hooks.json)
   ▼
agore-forward.sh ──POST──▶ 127.0.0.1:<random port>/events   (loopback only)
                                    │
                          ActivityMapper → PresenceStore (fold to 1 person)
                                    │
                    ┌───────────────┴───────────────┐
                    ▼                               ▼
              SpriteKit plaza              WebSocket hello/presence
                                                  │
                                           Go plaza server :8081
                                                  │
                                           broadcast to all clients
```

- **Hooks are the live path.** A tiny forwarder script posts presence to a loopback HTTP
  listener inside the app. The port is random per launch and written to
  `~/Library/Application Support/Agore/ingest.port`; the forwarder reads it from there.
  The script never blocks the agent: it has a 0.4s timeout and always exits 0.
- **Transcript scanning is the fallback.** Every 30 seconds Agore checks the modification
  time of Cursor's local transcript files under `~/.cursor/projects/*/agent-transcripts/`,
  which covers cold starts and sessions that began before the hook was installed.
- **Activity expires on a clock, membership does not.** Two minutes of silence sits an agent
  down to rest, but standing on the plaza is about being connected: people only walk out once
  the server drops their client from the roster.
- **An open tool call holds the clock.** Cursor emits nothing at all while a tool runs, so
  a long test command would otherwise look the same as an agent that quit. Agore pairs each
  `preToolUse` with its `postToolUse` (and the shell and MCP hooks with their counterparts)
  and keeps the person on stage until the call reports back, up to thirty minutes.

### Privacy

Agore is built to know *that* an agent is working, not *what* it is working on. The
forwarder sends only the conversation id, the hook event name, the tool name, the opaque
tool call id, and the last path component of the workspace folder. Prompts, file contents,
shell commands and their output, diffs, and full paths never leave the agent. The local
database (`~/Library/Application Support/Agore/presence.sqlite`) stores the same narrow set
and prunes itself after seven days. The local hook listener binds to loopback only.

The shared plaza server sees even less: `client_id`, nickname, activity kind, and the
current project folder name. A shared `AGORE_TOKEN` is required to join. Conversation
ids never leave the Mac.

## Project layout

```
Apps/Agore/          AppKit shell: status item, floating panel, onboarding window
Sources/AgoreCore/   presence model, Cursor adapters, plaza protocol, SQLite store
Sources/AgorePlaza/  pixel art, styles, SpriteKit scene, character behaviour
server/              Go WebSocket plaza (in-memory queue + broadcast)
Resources/hooks/     the Cursor hook forwarder that gets installed for you
Scripts/             Xcode project and app icon generators
Tests/               unit tests for the mapping, parsing, store, and hook install
```

The pixel world is 360×42 and the strip renders at exactly 2×, so every pixel lands on an
integer boundary. Changing one without the other will make the art blurry.

### Make targets

| Target | What it does |
| --- | --- |
| `make build` | build the app |
| `make run` | rebuild, kill the running copy, relaunch |
| `make test` | run the unit tests |
| `make gen-project` | regenerate `Agore.xcodeproj` from `Scripts/gen_pbxproj.py` |
| `make icons` | regenerate the app icon set from the source art |
| `make clean` | remove build output |
| `make plaza` | generate a self-signed cert, then run nginx (HTTPS :8081) + plaza |
| `make plaza-down` | stop the plaza container |
| `make plaza-test` | run the Go server tests |

`Agore.xcodeproj` is generated, not hand-edited. Add new source files to
`Scripts/gen_pbxproj.py` and run `make gen-project`.

## Shared plaza

Each Mac keeps a durable `client_id` in `~/Library/Application Support/Agore/client.json`.
Reconnecting with the same id replaces the old socket, so restarting Agore does not spawn
a second pixel person.

### Server

```bash
cp .env.example .env    # set AGORE_TOKEN
make plaza              # self-signed cert + nginx HTTPS :8081 + Go plaza
```

Same shape as CSPM's frontend: nginx terminates TLS on 443 (published as host **8081**),
then proxies to the Go process over HTTP inside the compose network. WebSocket upgrades
are forwarded. The cert is generated by `Scripts/gen_tls.sh` (SAN: `agore.bytebar.dev`,
`localhost`) and is not committed.

Cloudflare Tunnel should point at the nginx port, trusting the self-signed cert:

```yaml
  - hostname: agore.bytebar.dev
    service: https://localhost:8081
    originRequest:
      noTLSVerify: true
```

```bash
cloudflared tunnel route dns c38f0006-5b8c-47a2-9531-c9196a95ee89 agore.bytebar.dev
# then restart cloudflared so it reloads ~/.cloudflared/config.yml
```

`AGORE_TOKEN` is required; the process refuses to start without it.

### Client

Defaults to `wss://agore.bytebar.dev/v1/plaza` (Cloudflare's public cert, not the
self-signed one). Set the shared token:

```bash
defaults write com.wadeling.agore AgorePlazaToken "the-same-token"
```

Or set them from the menu bar: **Nickname…** and **Plaza Token…**. If the token is wrong
the status bar shows `plaza unauthorized` and the client stops retrying until you change it.

If the server is down the local pixel person still walks around; remote people disappear.

## Roadmap

- More agent providers beyond Cursor
- Rooms / per-user accounts (today there is one shared plaza token)

## License

Not yet decided.
