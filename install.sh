#!/bin/bash
# ============================================================
#  Unity MCP Local Installer
#  macOS · Claude Code + CoplayDev/unity-mcp + IvanMurzak/Unity-MCP
#  Usage: bash install.sh [--unity-project /path/to/project]
# ============================================================
set -euo pipefail

# ── 색상 ────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

ok()   { echo -e "${GREEN}  ✔ $1${RESET}"; }
info() { echo -e "${CYAN}  → $1${RESET}"; }
warn() { echo -e "${YELLOW}  ⚠ $1${RESET}"; }
err()  { echo -e "${RED}  ✘ $1${RESET}"; }
h1()   { echo -e "\n${BOLD}${CYAN}━━━ $1 ━━━${RESET}"; }
h2()   { echo -e "\n${BOLD}$1${RESET}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UNITY_PROJECT=""
INSTALL_COPLAY=true
INSTALL_IVAN=true
SKIP_HOMEBREW=false
DRY_RUN=false

# ── 인자 파싱 ────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --unity-project) UNITY_PROJECT="$2"; shift 2 ;;
    --coplay-only)   INSTALL_IVAN=false; shift ;;
    --ivan-only)     INSTALL_COPLAY=false; shift ;;
    --skip-homebrew) SKIP_HOMEBREW=true; shift ;;
    --dry-run)       DRY_RUN=true; shift ;;
    *) shift ;;
  esac
done

# ── 배너 ────────────────────────────────────────────────────
echo -e "${CYAN}"
cat << 'EOF'
  ██╗   ██╗███╗   ██╗██╗████████╗██╗   ██╗    ███╗   ███╗ ██████╗██████╗
  ██║   ██║████╗  ██║██║╚══██╔══╝╚██╗ ██╔╝    ████╗ ████║██╔════╝██╔══██╗
  ██║   ██║██╔██╗ ██║██║   ██║    ╚████╔╝     ██╔████╔██║██║     ██████╔╝
  ██║   ██║██║╚██╗██║██║   ██║     ╚██╔╝      ██║╚██╔╝██║██║     ██╔═══╝
  ╚██████╔╝██║ ╚████║██║   ██║      ██║       ██║ ╚═╝ ██║╚██████╗██║
   ╚═════╝ ╚═╝  ╚═══╝╚═╝   ╚═╝      ╚═╝       ╚═╝     ╚═╝ ╚═════╝╚═╝
EOF
echo -e "${RESET}"
echo -e "${BOLD}  Unity MCP Local Installer  |  macOS  |  Claude Code + Cursor${RESET}"
echo -e "  ─────────────────────────────────────────────────────────────\n"

[[ "$DRY_RUN" == true ]] && warn "DRY RUN 모드 — 실제 설치 없이 확인만 합니다"

# ─────────────────────────────────────────────────────────────
h1 "1. 시스템 진단"
# ─────────────────────────────────────────────────────────────

ERRORS=()

# macOS 확인
if [[ "$(uname)" != "Darwin" ]]; then
  err "이 스크립트는 macOS 전용입니다."; exit 1
fi
ok "macOS $(sw_vers -productVersion)"

# CPU 아키텍처
ARCH=$(uname -m)
if [[ "$ARCH" == "arm64" ]]; then
  ok "Apple Silicon (arm64)"
  BINARY_ARCH="osx-arm64"
else
  ok "Intel (x86_64)"
  BINARY_ARCH="osx-x64"
fi

# Homebrew
if command -v brew &>/dev/null; then
  ok "Homebrew $(brew --version | head -1)"
elif [[ "$SKIP_HOMEBREW" == false ]]; then
  warn "Homebrew 없음 — 자동 설치합니다"
  if [[ "$DRY_RUN" == false ]]; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || true
    eval "$(/usr/local/bin/brew shellenv)" 2>/dev/null || true
  fi
fi

# nvm / Node.js
NODE_OK=false
if command -v node &>/dev/null; then
  NODE_VER=$(node --version | sed 's/v//')
  NODE_MAJOR=$(echo "$NODE_VER" | cut -d. -f1)
  if [[ $NODE_MAJOR -ge 18 ]]; then
    ok "Node.js v$NODE_VER"
    NODE_OK=true
  else
    warn "Node.js v$NODE_VER — v18+ 필요"
  fi
fi

if [[ "$NODE_OK" == false ]]; then
  info "nvm + Node.js v21 설치 중..."
  if [[ "$DRY_RUN" == false ]]; then
    # nvm 설치
    if ! command -v nvm &>/dev/null && [[ ! -d "$HOME/.nvm" ]]; then
      curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    fi
    export NVM_DIR="$HOME/.nvm"
    # shellcheck disable=SC1091
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    nvm install 21
    nvm use 21
    nvm alias default 21
    ok "Node.js $(node --version) 설치 완료"
  else
    info "[DRY] nvm install 21 && nvm alias default 21"
  fi
fi

# npm
if command -v npm &>/dev/null; then
  ok "npm $(npm --version)"
else
  ERRORS+=("npm을 찾을 수 없습니다")
fi

# Claude Code
CLAUDE_PATH=""
for p in \
  "$HOME/.nvm/versions/node/$(node --version 2>/dev/null)/bin/claude" \
  "/opt/homebrew/bin/claude" \
  "/usr/local/bin/claude" \
  "$(which claude 2>/dev/null || true)"; do
  if [[ -x "$p" ]]; then
    CLAUDE_PATH="$p"
    break
  fi
done

if [[ -n "$CLAUDE_PATH" ]]; then
  ok "Claude Code: $CLAUDE_PATH"
else
  info "Claude Code 설치 중..."
  if [[ "$DRY_RUN" == false ]]; then
    npm install -g @anthropic-ai/claude-code
    CLAUDE_PATH=$(which claude)
    ok "Claude Code 설치 완료: $CLAUDE_PATH"
  else
    info "[DRY] npm install -g @anthropic-ai/claude-code"
    CLAUDE_PATH="(설치 후 확인)"
  fi
fi

# git
if command -v git &>/dev/null; then
  ok "git $(git --version | awk '{print $3}')"
else
  warn "git 없음 — brew install git"
  [[ "$DRY_RUN" == false ]] && brew install git
fi

# 에러 있으면 중단
if [[ ${#ERRORS[@]} -gt 0 ]]; then
  echo ""
  for e in "${ERRORS[@]}"; do err "$e"; done
  exit 1
fi

# ─────────────────────────────────────────────────────────────
h1 "2. Unity 프로젝트 경로 설정"
# ─────────────────────────────────────────────────────────────

if [[ -z "$UNITY_PROJECT" ]]; then
  echo -e "  Unity 프로젝트 절대 경로를 입력하세요 (엔터로 건너뛰기):"
  read -r -p "  > " INPUT_PATH
  UNITY_PROJECT="${INPUT_PATH:-}"
fi

if [[ -n "$UNITY_PROJECT" ]]; then
  UNITY_PROJECT="${UNITY_PROJECT/#\~/$HOME}"   # ~ 확장
  if [[ -d "$UNITY_PROJECT/Assets" ]]; then
    ok "Unity 프로젝트 확인: $UNITY_PROJECT"
  else
    warn "Assets 폴더를 찾을 수 없음. 경로를 다시 확인하세요: $UNITY_PROJECT"
    UNITY_PROJECT=""
  fi
else
  warn "프로젝트 경로 없이 진행 — MCP JSON 설정은 수동으로 하세요"
fi

# ─────────────────────────────────────────────────────────────
h1 "3. MCP 설치"
# ─────────────────────────────────────────────────────────────

h2 "  방법 선택:"
echo "  [A] CoplayDev/unity-mcp  — 씬 조작·프로파일러·물리 (기능 최다)"
echo "  [B] IvanMurzak/Unity-MCP — Roslyn 즉시 컴파일·Runtime AI"
echo "  [C] 둘 다 설치            — 멀티 클라이언트 (권장)"
echo ""
read -r -p "  선택 [A/B/C, 기본 C]: " METHOD
METHOD="${METHOD:-C}"
METHOD="${METHOD^^}"

case "$METHOD" in
  A) INSTALL_IVAN=false ;;
  B) INSTALL_COPLAY=false ;;
  C) ;;
  *) warn "잘못된 입력. 기본값 C(둘 다) 사용"; METHOD="C" ;;
esac

# ── CoplayDev ────────────────────────────────────────────────
if [[ "$INSTALL_COPLAY" == true ]]; then
  h2 "  ▸ CoplayDev/unity-mcp 설치"

  COPLAY_DIR="$HOME/.unity-mcp/coplaydev"

  if [[ "$DRY_RUN" == false ]]; then
    if [[ -d "$COPLAY_DIR/.git" ]]; then
      info "이미 존재 — git pull 업데이트 중..."
      git -C "$COPLAY_DIR" pull --ff-only || warn "업데이트 실패 (로컬 변경사항 확인)"
    else
      info "클론 중... $COPLAY_DIR"
      git clone https://github.com/CoplayDev/unity-mcp.git "$COPLAY_DIR"
    fi

    info "npm 의존성 설치 중..."
    (cd "$COPLAY_DIR/server" && npm install && npm run build) \
      || { err "CoplayDev 빌드 실패"; exit 1; }

    COPLAY_SERVER="$COPLAY_DIR/server/build/index.js"
    ok "CoplayDev 설치 완료: $COPLAY_SERVER"
  else
    info "[DRY] git clone https://github.com/CoplayDev/unity-mcp.git $COPLAY_DIR"
    COPLAY_SERVER="$HOME/.unity-mcp/coplaydev/server/build/index.js"
  fi

  # Unity 패키지 안내
  echo ""
  info "Unity 패키지를 수동으로 추가하세요:"
  echo -e "    ${BOLD}Window > Package Manager > + > Add package from git URL${RESET}"
  echo -e "    ${CYAN}https://github.com/CoplayDev/unity-mcp.git${RESET}"
  echo -e "    ${CYAN}com.unity.nuget.newtonsoft-json${RESET} (의존성)"
fi

# ── IvanMurzak ───────────────────────────────────────────────
if [[ "$INSTALL_IVAN" == true ]]; then
  h2 "  ▸ IvanMurzak/Unity-MCP 설치"

  if [[ "$DRY_RUN" == false ]]; then
    info "unity-mcp-cli 전역 설치 중..."
    npm install -g unity-mcp-cli
    ok "unity-mcp-cli 설치 완료"

    if [[ -n "$UNITY_PROJECT" ]]; then
      info "Unity 프로젝트에 플러그인 설치 중: $UNITY_PROJECT"
      unity-mcp-cli install-plugin "$UNITY_PROJECT" \
        && ok "플러그인 설치 완료" \
        || warn "설치 실패 — Unity Editor에서 수동 설치 필요"

      info "Claude Code 스킬 설정 중..."
      unity-mcp-cli setup-skills claude-code "$UNITY_PROJECT" \
        && ok "Skills 설정 완료" \
        || warn "Skills 설정 실패 — Unity Editor에서 수동 실행 필요"
    else
      warn "프로젝트 경로 없음 — 나중에 수동으로 실행:"
      echo -e "    ${CYAN}unity-mcp-cli install-plugin /your/project${RESET}"
      echo -e "    ${CYAN}unity-mcp-cli setup-skills claude-code /your/project${RESET}"
    fi
  else
    info "[DRY] npm install -g unity-mcp-cli"
    [[ -n "$UNITY_PROJECT" ]] && info "[DRY] unity-mcp-cli install-plugin + setup-skills"
  fi
fi

# ─────────────────────────────────────────────────────────────
h1 "4. MCP JSON 설정 생성"
# ─────────────────────────────────────────────────────────────

CLAUDE_CONFIG_DIR="$HOME/.claude"
CLAUDE_CONFIG="$CLAUDE_CONFIG_DIR/claude_desktop_config.json"
MCP_BACKUP=""

[[ "$DRY_RUN" == false ]] && mkdir -p "$CLAUDE_CONFIG_DIR"

# 기존 설정 백업
if [[ -f "$CLAUDE_CONFIG" && "$DRY_RUN" == false ]]; then
  MCP_BACKUP="${CLAUDE_CONFIG}.bak.$(date +%Y%m%d_%H%M%S)"
  cp "$CLAUDE_CONFIG" "$MCP_BACKUP"
  warn "기존 설정 백업: $MCP_BACKUP"
fi

# JSON 조합
build_mcp_json() {
  local servers=""

  if [[ "$INSTALL_COPLAY" == true ]]; then
    servers+=$(cat << EOF

    "unity-coplay": {
      "command": "node",
      "args": ["${COPLAY_SERVER:-$HOME/.unity-mcp/coplaydev/server/build/index.js}"],
      "env": {}
    }
EOF
)
  fi

  if [[ "$INSTALL_COPLAY" == true && "$INSTALL_IVAN" == true ]]; then
    servers+=","
  fi

  if [[ "$INSTALL_IVAN" == true ]]; then
    local ivan_bin=""
    if [[ -n "$UNITY_PROJECT" ]]; then
      ivan_bin="$UNITY_PROJECT/Library/mcp-server/$BINARY_ARCH/unity-mcp-server"
    else
      ivan_bin="/YOUR/PROJECT/Library/mcp-server/$BINARY_ARCH/unity-mcp-server"
    fi

    servers+=$(cat << EOF

    "unity-ivanmurzak": {
      "command": "$ivan_bin",
      "args": [
        "--port=8080",
        "--plugin-timeout=10000",
        "--client-transport=stdio"
      ],
      "env": {}
    }
EOF
)
  fi

  cat << EOF
{
  "mcpServers": {${servers}
  }
}
EOF
}

MCP_JSON=$(build_mcp_json)

if [[ "$DRY_RUN" == false ]]; then
  echo "$MCP_JSON" > "$CLAUDE_CONFIG"
  ok "Claude Code MCP 설정 저장: $CLAUDE_CONFIG"
else
  info "[DRY] 생성될 $CLAUDE_CONFIG 내용:"
  echo "$MCP_JSON"
fi

# Cursor 설정
if [[ -n "$UNITY_PROJECT" ]]; then
  CURSOR_CONFIG="$UNITY_PROJECT/.cursor/mcp.json"
  CURSOR_GLOBAL="$HOME/.cursor/mcp.json"

  h2 "  ▸ Cursor MCP 설정 생성"

  CURSOR_JSON=$(cat << EOF
{
  "mcpServers": {
    "unity-coplay": {
      "command": "node",
      "args": ["${COPLAY_SERVER:-$HOME/.unity-mcp/coplaydev/server/build/index.js}"]
    }
  }
}
EOF
)

  if [[ "$DRY_RUN" == false ]]; then
    mkdir -p "$(dirname "$CURSOR_CONFIG")"
    echo "$CURSOR_JSON" > "$CURSOR_CONFIG"
    ok "Cursor 프로젝트 설정: $CURSOR_CONFIG"

    # 글로벌 Cursor 설정도 생성
    mkdir -p "$(dirname "$CURSOR_GLOBAL")"
    [[ ! -f "$CURSOR_GLOBAL" ]] && echo "$CURSOR_JSON" > "$CURSOR_GLOBAL" \
      && ok "Cursor 글로벌 설정: $CURSOR_GLOBAL"
  else
    info "[DRY] Cursor mcp.json 생성: $CURSOR_CONFIG"
  fi
fi

# ─────────────────────────────────────────────────────────────
h1 "5. CLAUDE.md 생성"
# ─────────────────────────────────────────────────────────────

if [[ -n "$UNITY_PROJECT" ]]; then
  CLAUDE_MD="$UNITY_PROJECT/CLAUDE.md"

  if [[ -f "$CLAUDE_MD" ]]; then
    warn "CLAUDE.md 이미 존재 — 건너뜁니다 ($CLAUDE_MD)"
  else
    if [[ "$DRY_RUN" == false ]]; then
      cp "$SCRIPT_DIR/templates/CLAUDE.md.template" "$CLAUDE_MD" \
        && ok "CLAUDE.md 생성: $CLAUDE_MD" \
        || warn "CLAUDE.md 템플릿 복사 실패 — 수동 생성 필요"
    else
      info "[DRY] CLAUDE.md 생성: $CLAUDE_MD"
    fi
  fi
fi

# ─────────────────────────────────────────────────────────────
h1 "6. 설치 검증"
# ─────────────────────────────────────────────────────────────

if [[ "$DRY_RUN" == false ]]; then
  # Node.js 재확인
  command -v node &>/dev/null && ok "node $(node --version)" || err "node 없음"
  command -v npm  &>/dev/null && ok "npm $(npm --version)"  || err "npm 없음"

  # Claude Code
  if [[ -n "$CLAUDE_PATH" && -x "$CLAUDE_PATH" ]]; then
    ok "claude: $CLAUDE_PATH"
  else
    CLAUDE_PATH=$(which claude 2>/dev/null || true)
    [[ -n "$CLAUDE_PATH" ]] && ok "claude: $CLAUDE_PATH" || err "claude 명령어 없음"
  fi

  # CoplayDev 서버 파일
  if [[ "$INSTALL_COPLAY" == true ]]; then
    [[ -f "${COPLAY_SERVER:-}" ]] \
      && ok "CoplayDev 서버: $COPLAY_SERVER" \
      || err "CoplayDev 서버 파일 없음: ${COPLAY_SERVER:-?}"
  fi

  # unity-mcp-cli
  if [[ "$INSTALL_IVAN" == true ]]; then
    command -v unity-mcp-cli &>/dev/null \
      && ok "unity-mcp-cli $(unity-mcp-cli --version 2>/dev/null || echo '설치됨')" \
      || err "unity-mcp-cli 없음"
  fi

  # MCP config
  [[ -f "$CLAUDE_CONFIG" ]] && ok "MCP 설정: $CLAUDE_CONFIG" || err "MCP 설정 파일 없음"
fi

# ─────────────────────────────────────────────────────────────
h1 "7. 다음 단계"
# ─────────────────────────────────────────────────────────────

echo ""
echo -e "  ${BOLD}Unity Editor 설정 (수동 필요):${RESET}"
echo ""

if [[ "$INSTALL_COPLAY" == true ]]; then
  echo -e "  ${CYAN}[CoplayDev]${RESET}"
  echo "  1. Window > Package Manager > + > Add package from git URL"
  echo "     https://github.com/CoplayDev/unity-mcp.git"
  echo "  2. com.unity.nuget.newtonsoft-json 추가"
  echo "  3. Window > MCP Unity > Server Window > Start Server"
  if [[ -n "$CLAUDE_PATH" ]]; then
    echo "  4. Choose Claude Install Location: $CLAUDE_PATH"
  fi
  echo ""
fi

if [[ "$INSTALL_IVAN" == true ]]; then
  echo -e "  ${CYAN}[IvanMurzak]${RESET}"
  echo "  1. Window > AI Game Developer (Unity-MCP)"
  echo "  2. Claude Code 선택 > Generate Skills 클릭"
  echo ""
fi

echo -e "  ${BOLD}Claude Code 실행:${RESET}"
if [[ -n "$UNITY_PROJECT" ]]; then
  echo "  cd $UNITY_PROJECT"
else
  echo "  cd /your/unity/project"
fi
echo "  claude"
echo ""
echo -e "  ${BOLD}테스트 프롬프트:${RESET}"
echo '  "빨강, 파랑, 노랑 큐브 3개를 씬에 2m 간격으로 생성해줘"'
echo ""

if [[ -n "$MCP_BACKUP" ]]; then
  warn "이전 MCP 설정 백업 위치: $MCP_BACKUP"
fi

echo ""
echo -e "${GREEN}${BOLD}  ✔ 설치 완료!${RESET}"
echo ""
