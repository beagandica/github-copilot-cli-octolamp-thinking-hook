# mode.ps1 — Choose which assistant drives the Octolamp.
#
# Usage: .\mode.ps1 copilot   # only GitHub Copilot CLI hooks change the lamp
#        .\mode.ps1 claude    # only Claude Code hooks change the lamp
#        .\mode.ps1 both      # either one can (default when no mode is set)
#        .\mode.ps1 off       # neither; the lamp keeps whatever it shows
#        .\mode.ps1           # show the current mode
#
# Takes effect on the next hook; no restart needed. The mode is stored in
# ~/.config/octolamp/mode (or $env:XDG_CONFIG_HOME; override with OCTOLAMP_MODE_FILE).

param(
    [ValidateSet("copilot", "claude", "both", "off")]
    [string]$Mode
)

$ErrorActionPreference = "Stop"
$modeFile = if ($env:OCTOLAMP_MODE_FILE) { $env:OCTOLAMP_MODE_FILE } else {
    $configHome = if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { Join-Path $HOME ".config" }
    Join-Path (Join-Path $configHome "octolamp") "mode"
}

if ($Mode) {
    New-Item -ItemType Directory -Path (Split-Path $modeFile -Parent) -Force | Out-Null
    Set-Content -LiteralPath $modeFile -Value $Mode
    Write-Host "Octolamp mode: $Mode" -ForegroundColor Green
} elseif (Test-Path -LiteralPath $modeFile) {
    Write-Host "Octolamp mode: $((Get-Content -LiteralPath $modeFile -Raw).Trim())"
} else {
    Write-Host "Octolamp mode: both (default; no mode set)"
}
