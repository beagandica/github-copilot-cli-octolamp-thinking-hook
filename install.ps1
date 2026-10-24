# install.ps1 — Install WLED Octolamp hooks globally for GitHub Copilot CLI (Windows)
#
# Copies hook scripts to ~/.github/hooks/ and generates wled-hooks.json
# with absolute paths so hooks work from any directory.
#
# Usage: .\install.ps1
#        .\install.ps1 -WledInterface "Wi-Fi 2"   # enable dedicated adapter mode

param(
    [string]$WledInterface = ""
)

$ErrorActionPreference = "Stop"
$hooksDir = Join-Path $env:USERPROFILE ".github\hooks"
$scriptDir = Join-Path $PSScriptRoot ".github\hooks"

# Create target directory
New-Item -ItemType Directory -Path $hooksDir -Force | Out-Null

# Copy scripts
Copy-Item (Join-Path $scriptDir "wled-status.ps1") $hooksDir -Force
Copy-Item (Join-Path $scriptDir "wled-status.sh") $hooksDir -Force
Write-Host "Copied scripts to $hooksDir" -ForegroundColor Green

# Generate hooks JSON with absolute paths
$ps1Path = (Join-Path $hooksDir "wled-status.ps1") -replace '\\', '/'
$shPath  = (Join-Path $hooksDir "wled-status.sh") -replace '\\', '/'

$hookEntry = @{
    type       = "command"
    bash       = ""
    powershell = ""
    cwd        = "."
    timeoutSec = 15
}

$hooks = @{
    version = 1
    hooks   = @{
        sessionStart         = @()
        userPromptSubmitted   = @()
        Stop                 = @()
        sessionEnd           = @()
        errorOccurred        = @()
    }
}

$statuses = @{
    sessionStart       = "done"
    userPromptSubmitted = "busy"
    Stop               = "done"
    sessionEnd         = "done"
    errorOccurred      = "error"
}

foreach ($event in $statuses.Keys) {
    $s = $statuses[$event]
    $entry = @{
        type       = "command"
        bash       = "$shPath $s"
        powershell = "& '$ps1Path' -Status '$s'"
        cwd        = "."
        timeoutSec = 15
    }
    $hooks.hooks[$event] = @($entry)
}

$jsonPath = Join-Path $hooksDir "wled-hooks.json"
$hooks | ConvertTo-Json -Depth 5 | Set-Content $jsonPath -Encoding UTF8
Write-Host "Generated $jsonPath" -ForegroundColor Green

# Save WLED_INTERFACE to a .env hint file if specified
if ($WledInterface) {
    $envHint = @"
# Add these to your PowerShell profile or system environment variables:
# `$env:WLED_INTERFACE = "$WledInterface"
# `$env:WLED_SSID = "WLED-AP"
# `$env:WLED_HOST = "4.3.2.1"
"@
    $envHint | Set-Content (Join-Path $hooksDir ".env-hint") -Encoding UTF8
    Write-Host ""
    Write-Host "Dedicated adapter mode: set these environment variables:" -ForegroundColor Yellow
    Write-Host "  `$env:WLED_INTERFACE = `"$WledInterface`"" -ForegroundColor Cyan
    Write-Host "  `$env:WLED_SSID = `"WLED-AP`"" -ForegroundColor Cyan
    Write-Host "  `$env:WLED_HOST = `"4.3.2.1`"" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "Installation complete! Restart Copilot CLI to activate hooks." -ForegroundColor Green
Write-Host "Hooks installed to: $hooksDir" -ForegroundColor Gray
