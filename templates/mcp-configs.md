# MCP JSON 설정 템플릿

설치 후 경로를 실제 값으로 교체하세요.
`which claude` 로 Claude Code 경로를 확인하세요.

---

## Claude Code — CoplayDev만

`~/.claude/claude_desktop_config.json`

```json
{
  "mcpServers": {
    "unity-coplay": {
      "command": "node",
      "args": ["~/.unity-mcp/coplaydev/server/build/index.js"]
    }
  }
}
```

---

## Claude Code — IvanMurzak만

```json
{
  "mcpServers": {
    "unity-ivanmurzak": {
      "command": "/YOUR/PROJECT/Library/mcp-server/osx-arm64/unity-mcp-server",
      "args": [
        "--port=8080",
        "--plugin-timeout=10000",
        "--client-transport=stdio"
      ]
    }
  }
}
```

---

## Claude Code — 둘 다 (멀티 클라이언트)

```json
{
  "mcpServers": {
    "unity-coplay": {
      "command": "node",
      "args": ["~/.unity-mcp/coplaydev/server/build/index.js"]
    },
    "unity-ivanmurzak": {
      "command": "/YOUR/PROJECT/Library/mcp-server/osx-arm64/unity-mcp-server",
      "args": [
        "--port=8080",
        "--plugin-timeout=10000",
        "--client-transport=stdio"
      ]
    }
  }
}
```

---

## Cursor — 프로젝트 로컬

`.cursor/mcp.json` (프로젝트 루트에 위치)

```json
{
  "mcpServers": {
    "unity-coplay": {
      "command": "node",
      "args": ["~/.unity-mcp/coplaydev/server/build/index.js"]
    }
  }
}
```

---

## 아키텍처 주의

- `osx-arm64`: Apple Silicon (M1/M2/M3/M4)
- `osx-x64`: Intel Mac
- `uname -m` 으로 확인 (arm64 = Apple Silicon)
