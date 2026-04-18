#!/bin/bash
# Unity MCP Uninstaller
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

ok()   { echo -e "${GREEN}  ✔ $1${RESET}"; }
info() { echo -e "${CYAN}  → $1${RESET}"; }
warn() { echo -e "${YELLOW}  ⚠ $1${RESET}"; }

echo -e "\n${BOLD}${RED}  Unity MCP Uninstaller${RESET}\n"
warn "이 스크립트는 MCP 설정과 서버 파일을 제거합니다."
echo ""
read -r -p "  계속하시겠습니까? [y/N]: " CONFIRM
[[ "${CONFIRM,,}" != "y" ]] && echo "  취소됨." && exit 0

# Claude MCP 설정 제거
CLAUDE_CONFIG="$HOME/.claude/claude_desktop_config.json"
if [[ -f "$CLAUDE_CONFIG" ]]; then
  BACKUP="${CLAUDE_CONFIG}.uninstall.bak.$(date +%Y%m%d_%H%M%S)"
  cp "$CLAUDE_CONFIG" "$BACKUP"
  echo "{}" > "$CLAUDE_CONFIG"
  ok "Claude MCP 설정 초기화 (백업: $BACKUP)"
fi

# CoplayDev 서버 제거
COPLAY_DIR="$HOME/.unity-mcp/coplaydev"
if [[ -d "$COPLAY_DIR" ]]; then
  read -r -p "  CoplayDev 서버 폴더 삭제? $COPLAY_DIR [y/N]: " DEL
  if [[ "${DEL,,}" == "y" ]]; then
    rm -rf "$COPLAY_DIR"
    ok "CoplayDev 삭제 완료"
  fi
fi

# unity-mcp-cli 제거
if command -v unity-mcp-cli &>/dev/null; then
  read -r -p "  unity-mcp-cli 제거? [y/N]: " DEL
  [[ "${DEL,,}" == "y" ]] && npm uninstall -g unity-mcp-cli && ok "unity-mcp-cli 제거"
fi

echo ""
info "Unity 패키지(Package Manager에서 추가한 것)는 Unity Editor에서 직접 제거하세요."
echo -e "\n${GREEN}${BOLD}  완료${RESET}\n"
