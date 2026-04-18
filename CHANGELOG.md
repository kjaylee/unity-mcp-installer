# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] — 2026-04-18

First public release.

### Added
- `scripts/install.sh` — interactive + non-interactive installer
- `scripts/uninstall.sh` — reset MCP config + remove server files
- `scripts/doctor.sh` — read-only diagnostic
- `scripts/lib/common.sh` — shared helpers (logging, prompts, version check)
- MCP config templates: `coplay-only`, `ivan-only`, `both`, `cursor`
- `templates/CLAUDE.md.template` — generic project context seed
- ShellCheck CI on PR / push
- Issue and PR templates
- Troubleshooting + architecture docs

### Known issues
- CoplayDev build location probed across three candidate paths; may still
  miss if the upstream layout changes. Installer prints the attempted paths.
- Windows untested; installer errors out with a WSL2 pointer.
- Linux partial: unity-mcp-cli works; CoplayDev may need manual dependency tweaks.
