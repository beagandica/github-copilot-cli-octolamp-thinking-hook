#!/bin/bash
# mode.sh — Choose which assistant drives the Octolamp.
#
# Usage: ./mode.sh copilot   # only GitHub Copilot CLI hooks change the lamp
#        ./mode.sh claude    # only Claude Code hooks change the lamp
#        ./mode.sh both      # either one can (default when no mode is set)
#        ./mode.sh off       # neither; the lamp keeps whatever it shows
#        ./mode.sh           # show the current mode
#
# Takes effect on the next hook; no restart needed. The mode is stored in
# ${XDG_CONFIG_HOME:-~/.config}/octolamp/mode (override with OCTOLAMP_MODE_FILE).

set -euo pipefail

MODE_FILE="${OCTOLAMP_MODE_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/octolamp/mode}"

case "${1:-}" in
  copilot|claude|both|off)
    mkdir -p "$(dirname "$MODE_FILE")"
    printf '%s\n' "$1" > "$MODE_FILE"
    echo "🐙 Octolamp mode: $1"
    ;;
  "")
    if [ -r "$MODE_FILE" ]; then
      echo "🐙 Octolamp mode: $(tr -d '[:space:]' < "$MODE_FILE")"
    else
      echo "🐙 Octolamp mode: both (default; no mode set)"
    fi
    ;;
  *)
    echo "Usage: $0 [copilot|claude|both|off]" >&2
    exit 1
    ;;
esac
