# MRGARGSIR Windows Setup Utility

A single-script Windows debloat, privacy, and tweak tool with a GUI checkbox menu — run one command, pick what you want, done.

Developed By **@MRGARGSIR**

---

## Quick Start

Open PowerShell or Windows Terminal **as Administrator**, then run:

```powershell
irm https://mrgargsir.github.io/winsetup/win | iex
```

```powershell
irm https://mrgargsir.github.io/winsetup/setup.ps1 | iex
```

```powershell
irm https://winsetup.mrgargsir.store/setup.ps1 | iex
```


This downloads and runs the script directly — no need to clone the repo or save any files. A checkbox menu window will appear letting you choose which tweaks to apply.

---

## What It Does

### Core tweaks (pre-checked by default)
- **Auto-Partition** — if the disk has a single `C:` volume with 30 GB+ free, shrinks it by a tiered percentage (20-50% depending on free space) and formats the freed space as a `D:` data drive.
- **Remove Windows Bloatware** — strips out preinstalled junk apps (Xbox apps, Bing apps, Solitaire, Teams, Clipchamp, Cortana, etc.) while explicitly keeping Calculator, Notepad, Paint, Photos, and Microsoft Store.
- **Remove Start Menu Bloat** — removes provisioned stub packages (Spotify, LinkedIn, Disney+, Facebook, TikTok, Prime Video) that regenerate Start menu tiles, clears the Start menu tile cache, and deletes stray bloat shortcuts.
- **Remove OEM Bloat (Dell/HP/Lenovo)** — detects the PC manufacturer and removes vendor-specific junk (Dell SupportAssist/Optimizer/MyDell, HP Support Assistant/JumpStart, Lenovo Vantage/Companion), plus a vendor-agnostic list (McAfee, Norton, WildTangent, Waves MaxxAudio, Dolby Access, Booking.com, Amazon Assistant) that ships on any brand.
- **Disable Windows Recall** — disables the AI Recall feature via policy and removes the Recall Appx package.
- **Uninstall Software** — opens a searchable checkbox list of all installed programs (from registry) so you can select and remove any of them in one pass.
- **Disable Startup Items** — turns off auto-launch entries and related scheduled tasks for AnyDesk, BlueStacks, Chrome, Edge, Spotify, Discord, Teams, Adobe, Skype, Steam, and more.
- **Start Menu Tweaks** — switches Start layout to grid ("More pins"), stops tracking recent docs/apps, and hides the Recommended section.
- **Taskbar Tweaks** — moves the taskbar to the left, sets search box to icon-only, hides the Task View button, and disables the taskbar widgets panel.
- **File Explorer Tweaks** — sets File Explorer to open to "This PC" by default and enables "Show hidden items."
- **Browser Tweaks** — disables Chrome/Edge background running and built-in GenAI features, and force-enables the bookmarks/favorites bar.
- **Multiple Antivirus Check** — detects if more than one antivirus product is registered and prompts a warning to uninstall extras (opens Apps & Features).
- **Disable Copilot** — turns off Windows Copilot via policy and hides its taskbar button.
- **Disable Unnecessary Scheduled Tasks** — disables known telemetry/CEIP-related scheduled tasks.
- **Disable Telemetry + Advertising ID** — sets telemetry to the minimum allowed level, disables the DiagTrack service, and turns off the advertising ID.
- **Enable Defender + Update** — re-enables Windows Defender real-time protection and forces a signature update.
- **Windows Activation Status Check** — reports current Windows license/activation state.
- **MS Office Activation Status Check** — reports current Office license/activation state (via `ospp.vbs`).
- **Temp File + Windows Update Cache Cleanup** — clears temp folders, prefetch, `SoftwareDistribution`, `catroot2`, and empties the Recycle Bin.
- **Repair Print Spooler & Font Cache** — stops the spooler, clears stuck print jobs, clears the font cache, and restarts both services.
- **Network Optimizations** — disables the Group Policy network-wait delay, sets DNS to Cloudflare/Google on active adapters, and flushes DNS.
- **Disable Fast Startup** — turns off hybrid shutdown/hiberboot.
- **Tune Search Indexer and SysMain** — disables SysMain on systems with 8 GB RAM or less; leaves it enabled on higher-RAM systems.
- **Optimize Background Services + Notifications + Clipboard** — disables Welcome Experience tips, enables Clipboard History (Win+V), disables DiagTrack/WerSvc/RetailDemo/MapsBroker, and blocks UWP apps from running in the background.
- **Disable Sleep When Plugged In** — sets sleep/monitor/hibernate timeouts to Never on AC power (battery behavior untouched).
- **Update All Apps** — triggers Microsoft Store app updates, runs `winget upgrade --all`, and (if the `PSWindowsUpdate` module is installed) installs pending Windows Updates.

### Optional extras (unchecked by default)
- Classic right-click context menu (Windows 10 style, skips "Show more options")
- Disable lock screen ads / Start menu suggestions / tips
- Force dark mode (apps + system)
- Disable Cortana/Bing web results in Start menu search
- Performance-focused visual effects

---

## Requirements

- Windows 10 or 11
- PowerShell running **as Administrator**
- Internet connection (for the `irm | iex` one-liner, and for Update-AllApps)

---

## Notes

- The script is idempotent — safe to re-run; it only sets values, it doesn't fail if a tweak is already applied.
- The "Uninstall Software" and "Multiple Antivirus Check" options open their own dialogs mid-run — the process isn't fully silent end-to-end if those are selected.
- `Update-AllApps`'s Windows Update step requires the `PSWindowsUpdate` module (`Install-Module PSWindowsUpdate -Force`); it's skipped automatically if not present.

---

## Disclaimer

This script makes system-level changes (uninstalls software, edits the registry, disables services/scheduled tasks). Review the source before running on production machines. Use at your own risk.
