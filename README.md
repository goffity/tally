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
3. **Clear the Gatekeeper quarantine flag** — Tally is not yet signed with an
   Apple Developer ID, and on macOS 15.4+ the right-click → Open bypass is
   gone. Run this once after install:
   ```sh
   xattr -dr com.apple.quarantine /Applications/Tally.app
   ```
   After this, double-click `Tally.app` opens it normally. See
   [issue #7](https://github.com/goffity/tally/issues/7) for context and a
   GUI alternative via System Settings → Privacy & Security.
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

## Branching & release flow

```
feature/*  ─┐
fix/*      ─┼──►  develop  ──►  main  ──►  auto-tag + release
chore/*    ─┘                      │
                                   └──►  manual `git tag vX.Y.Z` also works
```

- **`develop`** is the default branch and integration target. Branch off it
  for any work: `feature/<short-name>`, `fix/<short-name>`, etc.
- Open PRs into `develop`. Merge when CI is green.
- When ready to ship, open a PR from `develop` → `main`. Merging it triggers
  [`release.yml`](.github/workflows/release.yml), which parses conventional
  commits since the last tag and:
    - bumps **minor** for any `feat:` commit,
    - bumps **patch** for `fix:` or `perf:`,
    - bumps **major** if any commit has a `BREAKING CHANGE:` footer,
    - **skips releasing** if all commits are housekeeping
      (`chore:`, `ci:`, `docs:`, `refactor:`, `style:`, `test:`).
- The workflow then builds `Tally.app`, stamps the new version, packages
  `Tally-<version>.zip` + `Tally-<version>.dmg`, creates the matching
  `vX.Y.Z` tag, and publishes a GitHub Release with auto-generated notes.
- For a hotfix or pre-release, you can still bypass `develop` by pushing a
  tag directly: `git tag v0.2.1 && git push --tags`.

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
