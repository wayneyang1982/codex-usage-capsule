# Codex Usage Capsule

A compact Windows title-bar widget for OpenAI Codex usage limits, reset times, and usage pace.

Codex Usage Capsule sits beside **Help** in Codex Desktop. The collapsed capsule stays quiet; click it to see quota bars, elapsed-time markers, reset countdowns, appearance controls, and sign-in startup.

> Community project. Not affiliated with or endorsed by OpenAI.

## What it shows

- One quota window: `7d 61% | 57%`
- Multiple quota windows: `5h (12|87) · 7d (61|97)`
- Left value: quota used. Right value: elapsed time in that quota window.
- The widget renders the windows returned by Codex App Server. It does not guess limits from Free, Plus, Pro, Business, or Enterprise plan names.
- When title-bar space becomes tight, it progressively collapses to compact text, `Usage ▾`, and finally `▾` instead of covering Codex controls.

## Requirements

- Windows 10 or Windows 11
- OpenAI Codex Desktop installed for the current Windows user
- Codex CLI installed natively on Windows and signed in to the same Windows account
- Windows PowerShell 5.1 or later
- No administrator rights or API key required

The official standalone Windows CLI is preferred. Existing npm installations are also supported and require Node.js. Codex Desktop alone is not treated as a CLI installation because executables inside its Windows app package are not a public integration point.

If `codex --version` is not available in PowerShell, install the [official Codex CLI](https://developers.openai.com/codex/cli) first. OpenAI's standalone Windows installer uses `%LOCALAPPDATA%\Programs\OpenAI\Codex\bin` by default. Run Codex once if sign-in is still required.

The current release is Windows-only. The quota model is portable, but macOS needs a separate native window and anchoring adapter.

## Install

Review the scripts, then run:

```powershell
git clone https://github.com/wayneyang1982/codex-usage-capsule.git
cd codex-usage-capsule
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Install.ps1
```

The installer copies the runtime to `%LOCALAPPDATA%\Programs\CodexUsageCapsule`, registers a current-user scheduled task named `CodexUsageCapsule`, waits one minute after Windows sign-in, and starts without a visible terminal. It does not modify Codex program files.

Check the installation:

```powershell
powershell.exe -NoProfile -File .\scripts\Get-Status.ps1
```

Uninstall:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Uninstall.ps1
```

Add `-RemoveSettings` to remove the saved appearance setting and runtime status file as well.

## Ask Codex to install it

Paste this into a local Codex task:

```text
Install Codex Usage Capsule from
https://github.com/wayneyang1982/codex-usage-capsule

Read README.md and AGENTS.md first. Inspect the installer, install it for the
current Windows user only, keep silent sign-in startup enabled, run the tests,
verify scripts/Get-Status.ps1, and report the final state. Do not request or
copy any API key or login token.
```

Codex reads repository-level `AGENTS.md` when it works inside a cloned repository, so the project includes concise maintenance and verification rules for coding agents.

## Privacy and data source

The widget launches your installed Codex CLI and uses its local [App Server](https://developers.openai.com/codex/app-server) method `account/rateLimits/read`. It reads `usedPercent`, `windowDurationMins`, `resetsAt`, and the plan label when the service returns it. Codex Desktop and native Codex on Windows use the same `%USERPROFILE%\.codex` home by default.

- No credentials are read, copied, logged, or uploaded.
- No reset credit is consumed.
- No Codex configuration or installation file is changed.
- `%LOCALAPPDATA%\CodexUsageCapsule\status.json` contains only local process state, the displayed quota text, timestamps, layout bounds, and the most recent App Server error.

See [SECURITY.md](SECURITY.md) for the trust boundary.

## Appearance and interaction

- Light, Dark, or System appearance; the choice is stored locally.
- System follows Windows appearance, not Codex's internal theme preference.
- Click the capsule to open or close it; click elsewhere or press Esc to close.
- The widget is visible only while an eligible Codex Desktop window is foreground.
- `Start at sign-in` enables or disables the existing scheduled task. Turning it off does not close the current widget.

## Development

Run the local test suite:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test.ps1 -RequireInstalledCodex
```

The default CI suite does not require Codex Desktop or Codex CLI. `-RequireInstalledCodex` adds local discovery of a callable Codex CLI.

## Known limitations

- Windows Desktop only; no macOS implementation yet.
- Title-bar anchoring depends on Windows UI Automation. Common Help-menu translations are recognized, with a bounded top-row fallback for other locales.
- Codex Desktop UI or App Server changes may require a compatibility update.
- The widget is an external no-activation WPF window visually attached to Codex; it is not an injected or native Codex control.

## License

[MIT](LICENSE)
