# Security

## Trust boundary

Codex Usage Capsule is a local current-user process. It launches a separately installed, user-callable Codex CLI, communicates with that process over redirected standard input/output, and displays rate-limit fields returned by Codex App Server. It never executes or copies binaries from the packaged Codex Desktop installation.

It must not read credential files, request API keys, modify Codex files, consume reset credits, inject code into Codex, or send telemetry.

The installer writes only to its selected install directory, a `CodexUsageCapsule` current-user scheduled task, and `%LOCALAPPDATA%\CodexUsageCapsule`. The uninstaller requires a matching installation marker before deleting the install directory and validates task ownership before unregistering it.

## Reporting a vulnerability

Please open a GitHub security advisory or contact the repository owner privately. Do not include credentials, tokens, or private account data in a public issue.
