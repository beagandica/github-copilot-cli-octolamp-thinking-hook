#!/bin/bash
# WLED Octolamp status light controller for GitHub Copilot CLI hooks
#
# Sends a color/effect command to a WLED device over HTTP. Designed to run
# as a Copilot CLI hook so your Octolamp reflects what Copilot is doing.
#
# Dedicated-adapter mode (optional):
#   Set WLED_INTERFACE to bind traffic to a specific NIC (e.g. a USB WiFi
#   adapter connected to the WLED access point). When set, the script also
#   performs best-effort route hygiene to prevent traffic hijacking.
#
# Usage: ./wled-status.sh busy    → rotating rainbow (thinking); clears error
#        ./wled-status.sh error   → blinking red (tool failed / error); sticky
#        ./wled-status.sh tool    → postToolUse for shell commands: red if the
#                                   command exited non-zero, else back to
#                                   rainbow (only if red is showing)
#        ./wled-status.sh done    → solid white (idle), unless red is showing
#        ./wled-status.sh reset   → solid white (session ended); clears error
#
# "Sticky" red: an error leaves a marker file so the Stop hook keeps the lamp
# red instead of turning it white while something still needs fixing.

STATUS="${1:-done}"
WLED_HOST="${WLED_HOST:-4.3.2.1}"
BRIGHTNESS="${WLED_BRIGHTNESS:-128}"
WLED_INTERFACE="${WLED_INTERFACE:-}"
ERROR_FLAG="${TMPDIR:-/tmp}"
ERROR_FLAG="${ERROR_FLAG%/}/wled-octolamp-error-${WLED_HOST//[^A-Za-z0-9.-]/_}"

# Hooks pipe event JSON via stdin. "tool" inspects it; others just drain it.
if [ "$STATUS" = "tool" ]; then
  HOOK_INPUT="$(cat 2>/dev/null)"
  # Copilot CLI reports a non-zero shell exit as resultType "success"; the
  # failure only shows in toolTelemetry (shell_error_category / exit_code).
  if printf '%s' "$HOOK_INPUT" | grep -qE '"shell_error_category"[[:space:]]*:[[:space:]]*"command_nonzero_exit"|"exit_code"[[:space:]]*:[[:space:]]*-?[1-9]'; then
    STATUS=error
  else
    STATUS=recover
  fi
else
  cat > /dev/null 2>&1 &
fi

# --- Sticky error state ---
case "$STATUS" in
  busy|reset) rm -f "$ERROR_FLAG" 2>/dev/null ;;
  error)      touch "$ERROR_FLAG" 2>/dev/null ;;
  recover)
    [ -e "$ERROR_FLAG" ] || exit 0   # Nothing to recover from; leave lamp alone
    rm -f "$ERROR_FLAG" 2>/dev/null
    STATUS=busy ;;
  *)
    [ -e "$ERROR_FLAG" ] && exit 0   # Keep red until fixed or next prompt
    ;;
esac

# --- Dedicated-adapter mode (only when WLED_INTERFACE is set) ---
BIND_ARG=""
if [ -n "$WLED_INTERFACE" ]; then
  # Try Linux ip command first, fall back to macOS ifconfig
  LOCAL_IP=$(ip -4 addr show "$WLED_INTERFACE" 2>/dev/null | grep -oP 'inet \K[\d.]+' | head -1)
  if [ -z "$LOCAL_IP" ]; then
    LOCAL_IP=$(ifconfig "$WLED_INTERFACE" 2>/dev/null | grep 'inet ' | awk '{print $2}' | head -1)
  fi
  if [ -n "$LOCAL_IP" ]; then
    BIND_ARG="--interface $LOCAL_IP"

    # Best-effort route hygiene: remove any default route on the dedicated
    # interface that DHCP may have assigned (prevents traffic hijacking).
    if command -v ip &>/dev/null; then
      DEV_GW=$(ip route show default dev "$WLED_INTERFACE" 2>/dev/null | awk '{print $3}' | head -1)
      if [ -n "$DEV_GW" ]; then
        ip route del default via "$DEV_GW" dev "$WLED_INTERFACE" 2>/dev/null || true
      fi
    fi
  else
    exit 0  # Dedicated interface not connected — silently skip
  fi
fi

# --- Build the WLED JSON API payload ---
case "$STATUS" in
  busy)  RGB='[255,0,0]'; FX=9; SX=128; IX=128; PAL=0 ;; # Rainbow
  error) RGB='[255,0,0]'; FX=1; SX=200; IX=128; PAL=0 ;;  # Blink
  *)     RGB='[255,255,255]'; FX=0; SX=128; IX=128; PAL=0 ;;  # Solid
esac

BODY="{\"on\":true,\"bri\":${BRIGHTNESS},\"seg\":[{\"col\":[${RGB},[0,0,0],[0,0,0]],\"fx\":${FX},\"sx\":${SX},\"ix\":${IX},\"pal\":${PAL}}]}"

curl -s -X POST "http://${WLED_HOST}/json/state" \
  -H "Content-Type: application/json" \
  -d "$BODY" \
  $BIND_ARG \
  --noproxy "*" \
  --connect-timeout 2 \
  -o /dev/null 2>/dev/null || true
