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
# Usage: .\wled-status.ps1 -Status "busy"    → rotating rainbow (thinking); clears error
#        .\wled-status.ps1 -Status "error"   → solid red (tool failed / error); sticky
#        .\wled-status.ps1 -Status "tool"    → postToolUse for shell commands: red if
#                                              the command exited non-zero, else back
#                                              to rainbow (only if red is showing)
#        .\wled-status.ps1 -Status "done"    → solid white (idle), unless red is showing
#        .\wled-status.ps1 -Status "reset"   → solid white (session ended); clears error
#        .\wled-status.ps1 -Color 255,128,0  → custom RGB
#
# "Sticky" red: an error leaves a marker file so the Stop hook keeps the lamp
# red instead of turning it white while something still needs fixing.
#
# Mode switch: WLED_SOURCE says which assistant fired the hook (copilot by
# default, claude for Claude Code). If the mode file (see mode.ps1) names a
# different assistant, or "off", the hook exits without touching the lamp.

param(
    [ValidateSet("busy", "done", "error", "tool", "recover", "reset")]
    [string]$Status,
    [int[]]$Color,
    [string]$WledHost = $($env:WLED_HOST ?? "4.3.2.1"),
    [int]$Brightness = $($env:WLED_BRIGHTNESS ?? 128),
    [string]$Interface = $($env:WLED_INTERFACE ?? ""),
    [string]$WledSSID = $($env:WLED_SSID ?? "WLED-AP")
)

# Hooks pipe event JSON via stdin. "tool" inspects it; others just drain it.
$hookInput = ""
if ([Console]::IsInputRedirected) {
    try { $hookInput = [Console]::In.ReadToEnd() } catch { }
}
$source = if ($env:WLED_SOURCE) { $env:WLED_SOURCE } else { "copilot" }
$modeFile = if ($env:OCTOLAMP_MODE_FILE) { $env:OCTOLAMP_MODE_FILE } else {
    $configHome = if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { Join-Path $HOME ".config" }
    Join-Path (Join-Path $configHome "octolamp") "mode"
}
$mode = "both"
if (Test-Path -LiteralPath $modeFile) {
    try { $mode = (Get-Content -LiteralPath $modeFile -Raw).Trim() } catch { }
}

function Write-DebugLog([string]$Message) {
    if ($env:WLED_DEBUG_LOG) {
        try { Add-Content -LiteralPath $env:WLED_DEBUG_LOG -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$source] $Message $hookInput" } catch { }
    }
}

# --- Mode switch: only the selected assistant drives the lamp ---
if ($Status -and $mode -and $mode -ne "both" -and $mode -ne $source) {
    Write-DebugLog "$Status -> skipped (mode=$mode)"
    exit 0
}

if ($Status -eq "tool") {
    # Copilot CLI reports a non-zero shell exit as resultType "success"; the
    # failure only shows in toolTelemetry (shell_error_category / exit_code).
    $Status = if ($hookInput -match '"shell_error_category"\s*:\s*"command_nonzero_exit"|"exit_code"\s*:\s*-?[1-9]|completed with exit code -?[1-9]') { "error" } else { "recover" }
    Write-DebugLog "tool -> $Status"
} elseif ($Status) {
    Write-DebugLog $Status
}

# --- Sticky error state ---
if ($Status) {
    $errorFlag = Join-Path ([IO.Path]::GetTempPath()) ("wled-octolamp-error-" + ($WledHost -replace '[^A-Za-z0-9.-]', '_'))
    switch ($Status) {
        { $_ -in "busy", "reset" } { Remove-Item -LiteralPath $errorFlag -Force -ErrorAction SilentlyContinue }
        "error" { try { New-Item -ItemType File -Path $errorFlag -Force | Out-Null } catch { } }
        "recover" {
            if (-not (Test-Path -LiteralPath $errorFlag)) { exit 0 }  # Nothing to recover from
            Remove-Item -LiteralPath $errorFlag -Force -ErrorAction SilentlyContinue
            $Status = "busy"
        }
        "done" { if (Test-Path -LiteralPath $errorFlag) { exit 0 } }  # Keep red until fixed
    }
    if ($Status -eq "reset") { $Status = "done" }
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
    busy  = @(255, 0, 0)     # unused by Rainbow, which draws its own colors
    done  = @(255, 255, 255) # white
    error = @(255, 0, 0)     # red
}

$rgb = if ($Color) { $Color } else { $colors[$Status] }

$effects = @{
    busy  = @{ fx = 9; sx = 128; ix = 128; pal = 0 } # Rainbow effect
    done  = @{ fx = 0; pal = 0 }                       # Solid
    error = @{ fx = 0; pal = 0 }                       # Solid
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
