# Troubleshooting

If something's off, first run:

```bash
bash scripts/doctor.sh
```

It's read-only and tells you exactly which step broke.

---

## `claude: command not found` inside Unity

**Cause.** macOS launches Unity via Finder / Unity Hub, which doesn't inherit
your shell `$PATH`. So even though `which claude` works in Terminal, Unity
can't find it.

**Fix (pick one).**

1. In Unity: `Window → MCP Unity → Server Window → Choose Claude Install Location`.
   Paste the absolute path from `which claude` (commonly
   `/Users/you/.nvm/versions/node/v21.7.1/bin/claude` or
   `/opt/homebrew/bin/claude`).

2. Launch Unity Hub from Terminal instead of Finder:
   ```bash
   open -a "Unity Hub"
   ```

3. Install Claude Code via Homebrew so it lands in a global path:
   ```bash
   # (if Anthropic publishes a brew formula — check docs.claude.com)
   ```

---

## MCP server doesn't connect to Claude Code

**Check config location.**

- macOS (current): `~/Library/Application Support/Claude/claude_desktop_config.json`
- Legacy / Linux: `~/.claude/claude_desktop_config.json`

Run `bash scripts/doctor.sh` — it prints whichever one it finds and shows the
`mcpServers` list.

**Restart Claude Code.** Config changes, especially switching between
`stdio` and `http` transport, require a full restart of the Claude Code
process. Quit it (not just the current session) and re-launch.

**Is the Unity MCP server actually running?** In Unity:
`Window → MCP Unity → Server Window` — the indicator should be green / "Running".
If it's off, click Start Server.

---

## `npm install` fails during CoplayDev build

Usually a Node version issue. The CoplayDev server targets Node 18+.

```bash
node --version        # must be >= 18
nvm use 21            # if you have nvm
```

If `npm install` fails with native-module compile errors on Apple Silicon,
you may need Xcode Command Line Tools:

```bash
xcode-select --install
```

---

## `port 8080 already in use` (IvanMurzak)

Something else is using 8080. Either kill it or change the port in
`claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "unity-ivanmurzak": {
      "command": ".../unity-mcp-server",
      "args": ["--port=8081", "--client-transport=stdio"]
    }
  }
}
```

Find what's on 8080:

```bash
lsof -i :8080
```

---

## IvanMurzak binary not found at `<project>/Library/mcp-server/...`

That directory is created by Unity **after you open the project with the
Unity-MCP plugin installed**. If you ran the installer but haven't opened
Unity yet, the path won't exist — this is expected.

Steps:

1. Open the Unity project in the Editor at least once.
2. Wait for package import + compilation to finish.
3. Check `<project>/Library/mcp-server/osx-arm64/` (or `osx-x64` on Intel).
4. If still missing: `Window → AI Game Developer → Generate Skills`.

---

## `osx-x64` binary downloaded on Apple Silicon

Happens occasionally with older `unity-mcp-cli` versions. Re-install:

```bash
npm uninstall -g unity-mcp-cli
npm install -g unity-mcp-cli@latest
```

Then in Unity: `Window → AI Game Developer → Force Re-download Server`.

Or grab the right arch directly from the
[Unity-MCP releases page](https://github.com/IvanMurzak/Unity-MCP/releases).

---

## Claude doesn't see any Unity tools

1. Run `bash scripts/doctor.sh` — confirm config file is present and lists
   `unity-coplay` / `unity-ivanmurzak`.
2. In Claude Code: type `/mcp` to list connected MCP servers. If Unity isn't
   there, the config didn't load.
3. Is Unity running? The server inside Unity must be up for Claude to
   connect.
4. Check Claude Code's own logs. On macOS:
   ```
   ~/Library/Logs/Claude/
   ```

---

## Installer crashed halfway

Everything is idempotent — safe to re-run:

```bash
bash scripts/install.sh --log /tmp/retry.log
```

Your prior MCP config was backed up to `claude_desktop_config.json.bak.YYYY…`
next to the original. To restore:

```bash
cp ~/Library/Application\ Support/Claude/claude_desktop_config.json.bak.20260418_143022 \
   ~/Library/Application\ Support/Claude/claude_desktop_config.json
```

---

## I want to start clean

```bash
bash scripts/uninstall.sh
# then
bash scripts/install.sh
```

Uninstall keeps Node.js, Claude Code, and your Unity project. It only
removes MCP server files and clears the `mcpServers` entry.

---

## Still stuck?

Open an issue with:
- full `doctor.sh` output
- the install log (`$TMPDIR/unity-mcp-install-*.log`)
- what you expected vs what happened

See [bug template](.github/ISSUE_TEMPLATE/bug_report.md).
