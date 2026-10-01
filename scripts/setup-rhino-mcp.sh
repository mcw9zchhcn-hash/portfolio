#!/usr/bin/env bash
# One-shot setup for driving Rhino 8/9 from Claude on macOS.
#
# Installs:  uv (launches the server), the rhinomcp Rhino plugin (via yak),
#            and the "rhino" MCP server entry for Claude Code and Claude Desktop.
# Safe to re-run. Existing Claude Desktop config is backed up before editing.

set -euo pipefail
say() { printf '\n==> %s\n' "$*"; }

# 1. uv, which runs "uvx rhinomcp@latest"
if command -v uv >/dev/null 2>&1; then
  say "uv already installed"
elif command -v brew >/dev/null 2>&1; then
  say "Installing uv with Homebrew"
  brew install uv
else
  say "Installing uv with the official installer"
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
fi

# 2. rhinomcp plugin inside Rhino, using Rhino's bundled yak CLI
YAK=""
for v in 8 9; do
  candidate="/Applications/Rhino $v.app/Contents/Resources/bin/yak"
  if [ -x "$candidate" ]; then YAK="$candidate"; break; fi
done
if [ -n "$YAK" ]; then
  say "Installing the rhinomcp plugin into Rhino"
  "$YAK" install rhinomcp || echo "yak install failed. In Rhino: Tools > Package Manager, search rhinomcp, Install."
else
  say "Rhino 8/9 not found in /Applications. In Rhino: Tools > Package Manager, search rhinomcp, Install."
fi

# 3. Claude Code: user-scoped server, available in every folder
if command -v claude >/dev/null 2>&1; then
  say "Registering the rhino MCP server with Claude Code"
  claude mcp remove rhino --scope user >/dev/null 2>&1 || true
  claude mcp add --scope user rhino -e RHINO_MCP_HOST=127.0.0.1 -- uvx rhinomcp@latest
else
  say "Claude Code CLI not on PATH; skipped. Install with: npm install -g @anthropic-ai/claude-code"
fi

# 4. Claude Desktop chat: merge into claude_desktop_config.json, keep other servers
CFG="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
if [ -d "$(dirname "$CFG")" ]; then
  say "Adding rhino to Claude Desktop config"
  [ -f "$CFG" ] && cp "$CFG" "$CFG.bak"
  python3 - "$CFG" <<'PY'
import json, os, sys
path = sys.argv[1]
cfg = {}
if os.path.exists(path):
    try:
        with open(path) as f:
            cfg = json.load(f)
    except Exception:
        cfg = {}
cfg.setdefault("mcpServers", {})["rhino"] = {
    "command": "uvx",
    "args": ["rhinomcp@latest"],
    "env": {"RHINO_MCP_HOST": "127.0.0.1"},
}
with open(path, "w") as f:
    json.dump(cfg, f, indent=2)
print("wrote", path)
PY
fi

say "Done. Restart Rhino, type  mcpstart  in its command line, then start Claude Code"
say "(or 'claude remote-control' to see it in the app) and ask it to list the objects in Rhino."
