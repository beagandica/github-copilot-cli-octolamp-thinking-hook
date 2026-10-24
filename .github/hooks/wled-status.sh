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
# Usage: ./wled-status.sh busy   → breathing green (thinking)
#        ./wled-status.sh done   → solid white     (idle)
#        ./wled-status.sh error  → blinking red

STATUS="${1:-done}"
WLED_HOST="${WLED_HOST:-4.3.2.1}"
BRIGHTNESS="${WLED_BRIGHTNESS:-128}"
WLED_INTERFACE="${WLED_INTERFACE:-}"

# Drain stdin if called as a hook (hooks pipe JSON via stdin)
cat > /dev/null 2>&1 &

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
  busy)  RGB='[0,255,0]'; FX=2; SX=80; IX=100; PAL=0 ;;   # Breathe
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
