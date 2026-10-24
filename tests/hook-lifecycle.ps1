param([string]$Bash = "bash")

$ErrorActionPreference = "Stop"
$repo = Split-Path $PSScriptRoot -Parent
$temp = Join-Path ([IO.Path]::GetTempPath()) ("wled-hook-test-" + [guid]::NewGuid())
$savedEnv = @{}
foreach ($name in "COPILOT_HOME", "WLED_HOST", "WLED_INTERFACE", "WLED_SSID", "WLED_BRIGHTNESS", "WLED_TEST_STATE") {
    $savedEnv[$name] = [Environment]::GetEnvironmentVariable($name)
    [Environment]::SetEnvironmentVariable($name, $null)
}

function curl.exe {
    $index = [Array]::IndexOf($args, "-d")
    if ($index -lt 0) { throw "Missing WLED request body." }
    Set-Content -LiteralPath $env:WLED_TEST_STATE -Value $args[$index + 1]
}

function Invoke-TestHook($Config, [string]$Event, [bool]$UseBash) {
    foreach ($entry in $Config.hooks.$Event) {
        Push-Location (Join-Path $repo $entry.cwd)
        try {
            if ($UseBash) {
                $command = @'
if command -v cygpath >/dev/null; then
    export WLED_TEST_STATE="$(cygpath -u "$WLED_TEST_STATE")"
fi
curl() {
    while [ "$#" -gt 0 ]; do
        if [ "$1" = "-d" ]; then
            printf '%s\n' "$2" > "$WLED_TEST_STATE"
            return
        fi
        shift
    done
    return 1
}
export -f curl
eval "$1"
'@
                "" | & $Bash --noprofile --norc -c $command "hook-test" $entry.bash
                if ($LASTEXITCODE -ne 0) { throw "Bash $Event hook failed." }
            } else {
                & ([scriptblock]::Create($entry.powershell))
            }
        } finally {
            Pop-Location
        }
    }
}

function Test-FirstPrompt($Config, [bool]$UseBash, [string]$Name) {
    if (Test-Path -LiteralPath $env:WLED_TEST_STATE) {
        Remove-Item -LiteralPath $env:WLED_TEST_STATE -Force
    }
    Invoke-TestHook $Config "userPromptSubmitted" $UseBash
    # Reproduce a slow startup reset finishing after the first prompt.
    Invoke-TestHook $Config "sessionStart" $UseBash
    $state = Get-Content -LiteralPath $env:WLED_TEST_STATE -Raw | ConvertFrom-Json
    if (-not $state.on -or $state.seg[0].fx -ne 2 -or ($state.seg[0].col[0] -join ",") -ne "0,255,0") {
        throw "${Name}: a late startup hook overwrote the first prompt's busy state."
    }
    Invoke-TestHook $Config "Stop" $UseBash
    $state = Get-Content -LiteralPath $env:WLED_TEST_STATE -Raw | ConvertFrom-Json
    if (-not $state.on -or $state.seg[0].fx -ne 0 -or ($state.seg[0].col[0] -join ",") -ne "255,255,255") {
        throw "${Name}: completion did not restore the idle state."
    }
    Write-Output "$Name passed."
}

try {
    New-Item -ItemType Directory -Path $temp | Out-Null
    $env:WLED_TEST_STATE = Join-Path $temp "lamp.json"
    $config = Get-Content -LiteralPath (Join-Path $repo ".github\hooks\wled-hooks.json") -Raw | ConvertFrom-Json
    Test-FirstPrompt $config $false "Repository PowerShell hooks"
    Test-FirstPrompt $config $true "Repository Bash hooks"

    $env:COPILOT_HOME = Join-Path $temp "powershell home"
    & (Join-Path $repo "install.ps1") | Out-Null
    $config = Get-Content -LiteralPath (Join-Path $env:COPILOT_HOME "hooks\wled-hooks.json") -Raw | ConvertFrom-Json
    Test-FirstPrompt $config $false "Installed PowerShell hooks"

    $env:COPILOT_HOME = Join-Path $temp "bash home"
    $command = @'
script="$1"
if command -v cygpath >/dev/null; then
    export COPILOT_HOME="$(cygpath -u "$COPILOT_HOME")"
    script="$(cygpath -u "$script")"
fi
exec bash "$script"
'@
    & $Bash --noprofile --norc -c $command "installer-test" (Join-Path $repo "install.sh") | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Bash installer failed." }
    $config = Get-Content -LiteralPath (Join-Path $env:COPILOT_HOME "hooks\wled-hooks.json") -Raw | ConvertFrom-Json
    Test-FirstPrompt $config $true "Installed Bash hooks"
} finally {
    foreach ($name in $savedEnv.Keys) {
        [Environment]::SetEnvironmentVariable($name, $savedEnv[$name])
    }
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
