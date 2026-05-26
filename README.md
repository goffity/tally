# Tally

[![build](https://github.com/goffity/tally/actions/workflows/build.yml/badge.svg)](https://github.com/goffity/tally/actions/workflows/build.yml)

A macOS menu-bar app that tallies how many tokens / requests you've spent on
each AI tool (Claude Code, Codex, Gemini, Copilot) by reading **local log files
only** — no API keys, no logins, no network calls.

## Providers

| Provider | Window                          | Source                                          |
|----------|----------------------------------|-------------------------------------------------|
| Claude   | 5h session, weekly, weekly Sonnet | `~/.claude/projects/**/*.jsonl`                |
| Codex    | 5h + 7d (Codex's own rate_limits) | `~/.codex/sessions/**/*.jsonl`                 |
| Gemini   | Rolling 24-hour requests         | `~/.gemini/tmp/**/chats/session-*.json`        |
| Copilot  | Monthly premium requests         | `~/.copilot/session-state/**/events.jsonl`     |

## Install

Pre-built downloads live on the [Releases](https://github.com/goffity/tally/releases)
page (DMG or `.app.zip`).

1. Download `Tally-<version>.dmg` (or `.zip`).
2. Move `Tally.app` into `/Applications`.
3. **First launch:** right-click → Open. macOS Gatekeeper will warn that the
   app is unsigned; clicking Open whitelists it. From then on, double-click
   works normally.
4. Optionally enable launch-at-login from Tally → Settings → General.

## Build from source

```bash
./Scripts/bundle.sh
open ./build/Tally.app
```

Requires Xcode 16+ and Swift 6 (`swift --version`) on macOS 14+.

## Dev loop

```bash
swift build            # compile only
./Scripts/bundle.sh    # produce build/Tally.app
```

## Cutting a release

Releases are built and published automatically by
[`.github/workflows/release.yml`](.github/workflows/release.yml) on tag push.

```bash
git tag v0.1.0
git push --tags
```

That triggers CI to build `Tally.app`, stamp the version into `Info.plist`,
package both `Tally-<version>.zip` and `Tally-<version>.dmg`, and attach them
to a new GitHub Release with auto-generated release notes.

For a local dry-run without publishing:

```bash
VERSION=0.1.0 ./Scripts/dist.sh
ls build/
```

## Architecture

```
Sources/Tally/
├── TallyApp.swift            # @main + MenuBarExtra + Settings scene
├── Models/                   # Provider, UsageWindow, UsageSnapshot
├── DataSources/              # per-provider readers (parse local logs)
├── Services/                 # AppSettings, UsageStore, FileSystemWatcher,
│                             # RefreshScheduler, LaunchAtLoginService
└── Views/                    # SwiftUI views for popover + Settings window
```

## Limits

Token limits per plan aren't published by Anthropic/Google/OpenAI/GitHub, so
Tally ships with rough Max-plan defaults you can tune in Settings. Each Claude
limit has a "Calibrate from /usage" button that back-calculates the limit from
the percent Claude Code's own `/usage` reports.

Codex provides `rate_limits` directly in its JSONL — no calibration needed.
