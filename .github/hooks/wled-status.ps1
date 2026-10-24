# WLED Octolamp status light controller for GitHub Copilot CLI hooks
#
# Sends a color/effect command to a WLED device over HTTP. Designed to run
# as a Copilot CLI hook so your Octolamp reflects what Copilot is doing.
#
# Dedicated-adapter mode (optional):
#   Set WLED_INTERFACE to bind traffic to a specific NIC (e.g. a USB WiFi
#   adapter connected to the WLED access point). When set, the script also
#   auto-reconnects the adapter, disables USB Selective Suspend, and removes
#   rogue default gateway routes — making the setup fully self-healing.
#
# Usage: .\wled-status.ps1 -Status "busy"   → breathing green (thinking)
#        .\wled-status.ps1 -Status "done"    → solid white     (idle)
#        .\wled-status.ps1 -Status "error"   → blinking red
#        .\wled-status.ps1 -Color 255,128,0  → custom RGB

param(
    [ValidateSet("busy", "done", "error")]
    [string]$Status,
    [int[]]$Color,
    [string]$WledHost = $($env:WLED_HOST ?? "4.3.2.1"),
    [int]$Brightness = $($env:WLED_BRIGHTNESS ?? 128),
    [string]$Interface = $($env:WLED_INTERFACE ?? ""),
    [string]$WledSSID = $($env:WLED_SSID ?? "WLED-AP")
)

# Drain stdin if called as a hook (hooks pipe JSON via stdin)
if (-not [Console]::IsInputRedirected) { } else {
    try { [Console]::In.ReadToEnd() | Out-Null } catch { }
}

# --- Dedicated-adapter mode (only when Interface is set) ---
$localIp = $null
if ($Interface) {
    # Check if the adapter exists at all (physically plugged in)
    $adapter = Get-NetAdapter -Name $Interface -ErrorAction SilentlyContinue
    if (-not $adapter) {
        exit 0  # Adapter not present — silently skip (undocked)
    }

    # Wake up the adapter if suspended or disconnected. USB Selective Suspend
    # and/or group policy can kill the WiFi association between hook events.
    if ($adapter.Status -ne 'Up') {
        try {
            netsh wlan connect name="$WledSSID" interface=$Interface 2>&1 | Out-Null
            for ($i = 0; $i -lt 10; $i++) {
                Start-Sleep -Milliseconds 500
                $ip = Get-NetIPAddress -InterfaceAlias $Interface -AddressFamily IPv4 -ErrorAction SilentlyContinue
                if ($ip -and $ip.AddressState -eq 'Preferred') { break }
            }
        } catch { }
    }

    # Best-effort: disable USB Selective Suspend so the adapter stays awake
    # between hook events. Group policy may re-enable this, so we try every time.
    try {
        $guid_usb = '2a737441-1930-4402-8d77-b2bebba308a3'
        $guid_sus = '48e6b7a6-50f5-4782-a5d4-53bb8f07e226'
        powercfg /SETACVALUEINDEX SCHEME_CURRENT $guid_usb $guid_sus 0 2>&1 | Out-Null
        powercfg /SETDCVALUEINDEX SCHEME_CURRENT $guid_usb $guid_sus 0 2>&1 | Out-Null
        powercfg /SETACTIVE SCHEME_CURRENT 2>&1 | Out-Null
    } catch { }

    # Resolve the local IP for curl --interface binding
    $localIp = (Get-NetIPAddress -InterfaceAlias $Interface -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.AddressState -eq 'Preferred' }).IPAddress
    if (-not $localIp) {
        exit 0  # IP not ready — silently skip
    }

    # Best-effort route hygiene: remove any default gateway route that DHCP
    # assigned to the dedicated adapter (prevents traffic hijacking).
    try {
        $ifIndex = $adapter.ifIndex
        if ($ifIndex) {
            Get-NetRoute -InterfaceIndex $ifIndex -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue |
                Remove-NetRoute -Confirm:$false -ErrorAction SilentlyContinue
        }
    } catch { }
}

# --- Build the WLED JSON API payload ---
$colors = @{
    busy  = @(0, 255, 0)    # green
    done  = @(255, 255, 255) # white
    error = @(255, 0, 0)     # red
}

$rgb = if ($Color) { $Color } else { $colors[$Status] }

$effects = @{
    busy  = @{ fx = 2; sx = 80; ix = 100; pal = 0 }  # Breathe effect
    done  = @{ fx = 0; pal = 0 }                       # Solid
    error = @{ fx = 1; sx = 200; pal = 0 }             # Blink effect
}

$seg = @{}
if ($Status -and $effects.ContainsKey($Status)) {
    $effects[$Status].GetEnumerator() | ForEach-Object { $seg[$_.Key] = $_.Value }
}

$segProps = @("`"col`": [[$($rgb[0]),$($rgb[1]),$($rgb[2])],[0,0,0],[0,0,0]]")
$seg.GetEnumerator() | ForEach-Object { $segProps += "`"$($_.Key)`": $($_.Value)" }
$segJson = "{" + ($segProps -join ",") + "}"

$body = "{`"on`":true,`"bri`":$Brightness,`"seg`":[$segJson]}"

# --- Send the command to WLED ---
try {
    $curlArgs = @(
        "-s", "-X", "POST", "http://${WledHost}/json/state",
        "-H", "Content-Type: application/json",
        "-d", $body,
        "--noproxy", "*",
        "--connect-timeout", "2",
        "-o", "NUL"
    )
    if ($localIp) {
        $curlArgs += @("--interface", $localIp)
    }
    & curl.exe @curlArgs 2>&1 | Out-Null
} catch {
    # Silently fail — Copilot CLI must never be interrupted by a hook failure
}
