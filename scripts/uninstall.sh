#!/usr/bin/env bash
# uninstall.sh — remove MCP server files and reset Claude Code MCP config.
# Does NOT remove: Unity packages (use Unity Package Manager),
# Node.js/nvm, Claude Code CLI (intentional — user may want to keep them).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

print_help() {
  cat << 'EOF'
Uninstall Unity MCP local components.

USAGE
  uninstall.sh [--yes] [--keep-repo] [--dry-run]

OPTIONS
  --yes, -y        Non-interactive; answer yes to prompts
  --keep-repo      Don't delete ~/.unity-mcp/coplaydev
  --dry-run        Show what would be removed; make no changes
  --help, -h       Show this help

WHAT IT REMOVES
  • Clears mcpServers in Claude Code config (backup first)
  • Deletes ~/.unity-mcp/coplaydev/ (unless --keep-repo)
  • Optionally uninstalls unity-mcp-cli (npm -g)

WHAT IT KEEPS
  • Your Unity project files
  • Node.js, nvm, Claude Code CLI
  • Unity packages (remove via Unity Editor)
EOF
}

ASSUME_YES=""
KEEP_REPO=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes|-y)    ASSUME_YES=1; shift ;;
    --keep-repo) KEEP_REPO=true; shift ;;
    --dry-run)   DRY_RUN=true; shift ;;
    --help|-h)   print_help; exit 0 ;;
    *) log_err "Unknown option: $1"; exit 2 ;;
  esac
done

export ASSUME_YES

log_h1 "Unity MCP Uninstaller"
$DRY_RUN && log_warn "DRY-RUN mode"

run() {
  if $DRY_RUN; then log_dim "[dry-run] $*"; return 0; fi
  "$@"
}

if ! confirm "Proceed with uninstall?" "N"; then
  echo "  Cancelled."
  exit 0
fi

# ─── reset Claude Code MCP configs ──────────────────────────────────────────
log_h2 "Claude Code configs"

for cfg in \
  "$HOME/Library/Application Support/Claude/claude_desktop_config.json" \
  "$HOME/.claude/claude_desktop_config.json"
do
  if [[ -f "$cfg" ]]; then
    BACKUP="$(backup_file "$cfg" 2>/dev/null || true)"
    [[ -n "${BACKUP:-}" ]] && log_warn "Backup: $BACKUP"

    # Prefer jq; fall back to emptying the mcpServers object
    if has_jq && ! $DRY_RUN; then
      if TMP="$(mktemp)"; then
        if jq '.mcpServers = {}' "$cfg" > "$TMP" && mv "$TMP" "$cfg"; then
          log_ok "Cleared mcpServers in $cfg"
        else
          log_err "jq failed on $cfg"
          rm -f "$TMP" 2>/dev/null || true
        fi
      fi
    elif ! $DRY_RUN; then
      echo '{"mcpServers": {}}' > "$cfg"
      log_ok "Reset (without jq): $cfg"
    else
      log_dim "[dry-run] would clear mcpServers in $cfg"
    fi
  fi
done

# ─── CoplayDev repo ─────────────────────────────────────────────────────────
log_h2 "CoplayDev server"
COPLAY_DIR="$HOME/.unity-mcp/coplaydev"
if [[ -d "$COPLAY_DIR" ]]; then
  if $KEEP_REPO; then
    log_dim "Keeping: $COPLAY_DIR (--keep-repo)"
  elif confirm "Delete $COPLAY_DIR ?" "Y"; then
    run rm -rf "$COPLAY_DIR"
    log_ok "Removed $COPLAY_DIR"

    # Remove parent if empty
    if [[ -d "$HOME/.unity-mcp" ]] && [[ -z "$(ls -A "$HOME/.unity-mcp" 2>/dev/null)" ]]; then
      run rmdir "$HOME/.unity-mcp"
    fi
  fi
else
  log_dim "Not found: $COPLAY_DIR"
fi

# ─── unity-mcp-cli ──────────────────────────────────────────────────────────
log_h2 "unity-mcp-cli"
if has_command unity-mcp-cli; then
  if confirm "npm uninstall unity-mcp-cli (global)?" "N"; then
    run npm uninstall -g unity-mcp-cli && log_ok "Removed"
  else
    log_dim "Keeping unity-mcp-cli"
  fi
else
  log_dim "unity-mcp-cli not installed"
fi

echo
log_info "Done. Reminder: remove Unity packages from inside Unity Editor:"
log_dim "  Window → Package Manager → find and remove CoplayDev / IvanMurzak packages"
echo
