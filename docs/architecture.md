# Architecture

## Why MCP at all?

Short answer: you often don't need it.

Claude Code can already read and write C# files, explain stack traces, and
refactor scripts by reading your Unity project folder directly. For a lot of
Unity work — especially coding-heavy tasks — that's enough.

MCP earns its keep when you need Claude to touch things that aren't on disk:

| Without MCP | With MCP |
|---|---|
| Read / edit C# files ✅ | Same ✅ |
| Generate scripts ✅ | Same ✅ |
| Explain errors ✅ | Same ✅ |
| Create GameObjects in scene ❌ | ✅ |
| Modify Inspector fields ❌ | ✅ |
| Read Console at runtime ❌ | ✅ |
| Start / stop Play Mode ❌ | ✅ |
| Query Profiler / memory ❌ | ✅ |

If your workflow is 90% "write and refactor code," MCP is optional.
If it's "prototype a scene, wire up references, debug live" — MCP is where
vibe coding actually clicks.

## Wire diagram

Everything runs locally on your Mac. No cloud, no external network.

```
┌──────────────────────────────────────────────────────────────────┐
│  Your Mac                                                        │
│                                                                  │
│   ┌─────────────────────┐        ┌────────────────────────────┐  │
│   │  Claude Code CLI    │        │  Cursor IDE (optional)     │  │
│   └──────────┬──────────┘        └──────────────┬─────────────┘  │
│              │ stdio / local HTTP                 │ local HTTP    │
│              └──────────────────┬───────────────┘                │
│                                 ▼                                │
│                  ┌─────────────────────────────┐                 │
│                  │  MCP Server(s)              │                 │
│                  │  • CoplayDev (Node.js)      │                 │
│                  │  • IvanMurzak (native bin)  │                 │
│                  └──────────────┬──────────────┘                 │
│                                 │ local IPC                      │
│                                 ▼                                │
│                  ┌─────────────────────────────┐                 │
│                  │  Unity Editor               │                 │
│                  │  (MCP package installed)    │                 │
│                  └─────────────────────────────┘                 │
└──────────────────────────────────────────────────────────────────┘
```

## Why two servers?

They specialize.

**CoplayDev/unity-mcp** — the "swiss army knife."
- `manage_scene`, `manage_gameobject`, `manage_asset`, `manage_packages`
- `manage_physics` (v9.6.2): collision matrix, joints, raycasts
- `manage_profiler` (v9.6.3): profiler sessions, memory snapshots
- Broad coverage of Editor operations; the thing you want for "make scene X"
  workflows.

**IvanMurzak/Unity-MCP** — the "REPL."
- `script-execute`: compile + run arbitrary C# via Roslyn without waiting
  for a full domain reload
- Method discovery + reflection-based execution across your whole codebase
- Runtime AI: the plugin works inside a compiled player build, not just the
  Editor, so you can debug live play sessions

Running both at once is fine — they bind to different names in
`mcpServers` and Claude routes calls by name.

## What lives where on disk

```
~/                                            Your home
├── .nvm/                                     Node Version Manager (if installed)
├── .claude/                                  Legacy / Linux Claude Code config
│   └── claude_desktop_config.json
├── Library/Application Support/Claude/       macOS Claude Code config (preferred)
│   └── claude_desktop_config.json
└── .unity-mcp/                               Installed by this installer
    └── coplaydev/                            Git clone of CoplayDev/unity-mcp
        └── server/build/index.js             Built MCP server entrypoint

<YourUnityProject>/                           Your Unity project
├── Assets/
├── Library/mcp-server/osx-arm64/             Created by Unity-MCP plugin after first launch
│   └── unity-mcp-server                      Native binary
├── .cursor/mcp.json                          Cursor project config (written by installer)
├── CLAUDE.md                                 Project context for Claude Code
└── Packages/manifest.json                    References CoplayDev + Unity-MCP packages
```

## Transport modes

Unity MCP servers speak two transports:

- **stdio** — Parent process spawns the server with pipes. Preferred for
  Claude Code (simplest, no ports). This is what the installer configures
  by default.
- **HTTP local** — The server listens on localhost. Preferred for Cursor
  and Windsurf because they manage MCP connections centrally and expect
  a URL.

You can run the same server in both modes at once (though usually you
don't need to). Switching modes in the Unity UI after Claude Code has
connected requires a Claude Code restart.

## Security / network posture

- **All communication is localhost or pipes.** Nothing is transmitted off
  your machine by these MCP servers themselves.
- Claude Code *does* make API calls to Anthropic for the LLM. That's
  separate from MCP.
- CoplayDev publishes anonymous telemetry by default; opt out with
  `DISABLE_TELEMETRY=true` in the environment. See their
  [TELEMETRY.md](https://github.com/CoplayDev/unity-mcp/blob/main/TELEMETRY.md).
- IvanMurzak's server defaults to loopback (127.0.0.1). Binding to all
  interfaces or exposing over HTTP to other machines is possible but
  requires explicit flags.

## Why the installer exists

Each of these components has reasonable docs on its own. The reason this
repo exists is that **wiring them together on macOS has a handful of
paper cuts that consume hours on first setup:**

- nvm PATH not inherited by GUI-launched apps
- `claude_desktop_config.json` lives in a different place than you expect
- Apple Silicon vs Intel binary selection
- Newtonsoft JSON dependency not obvious
- CoplayDev build directory layout has shifted between versions
- Backing up existing MCP config before overwriting

The installer is ~500 lines of bash that handles those once, so you can
focus on actually vibe-coding a game.
