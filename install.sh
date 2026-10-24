#!/bin/bash
# install.sh — Install WLED Octolamp hooks globally for GitHub Copilot CLI
#
# Copies hook scripts to ~/.github/hooks/ and generates wled-hooks.json
# with absolute paths so hooks work from any directory.
#
# Usage: ./install.sh
#        WLED_INTERFACE="wlan1" ./install.sh   # enable dedicated adapter mode

set -euo pipefail

HOOKS_DIR="$HOME/.github/hooks"
SCRIPT_DIR="$(cd "$(dirname "$0")/.github/hooks" && pwd)"

# Create target directory
mkdir -p "$HOOKS_DIR"

# Copy scripts
cp "$SCRIPT_DIR/wled-status.sh" "$HOOKS_DIR/"
cp "$SCRIPT_DIR/wled-status.ps1" "$HOOKS_DIR/"
chmod +x "$HOOKS_DIR/wled-status.sh"
echo "✅ Copied scripts to $HOOKS_DIR"

# Generate hooks JSON with absolute paths
SH_PATH="$HOOKS_DIR/wled-status.sh"
PS1_PATH="$HOOKS_DIR/wled-status.ps1"

cat > "$HOOKS_DIR/wled-hooks.json" << EOF
{
  "version": 1,
  "hooks": {
    "sessionStart": [
      {
        "type": "command",
        "bash": "$SH_PATH done",
        "powershell": "& '$PS1_PATH' -Status 'done'",
        "cwd": ".",
        "timeoutSec": 15
      }
    ],
    "userPromptSubmitted": [
      {
        "type": "command",
        "bash": "$SH_PATH busy",
        "powershell": "& '$PS1_PATH' -Status 'busy'",
        "cwd": ".",
        "timeoutSec": 15
      }
    ],
    "Stop": [
      {
        "type": "command",
        "bash": "$SH_PATH done",
        "powershell": "& '$PS1_PATH' -Status 'done'",
        "cwd": ".",
        "timeoutSec": 15
      }
    ],
    "sessionEnd": [
      {
        "type": "command",
        "bash": "$SH_PATH done",
        "powershell": "& '$PS1_PATH' -Status 'done'",
        "cwd": ".",
        "timeoutSec": 15
      }
    ],
    "errorOccurred": [
      {
        "type": "command",
        "bash": "$SH_PATH error",
        "powershell": "& '$PS1_PATH' -Status 'error'",
        "cwd": ".",
        "timeoutSec": 15
      }
    ]
  }
}
EOF

echo "✅ Generated $HOOKS_DIR/wled-hooks.json"

if [ -n "${WLED_INTERFACE:-}" ]; then
    echo ""
    echo "🔌 Dedicated adapter mode: add these to your shell profile:"
    echo "   export WLED_INTERFACE=\"$WLED_INTERFACE\""
    echo "   export WLED_SSID=\"WLED-AP\""
    echo "   export WLED_HOST=\"4.3.2.1\""
fi

echo ""
echo "✅ Installation complete! Restart Copilot CLI to activate hooks."
echo "   Hooks installed to: $HOOKS_DIR"
