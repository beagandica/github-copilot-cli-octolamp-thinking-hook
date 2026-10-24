# Repository guidance

## Architecture

This is a shell-script integration between Copilot CLI lifecycle hooks and a
networked WLED light. Each hook runs a short-lived status controller, which
ignores the hook's JSON stdin and POSTs a JSON payload to `/json/state` with curl.
There is no persistent service.

`.github/hooks/wled-hooks.json` is the per-repository configuration: version 1,
relative script paths, `cwd` set to `.github/hooks`, and a 15-second hook timeout.
`install.ps1` and `install.sh` copy both controllers into the user's
`~/.copilot/hooks/` directory (or `$COPILOT_HOME/hooks/` when set) and independently
generate a global configuration with absolute script paths and `cwd` set to `.`.
They persist explicitly supplied `WLED_*` settings in each hook's `env` block;
PowerShell also persists `-WledInterface`. They do not generate the configuration
from the checked-in JSON. Hooks are loaded at session start; installation or
configuration changes require restarting Copilot CLI.

Keep these event mappings synchronized in the checked-in JSON and both installers:

| Event | Status | Lamp |
| --- | --- | --- |
| `Stop`, `sessionEnd` | `done` | Solid white |
| `userPromptSubmitted` | `busy` | Breathing green |
| `errorOccurred` | `error` | Blinking red |

Do not add a `sessionStart` lamp command. The CLI can run it concurrently with
the first `userPromptSubmitted` hook, allowing a late idle reset to overwrite
the busy state. Opening or resuming a session leaves the lamp unchanged.

## Commands and validation

Run commands from the repository root. The Windows controller requires
PowerShell 7+ (`pwsh`) because it uses the `??` operator.

```powershell
# No-network lifecycle regression check (requires PowerShell 7 and Bash).
pwsh -NoProfile -File .\tests\hook-lifecycle.ps1 -Bash "C:\Program Files\Git\bin\bash.exe"

# Install globally on Windows (overwrites this integration's installed files).
.\install.ps1

# Single-status smoke test against the configured WLED device.
pwsh -NoProfile -File .\.github\hooks\wled-status.ps1 -Status busy
# Restore the idle state.
pwsh -NoProfile -File .\.github\hooks\wled-status.ps1 -Status done

# Parse the per-repository hook configuration.
Get-Content -Raw .\.github\hooks\wled-hooks.json | ConvertFrom-Json | Out-Null
```

In Bash on macOS/Linux:

```bash
bash install.sh
bash -n install.sh && bash -n .github/hooks/wled-status.sh
bash .github/hooks/wled-status.sh busy
bash .github/hooks/wled-status.sh done
```

Smoke tests send real device commands. Verify the lamp or inspect its
`/json/state` response; a successful script exit alone does not establish that the
request succeeded, because runtime network failures are intentionally suppressed.
With `WLED_INTERFACE` set, running a controller can also change networking or
power settings. Global installation writes outside the repository.

## Cross-platform conventions

- Keep the shared status semantics consistent between `wled-status.ps1` and
  `wled-status.sh`: busy uses green with `fx=2`, `sx=80`, `ix=100`; done uses white
  with `fx=0`; error uses red with `fx=1`, `sx=200`. Set `pal=0` and clear the two
  secondary color slots to black so prior device settings do not affect colors.
- Configuration uses `WLED_HOST` (default `4.3.2.1`), `WLED_BRIGHTNESS` (default
  `128`), and optional `WLED_INTERFACE`. PowerShell additionally uses `WLED_SSID`
  (default `WLED-AP`) for reconnection and accepts parameter overrides and custom
  RGB via `-Color`. Bash defaults a missing or unrecognized status to done;
  PowerShell validates explicit statuses with `ValidateSet`.
- Preserve silent, best-effort runtime behavior: a missing adapter, unavailable
  IP, or unreachable lamp must not interrupt Copilot. Both controllers bypass
  proxies, use a two-second curl connection timeout, and suppress response output.
  Installers instead fail on errors (`$ErrorActionPreference = "Stop"` and
  `set -euo pipefail`).
- Dedicated-adapter traffic binds curl to the adapter's local IPv4 address, not
  its display name. Both controllers attempt to remove default routes on that
  adapter to avoid diverting internet traffic through WLED. Windows additionally
  reconnects WiFi and disables USB Selective Suspend; Bash resolves addresses
  through Linux `ip` or macOS `ifconfig`. Do not assume identical recovery
  capabilities on both platforms.
- Keep README configuration, event mappings, and setup instructions aligned with
  changes to the controllers or installers. Windows AP setup deliberately uses a
  static address without a gateway and disables DAD for the ESP8266; preserve
  those constraints when changing dedicated-adapter behavior.
