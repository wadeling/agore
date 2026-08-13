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

First release: local presence only, Cursor as the single supported agent provider. The
plaza is built so remote agents can walk into it later — see [Roadmap](#roadmap).

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
- **Right-click** (or Control-click): menu with **Always on Top**, show/hide, hook status, quit
- **Drag** the strip anywhere; Agore remembers where you put it
- With **Always on Top** enabled the plaza joins every Space, survives clicks elsewhere, and
  comes back automatically on the next launch

The bar along the bottom shows how many agents are present, whether hooks are installed, and
when the last event arrived.

### What the pixel people are doing

| On screen | Activity | Comes from |
| --- | --- | --- |
| Sitting with a scroll | reading | `Read`, `Grep`, `Glob`, `WebSearch`, … |
| Scribbling | writing | `Write`, `StrReplace`, `ApplyPatch`, `afterFileEdit`, … |
| Pacing the plaza | running | `Shell`, `Task`, MCP calls, `beforeShellExecution`, … |
| Strolling, head down | thinking | `afterAgentThought`, anything unrecognised |
| Standing with a bubble | waiting | `stop`, `sessionStart`, a user turn |
| Walking off screen | idle | `sessionEnd`, or two minutes of silence |
| Asleep by the fountain | nobody home | no active agent at all |

Every Cursor conversation becomes its own pixel person, named after its project folder.
Subagents get their own smaller character. Up to eight agents each hold a distinct spot
around the fountain; beyond that the plaza fills a second row.

## How it works

```
Cursor agent
   │  user hook (~/.cursor/hooks.json)
   ▼
agore-forward.sh ──POST──▶ 127.0.0.1:<random port>/events   (loopback only)
                                    │
                          ActivityMapper → PresenceStore → SQLite
                                    │
                              SpriteKit plaza
```

- **Hooks are the live path.** A tiny forwarder script posts presence to a loopback HTTP
  listener inside the app. The port is random per launch and written to
  `~/Library/Application Support/Agore/ingest.port`; the forwarder reads it from there.
  The script never blocks the agent: it has a 0.4s timeout and always exits 0.
- **Transcript scanning is the fallback.** Every 30 seconds Agore checks the modification
  time of Cursor's local transcript files under `~/.cursor/projects/*/agent-transcripts/`,
  which covers cold starts and sessions that began before the hook was installed.
- **Presence expires on a clock.** Two minutes of silence sends an agent home; it walks to
  the nearest exit and the caretaker falls asleep once the plaza empties.

### Privacy

Agore is built to know *that* an agent is working, not *what* it is working on. The
forwarder sends only the conversation id, the hook event name, the tool name, and the last
path component of the workspace folder. Prompts, file contents, diffs, and full paths never
leave the agent. The local database (`~/Library/Application Support/Agore/presence.sqlite`)
stores the same narrow set and prunes itself after seven days. Nothing is sent off the
machine — the listener binds to loopback only.

## Project layout

```
Apps/Agore/          AppKit shell: status item, floating panel, onboarding window
Sources/AgoreCore/   presence model, activity mapping, Cursor adapters, SQLite store
Sources/AgorePlaza/  pixel art, SpriteKit scene, character behaviour
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

`Agore.xcodeproj` is generated, not hand-edited. Add new source files to
`Scripts/gen_pbxproj.py` and run `make gen-project`.

## Roadmap

- More agent providers beyond Cursor
- Phase two: an opt-in shared plaza, where the agents of everyone running Agore walk into
  the same square — the point of the name

## License

Not yet decided.
