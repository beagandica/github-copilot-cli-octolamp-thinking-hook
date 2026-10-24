# 🐙💡 GitHub Copilot CLI Octolamp Thinking Hook

Turn your [WLED](https://kno.wled.ge/)-powered [Octolamp](https://github.com/martinwoodward/octolamp) into a real-time status light for [GitHub Copilot CLI](https://docs.github.com/copilot/concepts/agents/about-copilot-cli). When Copilot is thinking, the lamp breathes green. When it's idle, solid white. If something breaks, it blinks red.

No model-level prompting tricks - this uses **Copilot CLI's native hooks system**, which fires at session lifecycle events.

<p align="center">
  <a href="https://github.com/martinwoodward/octolamp">
    <img src="https://raw.githubusercontent.com/martinwoodward/octolamp/main/images/IMG_9122.jpg" alt="Assembled Octolamp glowing" width="500" />
  </a>
</p>

---

## 🎤 GitHub Universe 2026

This is the companion repository for **[I made my Octolamp think with GitHub Copilot CLI hooks](https://reg.githubuniverse.com/flow/github/universe26/attendee-portal/page/sessioncatalog/session/1777614539199001PlmK)**.

- **Speaker:** Bea Mendez Gandica, CEO/Founder, Nuevo Foundation
- **When:** Wednesday, October 28, 2026, 11:20-11:35 AM PDT
- **Where:** Ship & Tell @ Firehouse

The idea grew out of the Octolamps handed out at GitHub Universe 2025: what if a lamp could show when Copilot CLI is working? This project connects native CLI lifecycle events to a physical light through the WLED API, making agent activity visible beyond the terminal.

The session walks through the build, how Copilot CLI hooks work under the hood, and how to adapt the same approach to your own automations.

**Try it yourself:** Follow the [Quick Start](#-quick-start), or explore [How Hooks Work](#-how-hooks-work). You can use any WLED-compatible light - not just an Octolamp.

---

## ✨ What It Does

| Status | Light Effect | Trigger |
|---|---|---|
| **Thinking** | 🟢 Breathing green (Apple-style pulse) | `userPromptSubmitted` - you hit enter |
| **Idle** | ⚪ Solid white | `Stop` - agent finishes responding |
| **Session end** | ⚪ Solid white | `sessionEnd` - session closes |
| **Error** | 🔴 Blinking red | `errorOccurred` - something broke |

### Key Features

- **System-level hooks** - not dependent on the AI model remembering to call a tool
- **Cross-platform** - PowerShell (Windows) and Bash (macOS/Linux) scripts
- **Self-healing** (optional) - auto-reconnects a dedicated WiFi adapter if it drops
- **Silent failure** - if the WLED device is unreachable, Copilot CLI continues uninterrupted
- **Works with any WLED device** - not just the Octolamp

---

## 🛒 Shopping List

You need a **WLED-compatible smart light** and a way to reach it over the network. The [Octolamp](https://github.com/martinwoodward/octolamp) is the recommended build - it's a 3D-printable GitHub Octocat lamp designed for WLED.

### Option A: Build an Octolamp (Recommended)

| Component | US Link | Notes |
|---|---|---|
| ESP8266 D1 Mini | [Amazon US](https://amzn.to/3koQwS0) | The brains - runs WLED firmware |
| WS2812B LED Strip (60 LEDs/m) | [Amazon US](https://amzn.to/3XwWnCT) | ~2m needed, sold in 5m spools |
| Black PLA Filament | [Amazon US](https://amzn.to/3CTo54W) | For the outer shell |
| White PLA Filament | [Amazon US](https://amzn.to/3GKObIz) | For the diffuser and reflector |
| Micro-USB cable | [Amazon US](https://amzn.to/3CTpqsl) | Powers the lamp via USB |

> **Total cost:** Under $20 for electronics (assuming you have a 3D printer and filament).
>
> Full build instructions, STL files, and assembly photos: [github.com/martinwoodward/octolamp](https://github.com/martinwoodward/octolamp)

### Option B: Any WLED Device

Already have a WLED-powered device? Skip the Octolamp build - these hooks work with any WLED controller. Just set `WLED_HOST` to your device's IP address.

### Optional: Dedicated USB WiFi Adapter

If your WLED device runs in Access Point mode (the default), you'll want a **dedicated USB WiFi adapter** so your main WiFi stays connected to the internet while the adapter connects to WLED-AP.

| Component | US Link | Notes |
|---|---|---|
| UGREEN AX900 USB WiFi 6 | [Amazon US](https://www.amazon.com/dp/B0DK14GTR2) | Compact; check platform compatibility below |

> **Compatibility:** This specific UGREEN AX900 model does **not** support **Windows on ARM** or **macOS**, including Apple silicon Macs. Other options on the market support these platforms; choose an adapter with manufacturer-confirmed support for your exact OS version and processor architecture. This limitation applies to the linked adapter, not the cross-platform hooks.

> **Not needed if** your WLED device is connected to your home/office WiFi network instead of running in AP mode.

---

## 🚀 Quick Start

### Prerequisites

- [GitHub Copilot CLI](https://docs.github.com/copilot/concepts/agents/about-copilot-cli) installed and authenticated
- A WLED device on the network (see [Shopping List](#-shopping-list) above)
- `curl` available in your terminal (included on Windows 10+, macOS, and most Linux distros)
- Windows: PowerShell 7+ (`pwsh`) installed and available in your PATH

### Step 1: Flash WLED

Plug your ESP8266/ESP32 into USB and visit the [WLED web installer](https://install.wled.me/). Flash the latest firmware. By default, the device creates a WiFi access point called **WLED-AP** (password: `wled1234`) at IP **`4.3.2.1`**.

### Step 2: Connect to the WLED Network

Connect your computer (or a dedicated USB WiFi adapter) to the **WLED-AP** network.
For a dedicated Windows adapter, follow the [one-time setup](#-dedicated-wifi-adapter-setup-windows) below before connecting, so it cannot take over your internet route.

### Step 3: Install the Hooks

Choose one of the two installation methods:

#### Method A: Global Install (Recommended)

Installs hooks to `~/.copilot/hooks/` (`%USERPROFILE%\.copilot\hooks\` on Windows) so they work from any directory. If `COPILOT_HOME` is set, installs to its `hooks` subdirectory instead.

**Windows (PowerShell):**
```powershell
git clone https://github.com/beagandica/github-copilot-cli-octolamp-thinking-hook.git
cd github-copilot-cli-octolamp-thinking-hook
.\install.ps1
# For a dedicated USB WiFi adapter, use this instead:
# .\install.ps1 -WledInterface "Wi-Fi 2"
```

**macOS / Linux:**
```bash
git clone https://github.com/beagandica/github-copilot-cli-octolamp-thinking-hook.git
cd github-copilot-cli-octolamp-thinking-hook
chmod +x install.sh
./install.sh
```

#### Method B: Per-Repository Install

Copy the `.github/hooks/` folder into any repository where you want the status light:

```bash
# From inside your project repo:
cp -r /path/to/github-copilot-cli-octolamp-thinking-hook/.github/hooks/ .github/hooks/
```

The hooks JSON uses relative paths, so it works out of the box.

### Step 4: Restart Copilot CLI

Restart the Copilot CLI process after installation so it reloads the hooks, then submit a prompt - your lamp should breathe green while thinking, then return to white.

---

## ⚙️ Configuration

All settings are controlled via environment variables - no code changes needed.
The global installers save any `WLED_*` settings below that are set at installation time into each hook's `env` block. Windows also saves the adapter supplied with `-WledInterface`. These saved settings override inherited environment variables; change them by rerunning the installer, then restart Copilot CLI. Unset settings use the controller defaults or the environment inherited at runtime.

| Variable | Default | Description |
|---|---|---|
| `WLED_HOST` | `4.3.2.1` | IP address of your WLED device |
| `WLED_BRIGHTNESS` | `128` | LED brightness (0–255) |
| `WLED_INTERFACE` | *(unset)* | Network interface name for dedicated adapter mode (e.g., `Wi-Fi 2`, `wlan1`) |
| `WLED_SSID` | `WLED-AP` | WiFi SSID to auto-reconnect to (only used when `WLED_INTERFACE` is set) |

### Simple Setup (WLED on your home network)

```powershell
$env:WLED_HOST = "192.168.1.42"
.\install.ps1
```

```bash
export WLED_HOST="192.168.1.42"
bash install.sh
```

### Dedicated Adapter Setup (WLED in AP mode)

```powershell
$env:WLED_INTERFACE = "Wi-Fi 2"
$env:WLED_SSID = "WLED-AP"
$env:WLED_HOST = "4.3.2.1"
.\install.ps1
```

```bash
export WLED_INTERFACE="wlan1"
export WLED_SSID="WLED-AP"
export WLED_HOST="4.3.2.1"
bash install.sh
```

> **Tip:** Installed hooks retain these settings across sessions without modifying your shell profile. Adapter names are local configuration, not hardcoded into the controllers.

---

## 🔌 Dedicated WiFi Adapter Setup (Windows)

If you're using a dedicated USB WiFi adapter (like the UGREEN) to connect to WLED-AP while keeping your main WiFi on your regular network, follow these steps. This is a **one-time setup**.

### Why a Dedicated Adapter?

When the USB adapter connects to WLED-AP, the ESP8266's DHCP server assigns a default gateway. If Windows picks that route over your main WiFi, **all your internet traffic routes through an ESP8266 that can't reach the internet**. The setup below prevents this.

### One-Time Configuration (Run as Administrator)

```powershell
# 1. Before connecting, set a static IP with NO gateway
netsh interface ip set address "Wi-Fi 2" static 4.3.2.100 255.255.255.0 none

# 2. Disable DAD - ESP8266 doesn't respond to ARP probes, causing the IP
#    to get stuck in "Tentative" state without this
netsh interface ip set interface "Wi-Fi 2" dadtransmits=0

# 3. In the Windows WiFi menu, select the USB adapter (Wi-Fi 2) and save
#    WLED-AP with password wled1234. Leave the main Wi-Fi adapter connected
#    to your regular network. Once the profile is saved:
netsh wlan connect name="WLED-AP" interface="Wi-Fi 2"

# 4. Auto-connect when the adapter is plugged in
netsh wlan set profileparameter name="WLED-AP" connectionmode=auto interface="Wi-Fi 2"
netsh wlan set profileorder name="WLED-AP" interface="Wi-Fi 2" priority=1

# 5. Remove WLED-AP from your MAIN WiFi adapter (prevents your laptop WiFi
#    from accidentally connecting to the Octolamp instead of your network)
netsh wlan delete profile name="WLED-AP" interface="Wi-Fi"

# 6. Disable USB Selective Suspend (prevents Windows from sleeping the adapter)
powercfg /SETACVALUEINDEX SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
powercfg /SETDCVALUEINDEX SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
powercfg /SETACTIVE SCHEME_CURRENT
```

> **Note:** Replace `"Wi-Fi 2"` with whatever Windows names your USB adapter. Check with `Get-NetAdapter`.

### Verify It Worked

```powershell
# Adapter connected?
(Get-NetAdapter -Name "Wi-Fi 2").Status  # → Up

# IP active (should say "Preferred", not "Tentative")?
Get-NetIPAddress -InterfaceAlias "Wi-Fi 2" -AddressFamily IPv4 |
    Format-Table IPAddress, AddressState

# No default route hijacking internet?
Get-NetRoute -InterfaceAlias "Wi-Fi 2" -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue
# (should return nothing)

# Octolamp reachable?
curl.exe -s --interface 4.3.2.100 --noproxy "*" http://4.3.2.1/json/state
# (should return JSON)

# Internet still works?
curl.exe -s -o NUL -w "HTTP %{http_code}" https://github.com
# (should return HTTP 200)
```

### How to Revert

```powershell
# Run as Administrator
netsh interface ip set address "Wi-Fi 2" dhcp
netsh interface ip set interface "Wi-Fi 2" dadtransmits=3
Restart-NetAdapter -Name "Wi-Fi 2"
```

### Dock / Undock Behavior

The adapter setup **persists across plug/unplug cycles**:
- **Unplug:** Hook scripts detect the adapter is missing → silently exit. Copilot CLI is unaffected.
- **Plug back in:** Windows reconnects to WLED-AP automatically, static IP activates, next hook fires normally.
- **Adapter suspended by Windows?** The script auto-reconnects and re-disables USB Selective Suspend on every invocation.

---

## 🤖 Auto-Setup with Copilot CLI

Already have Copilot CLI running? Just paste this prompt and let it handle everything:

<details>
<summary><strong>📋 Click to expand the Copilot CLI auto-setup prompt</strong></summary>

```
I need you to set up the WLED Octolamp thinking hook so my Octolamp shows my Copilot status.

Here's what I need you to do:

1. Clone https://github.com/beagandica/github-copilot-cli-octolamp-thinking-hook.git to a temp folder

2. Run the install script:
   - Windows: .\install.ps1
   - macOS/Linux: chmod +x install.sh && ./install.sh

3. Detect my OS and set environment variables:
   - Set WLED_HOST to 4.3.2.1 (or ask me if my WLED is on a different IP)
   - Set WLED_BRIGHTNESS to 128

4. If I'm on Windows and have a dedicated USB WiFi adapter for WLED:
   - Ask me what the adapter name is (check Get-NetAdapter for options)
   - Set WLED_INTERFACE to that adapter name
   - Set WLED_SSID to WLED-AP (or ask me)
   - Run the one-time adapter setup as Administrator:
     a. netsh interface ip set address "<adapter>" static 4.3.2.100 255.255.255.0 none
     b. netsh interface ip set interface "<adapter>" dadtransmits=0
     c. netsh wlan set profileparameter name="WLED-AP" connectionmode=auto interface="<adapter>"
     d. Disable USB Selective Suspend via powercfg
   - Re-run the installer with those env vars set so they are saved in the global hooks

5. Test the connection:
   - Verify the WLED device responds at the configured host
   - Run the status script with "busy" (should turn green)
   - Run the status script with "done" (should turn white)

6. Clean up the temp clone folder

After setup, tell me to restart Copilot CLI so the hooks load.
```

</details>

---

## 🪝 How Hooks Work

[Copilot CLI hooks](https://docs.github.com/copilot/how-tos/copilot-cli/customize-copilot/use-hooks) execute custom shell commands at key lifecycle points. They are system-level triggers - not dependent on the AI model choosing to call a tool.

The hook configuration maps lifecycle events to the status scripts:

- **`userPromptSubmitted`** → fires when you press enter → 🟢 breathing green
- **`Stop`** → fires when the agent finishes responding → ⚪ solid white
- **`sessionEnd`** → fires when the session closes → ⚪ solid white
- **`errorOccurred`** → fires on any agent error → 🔴 blinking red

Hooks receive JSON input via stdin. The status scripts drain this input and ignore it - they only care about which status to set.

There is deliberately no `sessionStart` lamp command. Copilot CLI can run it concurrently with `userPromptSubmitted` on the first prompt; a startup white reset can arrive after green and hide the thinking state. Opening or resuming a session leaves the lamp unchanged until a prompt or completion event.

---

## 🔍 Troubleshooting

### Hooks aren't firing

- Repository hooks go in `.github/hooks/`; global hooks go in `~/.copilot/hooks/` (or `$COPILOT_HOME/hooks/` when set)
- Check that the JSON has `"version": 1`
- **Restart Copilot CLI** after installing hooks (they're discovered at session start)

### Light doesn't change

- Verify your WLED device is reachable: `curl -s http://4.3.2.1/json/state`
- If using a dedicated adapter, check it's connected: `Get-NetAdapter -Name "Wi-Fi 2"`
- Test the script directly: `.\wled-status.ps1 -Status "busy"` or `./wled-status.sh busy`
- If only the first prompt stays white, reinstall the latest hooks and restart that CLI process. Remove any older WLED `sessionStart` reset from repository or user hooks; all sources run together.

### Adapter keeps disconnecting (Windows)

This is usually USB Selective Suspend. The script attempts to disable it automatically when `WLED_INTERFACE` is set, but group policy may override it. See [Dedicated WiFi Adapter Setup](#-dedicated-wifi-adapter-setup-windows) for the manual fix.

### Internet stops working when adapter is plugged in

The WLED device's DHCP server assigned a default gateway to your adapter, and Windows is routing all traffic through it. See [Dedicated WiFi Adapter Setup](#-dedicated-wifi-adapter-setup-windows) - specifically the static IP step that removes the gateway.

### Adding debug logging

Stack a logging hook alongside the status hook in `wled-hooks.json`:

```json
"Stop": [
  {
    "type": "command",
    "bash": "./wled-status.sh done",
    "powershell": "& './wled-status.ps1' -Status 'done'",
    "cwd": ".github/hooks",
    "timeoutSec": 15
  },
  {
    "type": "command",
    "bash": "echo \"$(date '+%Y-%m-%d %H:%M:%S') [Stop] fired\" >> .github/hooks/hook-events.log",
    "powershell": "Add-Content -Path '.github/hooks/hook-events.log' -Value \"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [Stop] fired\"",
    "cwd": ".",
    "timeoutSec": 5
  }
]
```

---

## 📁 Repository Structure

```
github-copilot-cli-octolamp-thinking-hook/
├── .github/
│   └── hooks/
│       ├── wled-hooks.json      ← Copilot CLI hook configuration
│       ├── wled-status.ps1      ← Windows (PowerShell) status controller
│       └── wled-status.sh       ← macOS/Linux (Bash) status controller
├── tests/
│   └── hook-lifecycle.ps1       ← No-network lifecycle regression check
├── install.ps1                  ← Windows global install script
├── install.sh                   ← macOS/Linux global install script
├── LICENSE                      ← MIT License
└── README.md                   ← You are here
```

### Hook lifecycle regression check

With PowerShell 7 and Bash installed, run `pwsh -NoProfile -File .\tests\hook-lifecycle.ps1` from the repository root. On Windows with Git for Windows, add `-Bash "C:\Program Files\Git\bin\bash.exe"`.

This checks repository and generated global hooks against the first-prompt startup race and response completion. It mocks HTTP requests and installs only into temporary directories; it does not contact the lamp or change your global hooks.

---

## 🎨 WLED API Reference

The scripts communicate with WLED via its [JSON API](https://kno.wled.ge/interfaces/json-api/) over HTTP POST to `/json/state`.

| Parameter | Busy (Thinking) | Done (Idle) | Error |
|---|---|---|---|
| `fx` (effect) | `2` (Breathe) | `0` (Solid) | `1` (Blink) |
| `sx` (speed) | `80` | - | `200` |
| `ix` (intensity) | `100` | - | - |
| `col` (color) | `[0,255,0]` 🟢 | `[255,255,255]` ⚪ | `[255,0,0]` 🔴 |

---

## 🙏 Credits

- **[Octolamp](https://github.com/martinwoodward/octolamp)** by [@martinwoodward](https://github.com/martinwoodward) - the 3D-printable GitHub Octocat lamp this was built for
- **[WLED](https://kno.wled.ge/)** - open source firmware for ESP8266/ESP32 LED controllers
- **[GitHub Copilot CLI](https://docs.github.com/copilot/concepts/agents/about-copilot-cli)** - the AI-powered terminal assistant with hooks support

---

## 📄 License

This hook integration is released under the [MIT License](LICENSE).

The Octolamp hardware design is separately licensed under [CC BY-NC 4.0](https://github.com/martinwoodward/octolamp/blob/main/LICENSE) by Martin Woodward.

---

## 📚 Further Reading

- [Using hooks with GitHub Copilot CLI](https://docs.github.com/copilot/how-tos/copilot-cli/customize-copilot/use-hooks)
- [Hooks configuration reference](https://docs.github.com/copilot/reference/hooks-configuration)
- [About GitHub Copilot CLI](https://docs.github.com/copilot/concepts/agents/about-copilot-cli)
- [Octolamp build instructions](https://github.com/martinwoodward/octolamp)
- [WLED documentation](https://kno.wled.ge/)
- [WLED JSON API](https://kno.wled.ge/interfaces/json-api/)
