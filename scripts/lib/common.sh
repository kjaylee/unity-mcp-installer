#!/usr/bin/env bash
# lib/common.sh — shared helpers for Unity MCP installer scripts.
# shellcheck shell=bash

# ─── colors (disabled when not a TTY or NO_COLOR set) ───────────────────────
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_RED=$'\033[0;31m'
  C_GREEN=$'\033[0;32m'
  C_YELLOW=$'\033[1;33m'
  C_CYAN=$'\033[0;36m'
  C_BOLD=$'\033[1m'
  C_DIM=$'\033[2m'
  C_RESET=$'\033[0m'
else
  C_RED=''
  C_GREEN=''
  C_YELLOW=''
  C_CYAN=''
  C_BOLD=''
  C_DIM=''
  C_RESET=''
fi
readonly C_RED C_GREEN C_YELLOW C_CYAN C_BOLD C_DIM C_RESET

# ─── logging ────────────────────────────────────────────────────────────────
LOG_FILE="${LOG_FILE:-}"

_log_to_file() {
  [[ -n "$LOG_FILE" ]] && printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG_FILE"
}

log_info() { printf '%s→%s %s\n' "$C_CYAN" "$C_RESET" "$*"; _log_to_file "INFO  $*"; }
log_ok()   { printf '%s✔%s %s\n'  "$C_GREEN" "$C_RESET" "$*"; _log_to_file "OK    $*"; }
log_warn() { printf '%s⚠%s %s\n'  "$C_YELLOW" "$C_RESET" "$*" >&2; _log_to_file "WARN  $*"; }
log_err()  { printf '%s✘%s %s\n'  "$C_RED" "$C_RESET" "$*" >&2; _log_to_file "ERROR $*"; }
log_dim()  { printf '%s  %s%s\n'  "$C_DIM" "$*" "$C_RESET"; }

log_h1() {
  printf '\n%s━━━ %s ━━━%s\n' "$C_BOLD$C_CYAN" "$*" "$C_RESET"
  _log_to_file "H1    $*"
}
log_h2() {
  printf '\n%s%s%s\n' "$C_BOLD" "$*" "$C_RESET"
  _log_to_file "H2    $*"
}

# ─── prompts ────────────────────────────────────────────────────────────────
# confirm <question> [default=N]  →  returns 0 for yes, 1 for no
confirm() {
  local question="$1"
  local default="${2:-N}"
  local hint reply

  if [[ "$default" == "Y" ]]; then hint="[Y/n]"; else hint="[y/N]"; fi

  # non-interactive: use default
  if [[ ! -t 0 ]] || [[ -n "${ASSUME_YES:-}" ]]; then
    [[ "$default" == "Y" ]] || [[ -n "${ASSUME_YES:-}" ]] && return 0 || return 1
  fi

  read -r -p "  ${question} ${hint}: " reply
  reply="${reply:-$default}"
  [[ "${reply,,}" == "y" || "${reply,,}" == "yes" ]]
}

# ask <question> [default=""]  → prints answer to stdout
ask() {
  local question="$1"
  local default="${2:-}"
  local reply

  if [[ ! -t 0 ]]; then
    printf '%s' "$default"
    return 0
  fi

  if [[ -n "$default" ]]; then
    read -r -p "  ${question} [${default}]: " reply
  else
    read -r -p "  ${question}: " reply
  fi
  printf '%s' "${reply:-$default}"
}

# ─── system detection ───────────────────────────────────────────────────────
detect_os() {
  case "$(uname -s)" in
    Darwin) echo "macos" ;;
    Linux)  echo "linux" ;;
    MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
    *) echo "unknown" ;;
  esac
}

detect_arch() {
  local m
  m="$(uname -m)"
  case "$m" in
    arm64|aarch64) echo "arm64" ;;
    x86_64|amd64)  echo "x64" ;;
    *) echo "$m" ;;
  esac
}

# macOS binary directory name for Unity MCP servers
mcp_binary_dir() {
  local os arch
  os="$(detect_os)"
  arch="$(detect_arch)"
  case "$os-$arch" in
    macos-arm64) echo "osx-arm64" ;;
    macos-x64)   echo "osx-x64" ;;
    linux-x64)   echo "linux-x64" ;;
    linux-arm64) echo "linux-arm64" ;;
    windows-x64) echo "win-x64" ;;
    *) return 1 ;;
  esac
}

# ─── dependency checks ──────────────────────────────────────────────────────
has_command() { command -v "$1" >/dev/null 2>&1; }

# version_ge <version> <minimum> → 0 if version >= minimum
# handles semver-ish: 18.17.1 >= 18.0.0
version_ge() {
  local current="$1" min="$2"
  [[ "$(printf '%s\n%s\n' "$min" "$current" | sort -V | head -1)" == "$min" ]]
}

node_version() {
  if has_command node; then
    node --version 2>/dev/null | sed 's/^v//'
  else
    return 1
  fi
}

# ─── file helpers ───────────────────────────────────────────────────────────
backup_file() {
  local file="$1"
  if [[ -f "$file" ]]; then
    local backup
    backup="${file}.bak.$(date +%Y%m%d_%H%M%S)"
    cp "$file" "$backup" || return 1
    printf '%s' "$backup"
  fi
}

# write_file_safe <path> <content> [mode=644]
# Fails if parent dir doesn't exist unless we can create it
write_file_safe() {
  local path="$1"
  local content="$2"
  local mode="${3:-644}"

  local dir
  dir="$(dirname "$path")"
  mkdir -p "$dir" || return 1

  printf '%s' "$content" > "$path" || return 1
  chmod "$mode" "$path" 2>/dev/null || true
}

# ─── path helpers ───────────────────────────────────────────────────────────
expand_path() {
  local path="$1"
  # Expand ~ to $HOME
  path="${path/#\~/$HOME}"
  # Resolve relative paths relative to pwd
  if [[ "$path" != /* ]]; then
    path="$PWD/$path"
  fi
  printf '%s' "$path"
}

# Find Claude Code executable across common install locations.
# Echoes path on success, returns 1 if not found.
find_claude_executable() {
  local candidates=(
    "$(command -v claude 2>/dev/null || true)"
    "$HOME/.nvm/versions/node/$(node --version 2>/dev/null)/bin/claude"
    "/opt/homebrew/bin/claude"
    "/usr/local/bin/claude"
    "$HOME/.local/bin/claude"
  )

  local c
  for c in "${candidates[@]}"; do
    if [[ -n "$c" && -x "$c" ]]; then
      printf '%s' "$c"
      return 0
    fi
  done
  return 1
}

# ─── json helpers (portable, no jq required) ────────────────────────────────
# We generate JSON by templating. For reading existing JSON, we require jq.
# If jq is missing, we fall back to regex-y heuristics (best-effort).
has_jq() { has_command jq; }

# ─── error trapping ─────────────────────────────────────────────────────────
# The installer uses explicit error handling. This is a helper for
# scripts that want a last-resort trap.
install_error_trap() {
  # shellcheck disable=SC2154  # rc is assigned inside the single-quoted trap
  trap 'rc=$?; log_err "Unexpected failure on line ${LINENO} (exit ${rc})"; exit "${rc}"' ERR
}
