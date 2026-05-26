# Tally

A macOS menu-bar app that tallies how many tokens / requests you've spent on
each AI tool (Claude Code, Codex, Gemini, Copilot) by reading **local log files
only** — no API keys, no logins, no network calls.

## Status — Phase 1 (MVP)

| Provider | Window                  | Status |
|----------|-------------------------|--------|
| Claude   | 5-hour session          | ✅      |
| Claude   | Weekly (all models)     | ✅      |
| Claude   | Weekly (Sonnet only)    | ✅      |
| Gemini   | Daily request count     | ⏳ Phase 2 |
| Codex    | Weekly token sum        | ⏳ Phase 2 |
| Copilot  | Monthly premium reqs    | ⏳ Phase 2 |

## Build & run

```bash
./Scripts/bundle.sh
open ./build/Tally.app
```

Requires Xcode command-line tools + Swift 6 (`swift --version`) and macOS 14+.

## Dev loop

```bash
swift build            # type-check / compile only
./Scripts/bundle.sh    # produce Tally.app
```

## Architecture

```
Sources/Tally/
├── TallyApp.swift            # @main + MenuBarExtra scene
├── Models/                   # Provider, UsageWindow, UsageSnapshot
├── DataSources/              # per-provider readers (parse local logs)
├── Services/                 # UsageStore (@Observable) + RefreshScheduler
└── Views/                    # SwiftUI views for the menu popover
```

## Limits

Token limits per plan aren't published by Anthropic/Google/OpenAI/GitHub, so
Tally ships with rough defaults you can tune in Settings (Phase 3). For now
they live in `ClaudeUsageReader.Limits`.
