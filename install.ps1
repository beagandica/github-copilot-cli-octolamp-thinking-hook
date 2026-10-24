# install.ps1 — Install WLED Octolamp hooks globally for GitHub Copilot CLI (Windows)
#
# Copies hook scripts to ~/.copilot/hooks/ (or $COPILOT_HOME/hooks/)
# and generates wled-hooks.json
# with absolute paths so hooks work from any directory.
#
# Usage: .\install.ps1
#        .\install.ps1 -WledInterface "Wi-Fi 2"   # enable dedicated adapter mode

param(
    [string]$WledInterface = ""
)

$ErrorActionPreference = "Stop"
$copilotHome = if ($env:COPILOT_HOME) { $env:COPILOT_HOME } else { Join-Path $env:USERPROFILE ".copilot" }
$hooksDir = Join-Path $copilotHome "hooks"
$scriptDir = Join-Path $PSScriptRoot ".github\hooks"

# Create target directory
$hooksDir = (New-Item -ItemType Directory -Path $hooksDir -Force).FullName

# Copy scripts
Copy-Item (Join-Path $scriptDir "wled-status.ps1") $hooksDir -Force
Copy-Item (Join-Path $scriptDir "wled-status.sh") $hooksDir -Force
Write-Host "Copied scripts to $hooksDir" -ForegroundColor Green

# Generate hooks JSON with absolute paths
$ps1Path = (Join-Path $hooksDir "wled-status.ps1") -replace '\\', '/'
$shPath  = (Join-Path $hooksDir "wled-status.sh") -replace '\\', '/'
$ps1CommandPath = "'" + $ps1Path.Replace("'", "''") + "'"
$shCommandPath = "'" + $shPath.Replace("'", "'\''") + "'"

$hookEnv = @{}
foreach ($name in "WLED_HOST", "WLED_BRIGHTNESS", "WLED_INTERFACE", "WLED_SSID") {
    $value = [Environment]::GetEnvironmentVariable($name)
    if ($value) { $hookEnv[$name] = $value }
}
if ($WledInterface) {
    $hookEnv["WLED_INTERFACE"] = $WledInterface
}

$hooks = @{
    version = 1
    hooks   = @{
        userPromptSubmitted   = @()
        Stop                 = @()
        sessionEnd           = @()
        errorOccurred        = @()
    }
}

$statuses = @{
    userPromptSubmitted = "busy"
    Stop               = "done"
    sessionEnd         = "done"
    errorOccurred      = "error"
}

foreach ($event in $statuses.Keys) {
    $s = $statuses[$event]
    $entry = @{
        type       = "command"
        bash       = "$shCommandPath $s"
        powershell = "& $ps1CommandPath -Status '$s'"
        cwd        = "."
        env        = $hookEnv
        timeoutSec = 15
    }
    $hooks.hooks[$event] = @($entry)
}

$jsonPath = Join-Path $hooksDir "wled-hooks.json"
$hooks | ConvertTo-Json -Depth 5 | Set-Content $jsonPath -Encoding UTF8
Write-Host "Generated $jsonPath" -ForegroundColor Green

if ($hookEnv.ContainsKey("WLED_INTERFACE")) {
    Write-Host ""
    Write-Host "Dedicated adapter saved in hooks: $($hookEnv['WLED_INTERFACE'])" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "Installation complete! Restart Copilot CLI to activate hooks." -ForegroundColor Green
Write-Host "Hooks installed to: $hooksDir" -ForegroundColor Gray
