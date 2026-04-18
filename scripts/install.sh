#!/usr/bin/env bash
# install.sh — Unity MCP local installer for Claude Code / Cursor.
# Repo: https://github.com/<owner>/unity-mcp-installer
# License: MIT

# We intentionally DO NOT use `set -e` — failures are handled explicitly so
# partial success is visible to the user, and so doctor.sh can pinpoint what
# actually went wrong.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

# ─── defaults ───────────────────────────────────────────────────────────────
VERSION="0.1.0"
UNITY_PROJECT=""
INSTALL_COPLAY="auto"   # auto|yes|no
INSTALL_IVAN="auto"
ASSUME_YES=""
DRY_RUN=false
LOG_FILE="${TMPDIR:-/tmp}/unity-mcp-install-$(date +%Y%m%d_%H%M%S).log"
NODE_MIN_VERSION="18.0.0"
NODE_RECOMMENDED="21"

COPLAY_REPO="https://github.com/CoplayDev/unity-mcp.git"
COPLAY_DIR="$HOME/.unity-mcp/coplaydev"

MCP_CONFIG_PATH_CLAUDE_CODE=""  # set later based on OS

# ─── help ───────────────────────────────────────────────────────────────────
print_help() {
  cat << EOF
Unity MCP Local Installer v${VERSION}

USAGE
  install.sh [OPTIONS]

OPTIONS
  --unity-project <path>   Unity project absolute path
  --coplay                 Install CoplayDev/unity-mcp (default: ask)
  --no-coplay              Skip CoplayDev
  --ivan                   Install IvanMurzak/Unity-MCP CLI (default: ask)
  --no-ivan                Skip IvanMurzak CLI
  --yes, -y                Non-interactive; accept defaults
  --dry-run                Show what would happen; make no changes
  --log <file>             Write log to file (default: \$TMPDIR/unity-mcp-install-*.log)
  --help, -h               Show this help

EXAMPLES
  # Interactive
  bash install.sh

  # Non-interactive, install everything
  bash install.sh -y --unity-project ~/Dev/MyGame

  # Dry run to preview
  bash install.sh --dry-run

FILES
  ~/.unity-mcp/coplaydev/                    CoplayDev MCP server clone
  ~/.claude/claude_desktop_config.json       Claude Code MCP config (Linux/legacy)
  ~/Library/Application Support/Claude/...   Claude Code MCP config (macOS)
  <project>/.cursor/mcp.json                 Cursor project config

DOCS
  docs/troubleshooting.md
  docs/architecture.md
EOF
}

# ─── argument parsing ───────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --unity-project) UNITY_PROJECT="${2:-}"; shift 2 ;;
    --coplay)        INSTALL_COPLAY="yes"; shift ;;
    --no-coplay)     INSTALL_COPLAY="no"; shift ;;
    --ivan)          INSTALL_IVAN="yes"; shift ;;
    --no-ivan)       INSTALL_IVAN="no"; shift ;;
    --yes|-y)        ASSUME_YES=1; shift ;;
    --dry-run)       DRY_RUN=true; shift ;;
    --log)           LOG_FILE="${2:-}"; shift 2 ;;
    --help|-h)       print_help; exit 0 ;;
    --version|-v)    echo "v${VERSION}"; exit 0 ;;
    *) log_err "Unknown option: $1"; echo; print_help; exit 2 ;;
  esac
done

# ─── exports for common.sh (readonly after this point) ──────────────────────
export LOG_FILE ASSUME_YES
touch "$LOG_FILE" 2>/dev/null || LOG_FILE=""

# ─── dry-run wrapper ────────────────────────────────────────────────────────
run() {
  if $DRY_RUN; then
    log_dim "[dry-run] $*"
    return 0
  fi
  log_dim "\$ $*"
  _log_to_file "CMD  $*"
  "$@"
}

# ─── banner ─────────────────────────────────────────────────────────────────
printf '\n%s' "$C_CYAN"
cat << 'EOF'
  ██╗   ██╗███╗   ██╗██╗████████╗██╗   ██╗    ███╗   ███╗ ██████╗██████╗
  ██║   ██║████╗  ██║██║╚══██╔══╝╚██╗ ██╔╝    ████╗ ████║██╔════╝██╔══██╗
  ██║   ██║██╔██╗ ██║██║   ██║    ╚████╔╝     ██╔████╔██║██║     ██████╔╝
  ██║   ██║██║╚██╗██║██║   ██║     ╚██╔╝      ██║╚██╔╝██║██║     ██╔═══╝
  ╚██████╔╝██║ ╚████║██║   ██║      ██║       ██║ ╚═╝ ██║╚██████╗██║
EOF
printf '%s\n' "$C_RESET"
printf '  %s%sUnity MCP Local Installer v%s%s\n' "$C_BOLD" "$C_CYAN" "$VERSION" "$C_RESET"
printf '  Log: %s\n' "$LOG_FILE"
$DRY_RUN && log_warn "DRY-RUN mode — no changes will be made"
echo

# ─── step 1: system checks ──────────────────────────────────────────────────
log_h1 "1/6  System Checks"

OS="$(detect_os)"
ARCH="$(detect_arch)"
MCP_BIN_DIR="$(mcp_binary_dir || echo 'unsupported')"

case "$OS" in
  macos)
    log_ok "macOS $(sw_vers -productVersion 2>/dev/null || echo '?')"
    MCP_CONFIG_PATH_CLAUDE_CODE="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
    ;;
  linux)
    log_warn "Linux — partial support; CoplayDev may build fine, IvanMurzak binaries vary"
    MCP_CONFIG_PATH_CLAUDE_CODE="$HOME/.claude/claude_desktop_config.json"
    ;;
  *)
    log_err "Unsupported OS: $(uname -s). See docs/windows.md for WSL setup."
    exit 1
    ;;
esac

log_ok "Architecture: $ARCH ($MCP_BIN_DIR)"

# macOS Xcode CLT
if [[ "$OS" == "macos" ]] && ! xcode-select -p >/dev/null 2>&1; then
  log_warn "Xcode Command Line Tools not installed"
  if confirm "Install Xcode Command Line Tools now?" "Y"; then
    run xcode-select --install || true
    log_info "Finish the Xcode CLT install dialog, then re-run this script."
    exit 0
  else
    log_err "git requires Xcode CLT on macOS. Aborting."
    exit 1
  fi
fi

# git
if has_command git; then
  log_ok "git $(git --version | awk '{print $3}')"
else
  log_err "git not found. Install via: brew install git"
  exit 1
fi

# ─── step 2: node.js ────────────────────────────────────────────────────────
log_h1 "2/6  Node.js"

NODE_OK=false
if has_command node; then
  CURRENT="$(node_version)"
  if version_ge "$CURRENT" "$NODE_MIN_VERSION"; then
    log_ok "node v$CURRENT (>= $NODE_MIN_VERSION)"
    NODE_OK=true
  else
    log_warn "node v$CURRENT is older than $NODE_MIN_VERSION"
  fi
fi

if ! $NODE_OK; then
  if $DRY_RUN; then
    log_dim "[dry-run] would install nvm + Node.js v$NODE_RECOMMENDED"
  else
    log_info "Installing Node.js v$NODE_RECOMMENDED via nvm…"

    # Install nvm if missing
    if [[ ! -d "$HOME/.nvm" ]]; then
      if confirm "Install nvm (Node Version Manager)?" "Y"; then
        if ! run bash -c 'curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash'; then
          log_err "nvm install failed"
          exit 1
        fi
      else
        log_err "nvm required. Install Node.js manually and re-run."
        exit 1
      fi
    fi

    # Load nvm in current shell
    # shellcheck disable=SC1091
    if [[ -s "$HOME/.nvm/nvm.sh" ]]; then
      export NVM_DIR="$HOME/.nvm"
      \. "$HOME/.nvm/nvm.sh"
    fi

    if has_command nvm; then
      if ! run nvm install "$NODE_RECOMMENDED"; then
        log_err "nvm install failed"
        exit 1
      fi
      run nvm use "$NODE_RECOMMENDED" || true
      run nvm alias default "$NODE_RECOMMENDED" || true
      log_ok "node $(node --version)"
    else
      log_err "nvm not available in this shell. Open a new terminal and re-run."
      exit 1
    fi
  fi
fi

if has_command npm; then
  log_ok "npm $(npm --version)"
else
  log_err "npm missing (unexpected)."
  exit 1
fi

# ─── step 3: claude code ────────────────────────────────────────────────────
log_h1 "3/6  Claude Code CLI"

CLAUDE_PATH=""
if CLAUDE_PATH=$(find_claude_executable); then
  log_ok "claude: $CLAUDE_PATH"
else
  if confirm "Install @anthropic-ai/claude-code globally?" "Y"; then
    if $DRY_RUN; then
      log_dim "[dry-run] npm install -g @anthropic-ai/claude-code"
      log_dim "[dry-run] would verify claude binary exists on PATH"
      CLAUDE_PATH="(would be installed)"
    else
      if ! run npm install -g @anthropic-ai/claude-code; then
        log_err "claude-code install failed"
        exit 1
      fi
      CLAUDE_PATH=$(find_claude_executable || echo "")
      if [[ -n "$CLAUDE_PATH" ]]; then
        log_ok "installed: $CLAUDE_PATH"
      else
        log_err "claude binary not found after install. Open new shell; check PATH."
        exit 1
      fi
    fi
  else
    log_err "Claude Code required to continue."
    exit 1
  fi
fi

# ─── step 4: unity project ──────────────────────────────────────────────────
log_h1 "4/6  Unity Project"

if [[ -z "$UNITY_PROJECT" ]]; then
  UNITY_PROJECT="$(ask "Unity project absolute path (leave empty to skip)")"
fi

if [[ -n "$UNITY_PROJECT" ]]; then
  UNITY_PROJECT="$(expand_path "$UNITY_PROJECT")"
  if [[ ! -d "$UNITY_PROJECT" ]]; then
    log_err "Path does not exist: $UNITY_PROJECT"
    exit 1
  fi
  if [[ ! -d "$UNITY_PROJECT/Assets" ]]; then
    log_warn "No Assets/ folder at $UNITY_PROJECT — is this really a Unity project?"
    if ! confirm "Continue anyway?" "N"; then
      exit 1
    fi
  fi
  log_ok "Unity project: $UNITY_PROJECT"
else
  log_warn "No project path — MCP configs will use placeholders; Cursor config skipped"
fi

# ─── step 5: choose + install MCP servers ───────────────────────────────────
log_h1 "5/6  Install MCP Servers"

# Resolve auto → yes/no
if [[ "$INSTALL_COPLAY" == "auto" ]]; then
  if confirm "Install CoplayDev/unity-mcp (scene/physics/profiler tools)?" "Y"; then
    INSTALL_COPLAY="yes"
  else
    INSTALL_COPLAY="no"
  fi
fi

if [[ "$INSTALL_IVAN" == "auto" ]]; then
  if confirm "Install IvanMurzak/Unity-MCP CLI (Roslyn execution, runtime AI)?" "Y"; then
    INSTALL_IVAN="yes"
  else
    INSTALL_IVAN="no"
  fi
fi

if [[ "$INSTALL_COPLAY" == "no" && "$INSTALL_IVAN" == "no" ]]; then
  log_warn "Nothing selected. Exiting."
  exit 0
fi

# ── CoplayDev ───────────────────────────────────────────────────────────────
COPLAY_ENTRY=""
if [[ "$INSTALL_COPLAY" == "yes" ]]; then
  log_h2 "  ▸ CoplayDev/unity-mcp"

  if [[ -d "$COPLAY_DIR/.git" ]]; then
    log_info "Updating existing repo…"
    run git -C "$COPLAY_DIR" fetch --prune || log_warn "git fetch failed"
    run git -C "$COPLAY_DIR" pull --ff-only || log_warn "pull failed (local changes?)"
  else
    run mkdir -p "$(dirname "$COPLAY_DIR")"
    run git clone --depth 1 "$COPLAY_REPO" "$COPLAY_DIR" \
      || { log_err "clone failed"; INSTALL_COPLAY="failed"; }
  fi

  # Find server entrypoint — be defensive about directory structure changes
  if [[ "$INSTALL_COPLAY" != "failed" ]]; then
    for candidate in \
      "$COPLAY_DIR/server/build/index.js" \
      "$COPLAY_DIR/UnityMcpBridge/server/build/index.js" \
      "$COPLAY_DIR/mcp-server/build/index.js"
    do
      if [[ -d "$(dirname "$candidate")/.." ]]; then
        SERVER_DIR="$(dirname "$(dirname "$candidate")")"
        if [[ -f "$SERVER_DIR/package.json" ]]; then
          log_info "Building server in $SERVER_DIR…"
          if run bash -c "cd '$SERVER_DIR' && npm install --silent && npm run build"; then
            COPLAY_ENTRY="$candidate"
            break
          else
            log_warn "build in $SERVER_DIR failed, trying next location"
          fi
        fi
      fi
    done

    if [[ -n "$COPLAY_ENTRY" && -f "$COPLAY_ENTRY" ]]; then
      log_ok "CoplayDev built: $COPLAY_ENTRY"
    elif [[ -n "$COPLAY_ENTRY" ]]; then
      log_warn "Expected $COPLAY_ENTRY but file not found. Repo structure may have changed."
      INSTALL_COPLAY="partial"
    else
      log_warn "Could not locate CoplayDev server package.json. Manual build needed."
      INSTALL_COPLAY="partial"
    fi
  fi
fi

# ── IvanMurzak CLI ──────────────────────────────────────────────────────────
if [[ "$INSTALL_IVAN" == "yes" ]]; then
  log_h2 "  ▸ IvanMurzak/Unity-MCP CLI"

  if has_command unity-mcp-cli; then
    log_ok "unity-mcp-cli already installed"
  else
    run npm install -g unity-mcp-cli \
      || { log_err "unity-mcp-cli install failed"; INSTALL_IVAN="failed"; }
  fi

  # Only install plugin if project was supplied AND CLI works
  if [[ "$INSTALL_IVAN" == "yes" && -n "$UNITY_PROJECT" ]] && has_command unity-mcp-cli; then
    if confirm "Install Unity-MCP plugin into $UNITY_PROJECT ?" "Y"; then
      if run unity-mcp-cli install-plugin "$UNITY_PROJECT"; then
        log_ok "Plugin installed"
        run unity-mcp-cli setup-skills claude-code "$UNITY_PROJECT" \
          || log_warn "Skills setup failed — you can run this manually later"
      else
        log_warn "Plugin install failed — install manually via Unity Package Manager"
      fi
    fi
  elif [[ -z "$UNITY_PROJECT" ]]; then
    log_dim "Skipping plugin install (no project path)"
    log_dim "Later, run: unity-mcp-cli install-plugin /your/project"
  fi
fi

# ─── step 6: write configs ──────────────────────────────────────────────────
log_h1 "6/6  Write MCP Configuration"

# Pick template
pick_template() {
  local template
  if [[ "$INSTALL_COPLAY" == "yes" || "$INSTALL_COPLAY" == "partial" ]] \
     && [[ "$INSTALL_IVAN" == "yes" ]]; then
    template="both"
  elif [[ "$INSTALL_COPLAY" == "yes" || "$INSTALL_COPLAY" == "partial" ]]; then
    template="coplay-only"
  elif [[ "$INSTALL_IVAN" == "yes" ]]; then
    template="ivan-only"
  else
    return 1
  fi
  printf '%s' "$template"
}

if TEMPLATE=$(pick_template); then
  TEMPLATE_FILE="$REPO_ROOT/templates/mcp-configs/${TEMPLATE}.json"
  if [[ ! -f "$TEMPLATE_FILE" ]]; then
    log_err "Missing template: $TEMPLATE_FILE"
    exit 1
  fi

  # Substitute placeholders
  IVAN_BIN_PATH="/YOUR/PROJECT/Library/mcp-server/${MCP_BIN_DIR}/unity-mcp-server"
  if [[ -n "$UNITY_PROJECT" ]]; then
    IVAN_BIN_PATH="$UNITY_PROJECT/Library/mcp-server/${MCP_BIN_DIR}/unity-mcp-server"
  fi

  COPLAY_ENTRY_OR_PLACEHOLDER="${COPLAY_ENTRY:-$COPLAY_DIR/server/build/index.js}"

  CONFIG_CONTENT="$(sed \
    -e "s|{{COPLAY_ENTRY}}|${COPLAY_ENTRY_OR_PLACEHOLDER}|g" \
    -e "s|{{IVAN_BIN}}|${IVAN_BIN_PATH}|g" \
    "$TEMPLATE_FILE")"

  # Write Claude Code config (backup first)
  CLAUDE_CFG="$MCP_CONFIG_PATH_CLAUDE_CODE"
  if [[ -f "$CLAUDE_CFG" ]] && ! $DRY_RUN; then
    BACKUP="$(backup_file "$CLAUDE_CFG")"
    [[ -n "$BACKUP" ]] && log_warn "Backed up existing config: $BACKUP"
  fi

  if $DRY_RUN; then
    log_dim "[dry-run] would write to: $CLAUDE_CFG"
    printf '%s\n' "$CONFIG_CONTENT"
  else
    if write_file_safe "$CLAUDE_CFG" "$CONFIG_CONTENT"; then
      log_ok "Claude Code MCP config: $CLAUDE_CFG"
    else
      log_err "Failed to write $CLAUDE_CFG"
    fi
  fi

  # Cursor project config
  if [[ -n "$UNITY_PROJECT" && "$INSTALL_COPLAY" != "no" ]]; then
    CURSOR_CFG="$UNITY_PROJECT/.cursor/mcp.json"
    CURSOR_TEMPLATE="$REPO_ROOT/templates/mcp-configs/cursor.json"
    if [[ -f "$CURSOR_TEMPLATE" ]]; then
      CURSOR_CONTENT="$(sed "s|{{COPLAY_ENTRY}}|${COPLAY_ENTRY_OR_PLACEHOLDER}|g" "$CURSOR_TEMPLATE")"
      if $DRY_RUN; then
        log_dim "[dry-run] would write: $CURSOR_CFG"
      else
        write_file_safe "$CURSOR_CFG" "$CURSOR_CONTENT" && log_ok "Cursor config: $CURSOR_CFG"
      fi
    fi
  fi
fi

# CLAUDE.md template
if [[ -n "$UNITY_PROJECT" ]]; then
  CLAUDE_MD="$UNITY_PROJECT/CLAUDE.md"
  TEMPLATE_MD="$REPO_ROOT/templates/CLAUDE.md.template"

  if [[ -f "$CLAUDE_MD" ]]; then
    log_dim "CLAUDE.md already exists — keeping your version"
  elif [[ -f "$TEMPLATE_MD" ]]; then
    if confirm "Create CLAUDE.md from template?" "Y"; then
      if $DRY_RUN; then
        log_dim "[dry-run] would copy $TEMPLATE_MD → $CLAUDE_MD"
      else
        cp "$TEMPLATE_MD" "$CLAUDE_MD" && log_ok "CLAUDE.md created"
      fi
    fi
  fi
fi

# ─── summary ────────────────────────────────────────────────────────────────
log_h1 "Done"

echo
printf '  %sInstall summary%s\n' "$C_BOLD" "$C_RESET"
printf '    CoplayDev:   %s\n' "$INSTALL_COPLAY"
printf '    IvanMurzak:  %s\n' "$INSTALL_IVAN"
printf '    Unity proj:  %s\n' "${UNITY_PROJECT:-<none>}"
printf '    Log:         %s\n' "$LOG_FILE"
echo

printf '  %sNext (manual Unity Editor steps):%s\n\n' "$C_BOLD" "$C_RESET"

if [[ "$INSTALL_COPLAY" != "no" ]]; then
  cat << EOF
  ${C_CYAN}[CoplayDev]${C_RESET}
  1. Open Unity → Window > Package Manager → + → "Add package from git URL"
  2. Enter: ${C_CYAN}${COPLAY_REPO}${C_RESET}
  3. Also add dependency: ${C_CYAN}com.unity.nuget.newtonsoft-json${C_RESET}
  4. Window → MCP Unity → Server Window → ${C_BOLD}Start Server${C_RESET}
  5. "Choose Claude Install Location" → ${C_CYAN}${CLAUDE_PATH}${C_RESET}

EOF
fi

if [[ "$INSTALL_IVAN" != "no" ]]; then
  cat << EOF
  ${C_CYAN}[IvanMurzak]${C_RESET}
  1. Window → AI Game Developer (Unity-MCP)
  2. Select Claude Code → click ${C_BOLD}Generate Skills${C_RESET}

EOF
fi

cat << EOF
  ${C_BOLD}Then, start a session:${C_RESET}
    cd ${UNITY_PROJECT:-/your/unity/project}
    claude

  ${C_BOLD}Test prompt:${C_RESET}
    "Create three cubes (red, blue, yellow) in the scene, 2m apart"

  ${C_BOLD}Verify install:${C_RESET}
    bash scripts/doctor.sh

EOF

$DRY_RUN && log_warn "DRY-RUN: no changes were made."
log_ok "All steps completed."
