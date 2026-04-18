#!/usr/bin/env bash
# doctor.sh — diagnose Unity MCP local setup issues.
# Read-only; makes no changes to your system.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

FAILED=0
WARNED=0

# shellcheck disable=SC2317  # called dynamically below
check() {
  local label="$1" cmd="$2"
  if eval "$cmd" >/dev/null 2>&1; then
    log_ok "$label"
    return 0
  else
    log_err "$label"
    FAILED=$((FAILED + 1))
    return 1
  fi
}

# shellcheck disable=SC2317
soft_check() {
  local label="$1" cmd="$2"
  if eval "$cmd" >/dev/null 2>&1; then
    log_ok "$label"
  else
    log_warn "$label"
    WARNED=$((WARNED + 1))
  fi
}

# ─── OS / arch ──────────────────────────────────────────────────────────────
log_h1 "System"

OS="$(detect_os)"
ARCH="$(detect_arch)"

case "$OS" in
  macos)
    log_ok "OS: macOS $(sw_vers -productVersion 2>/dev/null || echo '?')"
    ;;
  linux)
    log_warn "OS: Linux — partially supported (IvanMurzak CLI works, CoplayDev may need manual build)"
    WARNED=$((WARNED + 1))
    ;;
  windows)
    log_err "OS: Windows — use WSL2 or see docs/windows.md (not yet supported)"
    FAILED=$((FAILED + 1))
    ;;
  *)
    log_err "OS: $(uname -s) — unsupported"
    FAILED=$((FAILED + 1))
    ;;
esac

log_ok "Arch: $ARCH"
if MCP_DIR=$(mcp_binary_dir); then
  log_dim "Unity MCP binary dir: $MCP_DIR"
fi

# ─── dependencies ───────────────────────────────────────────────────────────
log_h1 "Dependencies"

# git
if has_command git; then
  log_ok "git $(git --version | awk '{print $3}')"
else
  log_err "git not found (install via: brew install git)"
  FAILED=$((FAILED + 1))
fi

# Node.js
if has_command node; then
  NODE_VER="$(node_version)"
  if version_ge "$NODE_VER" "18.0.0"; then
    log_ok "node v$NODE_VER"
  else
    log_err "node v$NODE_VER — v18+ required"
    FAILED=$((FAILED + 1))
  fi
else
  log_err "node not found"
  FAILED=$((FAILED + 1))
fi

# npm
if has_command npm; then
  log_ok "npm $(npm --version)"
else
  log_err "npm not found"
  FAILED=$((FAILED + 1))
fi

# Xcode Command Line Tools (macOS)
if [[ "$OS" == "macos" ]]; then
  if xcode-select -p >/dev/null 2>&1; then
    log_ok "Xcode Command Line Tools"
  else
    log_warn "Xcode Command Line Tools missing (install: xcode-select --install)"
    WARNED=$((WARNED + 1))
  fi
fi

# ─── Claude Code ────────────────────────────────────────────────────────────
log_h1 "Claude Code"

CLAUDE=""
if CLAUDE=$(find_claude_executable); then
  log_ok "claude: $CLAUDE"
  if "$CLAUDE" --version >/dev/null 2>&1; then
    log_dim "version: $("$CLAUDE" --version 2>&1 | head -1)"
  fi
else
  log_err "claude not found (install: npm install -g @anthropic-ai/claude-code)"
  FAILED=$((FAILED + 1))
fi

# ─── MCP servers ────────────────────────────────────────────────────────────
log_h1 "MCP Servers"

# CoplayDev
COPLAY_DIR="${COPLAY_DIR:-$HOME/.unity-mcp/coplaydev}"
COPLAY_ENTRY="$COPLAY_DIR/server/build/index.js"

if [[ -d "$COPLAY_DIR" ]]; then
  log_ok "CoplayDev repo: $COPLAY_DIR"
  if [[ -f "$COPLAY_ENTRY" ]]; then
    log_ok "CoplayDev built: $COPLAY_ENTRY"
  else
    log_warn "CoplayDev not built (run: install.sh or cd $COPLAY_DIR/server && npm install && npm run build)"
    WARNED=$((WARNED + 1))
  fi

  if has_command git && git -C "$COPLAY_DIR" rev-parse >/dev/null 2>&1; then
    log_dim "commit: $(git -C "$COPLAY_DIR" rev-parse --short HEAD)"
    log_dim "branch: $(git -C "$COPLAY_DIR" rev-parse --abbrev-ref HEAD)"
  fi
else
  log_warn "CoplayDev not installed (optional)"
  WARNED=$((WARNED + 1))
fi

# IvanMurzak CLI
if has_command unity-mcp-cli; then
  log_ok "unity-mcp-cli: $(command -v unity-mcp-cli)"
else
  log_warn "unity-mcp-cli not installed (optional)"
  WARNED=$((WARNED + 1))
fi

# ─── MCP configs ────────────────────────────────────────────────────────────
log_h1 "MCP Configuration"

CLAUDE_CFG_V1="$HOME/.claude/claude_desktop_config.json"
CLAUDE_CFG_V2="$HOME/Library/Application Support/Claude/claude_desktop_config.json"

for cfg in "$CLAUDE_CFG_V1" "$CLAUDE_CFG_V2"; do
  if [[ -f "$cfg" ]]; then
    log_ok "Claude MCP config: $cfg"
    if has_jq; then
      SERVER_COUNT=$(jq -r '.mcpServers // {} | keys | length' "$cfg" 2>/dev/null || echo "?")
      log_dim "mcpServers: $SERVER_COUNT"
      jq -r '.mcpServers // {} | keys[]' "$cfg" 2>/dev/null | while read -r s; do
        log_dim "  • $s"
      done
    fi
  fi
done

# ─── summary ────────────────────────────────────────────────────────────────
log_h1 "Summary"

if (( FAILED == 0 && WARNED == 0 )); then
  log_ok "All checks passed."
  exit 0
elif (( FAILED == 0 )); then
  log_warn "$WARNED warning(s). Setup is usable but not complete."
  exit 0
else
  log_err "$FAILED check(s) failed, $WARNED warning(s)."
  echo
  log_dim "Run: bash scripts/install.sh"
  log_dim "Or see: docs/troubleshooting.md"
  exit 1
fi
