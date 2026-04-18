# Contributing

Thanks for considering a contribution! This is a small, volunteer-maintained
project, so here's what helps most:

## Bug reports

1. Run `bash scripts/doctor.sh` and paste the output.
2. Include your macOS version, Apple Silicon or Intel, Unity version, and
   the exact command you ran.
3. If the installer crashed, attach the log file it wrote (the path is
   printed at the top of every run, usually `$TMPDIR/unity-mcp-install-*.log`).

## Pull requests

- **Run ShellCheck first.** CI will run it automatically, but catching it
  locally saves a round trip:
  ```bash
  shellcheck -x scripts/*.sh scripts/lib/*.sh
  ```
- **Keep `set -e` out of `install.sh`.** Errors are handled explicitly so
  partial success is visible to the user and `doctor.sh` stays accurate.
- **Don't hard-code paths** that depend on upstream repo layout — probe
  multiple candidate locations instead (see how CoplayDev build is found).
- **Test the dry-run path** (`--dry-run`) for every new action.
- **Update CHANGELOG.md** under `[Unreleased]`.

## Scope

In scope:
- macOS support improvements
- Linux / Windows (WSL) ports
- Better error messages
- Support for additional Unity MCP implementations as they mature
- `doctor.sh` checks

Out of scope (for now):
- Driving the Unity Editor GUI (use Unity AI Beta or CoplayDev's own scripts)
- Shipping MCP server binaries (we clone/install from upstream)
- A GUI wrapper

## Local development

```bash
# Fast feedback: dry-run with a throwaway project
bash scripts/install.sh --dry-run --unity-project /tmp/fake-unity

# Real end-to-end test (will modify your system — use a VM if worried)
bash scripts/install.sh --unity-project ~/Dev/TestProject
```

## Code style

- Bash: 2-space indent, `"$var"` quoting, `[[ ]]` not `[ ]`
- Markdown: wrap around 100 cols, reference-style links for long URLs
- Commit messages: conventional-ish; `fix:`, `feat:`, `docs:`, `chore:` prefixes

## Releases

Tags follow semver. Push a tag to trigger a GitHub Release after CI passes:

```bash
git tag -a v0.1.1 -m "v0.1.1"
git push origin v0.1.1
```
