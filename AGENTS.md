# AGENTS.md

## Repository expectations

- This is an unofficial, local-only Windows companion for Codex Desktop. Never claim OpenAI affiliation or native title-bar integration.
- Never read, copy, print, or persist API keys, ChatGPT tokens, browser cookies, or Codex credential files.
- Do not patch, inject into, copy from, or modify Codex Desktop files. Use a separately installed, user-callable Codex CLI and its read-only App Server rate-limit method.
- Keep quota rendering data-driven. Do not infer window counts or durations from plan names.
- Keep portable quota/model logic separate from Windows WPF, Win32, UI Automation, and Task Scheduler adapters.
- Installation must stay current-user, non-admin, idempotent, reversible, and hidden at sign-in.
- Before a commit, run `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test.ps1`.
- For Windows integration changes, also run `scripts\Test.ps1 -RequireInstalledCodex`, a temporary-root install/uninstall test, and a native foreground/resize/click smoke test when Codex Desktop is available.
- Never call a generated HTML prototype, a running PID, or a passing unit test native UI acceptance.
- Keep README requirements, privacy statements, limitations, and uninstall behavior synchronized with code.

## Code review rules

- Flag any path that can overwrite or delete a task or directory without first proving ownership.
- Flag any fallback that can place the overlay over Help, caption buttons, or outside the owning Codex window.
- Flag stale quota data presented as current, expired windows presented as reset, or absent data presented as 0%.
- Flag new network calls, credential access, telemetry, elevation, or external persistence.
