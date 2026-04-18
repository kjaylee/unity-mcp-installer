# unity-mcp-installer

> Opinionated, one-command installer for using **Claude Code** (and Cursor) with **Unity3D** via **MCP** on macOS.

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Shell](https://img.shields.io/badge/shell-bash%205%2B-green.svg)](#requirements)
[![macOS](https://img.shields.io/badge/macOS-12%2B-lightgrey.svg)](#requirements)
[![Status](https://img.shields.io/badge/status-alpha-orange.svg)](#status)

This script wires up the two most useful Unity MCP servers — [CoplayDev/unity-mcp](https://github.com/CoplayDev/unity-mcp) (scene/physics/profiler tools) and [IvanMurzak/Unity-MCP](https://github.com/IvanMurzak/Unity-MCP) (Roslyn execution, runtime AI) — to Claude Code and Cursor on your Mac, including all the "first time" PATH, Node, and config-file gotchas that usually eat the first hour.

## Status

**Alpha / single-maintainer.** Tested on macOS 15 (Apple Silicon) with Unity 6 + Claude Code. Linux runs most paths but CoplayDev binaries are macOS-focused. Windows users: please use WSL2. See [docs/troubleshooting.md](docs/troubleshooting.md) if something breaks, and open an issue with `bash scripts/doctor.sh` output attached.

This is **not affiliated with Anthropic, Unity, CoplayDev, or IvanMurzak**. It just automates the public setup steps they document.

## What it does

| Step | Action |
|---|---|
| 1 | Detect macOS version, Apple Silicon vs Intel, shell |
| 2 | Install Node.js v21 via nvm (if missing) |
| 3 | Install Claude Code CLI (`@anthropic-ai/claude-code`) |
| 4 | Clone & build [CoplayDev/unity-mcp](https://github.com/CoplayDev/unity-mcp) to `~/.unity-mcp/coplaydev` |
| 5 | Install `unity-mcp-cli` for [IvanMurzak/Unity-MCP](https://github.com/IvanMurzak/Unity-MCP) |
| 6 | Write `claude_desktop_config.json` with correct paths (backup of existing) |
| 7 | Drop a `.cursor/mcp.json` into your Unity project |
| 8 | Seed a `CLAUDE.md` template you can edit |

Unity-side steps (package install, server start, Skills generation) stay manual — they require the Unity Editor GUI and the script prints exact instructions.

## Quick start

```bash
git clone https://github.com/kjaylee/unity-mcp-installer.git
cd unity-mcp-installer

# Interactive
bash scripts/install.sh

# Or: non-interactive with a project path
bash scripts/install.sh -y --unity-project ~/Dev/MyUnityGame

# Preview without changing anything
bash scripts/install.sh --dry-run
```

After it finishes, follow the "manual Unity Editor steps" it prints, then:

```bash
cd ~/Dev/MyUnityGame
claude
# Try: "Create three cubes (red, blue, yellow) in the scene, 2m apart"
```

## Requirements

- **macOS 12+** (Linux works for most steps; Windows via WSL2)
- **Unity 6+** recommended (most MCP tools assume Unity 6 APIs)
- **Xcode Command Line Tools** (`xcode-select --install`) — the installer will prompt if missing
- **git**, **bash 4+** (macOS ships with 3.2; the installer works with 3.2+ but `zsh` and `bash 4+` are smoother)

All other dependencies (Node.js, nvm, Claude Code, CoplayDev server, unity-mcp-cli) are installed for you on demand.

## Options

```
install.sh [OPTIONS]

  --unity-project <path>   Unity project absolute path
  --coplay                 Install CoplayDev (default: ask)
  --no-coplay              Skip CoplayDev
  --ivan                   Install IvanMurzak CLI (default: ask)
  --no-ivan                Skip IvanMurzak CLI
  --yes, -y                Accept all defaults (CI-friendly)
  --dry-run                Preview; make no changes
  --log <file>             Log path (default: $TMPDIR/unity-mcp-install-*.log)
  --help, -h
```

## Diagnostics

```bash
bash scripts/doctor.sh
```

Checks OS/arch, Node version, Claude Code binary, MCP server paths, and existing config files. Makes **zero** changes — read-only. Attach its output to any bug report.

## Uninstall

```bash
bash scripts/uninstall.sh
```

Resets `mcpServers` in your Claude Code config (with timestamped backup), removes `~/.unity-mcp/coplaydev/`, and optionally removes `unity-mcp-cli`. Does **not** touch Node.js, nvm, Claude Code CLI, or your Unity project. Use `--keep-repo` to leave the CoplayDev clone in place.

## Project layout

```
unity-mcp-installer/
├── scripts/
│   ├── install.sh          # main installer
│   ├── uninstall.sh        # reset + cleanup
│   ├── doctor.sh           # read-only diagnostics
│   └── lib/common.sh       # shared helpers
├── templates/
│   ├── CLAUDE.md.template  # seed for your project's CLAUDE.md
│   └── mcp-configs/        # JSON templates (placeholders substituted)
├── docs/
│   ├── troubleshooting.md
│   └── architecture.md
├── .github/                # CI, issue/PR templates
├── CHANGELOG.md
├── CONTRIBUTING.md
├── LICENSE
└── README.md
```

## Caveats / known limits

- **CoplayDev was acquired by Ramen in March 2026.** The OSS repo remains MIT-licensed, but future update cadence of the free MCP may slow in favor of the paid "Aura" product. See the [announcement](https://www.gamespress.com/GDC-Ramen-Acquisition-of-Coplay-Brings-Together-the-Best-In-Class-Mult).
- **IvanMurzak binaries** are compiled into `<UnityProject>/Library/mcp-server/<arch>/…` on first Unity launch with the plugin installed — which is why the MCP config path points there. If you haven't opened the project yet, that path won't exist until you do. This is expected.
- **Unity-side setup is manual** — we can't drive the Unity Editor GUI from a shell script. The installer prints exact menu paths.
- **macOS `Finder`/Unity Hub launches lose `$PATH`**. The installer detects `claude` location and prints it so you can paste into "Choose Claude Install Location" in the CoplayDev server window.
- **`jq` is optional** but recommended; the uninstaller prefers it for safe JSON edits and falls back to a cruder reset if missing.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Bug reports, Linux/Windows ports, and doc improvements are very welcome. Please attach `doctor.sh` output to bug reports.

Runs [ShellCheck](https://www.shellcheck.net/) in CI — keep it clean.

## License

MIT. See [LICENSE](LICENSE).

## Acknowledgements

- [CoplayDev](https://github.com/CoplayDev/unity-mcp) — scene/physics/profiler MCP tools
- [Ivan Murzak](https://github.com/IvanMurzak/Unity-MCP) — Roslyn-based MCP server
- [CoderGamester](https://github.com/CoderGamester/mcp-unity) — alternate Unity MCP implementation (not auto-installed here, but recommended)
- [Anthropic](https://www.anthropic.com/) — Claude Code, MCP
