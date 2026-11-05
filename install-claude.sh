#!/bin/bash
# install-claude.sh — Install WLED Octolamp hooks globally for Claude Code
#
# Copies wled-status.sh to ~/.claude/hooks/octolamp/ (or $CLAUDE_CONFIG_DIR)
# and merges hook entries into ~/.claude/settings.json. Re-running replaces
# the previous Octolamp entries and leaves your other settings and hooks alone.
# A backup of settings.json is written next to it first.
#
# Hooks run in the Claude Code CLI and the VS Code / JetBrains extensions.
#
# Usage: WLED_HOST="192.168.1.42" ./install-claude.sh
# Requires: python3 (to edit settings.json safely)

set -euo pipefail

CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
HOOKS_DIR="$CLAUDE_DIR/hooks/octolamp"
SETTINGS="$CLAUDE_DIR/settings.json"
SCRIPT_DIR="$(cd "$(dirname "$0")/.github/hooks" && pwd)"

if ! command -v python3 >/dev/null 2>&1; then
    echo "❌ python3 is required to update $SETTINGS" >&2
    exit 1
fi

mkdir -p "$HOOKS_DIR"
HOOKS_DIR="$(cd "$HOOKS_DIR" && pwd)"
cp "$SCRIPT_DIR/wled-status.sh" "$HOOKS_DIR/"
chmod +x "$HOOKS_DIR/wled-status.sh"
echo "✅ Copied wled-status.sh to $HOOKS_DIR"

# Build the command prefix: WLED_SOURCE=claude plus any WLED_* settings set now.
PREFIX="WLED_SOURCE=claude"
for name in WLED_HOST WLED_BRIGHTNESS WLED_INTERFACE WLED_SSID WLED_DEBUG_LOG; do
    value="${!name:-}"
    if [ -n "$value" ]; then
        printf -v quoted '%q' "$value"
        PREFIX+=" $name=$quoted"
    fi
done
printf -v SH_PATH '%q' "$HOOKS_DIR/wled-status.sh"

if [ -f "$SETTINGS" ]; then
    cp "$SETTINGS" "$SETTINGS.octolamp-backup"
    echo "✅ Backed up settings to $SETTINGS.octolamp-backup"
fi

OCTOLAMP_PREFIX="$PREFIX" OCTOLAMP_SCRIPT="$SH_PATH" python3 -I - "$SETTINGS" <<'PY'
import json, os, sys

path = sys.argv[1]
prefix = os.environ["OCTOLAMP_PREFIX"]
script = os.environ["OCTOLAMP_SCRIPT"]

settings = {}
if os.path.exists(path):
    with open(path) as f:
        text = f.read().strip()
    if text:
        settings = json.loads(text)

hooks = settings.setdefault("hooks", {})

def is_octolamp(group):
    return any("wled-status.sh" in h.get("command", "") for h in group.get("hooks", []))

# Drop Octolamp entries from a previous install; keep everything else.
for event in list(hooks):
    hooks[event] = [g for g in hooks[event] if not is_octolamp(g)]
    if not hooks[event]:
        del hooks[event]

def add(event, status, matcher=None):
    group = {"hooks": [{"type": "command", "command": f"{prefix} {script} {status}", "timeout": 15}]}
    if matcher:
        group = {"matcher": matcher, **group}
    hooks.setdefault(event, []).append(group)

add("UserPromptSubmit", "busy")
add("PostToolUse", "recover", "Bash|PowerShell")       # command succeeded
add("PostToolUseFailure", "error", "Bash|PowerShell")  # command failed / exited non-zero
add("Stop", "done")
add("SessionEnd", "reset")

os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "w") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")
PY

echo "✅ Added Octolamp hooks to $SETTINGS"
echo ""
echo "✅ Installation complete! Start a new Claude Code session to activate hooks."
echo "   Choose which assistant drives the lamp with: ./mode.sh claude"
