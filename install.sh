#!/bin/bash
# install.sh — Install WLED Octolamp hooks globally for GitHub Copilot CLI
#
# Copies hook scripts to ~/.copilot/hooks/ (or $COPILOT_HOME/hooks/)
# and generates wled-hooks.json
# with absolute paths so hooks work from any directory.
#
# Usage: ./install.sh
#        WLED_INTERFACE="wlan1" ./install.sh   # enable dedicated adapter mode

set -euo pipefail

HOOKS_DIR="${COPILOT_HOME:-$HOME/.copilot}/hooks"
SCRIPT_DIR="$(cd "$(dirname "$0")/.github/hooks" && pwd)"

# Create target directory
mkdir -p "$HOOKS_DIR"
HOOKS_DIR="$(cd "$HOOKS_DIR" && pwd)"

# Copy scripts
cp "$SCRIPT_DIR/wled-status.sh" "$HOOKS_DIR/"
cp "$SCRIPT_DIR/wled-status.ps1" "$HOOKS_DIR/"
chmod +x "$HOOKS_DIR/wled-status.sh"
echo "✅ Copied scripts to $HOOKS_DIR"

json_escape() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//$'\b'/\\b}"
    value="${value//$'\f'/\\f}"
    value="${value//$'\n'/\\n}"
    value="${value//$'\r'/\\r}"
    value="${value//$'\t'/\\t}"
    printf '%s' "$value"
}

# Quote shell paths before escaping them for JSON.
printf -v SH_PATH '%q' "$HOOKS_DIR/wled-status.sh"
SH_PATH="$(json_escape "$SH_PATH")"
PS1_PATH="$HOOKS_DIR/wled-status.ps1"
PS1_PATH="$(json_escape "${PS1_PATH//\'/\'\'}")"

HOOK_ENV=""
for name in WLED_HOST WLED_BRIGHTNESS WLED_INTERFACE WLED_SSID; do
    value="${!name:-}"
    if [ -n "$value" ]; then
        if [ -n "$HOOK_ENV" ]; then HOOK_ENV+=", "; fi
        HOOK_ENV+="\"$name\": \"$(json_escape "$value")\""
    fi
done

cat > "$HOOKS_DIR/wled-hooks.json" << EOF
{
  "version": 1,
  "hooks": {
    "userPromptSubmitted": [
      {
        "type": "command",
        "bash": "$SH_PATH busy",
        "powershell": "& '$PS1_PATH' -Status 'busy'",
        "cwd": ".",
        "env": {$HOOK_ENV},
        "timeoutSec": 15
      }
    ],
    "Stop": [
      {
        "type": "command",
        "bash": "$SH_PATH done",
        "powershell": "& '$PS1_PATH' -Status 'done'",
        "cwd": ".",
        "env": {$HOOK_ENV},
        "timeoutSec": 15
      }
    ],
    "sessionEnd": [
      {
        "type": "command",
        "bash": "$SH_PATH done",
        "powershell": "& '$PS1_PATH' -Status 'done'",
        "cwd": ".",
        "env": {$HOOK_ENV},
        "timeoutSec": 15
      }
    ],
    "errorOccurred": [
      {
        "type": "command",
        "bash": "$SH_PATH error",
        "powershell": "& '$PS1_PATH' -Status 'error'",
        "cwd": ".",
        "env": {$HOOK_ENV},
        "timeoutSec": 15
      }
    ]
  }
}
EOF

echo "✅ Generated $HOOKS_DIR/wled-hooks.json"

if [ -n "${WLED_INTERFACE:-}" ]; then
    echo ""
    echo "🔌 Dedicated adapter saved in hooks: $WLED_INTERFACE"
fi

echo ""
echo "✅ Installation complete! Restart Copilot CLI to activate hooks."
echo "   Hooks installed to: $HOOKS_DIR"
